import os
import json
import sqlite3
from typing import List, Dict, Any

import modal
from modal import App, Image, Mount, Volume, Secret
import openai
from fastapi import FastAPI, Request, Form
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

# Initialize Modal App and Volume
app = modal.App(name="bitcoin-explorer-webapp")
volume = modal.Volume.from_name("chongchen-bitcoin-data")

# Define the image - includes FastAPI, Jinja2 for templating
image = modal.Image.debian_slim().pip_install(
    "fastapi", 
    "jinja2", 
    "python-multipart", 
    "uvicorn", 
    "openai"
)

# Database related functions
@app.function(volumes={"/data": volume})
def get_db_schema():
    """Get the schema information from SQLite database"""
    conn = sqlite3.connect('/data/bitcoin.db')
    cursor = conn.cursor()
    cursor.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='block'")
    schema = cursor.fetchone()[0]
    conn.close()
    return schema

@app.function(volumes={"/data": volume})
def execute_query(sql: str) -> List[Dict[str, Any]]:
    """Execute SQL query and return results as a list of dictionaries"""
    conn = sqlite3.connect('/data/bitcoin.db')
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    try:
        cursor.execute(sql)
        results = [dict(row) for row in cursor.fetchall()]
        return results
    except sqlite3.Error as e:
        return [{"error": str(e)}]
    finally:
        conn.close()

# OpenAI function to convert natural language to SQL
@app.function(secrets=[Secret.from_name("openai-api-key")])
def generate_sql(query: str, schema: str) -> str:
    """Use OpenAI to convert natural language query to SQL"""
    openai.api_key = os.environ["OPENAI_API_KEY"]
    
    prompt = f"""
You are an SQL expert. Convert the following natural language query into a valid SQL query for a Bitcoin blockchain database.

Database Schema:
{schema}

User Query: {query}

Generate only the SQL statement, with no additional explanation. Make sure the SQL is valid for SQLite.
"""
    
    response = openai.chat.completions.create(
        model="gpt-4-turbo",
        messages=[
            {"role": "system", "content": "You are an SQL expert specializing in SQLite."},
            {"role": "user", "content": prompt}
        ],
        temperature=0.1
    )
    
    return response.choices[0].message.content.strip()

# Create templates directory structure
@app.function()
def setup_templates():
    os.makedirs("templates", exist_ok=True)
    
    # Create the main page template
    with open("templates/index.html", "w") as f:
        f.write("""
<!DOCTYPE html>
<html>
<head>
    <title>Bitcoin Blockchain Explorer</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .container { max-width: 900px; margin: 0 auto; }
        textarea { width: 100%; height: 100px; margin-bottom: 10px; }
        .box { border: 1px solid #ccc; padding: 10px; margin-bottom: 15px; background-color: #f9f9f9; }
        .results { white-space: pre-wrap; }
        button { padding: 8px 15px; background-color: #4CAF50; color: white; border: none; cursor: pointer; }
        h3 { margin-top: 20px; margin-bottom: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Bitcoin Blockchain Explorer</h1>
        
        <h3>Database Schema:</h3>
        <div class="box">
            <pre>{{ schema }}</pre>
        </div>
        
        <h3>Ask a question about Bitcoin blockchain:</h3>
        <form method="post">
            <textarea name="query" placeholder="E.g., What is the average block size in the last 10 blocks?">{{ query }}</textarea>
            <button type="submit">Submit</button>
        </form>
        
        {% if sql %}
        <h3>Generated SQL:</h3>
        <div class="box">
            <code>{{ sql }}</code>
        </div>
        {% endif %}
        
        {% if result %}
        <h3>Results:</h3>
        <div class="box results">
            {{ result }}
        </div>
        {% endif %}
    </div>
</body>
</html>
        """)
    return "Templates created successfully"

# Main entry point for the Modal web service
@app.function(
    image=image,
    volumes={"/data": volume},
    secrets=[Secret.from_name("openai-api-key")],
    mounts=[Mount.from_local_dir("templates", remote_path="/app/templates")],
)
@modal.asgi_app()
def serve_app():
    # Make sure templates exist
    setup_templates.remote()
    
    # Create a FastAPI instance
    web_app = FastAPI()
    
    # Add CORS middleware
    web_app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    # Set up templates directory
    templates = Jinja2Templates(directory="templates")
    
    @web_app.get("/", response_class=HTMLResponse)
    async def index(request: Request):
        """Render the main page"""
        schema = get_db_schema.remote()
        return templates.TemplateResponse(
            "index.html",
            {"request": request, "schema": schema, "query": "", "sql": "", "result": ""}
        )
    
    @web_app.post("/", response_class=HTMLResponse)
    async def process_query(request: Request, query: str = Form(...)):
        """Process user query, generate SQL, and show results"""
        schema = get_db_schema.remote()
        
        # Generate SQL using OpenAI
        sql = generate_sql.remote(query, schema)
        
        # Execute the generated SQL query
        results = execute_query.remote(sql)
        
        # Format the results for display
        result_text = json.dumps(results, indent=2)
        
        return templates.TemplateResponse(
            "index.html",
            {
                "request": request,
                "schema": schema,
                "query": query,
                "sql": sql,
                "result": result_text
            }
        )
    
    return web_app

if __name__ == "__main__":
    # For local development only
    app = FastAPI()
    # You would add routes here for local development
    uvicorn.run(app, host="0.0.0.0", port=8000)