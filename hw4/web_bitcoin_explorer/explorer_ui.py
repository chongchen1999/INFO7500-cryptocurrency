import modal
import sqlite3
import os

app = modal.App(name="bitcoin-query-app")
volume = modal.Volume.from_name("chongchen-bitcoin-data", create_if_missing=True)

# First create the image with all dependencies
bitcoin_image = (
    modal.Image.debian_slim()
    .pip_install(
        "openai", 
        "fastapi", 
        "jinja2", 
        "python-multipart",
        "uvicorn"  # Required for ASGI implementation
    )
    .add_local_dir("templates", remote_path="/root/templates")
    .add_local_dir("static", remote_path="/root/static")
)

DB_PATH = "/data/bitcoin.db"
OPENAI_SECRET = modal.Secret.from_name("openai-api-key")

# Move FastAPI creation inside a function to ensure proper dependency loading
def create_app():
    from fastapi import FastAPI, Request, Form
    from fastapi.responses import HTMLResponse
    from fastapi.staticfiles import StaticFiles
    from fastapi.templating import Jinja2Templates
    
    web_app = FastAPI()
    templates = Jinja2Templates(directory="/root/templates")
    web_app.mount("/static", StaticFiles(directory="/root/static"), name="static")
    
    @web_app.get("/", response_class=HTMLResponse)
    async def read_root(request: Request):
        return templates.TemplateResponse("index.html", {"request": request})
    
    @web_app.post("/query", response_class=HTMLResponse)
    async def handle_query(request: Request, question: str = Form(...)):
        try:
            generated_sql = generate_sql.remote(question)
            results = execute_query.remote(generated_sql)
            db_info = get_database_info.remote()
            
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
    
    return web_app

@app.function(
    image=bitcoin_image,
    secrets=[OPENAI_SECRET],
    keep_warm=1
)
def generate_sql(question: str) -> str:
    import openai
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
    image=bitcoin_image,
    volumes={"/data": volume},
    keep_warm=1
)
def execute_query(sql: str) -> list:
    # Keep your existing query execution logic
    pass  

@app.function(
    image=bitcoin_image,
    volumes={"/data": volume},
    keep_warm=1
)
def get_database_info() -> dict:
    # Keep your existing database info logic
    pass

@app.function(image=bitcoin_image)
@modal.asgi_app()
def fastapi_app():
    return create_app()