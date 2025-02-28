import modal
import sqlite3
import os
from openai import OpenAI
from datetime import datetime

app = modal.App("bitcoin-sql-qa")
volume = modal.Volume.from_name("chongchen-bitcoin-data", create_if_missing=True)
image = modal.Image.debian_slim().pip_install("openai")

test_cases = [
    {
        "question": "What is the hash of the genesis block (block at height 0)?",
        "expected_sql": "SELECT hash FROM block WHERE height = 0;"
    },
    {
        "question": "How many confirmations does block #100000 have?",
        "expected_sql": "SELECT confirmations FROM block WHERE height = 100000;"
    },
    {
        "question": "What is the average block size for blocks between height 50000 and 55000?",
        "expected_sql": "SELECT AVG(size) FROM block WHERE height BETWEEN 50000 AND 55000;"
    },
    {
        "question": "Which block has the highest difficulty between blocks 150000 and 160000?",
        "expected_sql": "SELECT hash, height, difficulty FROM block WHERE height BETWEEN 150000 AND 160000 ORDER BY difficulty DESC LIMIT 1;"
    },
    {
        "question": "How many transactions (ntx) were there in total across all blocks in the range 123000 to 123100?",
        "expected_sql": "SELECT SUM(ntx) FROM block WHERE height BETWEEN 123000 AND 123100;"
    },
    {
        "question": "What is the timestamp (time) of the latest block in the database?",
        "expected_sql": "SELECT time, height FROM block ORDER BY height DESC LIMIT 1;"
    },
    {
        "question": "Find the 5 blocks with the largest size difference compared to their previous block between heights 75000 and 80000.",
        "expected_sql": "SELECT b.height, b.hash, b.size, p.size AS prev_size, (b.size - p.size) AS size_diff FROM block b JOIN block p ON b.previousblockhash = p.hash WHERE b.height BETWEEN 75000 AND 80000 ORDER BY ABS(b.size - p.size) DESC LIMIT 5;"
    },
    {
        "question": "What was the average time (in seconds) between blocks from height 140000 to 140100?",
        "expected_sql": "WITH block_times AS (SELECT height, time, LAG(time) OVER (ORDER BY height) AS prev_time FROM block WHERE height BETWEEN 140000 AND 140100) SELECT AVG(time - prev_time) FROM block_times WHERE prev_time IS NOT NULL;"
    },
    {
        "question": "How many blocks have a nonce value greater than 3000000000 between heights 50000 and 60000?",
        "expected_sql": "SELECT COUNT(*) FROM block WHERE height BETWEEN 50000 AND 60000 AND nonce > 3000000000;"
    },
    {
        "question": "What is the distribution of block sizes by month in 2012? Show the month, average size, min size, and max size.",
        "expected_sql": "SELECT strftime('%Y-%m', datetime(time, 'unixepoch')) AS month, AVG(size) AS avg_size, MIN(size) AS min_size, MAX(size) AS max_size FROM block WHERE strftime('%Y', datetime(time, 'unixepoch')) = '2012' GROUP BY month ORDER BY month;"
    },
    {
        "question": "Find blocks where the difficulty increased by more than 10% compared to the previous block in the range 80000 to 90000.",
        "expected_sql": "SELECT b.height, b.hash, b.difficulty, p.difficulty AS prev_difficulty, (b.difficulty - p.difficulty)/p.difficulty*100 AS difficulty_increase_pct FROM block b JOIN block p ON b.previousblockhash = p.hash WHERE b.height BETWEEN 80000 AND 90000 AND (b.difficulty - p.difficulty)/p.difficulty > 0.1 ORDER BY difficulty_increase_pct DESC;"
    },
    {
        "question": "What is the correlation between block size and number of transactions (ntx) for blocks 100000 to 110000?",
        "expected_sql": "SELECT (COUNT(*) * SUM(size * ntx) - SUM(size) * SUM(ntx)) / (SQRT(COUNT(*) * SUM(size * size) - SUM(size) * SUM(size)) * SQRT(COUNT(*) * SUM(ntx * ntx) - SUM(ntx) * SUM(ntx))) AS correlation FROM block WHERE height BETWEEN 100000 AND 110000;"
    },
    {
        "question": "How has the average block size changed each year from 2009 to 2015?",
        "expected_sql": "SELECT strftime('%Y', datetime(time, 'unixepoch')) AS year, AVG(size) AS avg_size FROM block WHERE strftime('%Y', datetime(time, 'unixepoch')) BETWEEN '2009' AND '2015' GROUP BY year ORDER BY year;"
    },
    {
        "question": "Find the top 5 blocks with the most transactions (ntx) between height 160000 and 170000.",
        "expected_sql": "SELECT height, hash, ntx FROM block WHERE height BETWEEN 160000 AND 170000 ORDER BY ntx DESC LIMIT 5;"
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

def format_result_for_markdown(result):
    """Format SQL result for markdown display"""
    if not result or len(result) == 0:
        return "No results"
    
    # For single value results
    if len(result) == 1 and len(result[0]) == 1:
        return str(result[0][0])
    
    # For multi-row results, create a simplified representation
    if len(result) <= 5:
        return str(result)
    else:
        return f"{str(result[:5])}... (showing 5 of {len(result)} rows)"

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
        temperature=0.1,
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

@app.function(
    image=image,
    volumes={"/data": volume},
    secrets=[modal.Secret.from_name("chongchen-llm-api-key")]
)
def generate_markdown_report(db_path = "/data/bitcoin.db"):
    conn = sqlite3.connect(db_path)
    
    # Initialize markdown content
    markdown_content = "# Bitcoin Database Natural Language to SQL Test Results\n\n"
    markdown_content += "This report shows the results of testing natural language queries against a Bitcoin blockchain database.\n\n"
    markdown_content += "| # | Question | SQL Statement | Result |\n"
    markdown_content += "|---|---------|--------------|--------|\n"
    
    # Process each test case
    for idx, case in enumerate(test_cases, 1):
        question = case["question"]
        expected_sql = case["expected_sql"]
        
        # Execute SQL to get the answer
        result, error = execute_sql(conn, expected_sql)
        
        # Format result for markdown
        if error:
            result_text = f"ERROR: {error}"
        else:
            result_text = format_result_for_markdown(result)
        
        # Add to markdown table
        markdown_content += f"| {idx} | {question} | `{expected_sql}` | {result_text} |\n"
    
    conn.close()
    
    # Save the markdown file
    report_dir = "/data/reports"
    os.makedirs(report_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    report_file = os.path.join(report_dir, f"bitcoin_sql_report_{timestamp}.md")
    
    with open(report_file, 'w') as f:
        f.write(markdown_content)
    
    volume.commit()  # Persist changes to the volume
    
    print(f"Markdown report generated: {report_file}")
    return report_file

@app.function(
    image=image,
    volumes={"/data": volume},
    secrets=[modal.Secret.from_name("chongchen-llm-api-key")]
)
def run_tests_and_generate_report(db_path = "/data/bitcoin.db"):
    """Run all test cases and generate both individual test results and a comprehensive report"""
    # Run test cases
    conn = sqlite3.connect(db_path)
    
    # Initialize markdown content
    markdown_content = "# Bitcoin Database Natural Language to SQL Test Results\n\n"
    markdown_content += "This report shows the results of testing natural language queries against a Bitcoin blockchain database.\n\n"
    markdown_content += "## Test Case Results\n\n"
    
    for test_id, case in enumerate(test_cases, 1):
        question = case["question"]
        expected_sql = case["expected_sql"]
        
        # Get expected answer
        expected_result, expected_error = execute_sql(conn, expected_sql)
        
        # Get system's response (using LLM)
        response = answer_question.remote(question, db_path)
        generated_sql = response["generated_sql"]
        generated_result = response["result"]
        generated_error = response["error"]
        
        # Format results for markdown
        if expected_error:
            expected_result_text = f"ERROR: {expected_error}"
        else:
            expected_result_text = format_result_for_markdown(expected_result)
        
        if generated_error:
            generated_result_text = f"ERROR: {generated_error}"
        else:
            generated_result_text = format_result_for_markdown(generated_result)
        
        # Add section for this test case
        markdown_content += f"### Test Case {test_id}\n\n"
        markdown_content += f"**Question:** {question}\n\n"
        markdown_content += "**Expected SQL:**\n```sql\n{}\n```\n\n".format(expected_sql)
        markdown_content += f"**Expected Result:** {expected_result_text}\n\n"
        markdown_content += "**Generated SQL:**\n```sql\n{}\n```\n\n".format(generated_sql)
        markdown_content += f"**Actual Result:** {generated_result_text}\n\n"
        
        # Add comparison
        if expected_error is None and generated_error is None:
            if str(expected_result) == str(generated_result):
                markdown_content += "✅ **Result Match**: The generated query produced the correct result.\n\n"
            else:
                markdown_content += "❌ **Result Mismatch**: The generated query produced a different result than expected.\n\n"
        else:
            markdown_content += "⚠️ **Error in Execution**: One or both queries produced an error.\n\n"
        
        markdown_content += "---\n\n"
    
    conn.close()
    
    # Save the markdown file
    report_dir = "/data/reports"
    os.makedirs(report_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    report_file = os.path.join(report_dir, f"bitcoin_sql_report_{timestamp}.md")
    
    with open(report_file, 'w') as f:
        f.write(markdown_content)
    
    volume.commit()  # Persist changes to the volume
    
    print(f"Comprehensive markdown report generated: {report_file}")
    return report_file

@app.function(
    image=image,
    volumes={"/data": volume},
    secrets=[modal.Secret.from_name("chongchen-llm-api-key")]
)
def generate_summary_table(db_path = "/data/bitcoin.db"):
    """Generate a single markdown file with just the summary table of all test cases"""
    conn = sqlite3.connect(db_path)
    
    # Initialize markdown content
    markdown_content = "# Bitcoin Database Natural Language to SQL Test Cases\n\n"
    markdown_content += "| # | Question | SQL Statement | Result |\n"
    markdown_content += "|---|---------|--------------|--------|\n"
    
    # Process each test case
    for idx, case in enumerate(test_cases, 1):
        question = case["question"]
        expected_sql = case["expected_sql"]
        
        # Execute SQL to get the answer
        result, error = execute_sql(conn, expected_sql)
        
        # Format result for markdown
        if error:
            result_text = f"ERROR: {error}"
        else:
            result_text = format_result_for_markdown(result)
        
        # Add to markdown table
        markdown_content += f"| {idx} | {question} | `{expected_sql}` | {result_text} |\n"
    
    conn.close()
    
    # Save the markdown file
    report_dir = "/data/reports"
    os.makedirs(report_dir, exist_ok=True)
    report_file = os.path.join(report_dir, "bitcoin_sql_summary.md")
    
    with open(report_file, 'w') as f:
        f.write(markdown_content)
    
    volume.commit()  # Persist changes to the volume
    
    print(f"Summary table report generated: {report_file}")
    return report_file

if __name__ == "__main__":
    with app.run():
        # Path to your SQLite database
        db_path = "/data/bitcoin.db"  
        
        # Generate the markdown report with all test cases in a single table
        generate_summary_table.call(db_path)
        
        # Optionally, run tests with LLM and generate detailed report
        # run_tests_and_generate_report.call(db_path)