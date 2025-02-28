import modal
import sqlite3
import os
from openai import OpenAI
from datetime import datetime

app = modal.App("bitcoin-sql-qa")
volume = modal.Volume.from_name("chongchen-bitcoin-data", create_if_missing=True)
image = modal.Image.debian_slim().pip_install("openai")

hard_test_cases = [
    {
        "question": "What is the median nonce value for blocks mined in February 2013?",
        "expected_sql": """
            SELECT AVG(nonce) 
            FROM (
                SELECT nonce 
                FROM block 
                WHERE strftime('%Y-%m', datetime(time, 'unixepoch')) = '2013-02' 
                ORDER BY nonce 
                LIMIT 2 - (
                    SELECT COUNT(*) 
                    FROM block 
                    WHERE strftime('%Y-%m', datetime(time, 'unixepoch')) = '2013-02'
                ) % 2 
                OFFSET (
                    SELECT COUNT(*) 
                    FROM block 
                    WHERE strftime('%Y-%m', datetime(time, 'unixepoch')) = '2013-02'
                ) / 2
            );
        """
    },
    {
        "question": "Analyze the 'fee market' development by calculating the implicit fee per transaction in satoshis for each block from 150000 to 160000. For this, estimate the mining reward by using the formula: (block_reward_bitcoins * 10^8 + (block_size - 80) * 10). Then calculate fee = (reward - expected_subsidy) / ntx where expected_subsidy is 50 BTC per block multiplied by 10^8 to convert to satoshis. Show the top 10 blocks with highest average fee per transaction, including block height, time (formatted as date), number of transactions, and average fee per transaction.",
        "expected_sql": """
            WITH block_rewards AS (
                SELECT
                    height,
                    hash,
                    ntx,
                    size,
                    datetime(time, 'unixepoch') AS block_date,
                    (size - 80) * 10 AS size_reward_satoshis,
                    CASE
                        WHEN height < 210000 THEN 5000000000 -- 50 BTC in satoshis
                        WHEN height < 420000 THEN 2500000000 -- 25 BTC in satoshis
                        WHEN height < 630000 THEN 1250000000 -- 12.5 BTC in satoshis
                        ELSE 625000000 -- 6.25 BTC in satoshis
                    END AS block_subsidy_satoshis
                FROM block
                WHERE height BETWEEN 150000 AND 160000 AND ntx > 1
            )
            SELECT
                height,
                hash,
                block_date,
                ntx,
                size,
                block_subsidy_satoshis,
                size_reward_satoshis,
                CASE
                    WHEN ntx > 1 THEN ROUND((size_reward_satoshis - block_subsidy_satoshis) / (ntx - 1), 2)
                    ELSE 0
                END AS avg_fee_per_tx_satoshis
            FROM block_rewards
            ORDER BY avg_fee_per_tx_satoshis DESC
            LIMIT 10;
        """
    },
    {
        "question": "Calculate the mining difficulty adjustment pattern by finding the percentage change in difficulty between each difficulty adjustment period (every 2016 blocks) from block 50000 to 100000. Show the starting block of each period, the average block time in minutes for that period, and the percentage difficulty change.",
        "expected_sql": """
            WITH adjustment_periods AS (
                SELECT 
                    height, 
                    difficulty,
                    time,
                    height / 2016 AS period_number
                FROM block 
                WHERE height BETWEEN 50000 AND 100000
            ),
            period_stats AS (
                SELECT 
                    period_number,
                    MIN(height) AS start_block,
                    MAX(difficulty) AS difficulty,
                    (MAX(time) - MIN(time)) / (COUNT(*) - 1) / 60.0 AS avg_block_time_minutes,
                    LAG(MAX(difficulty)) OVER (ORDER BY period_number) AS prev_difficulty
                FROM adjustment_periods
                GROUP BY period_number
            )
            SELECT 
                start_block,
                avg_block_time_minutes,
                difficulty,
                prev_difficulty,
                CASE
                    WHEN prev_difficulty IS NULL THEN NULL
                    ELSE ROUND((difficulty - prev_difficulty) / prev_difficulty * 100, 2)
                END AS difficulty_change_percent
            FROM period_stats
            ORDER BY start_block;
        """
    }
]

SYSTEM_PROMPT = """
    You are a SQL developer that is expert in Bitcoin and you answer natural \
    language questions about the bitcoind database in a sqlite database. \
    You always only respond with SQL statements that are correct, \
    you just need to give the SQL statement, nothing extra.
"""

def get_schema(conn):
    """Extract schema from SQLite database."""
    cursor = conn.cursor()
    cursor.execute("SELECT sql FROM sqlite_master WHERE type IN ('table', 'view') AND sql IS NOT NULL")
    schemas = cursor.fetchall()
    return '\n'.join([schema[0] for schema in schemas])

def execute_sql(conn, sql):
    """Execute SQL query and return results or error."""
    try:
        cursor = conn.cursor()
        cursor.execute(sql)
        result = cursor.fetchall()
        return result, None
    except sqlite3.Error as e:
        return None, str(e)

def log_qa_history(volume, question, sql, result, error):
    """Log QA history to a file in the Modal Volume."""
    log_dir = "/data/qa_history"
    if not os.path.exists(log_dir):
        os.makedirs(log_dir, exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"{timestamp}.txt")
    
    log_content = f"Question: {question}\nGenerated SQL: {sql}\n"
    if error:
        log_content += f"Error: {error}\n"
    else:
        log_content += f"Result: {result}\n"
    
    with open(log_file, 'w') as f:
        f.write(log_content)
    
    volume.commit()  # Persist changes to the volume

@app.function(
    image=image,
    volumes={"/data": volume},
    secrets=[modal.Secret.from_name("chongchen-llm-api-key")]
)
def answer_question(question: str, db_path: str):
    conn = sqlite3.connect(db_path)
    schema = get_schema(conn)
    user_prompt = f"Database schema:\n{schema}\n\nQuestion: {question}"
    
    # Generate SQL
    llm_api_key = os.environ["DMX_API"]
    client = OpenAI(base_url="https://www.dmxapi.com/v1", api_key=llm_api_key)
    response = client.chat.completions.create(
        model="grok-3",
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt}
        ],
        temperature=0.2,
        max_tokens=500
    )
    generated_sql = response.choices[0].message.content.strip()
    
    # Execute SQL
    result, error = execute_sql(conn, generated_sql)
    conn.close()
    
    # Log history
    log_qa_history(volume, question, generated_sql, result, error)
    
    return {
        "generated_sql": generated_sql,
        "result": result,
        "error": error
    }

def log_test_result(test_type: str, content: str, filename: str):
    log_dir = f"/data/sql_tests/{test_type}"
    os.makedirs(log_dir, exist_ok=True)
    # timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"{filename}.txt")
    
    with open(log_file, 'w') as f:
        f.write(content)
    volume.commit()

@app.function(
    image=image,
    volumes={"/data": volume},
    secrets=[modal.Secret.from_name("chongchen-llm-api-key")]
)
def test_hard_cases(db_path = "/data/bitcoin.db"):
    conn = sqlite3.connect(db_path)
    for test_id, case in enumerate(hard_test_cases, start=1):
        question = case["question"]
        expected_sql = case["expected_sql"]
        
        # Get expected answer
        expected_answer, _ = execute_sql(conn, expected_sql)
        
        # Get system's response
        response = answer_question.remote(question, db_path)
        generated_sql = response["generated_sql"]
        generated_answer = response["result"]
        error = response["error"]
        
        # Build log content
        log_content = (
            f"Question: {question}\n"
            f"Expected SQL: {expected_sql}\n"
            f"Expected Answer: {expected_answer}\n"
            f"Generated SQL: {generated_sql}\n"
            f"Generated Answer: {generated_answer}\n"
        )
        if error:
            log_content += f"Error: {error}\n"
        
        log_test_result("hard", log_content, f"test_{test_id}")
    conn.close()