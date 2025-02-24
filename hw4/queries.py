import sqlite3
import json
from typing import List, Dict, Any, Tuple
from fastapi import FastAPI, Request, Form
from fastapi.responses import HTMLResponse
import openai
import os
from modal import App, Volume, web_endpoint, Secret
import modal

app = App("static_bitcoin_explorer")
volume = Volume.from_name("chongchen-bitcoin-data")
image = modal.Image.debian_slim().pip_install("fastapi[standard]")


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

class QueryResult:
    def __init__(self, question, sql, result=None, error=None):
        self.question = question
        self.sql = sql
        self.result = result
        self.error = error

# Function to translate natural language to SQL using OpenAI API
@app.function(secrets=[Secret.from_name("openai-api-key")])
def translate_to_sql(question: str) -> str:
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
    
    Return ONLY the SQL statement without any explanation.
    """
    
    response = client.chat.completions.create(
        model="gpt-4-turbo",
        messages=[
            {"role": "system", "content": "You are a helpful assistant that translates natural language questions to SQL queries. Return ONLY the SQL query without any explanation."},
            {"role": "user", "content": prompt}
        ],
        temperature=0.1
    )
    
    return response.choices[0].message.content.strip()

@app.function(volumes={"/data": volume})
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

@app.function(volumes={"/data": volume}, secrets=[Secret.from_name("openai-api-key")])
def generate_all_qa_pairs() -> List[Dict]:
    """Generate Q&A pairs for all preset questions."""
    results = []
    
    for question in PRESET_QUESTIONS:
        try:
            sql = translate_to_sql.remote(question)
            query_result = execute_query.remote(sql)
            results.append({
                "question": question,
                "sql": sql,
                "result": query_result,
                "error": None
            })
        except Exception as e:
            results.append({
                "question": question,
                "sql": sql if 'sql' in locals() else "Error generating SQL",
                "result": None,
                "error": str(e)
            })
    
    return results

@app.function(volumes={"/data": volume}, secrets=[Secret.from_name("openai-api-key")])
@modal.web_endpoint()
def bitcoin_qa_web_interface(request: Request):
    """Web interface for Bitcoin blockchain Q&A."""
    current_qa = None
    
    # Generate preset Q&A pairs
    preset_qa_pairs = generate_all_qa_pairs.remote()
    
    # Render HTML template
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Bitcoin Blockchain Q&A</title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <script src="https://cdn.tailwindcss.com"></script>
    </head>
    <body class="bg-gray-100 p-8">
        <div class="max-w-6xl mx-auto">
            <h1 class="text-3xl font-bold mb-8 text-center">Bitcoin Blockchain Q&A</h1>
            
            <!-- User Question Form -->
            <div class="bg-white shadow-md rounded-lg p-6 mb-8">
                <h2 class="text-xl font-semibold mb-4">Ask a Question</h2>
                <form method="POST" class="flex gap-4">
                    <input 
                        type="text" 
                        name="question" 
                        placeholder="Enter your Bitcoin blockchain question..." 
                        class="flex-grow p-2 border rounded"
                        required
                    >
                    <button type="submit" class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">
                        Submit
                    </button>
                </form>
            </div>
            
            <!-- Preset Questions -->
            <div class="bg-white shadow-md rounded-lg p-6">
                <h2 class="text-xl font-semibold mb-6">Preset Bitcoin Blockchain Questions</h2>
                
                <!-- Basic Questions -->
                <div class="mb-8">
                    <h3 class="text-lg font-medium mb-4 border-b pb-2">Basic Questions</h3>
                    {generate_qa_html(preset_qa_pairs[:5])}
                </div>
                
                <!-- Intermediate Questions -->
                <div class="mb-8">
                    <h3 class="text-lg font-medium mb-4 border-b pb-2">Intermediate Questions</h3>
                    {generate_qa_html(preset_qa_pairs[5:10])}
                </div>
                
                <!-- Advanced Questions -->
                <div>
                    <h3 class="text-lg font-medium mb-4 border-b pb-2">Advanced Questions</h3>
                    {generate_qa_html(preset_qa_pairs[10:])}
                </div>
            </div>
        </div>
    </body>
    </html>
    """
    
    # Helper function to generate HTML for Q&A pairs
    def generate_qa_html(qa_pairs):
        html = ""
        for qa in qa_pairs:
            html += f"""
            <div class="mb-6 pb-6 border-b border-gray-200 last:border-0">
                <h4 class="font-medium mb-2">{qa['question']}</h4>
                <p class="text-sm text-gray-600 mb-2">SQL: <code>{qa['sql']}</code></p>
                
                {'<div class="bg-red-100 border-l-4 border-red-500 p-4"><p class="text-red-700">Error: '+qa['error']+'</p></div>' if qa['error'] else f'<div class="overflow-x-auto"><pre class="bg-gray-100 p-3 rounded text-sm">{json.dumps(qa["result"], indent=2)}</pre></div>'}
            </div>
            """
        return html
    
    # Return HTML response
    return HTMLResponse(content=html_content)

@app.function(
        volumes={"/data": volume}, 
        secrets=[Secret.from_name("openai-api-key")]
)
@modal.web_endpoint()
async def handle_query(request: Request):
    """Handle user query from form submission."""
    if request.method == "POST":
        form_data = await request.form()
        user_question = form_data.get("question", "")
        
        if user_question:
            try:
                sql = translate_to_sql.remote(user_question)
                result = execute_query.remote(sql)
                return HTMLResponse(content=f"""
                <div class="bg-white shadow-md rounded-lg p-6 mb-8">
                    <h2 class="text-xl font-semibold mb-2">Your Question</h2>
                    <p class="mb-4">{user_question}</p>
                    
                    <h3 class="font-medium mb-2">SQL Query</h3>
                    <pre class="bg-gray-100 p-3 rounded mb-4 overflow-x-auto">{sql}</pre>
                    
                    <h3 class="font-medium mb-2">Result</h3>
                    <div class="overflow-x-auto">
                        <pre class="bg-gray-100 p-3 rounded">{json.dumps(result, indent=2)}</pre>
                    </div>
                </div>
                """)
            except Exception as e:
                return HTMLResponse(content=f"""
                <div class="bg-white shadow-md rounded-lg p-6 mb-8">
                    <h2 class="text-xl font-semibold mb-2">Your Question</h2>
                    <p class="mb-4">{user_question}</p>
                    
                    <h3 class="font-medium mb-2">SQL Query</h3>
                    <pre class="bg-gray-100 p-3 rounded mb-4 overflow-x-auto">{sql if 'sql' in locals() else "Error generating SQL"}</pre>
                    
                    <div class="bg-red-100 border-l-4 border-red-500 p-4 mb-4">
                        <p class="text-red-700">Error: {str(e)}</p>
                    </div>
                </div>
                """)
    
    return HTMLResponse(content="Method not allowed", status_code=405)

if __name__ == "__main__":
    # For testing the function locally
    results = generate_all_qa_pairs.call()
    print(json.dumps(results, indent=2))