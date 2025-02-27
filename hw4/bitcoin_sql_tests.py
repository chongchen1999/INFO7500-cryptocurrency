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
        "question": "Find the block with the largest time difference from its parent (excluding genesis).",
        "expected_sql": """
            SELECT b1.height, (b1.time - b2.time) AS time_gap
            FROM block b1
            JOIN block b2 ON b1.previousblockhash = b2.hash
            WHERE b1.height <= 60000
            ORDER BY time_gap DESC
            LIMIT 1;
        """
    },
    {
        "question": "What is the average number of transactions (ntx) for blocks where the next block has more weight?",
        "expected_sql": """
            SELECT AVG(b1.ntx)
            FROM block b1
            JOIN block b2 ON b1.nextblockhash = b2.hash
            WHERE b2.weight > b1.weight
              AND b1.height <= 60000;
        """
    },
    {
        "question": "Which block (height > 1000) shares the same version as its parent and has the most transactions?",
        "expected_sql": """
            SELECT b1.height
            FROM block b1
            JOIN block b2 ON b1.previousblockhash = b2.hash
            WHERE b1.version = b2.version
              AND b1.height > 1000
            ORDER BY b1.ntx DESC
            LIMIT 1;
        """
    }
]

SYSTEM_PROMPT = """You are a SQL developer that is expert in Bitcoin and you answer natural \
    language questions about the bitcoind database in a sqlite database. \
        You always only respond with SQL statements that are correct."""

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
        response = answer_question(question, db_path)
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