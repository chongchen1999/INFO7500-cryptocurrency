import sqlite3
import json
from typing import List, Dict
import os
from fastapi import FastAPI, Request, Form
from fastapi.responses import HTMLResponse
import modal

app = modal.App("bitcoin-qa")
volume = modal.Volume.from_name("chongchen-bitcoin-data")
qa_history_volume = modal.Volume.from_name("chongchen-qa-history", create_if_missing=True)

image = modal.Image.debian_slim().pip_install("fastapi", "uvicorn", "openai")

# Define preset questions with varying difficulty levels
PRESET_QUESTIONS = [
    # Basic questions
    "What is the height of the latest block?",
    "How many total blocks are in the database?",
    "What is the average block size?",
    "What was the timestamp of the first block in the database?",
    "What is the total number of transactions across all blocks?",
    
    # Intermediate questions
    "Which block had the most transactions?",
    "What is the average difficulty over the last 100 blocks?",
    "How has the block size changed over time (comparing the first 100 and last 100 blocks)?",
    "What's the distribution of block weights in the database?",
    "What is the average time between blocks?",
    
    # Advanced questions (harder)
    "Which blocks had unusual nonce values (statistical outliers)?",
    "What is the correlation between block difficulty and the number of transactions?",
    "Can you identify patterns in hash difficulty changes that might indicate mining algorithm adjustments?"
]

# Function to translate natural language to SQL using OpenAI API
@app.function(image=image, secrets=[modal.Secret.from_name("openai-api-key")])
def translate_to_sql(question: str) -> str:
    import openai
    client = openai.Client(api_key=os.environ["OPENAI_API_KEY"])
    
    prompt = f"""
    Given this SQLite database schema for Bitcoin blockchain data:
    
    CREATE TABLE IF NOT EXISTS block (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hash VARCHAR(255) NOT NULL,
        confirmations INTEGER NOT NULL,
        height INTEGER NOT NULL,
        version INTEGER NOT NULL,
        versionhex VARCHAR(255) NOT NULL,
        merkleroot VARCHAR(255) NOT NULL,
        time INTEGER NOT NULL,
        mediantime INTEGER NOT NULL,
        nonce INTEGER NOT NULL,
        bits VARCHAR(255) NOT NULL,
        difficulty REAL NOT NULL,
        chainwork VARCHAR(255) NOT NULL,
        ntx INTEGER NOT NULL,
        previousblockhash VARCHAR(255) NOT NULL,
        nextblockhash VARCHAR(255) NOT NULL,
        strippedsize INTEGER NOT NULL,
        size INTEGER NOT NULL,
        weight INTEGER NOT NULL,
        tx JSON NOT NULL
    );
    
    Convert the following natural language question to a SQL query:
    "{question}"
    
    Return ONLY the SQL statement without any explanation and format, that means no "```sql ```"
    """
    
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": "You are a helpful assistant that translates natural language questions to SQL queries. Return ONLY the SQL query without any explanation."},
            {"role": "user", "content": prompt}
        ],
        temperature=0.1
    )
    
    result = response.choices[0].message.content.strip()
    print(result)
    return result

@app.function(image=image, volumes={"/data": volume})
def execute_query(sql: str) -> List[Dict]:
    """Execute SQL query against the Bitcoin blockchain database."""
    conn = sqlite3.connect("/data/bitcoin.db")
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    try:
        cursor.execute(sql)
        result = [dict(row) for row in cursor.fetchall()]
    except sqlite3.Error as e:
        conn.close()
        raise ValueError(f"SQL Error: {str(e)}")
    
    conn.close()
    return result

@app.function(
    image=image, 
    volumes={"/bitcoin-explorer": volume}, 
    secrets=[modal.Secret.from_name("openai-api-key")]
)
def process_question(question: str) -> Dict:
    """Process a single question and return the results."""

    history_path = "/bitcoin-explorer/history.txt"

    try:
        sql = translate_to_sql.remote(question)
        result = execute_query.remote(sql)

        return_result = {
            "question": question,
            "sql": sql,
            "result": result,
            "error": None
        }

        with open(history_path, "a") as f:
            f.write(json.dumps(return_result) + "\n")

        return return_result
    except Exception as e:
        return {
            "question": question,
            "sql": sql if 'sql' in locals() else "Error generating SQL",
            "result": None,
            "error": str(e)
        }

@app.function(
    image=image, 
    volumes={"/data": volume}, 
    secrets=[modal.Secret.from_name("openai-api-key")]
)
def generate_all_qa_pairs() -> List[Dict]:
    """Generate Q&A pairs for all preset questions."""
    results = []
    for question in PRESET_QUESTIONS:
        results.append(process_question.remote(question))
    return results

def generate_qa_html(qa_pairs):
    """Generate HTML for Q&A pairs."""
    html = ""
    for qa in qa_pairs:
        html += f"""
        <div class="card">
            <div class="question">{qa['question']}</div>
            <div class="sql"><code>{qa['sql']}</code></div>
            {'<div class="error">Error: '+qa['error']+'</div>' if qa['error'] else f'<div class="result"><pre>{json.dumps(qa["result"], indent=2)}</pre></div>'}
        </div>
        """
    return html

@app.function(
    image=image,
    volumes={"/data": volume}, 
    secrets=[modal.Secret.from_name("openai-api-key")]
)
@modal.web_endpoint(method="GET")
def index():
    """Web interface for Bitcoin blockchain Q&A."""
    # Generate preset Q&A pairs
    qa_pairs = generate_all_qa_pairs.remote()
    
    # Simplified HTML content
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Bitcoin Blockchain Q&A</title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body { font-family: sans-serif; margin: 0; padding: 20px; }
            h1 { text-align: center; }
            .container { max-width: 1000px; margin: 0 auto; }
            .card { background: white; border: 1px solid #ddd; border-radius: 5px; padding: 20px; margin-bottom: 20px; }
            .question { font-weight: bold; margin-bottom: 10px; }
            .sql { background: #f5f5f5; padding: 10px; border-radius: 5px; margin-bottom: 10px; overflow-x: auto; }
            pre { white-space: pre-wrap; margin: 0; }
            .result { background: #f5f5f5; padding: 10px; border-radius: 5px; overflow-x: auto; }
            .error { background: #ffebee; color: #c62828; padding: 10px; border-radius: 5px; }
            .section { margin-bottom: 30px; }
            form { display: flex; margin-bottom: 20px; }
            input[type="text"] { flex-grow: 1; padding: 8px; margin-right: 10px; }
            button { background: #2196F3; color: white; border: none; padding: 8px 15px; border-radius: 5px; cursor: pointer; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Bitcoin Blockchain Q&A</h1>
            
            <form action="/query" method="post">
                <input type="text" name="question" placeholder="Enter your Bitcoin blockchain question..." required>
                <button type="submit">Ask</button>
            </form>
            
            <div class="section">
                <h2>Basic Questions</h2>
                {basic_questions}
            </div>
            
            <div class="section">
                <h2>Intermediate Questions</h2>
                {intermediate_questions}
            </div>
            
            <div class="section">
                <h2>Advanced Questions</h2>
                {advanced_questions}
            </div>
        </div>
    </body>
    </html>
    """.format(
        basic_questions=generate_qa_html(qa_pairs[:5]),
        intermediate_questions=generate_qa_html(qa_pairs[5:10]),
        advanced_questions=generate_qa_html(qa_pairs[10:])
    )
    
    return HTMLResponse(content=html_content)

@app.function(
    image=image,
    volumes={"/data": volume}, 
    secrets=[modal.Secret.from_name("openai-api-key")]
)
@modal.web_endpoint(method="POST")
async def query(request: Request):
    """Handle user query from form submission."""
    form_data = await request.form()
    user_question = form_data.get("question", "")
    
    if user_question:
        result = process_question.remote(user_question)
        
        html_content = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Bitcoin Blockchain Q&A</title>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { font-family: sans-serif; margin: 0; padding: 20px; }
                h1, h2 { text-align: center; }
                .container { max-width: 1000px; margin: 0 auto; }
                .card { background: white; border: 1px solid #ddd; border-radius: 5px; padding: 20px; margin-bottom: 20px; }
                .question { font-weight: bold; margin-bottom: 10px; }
                .sql { background: #f5f5f5; padding: 10px; border-radius: 5px; margin-bottom: 10px; overflow-x: auto; }
                pre { white-space: pre-wrap; margin: 0; }
                .result { background: #f5f5f5; padding: 10px; border-radius: 5px; overflow-x: auto; }
                .error { background: #ffebee; color: #c62828; padding: 10px; border-radius: 5px; }
                .back-button { display: block; margin: 20px auto; background: #2196F3; color: white; border: none; padding: 8px 15px; border-radius: 5px; cursor: pointer; text-decoration: none; text-align: center; width: 100px; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>Bitcoin Blockchain Q&A</h1>
                
                <div class="card">
                    <h2>Your Question</h2>
                    <div class="question">{question}</div>
                    <h3>SQL Query</h3>
                    <div class="sql"><code>{sql}</code></div>
                    {result_or_error}
                </div>
                
                <a href="/" class="back-button">Back</a>
            </div>
        </body>
        </html>
        """.format(
            question=result["question"],
            sql=result["sql"],
            result_or_error=(
                f'<div class="error">Error: {result["error"]}</div>' 
                if result["error"] else 
                f'<h3>Result</h3><div class="result"><pre>{json.dumps(result["result"], indent=2)}</pre></div>'
            )
        )
        
        return HTMLResponse(content=html_content)
    
    return HTMLResponse(content="No question provided", status_code=400)