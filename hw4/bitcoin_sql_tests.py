import modal
import sqlite3
import os
from openai import OpenAI
from datetime import datetime

app = modal.App("bitcoin-sql-qa")
volume = modal.Volume.from_name("chongchen-bitcoin-data", create_if_missing=True)
image = modal.Image.debian_slim().pip_install("openai")

normal_test_cases = [
    {
        "question": "How many blocks are there between height 1000 and 10000?",
        "correct_sql": "SELECT COUNT(*) FROM block WHERE height BETWEEN 1000 AND 10000;"
    },
    {
        "question": "How many blocks have exactly 100 confirmations (for blocks below height 50000)?",
        "correct_sql": "SELECT COUNT(*) FROM block WHERE confirmations = 100 AND height < 50000;"
    },
    {
        "question": "What is the average difficulty of the first 1000 blocks?",
        "correct_sql": "SELECT AVG(difficulty) FROM block WHERE height <= 1000;"
    },
    {
        "question": "List the top 5 smallest blocks by size (where size > 0 bytes).",
        "correct_sql": "SELECT * FROM block WHERE size > 0 ORDER BY size ASC LIMIT 5;"
    },
    {
        "question": "What is the previous block hash of the block at height 60000?",
        "correct_sql": "SELECT previousblockhash FROM block WHERE height = 60000;"
    },
    {
        "question": "How many blocks have a nonce value between 1000 and 2000?",
        "correct_sql": "SELECT COUNT(*) FROM block WHERE nonce BETWEEN 1000 AND 2000;"
    },
    {
        "question": "What is the earliest timestamp (time) of a block with exactly 200 transactions?",
        "correct_sql": "SELECT MIN(time) FROM block WHERE ntx = 200;"
    },
    {
        "question": "What is the total weight of blocks mined in the last 1000 blocks?",
        "correct_sql": "SELECT SUM(weight) FROM block WHERE height >= 59000;"
    },
    {
        "question": "Which block has the highest difficulty among the first 1000 blocks?",
        "correct_sql": "SELECT * FROM block WHERE height <= 1000 ORDER BY difficulty DESC LIMIT 1;"
    },
    {
        "question": "List blocks where the merkleroot starts with '0000' (limited to 10).",
        "correct_sql": "SELECT * FROM block WHERE merkleroot LIKE '0000%' LIMIT 10;"
    }
]

hard_test_cases = [
    {
        "question": "Find the block where the difficulty increased by more than 10% compared to its previous block, but only if it was mined at least 2 hours after the median time of the prior 50 blocks. Include the percentage increase and the time difference.",
        "expected_sql": """
            WITH BlockPairs AS (
                SELECT 
                    b1.height AS current_height,
                    b1.difficulty AS current_difficulty,
                    b1.time AS current_time,
                    b2.difficulty AS prev_difficulty,
                    b2.time AS prev_time,
                    (SELECT AVG(b3.mediantime) 
                     FROM block b3 
                     WHERE b3.height BETWEEN b1.height - 50 AND b1.height - 1) AS prior_50_median
                FROM block b1
                JOIN block b2 ON b1.previousblockhash = b2.hash
            )
            SELECT 
                current_height,
                ((current_difficulty - prev_difficulty) / prev_difficulty) * 100 AS percent_increase,
                (current_time - prior_50_median) AS time_diff_seconds
            FROM BlockPairs
            WHERE (current_difficulty / prev_difficulty) > 1.10
            AND (current_time - prior_50_median) >= 7200
            LIMIT 1;
        """
    },
    {
        "question": "How many blocks contain at least 3 transactions where the first transaction’s input script contains the hex pattern 'deadbeef' and the last transaction’s output value exceeds 1 BTC?",
        "expected_sql": """
            SELECT COUNT(*)
            FROM block
            WHERE (
                SELECT COUNT(*)
                FROM json_each(block.tx) AS tx
                WHERE 
                    json_extract(tx.value, '$.inputs[0].script') LIKE '%deadbeef%'
                    AND (
                        SELECT json_extract(tx.value, '$.outputs[0].value')
                        FROM json_each(tx.value) 
                        ORDER BY CAST(json_extract(tx.value, '$.index') AS INT) DESC
                        LIMIT 1
                    ) > 100000000
            ) >= 3;
        """
    },
    {
        "question": "Identify the 10-block consecutive sequence (by height) with the steepest exponential increase in chainwork value, calculated as the sum of chainwork differences between adjacent blocks.",
        "expected_sql": """
            WITH ChainworkNumeric AS (
                SELECT 
                    height,
                    CAST(chainwork AS INTEGER) AS chainwork_num  -- Will FAIL in SQLite (hex-to-decimal)
                FROM block
            ),
            Diffs AS (
                SELECT
                    height,
                    chainwork_num - LAG(chainwork_num, 1) OVER (ORDER BY height) AS diff
                FROM ChainworkNumeric
            ),
            Windows AS (
                SELECT
                    height,
                    SUM(diff) OVER (ORDER BY height ROWS BETWEEN 9 PRECEDING AND CURRENT ROW) AS total_diff
                FROM Diffs
            )
            SELECT 
                height - 9 AS start_height,
                height AS end_height,
                total_diff
            FROM Windows
            ORDER BY total_diff DESC
            LIMIT 1;
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
def test_normal_cases(db_path = "/data/bitcoin.db"):
    conn = sqlite3.connect(db_path)
    for test_id, case in enumerate(normal_test_cases):
        question = case["question"]
        correct_sql = case["correct_sql"]
        
        # Get expected answer
        expected_answer, _ = execute_sql(conn, correct_sql)
        
        # Get system's response
        response = answer_question.remote(question, db_path)
        generated_sql = response["generated_sql"]
        generated_answer = response["result"]
        error = response["error"]
        
        # Build log content
        log_content = (
            f"Question: {question}\n"
            f"Correct SQL: {correct_sql}\n"
            f"Expected Answer: {expected_answer}\n"
            f"Generated SQL: {generated_sql}\n"
            f"Generated Answer: {generated_answer}\n"
        )
        if error:
            log_content += f"Error: {error}\n"
        
        log_test_result("normal", log_content, f"test_{test_id}")
    conn.close()

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

if __name__ == "__main__":
    with app.run():
        # Path to your SQLite database
        db_path = "/data/bitcoin.db"  
        
        # Run normal tests
        test_normal_cases.call(db_path)
        
        # Run hard tests
        test_hard_cases.call(db_path)