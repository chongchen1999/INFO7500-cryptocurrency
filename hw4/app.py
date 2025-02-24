import os
import sqlite3
import json
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import modal
import openai

app = modal.App(name="bitcoin-explorer-webapp")
volume = modal.Volume.from_name("chongchen-bitcoin-data")

DB_PATH = "/root/bitcoin.db"
SCHEMA_DESCRIPTION = """
Database Schema for Bitcoin Blockchain:
- block table:
  id (INTEGER): Auto-incrementing primary key
  hash (VARCHAR): Block hash
  confirmations (INTEGER): Number of confirmations
  height (INTEGER): Block height
  version (INTEGER): Block version
  versionhex (VARCHAR): Version in hexadecimal
  merkleroot (VARCHAR): Merkle root hash
  time (INTEGER): Block timestamp
  mediantime (INTEGER): Median time
  nonce (INTEGER): Nonce value
  bits (VARCHAR): Bits field
  difficulty (REAL): Difficulty value
  chainwork (VARCHAR): Chain work value
  ntx (INTEGER): Number of transactions
  previousblockhash (VARCHAR): Previous block hash
  nextblockhash (VARCHAR): Next block hash
  strippedsize (INTEGER): Stripped size
  size (INTEGER): Full size
  weight (INTEGER): Block weight
  tx (JSON): Transactions list
"""

web_app = FastAPI()
templates = Jinja2Templates(directory="templates")
web_app.mount("/static", StaticFiles(directory="static"), name="static")

def generate_sql(question: str) -> str:
    prompt = f"""Convert this natural language question to SQL for the bitcoin blockchain database.
    Database schema: {SCHEMA_DESCRIPTION}
    Question: {question}
    Respond only with the SQL query, no explanations."""
    
    response = openai.ChatCompletion.create(
        model="gpt-3.5-turbo",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.1
    )
    return response.choices[0].message.content.strip()

def execute_query(sql: str):
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    
    try:
        cur.execute(sql)
        results = cur.fetchall()
        return [dict(row) for row in results]
    finally:
        conn.close()

@web_app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@web_app.post("/ask")
async def handle_query(request: Request):
    form_data = await request.form()
    question = form_data["question"]
    
    # Generate SQL
    sql = generate_sql(question)
    
    # Execute query
    results = execute_query(sql)
    
    return {
        "sql": sql,
        "results": results,
        "schema": SCHEMA_DESCRIPTION
    }

html_template = """
<!DOCTYPE html>
<html>
<head>
    <title>Bitcoin Blockchain Explorer</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        .section { margin-bottom: 30px; }
        pre { background: #f4f4f4; padding: 10px; overflow-x: auto; }
        input[type="text"] { width: 100%; padding: 8px; margin: 10px 0; }
        button { padding: 8px 16px; background: #007bff; color: white; border: none; cursor: pointer; }
    </style>
</head>
<body>
    <h1>Bitcoin Blockchain Explorer</h1>
    
    <div class="section">
        <h2>Ask a Question</h2>
        <form method="post" action="/ask">
            <input type="text" name="question" placeholder="Enter your question about Bitcoin blockchain...">
            <button type="submit">Ask</button>
        </form>
    </div>

    {% if sql %}
    <div class="section">
        <h2>Generated SQL</h2>
        <pre>{{ sql }}</pre>
    </div>
    {% endif %}

    {% if results %}
    <div class="section">
        <h2>Query Results</h2>
        <pre>{{ results|tojson(indent=2) }}</pre>
    </div>
    {% endif %}

    <div class="section">
        <h2>Database Structure</h2>
        <pre>{{ schema }}</pre>
    </div>
</body>
</html>
"""

@app.function(
    secrets=[modal.Secret.from_name("openai-api-key")],
    volumes={"/root/bitcoin.db": volume},
    allow_concurrent_inputs=20,
)
@modal.asgi_app()
def fastapi_app():
    # Create necessary directories and files
    os.makedirs("templates", exist_ok=True)
    os.makedirs("static", exist_ok=True)
    
    # Write the HTML template
    with open("templates/index.html", "w") as f:
        f.write(html_template)
    
    # Initialize OpenAI
    openai.api_key = os.environ["OPENAI_API_KEY"]
    
    return web_app