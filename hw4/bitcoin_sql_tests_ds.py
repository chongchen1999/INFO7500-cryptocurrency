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
        "question": "What is the total number of blocks?",
        "correct_sql": "SELECT COUNT(*) FROM block;"
    },
    {
        "question": "How many blocks have exactly 1000 confirmations?",
        "correct_sql": "SELECT COUNT(*) FROM block WHERE confirmations = 1000;"
    },
    {
        "question": "What is the average difficulty of blocks mined after January 1, 2023?",
        "correct_sql": "SELECT AVG(difficulty) FROM block WHERE time > 1672531200;"
    },
    {
        "question": "List the blocks with a strippedsize greater than 1MB (1,000,000 bytes).",
        "correct_sql": "SELECT * FROM block WHERE strippedsize > 1000000;"
    },
    {
        "question": "What is the next block hash of the block with height 700000?",
        "correct_sql": "SELECT nextblockhash FROM block WHERE height = 700000;"
    },
    {
        "question": "How many blocks have a nonce value starting with '12345'?",
        "correct_sql": "SELECT COUNT(*) FROM block WHERE CAST(nonce AS TEXT) LIKE '12345%';"
    },
    {
        "question": "What is the median time of the block with the maximum number of transactions?",
        "correct_sql": "SELECT mediantime FROM block WHERE ntx = (SELECT MAX(ntx) FROM block);"
    },
    {
        "question": "What is the total weight of all blocks in the database?",
        "correct_sql": "SELECT SUM(weight) FROM block;"
    },
    {
        "question": "Which block has the smallest size but the highest difficulty?",
        "correct_sql": "SELECT * FROM block ORDER BY size ASC, difficulty DESC LIMIT 1;"
    },
    {
        "question": "List blocks where the merkleroot starts with 'a1b2c3' and version is 4.",
        "correct_sql": "SELECT * FROM block WHERE merkleroot LIKE 'a1b2c3%' AND version = 4;"
    }
]

hard_test_cases = [
    {
        "question": "Find the block with the longest time gap between its mediantime and the previous block's mediantime.",
        "expected_sql": """
            SELECT b1.height, (b1.mediantime - b2.mediantime) AS time_gap
            FROM block b1
            JOIN block b2 ON b1.previousblockhash = b2.hash
            ORDER BY time_gap DESC
            LIMIT 1;
        """
    },
    {
        "question": "What is the average number of transactions per block for blocks where the next block's weight is at least 10% higher?",
        "expected_sql": """
            SELECT AVG(b1.ntx)
            FROM block b1
            JOIN block b2 ON b1.nextblockhash = b2.hash
            WHERE b2.weight >= b1.weight * 1.1;
        """
    },
    {
        "question": "Which block has the highest number of transactions (ntx) in the same version group as its parent block?",
        "expected_sql": """
            SELECT b1.height
            FROM block b1
            JOIN block b2 ON b1.previousblockhash = b2.hash
            WHERE b1.version = b2.version
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

def log_test_result(test_type: str, content: str):
    log_dir = f"/data/sql_tests/{test_type}"
    os.makedirs(log_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"{timestamp}.txt")
    
    with open(log_file, 'w') as f:
        f.write(content)
    volume.commit()

@app.function(
    image=image,
    volumes={"/data": volume},
    secrets=[modal.Secret.from_name("chongchen-llm-api-key")]
)
def test_normal_cases(db_path: str):
    conn = sqlite3.connect(db_path)
    for case in normal_test_cases:
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
        
        log_test_result("normal", log_content)
    conn.close()

@app.function(
    image=image,
    volumes={"/data": volume},
    secrets=[modal.Secret.from_name("chongchen-llm-api-key")]
)
def test_hard_cases(db_path: str):
    conn = sqlite3.connect(db_path)
    for case in hard_test_cases:
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
        
        log_test_result("hard", log_content)
    conn.close()

if __name__ == "__main__":
    with app.run():
        # Path to your SQLite database
        db_path = "/data/bitcoin.db"  
        
        # Run normal tests
        test_normal_cases.call(db_path)
        
        # Run hard tests
        # test_hard_cases.call(db_path)