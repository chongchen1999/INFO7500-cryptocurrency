import modal
from fastapi import FastAPI, Request, Form
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import openai
import sqlite3
import os

app = modal.App(name="bitcoin-query-app")
volume = modal.Volume.from_name("chongchen-bitcoin-data", create_if_missing=True)
bitcoin_image = (
    modal.Image.debian_slim()
    .pip_install("openai", "fastapi", "jinja2", "python-multipart")
    .add_local_dir("templates", remote_path="/root/templates")
    .add_local_dir("static", remote_path="/root/static")
)

DB_PATH = "/data/bitcoin.db"
OPENAI_SECRET = modal.Secret.from_name("openai-api-key")

web_app = FastAPI()
templates = Jinja2Templates(directory="templates")
web_app.mount("/static", StaticFiles(directory="static"), name="static")

@web_app.get("/", response_class=HTMLResponse)
async def read_root(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@web_app.post("/query", response_class=HTMLResponse)
async def handle_query(request: Request, question: str = Form(...)):
    try:
        # Generate SQL
        generated_sql = generate_sql(question)
        
        # Execute query
        results = execute_query(generated_sql)
        
        # Get database info
        db_info = get_database_info()
        
        return templates.TemplateResponse("index.html", {
            "request": request,
            "question": question,
            "sql": generated_sql,
            "results": results,
            "db_info": db_info
        })
    except Exception as e:
        return templates.TemplateResponse("index.html", {
            "request": request,
            "error": str(e),
            "question": question
        })

@app.function(
    volumes={"/data": volume},
    image=bitcoin_image,
    secrets=[OPENAI_SECRET],
    keep_warm=1
)
def generate_sql(question: str) -> str:
    openai.api_key = os.environ["OPENAI_API_KEY"]
    
    schema = """
    CREATE TABLE block (
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
    """
    
    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[{
            "role": "system",
            "content": f"Convert this natural language question into a SQL query for the following schema. Only respond with SQL, no explanation.\n\nSchema:\n{schema}"
        }, {
            "role": "user",
            "content": question
        }]
    )
    
    return response.choices[0].message.content.strip()

@app.function(
    volumes={"/data": volume},
    image=bitcoin_image,
    keep_warm=1
)
def execute_query(sql: str) -> list:
    with sqlite3.connect(DB_PATH) as conn:
        cursor = conn.cursor()
        cursor.execute(sql)
        results = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]
        return {"columns": columns, "data": results}

@app.function(
    volumes={"/data": volume},
    image=bitcoin_image,
    keep_warm=1
)
def get_database_info() -> dict:
    with sqlite3.connect(DB_PATH) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM block")
        block_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT MAX(height) FROM block")
        max_height = cursor.fetchone()[0]
        
        return {
            "block_count": block_count,
            "max_height": max_height,
            "database_size": os.path.getsize(DB_PATH)
        }

@app.function(
    mounts=[
        modal.Mount.from_local_dir("templates", remote_path="/root/templates"),
        modal.Mount.from_local_dir("static", remote_path="/root/static")
    ]
)
@modal.asgi_app()
def fastapi_app():
    return web_app