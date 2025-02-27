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
        "question": "What is the median `ntx` value for blocks mined between 12:00 AM and 3:00 AM UTC, where the block's `chainwork` (hexadecimal) converted to decimal is greater than the average `chainwork` of all blocks in the same calendar week?",
        "expected_sql": """
            WITH WeeklyAvgChainwork AS (
                SELECT 
                    strftime('%Y-%W', datetime(time, 'unixepoch')) AS week,
                    AVG(CAST(chainwork AS INTEGER)) AS avg_chainwork_decimal
                FROM block
                GROUP BY week
            )
            SELECT 
                PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY ntx) AS median_ntx
            FROM block
            JOIN WeeklyAvgChainwork 
                ON strftime('%Y-%W', datetime(block.time, 'unixepoch')) = WeeklyAvgChainwork.week
            WHERE 
                CAST(strftime('%H', datetime(time, 'unixepoch')) AS INTEGER) BETWEEN 0 AND 2
                AND CAST(chainwork AS INTEGER) > avg_chainwork_decimal;
        """
    },
    {
        "question": "Find the longest consecutive sequence of blocks where each block's `mediantime` is within 10 minutes of the previous block's `mediantime`, and all blocks in the sequence have `version` 0x20000000.",
        "expected_sql": """
            WITH RECURSIVE Chain AS (
                SELECT 
                    height, 
                    mediantime, 
                    1 AS length
                FROM block
                WHERE version = 0x20000000
                UNION ALL
                SELECT 
                    b.height,
                    b.mediantime,
                    CASE WHEN ABS(b.mediantime - c.mediantime) <= 600 
                        THEN c.length + 1 ELSE 1 END
                FROM block b
                JOIN Chain c ON b.height = c.height + 1
                WHERE b.version = 0x20000000
            )
            SELECT MAX(length) FROM Chain;
        """
    },
    {
        "question": "How many blocks contain at least 3 transactions where: 1) The transaction has exactly 2 `vin` inputs, 2) At least one `vin` contains a `txid` with exactly 64 hexadecimal characters, and 3) The sum of `value` in `vout` is greater than 1 BTC?",
        "expected_sql": """
            SELECT COUNT(DISTINCT block.height)
            FROM block, json_each(block.tx) AS tx
            WHERE (
                SELECT COUNT(*)
                FROM json_each(json_extract(tx.value, '$.vin')) AS vin
                WHERE LENGTH(hex(vin.value->>'txid')) = 64
            ) >= 1
            AND json_array_length(json_extract(tx.value, '$.vin')) = 2
            AND (
                SELECT SUM(vout.value->>'value')
                FROM json_each(json_extract(tx.value, '$.vout')) AS vout
            ) > 100000000
            GROUP BY block.height
            HAVING COUNT(*) >= 3;
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
        # test_hard_cases.call(db_path)