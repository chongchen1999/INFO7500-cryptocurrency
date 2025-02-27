import modal
import sqlite3
import os
import json
from openai import OpenAI
from datetime import datetime

app = modal.App("bitcoin-sql-qa-test")
volume = modal.Volume.from_name("chongchen-bitcoin-data", create_if_missing=True)
image = modal.Image.debian_slim().pip_install("openai")

SYSTEM_PROMPT = """You are a SQL developer that is expert in Bitcoin and you answer natural \
    language questions about the bitcoind database in a sqlite database. \
        You always only respond with SQL statements that are correct."""

# List to store normal questions with expected SQL
normal_questions = [
    {
        "question": "What is the average block size in the database?",
        "expected_sql": "SELECT AVG(size) FROM block;"
    },
    {
        "question": "How many blocks have a difficulty greater than 1,000,000?",
        "expected_sql": "SELECT COUNT(*) FROM block WHERE difficulty > 1000000;"
    },
    {
        "question": "What are the top 5 blocks by size?",
        "expected_sql": "SELECT hash, size FROM block ORDER BY size DESC LIMIT 5;"
    },
    {
        "question": "What is the total number of transactions across all blocks?",
        "expected_sql": "SELECT SUM(ntx) FROM block;"
    },
    {
        "question": "What is the average time between blocks?",
        "expected_sql": "SELECT AVG(time - LAG(time) OVER (ORDER BY height)) FROM block;"
    },
    {
        "question": "What is the highest difficulty value in the database?",
        "expected_sql": "SELECT MAX(difficulty) FROM block;"
    },
    {
        "question": "How has the average block size changed over time? Group by every 1000 blocks.",
        "expected_sql": "SELECT (height / 1000) * 1000 AS block_group, AVG(size) AS avg_size FROM block GROUP BY block_group ORDER BY block_group;"
    },
    {
        "question": "What percentage of blocks have more than 2000 transactions?",
        "expected_sql": "SELECT (COUNT(*) * 100.0 / (SELECT COUNT(*) FROM block)) FROM block WHERE ntx > 2000;"
    },
    {
        "question": "Which block has the highest number of transactions?",
        "expected_sql": "SELECT hash, height, ntx FROM block ORDER BY ntx DESC LIMIT 1;"
    },
    {
        "question": "What is the median block size?",
        "expected_sql": "SELECT size FROM block ORDER BY size LIMIT 1 OFFSET (SELECT COUNT(*) FROM block) / 2;"
    }
]

# List to store hard questions with expected SQL and known issues
hard_questions = [
    {
        "question": "How has the block weight to size ratio evolved over time? Calculate for every 10000 blocks.",
        "expected_sql": "SELECT (height / 10000) * 10000 AS block_group, AVG(weight * 1.0 / size) AS weight_size_ratio FROM block GROUP BY block_group ORDER BY block_group;",
        "known_incorrect_sql": "SELECT height / 10000 AS block_group, AVG(weight / size) AS weight_size_ratio FROM block GROUP BY block_group ORDER BY block_group;"
    },
    {
        "question": "Calculate the correlation coefficient between block size and number of transactions.",
        "expected_sql": "SELECT (AVG(size * ntx) - AVG(size) * AVG(ntx)) / (SQRT(AVG(size * size) - AVG(size) * AVG(size)) * SQRT(AVG(ntx * ntx) - AVG(ntx) * AVG(ntx))) AS correlation FROM block;",
        "known_incorrect_sql": "SELECT AVG(size * ntx) - AVG(size) * AVG(ntx) FROM block;"
    },
    {
        "question": "Identify blocks where the nonce distribution is unusual (outside 3 standard deviations from the mean).",
        "expected_sql": "WITH stats AS (SELECT AVG(nonce) AS avg_nonce, SQRT(AVG(nonce * nonce) - AVG(nonce) * AVG(nonce)) AS stddev_nonce FROM block) SELECT hash, height, nonce FROM block, stats WHERE nonce > avg_nonce + 3 * stddev_nonce OR nonce < avg_nonce - 3 * stddev_nonce;",
        "known_incorrect_sql": "SELECT hash, height, nonce FROM block WHERE nonce > (SELECT AVG(nonce) + 3 * STDEV(nonce) FROM block) OR nonce < (SELECT AVG(nonce) - 3 * STDEV(nonce) FROM block);"
    }
]

@app.function(
    image=image,
    volumes={"/data": volume},
    secrets=[modal.Secret.from_name("chongchen-llm-api-key")]
)
def test_normal_cases(db_path: str):
    """Test the system with normal questions and record results."""
    # Create directory for test results if it doesn't exist
    test_dir = "/data/sql_tests/normal"
    os.makedirs(test_dir, exist_ok=True)
    
    # Connect to the database
    conn = sqlite3.connect(db_path)
    
    # Initialize results list
    results = []
    
    for idx, question_data in enumerate(normal_questions):
        question = question_data["question"]
        expected_sql = question_data["expected_sql"]
        
        # Generate SQL using the answer_question function
        response = answer_question.remote(question, db_path)
        generated_sql = response.get("generated_sql", "Error: No SQL generated")
        
        # Execute the expected SQL
        expected_result, expected_error = execute_sql(conn, expected_sql)
        
        # Execute the generated SQL
        actual_result, actual_error = None, None
        if "error" not in response or not response["error"]:
            actual_result = response.get("result", [])
        else:
            actual_error = response.get("error", "Unknown error")
        
        # Record the results
        result_entry = {
            "question": question,
            "expected_sql": expected_sql,
            "expected_result": expected_result,
            "expected_error": expected_error,
            "generated_sql": generated_sql,
            "actual_result": actual_result,
            "actual_error": actual_error
        }
        results.append(result_entry)
        
        # Save individual test result
        with open(os.path.join(test_dir, f"test_{idx+1}.json"), 'w') as f:
            json.dump(result_entry, f, indent=2)
    
    # Save all results to a summary file
    with open(os.path.join(test_dir, "summary.json"), 'w') as f:
        json.dump(results, f, indent=2)
    
    # Close the connection
    conn.close()
    
    # Commit changes to the volume
    volume.commit()
    
    return {"message": f"Completed {len(normal_questions)} normal test cases", "results": results}

@app.function(
    image=image,
    volumes={"/data": volume},
    secrets=[modal.Secret.from_name("chongchen-llm-api-key")]
)
def test_hard_cases(db_path: str):
    """Test the system with hard questions and record results."""
    # Create directory for test results if it doesn't exist
    test_dir = "/data/sql_tests/hard"
    os.makedirs(test_dir, exist_ok=True)
    
    # Connect to the database
    conn = sqlite3.connect(db_path)
    
    # Initialize results list
    results = []
    
    for idx, question_data in enumerate(hard_questions):
        question = question_data["question"]
        expected_sql = question_data["expected_sql"]
        known_incorrect_sql = question_data["known_incorrect_sql"]
        
        # Generate SQL using the answer_question function
        response = answer_question.call(question, db_path)
        generated_sql = response.get("generated_sql", "Error: No SQL generated")
        
        # Execute the expected SQL
        expected_result, expected_error = execute_sql(conn, expected_sql)
        
        # Execute the known incorrect SQL
        incorrect_result, incorrect_error = execute_sql(conn, known_incorrect_sql)
        
        # Execute the generated SQL
        actual_result, actual_error = None, None
        if "error" not in response or not response["error"]:
            actual_result = response.get("result", [])
        else:
            actual_error = response.get("error", "Unknown error")
        
        # Record the results
        result_entry = {
            "question": question,
            "expected_sql": expected_sql,
            "expected_result": expected_result,
            "expected_error": expected_error,
            "known_incorrect_sql": known_incorrect_sql,
            "incorrect_result": incorrect_result,
            "incorrect_error": incorrect_error,
            "generated_sql": generated_sql,
            "actual_result": actual_result,
            "actual_error": actual_error
        }
        results.append(result_entry)
        
        # Save individual test result
        with open(os.path.join(test_dir, f"test_{idx+1}.json"), 'w') as f:
            json.dump(result_entry, f, indent=2)
    
    # Save all results to a summary file
    with open(os.path.join(test_dir, "summary.json"), 'w') as f:
        json.dump(results, f, indent=2)
    
    # Close the connection
    conn.close()
    
    # Commit changes to the volume
    volume.commit()
    
    return {"message": f"Completed {len(hard_questions)} hard test cases", "results": results}

def execute_sql(conn, sql):
    """Execute SQL query and return results or error."""
    try:
        cursor = conn.cursor()
        cursor.execute(sql)
        result = cursor.fetchall()
        return result, None
    except sqlite3.Error as e:
        return None, str(e)

@app.function(
    image=image,
    volumes={"/data": volume},
    secrets=[modal.Secret.from_name("chongchen-llm-api-key")]
)
def answer_question(question: str, db_path: str):
    """Modified function to answer natural language questions and return both SQL and results."""
    # Connect to the database
    conn = sqlite3.connect(db_path)
    
    # Extract schema and prepare user prompt
    schema = get_schema(conn)
    user_prompt = f"Database schema:\n{schema}\n\nQuestion: {question}"
    
    # Generate SQL using OpenAI API
    llm_api_key = os.environ["DMX_API"]
    client = OpenAI(
        base_url="https://www.dmxapi.com/v1", 
        api_key=llm_api_key
    )
    
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
    
    # Execute the generated SQL
    result, error = execute_sql(conn, generated_sql)
    conn.close()
    
    # Log the interaction
    log_qa_history(volume, question, generated_sql, result, error)
    
    return {
        "generated_sql": generated_sql,
        "result": result, 
        "error": error
    }

def get_schema(conn):
    """Extract schema from SQLite database."""
    cursor = conn.cursor()
    cursor.execute("SELECT sql FROM sqlite_master WHERE type IN ('table', 'view') AND sql IS NOT NULL")
    schemas = cursor.fetchall()
    return '\n'.join([schema[0] for schema in schemas])

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
    volumes={"/data": volume}
)
def run_all_tests(db_path: str):
    """Run both normal and hard test cases."""
    normal_results = test_normal_cases.call(db_path)
    hard_results = test_hard_cases.call(db_path)
    
    return {
        "normal_tests": normal_results,
        "hard_tests": hard_results
    }