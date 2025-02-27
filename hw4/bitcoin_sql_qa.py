import modal
import sqlite3
import os
from openai import OpenAI
from datetime import datetime

app = modal.App("bitcoin-sql-qa")
volume = modal.Volume.from_name("chongchen-bitcoin-data", create_if_missing=True)
image = modal.Image.debian_slim().pip_install("openai")

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
    """Main function to answer natural language questions using the SQLite database."""
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
    
    return {"result": result, "error": error}

# Local testing entry point
if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Answer natural language questions about a Bitcoin SQLite database.")
    parser.add_argument("question", type=str, help="Natural language question")
    parser.add_argument("db_path", type=str, help="Absolute path to the SQLite database file")
    args = parser.parse_args()
    
    with app.run():
        answer = answer_question.remote(args.question, args.db_path)
        if answer["error"]:
            print(f"Error: {answer['error']}")
        else:
            print(f"Result: {answer['result']}")