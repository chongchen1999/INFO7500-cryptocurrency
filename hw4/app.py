import modal
from fastapi import Request
from fastapi.responses import HTMLResponse
import sqlite3
import openai
from html import escape

app = modal.App(name="bitcoin-explorer-webapp")
volume = modal.Volume.from_name("chongchen-bitcoin-data")

SCHEMA_DESCRIPTION = """
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
"""

@app.function(secrets=[modal.Secret.from_name("openai-api-key")])
def generate_sql(question: str) -> str:
    prompt = f"""Given this SQLite schema for Bitcoin blocks:
{SCHEMA_DESCRIPTION}
Write a SQL query to answer: {question}
Return ONLY the SQL code, no explanations."""
    
    response = openai.ChatCompletion.create(
        model="gpt-3.5-turbo",
        messages=[{"role": "user", "content": prompt}]
    )
    
    sql = response.choices[0].message.content.strip()
    for marker in ["```sql", "```"]:
        sql = sql.replace(marker, "")
    return sql.strip()

def html_template(question="", sql="", sql_error="", results=None, columns=None, query_error=""):
    return f"""
    <html>
        <head><title>Bitcoin Blockchain Explorer</title></head>
        <body>
            <h1>Bitcoin Blockchain Explorer</h1>
            <form method="post">
                <textarea name="question" rows="4" cols="50">{escape(question)}</textarea><br>
                <input type="submit" value="Ask">
            </form>
            
            <h2>Database Structure</h2>
            <pre>{escape(SCHEMA_DESCRIPTION)}</pre>
            
            <h2>Generated SQL</h2>
            {f"<pre>{escape(sql)}</pre>" if sql else ""}
            {f"<p style='color:red'>{escape(sql_error)}</p>" if sql_error else ""}
            
            <h2>Results</h2>
            {render_results(results, columns, query_error)}
        </body>
    </html>
    """

def render_results(results, columns, error):
    if error:
        return f"<p style='color:red'>{escape(error)}</p>"
    if not results:
        return "<p>No results found</p>"
    
    html = "<table border='1'><tr>"
    for col in columns:
        html += f"<th>{escape(col)}</th>"
    html += "</tr>"
    
    for row in results:
        html += "<tr>"
        for cell in row:
            html += f"<td>{escape(str(cell))}</td>"
        html += "</tr>"
    return html + "</table>"

@app.web_endpoint(methods=["GET", "POST"], volumes={"/data": volume})
async def web_handler(request: Request):
    if request.method == "GET":
        return HTMLResponse(html_template())
    
    form_data = await request.form()
    question = form_data.get("question", "")
    
    # Generate SQL
    sql, sql_error = "", ""
    try:
        sql = generate_sql.remote(question)
    except Exception as e:
        sql_error = f"SQL Generation Error: {str(e)}"
    
    # Execute Query
    results, columns, query_error = [], [], ""
    if sql and not sql_error:
        try:
            with sqlite3.connect('/data/bitcoin.db') as conn:
                cur = conn.cursor()
                cur.execute(sql)
                if cur.description:
                    columns = [d[0] for d in cur.description]
                    results = cur.fetchall()
                else:
                    columns = ["Message"]
                    results = [[f"Query executed successfully. Rows affected: {cur.rowcount}"]]
        except Exception as e:
            query_error = f"Query Execution Error: {str(e)}"
    
    return HTMLResponse(html_template(
        question=question,
        sql=sql,
        sql_error=sql_error,
        results=results,
        columns=columns,
        query_error=query_error
    ))