# Homework 4: Text-to-SQL

## 1. Auto-Generating SQL Schema

### Approach:
- Use a python script to convert JSON schema into SQL schema.

### Implementation:
The main process of the script is:
1. Parses a sample JSON block response.
2. Extracts keys and determines types.
3. Generates SQL schema dynamically.

I used the below code to auto generate the SQL schema from the JSON object:

```python
import json
from typing import List, Any

def infer_sql_type(value: Any) -> str:
    """
    Infer SQL data type from a Python value with improved type mapping.
    
    Args:
        value: Any Python value to analyze
        
    Returns:
        str: Corresponding SQL data type
    """
    if value is None:
        return "TEXT"
    elif isinstance(value, bool):
        return "BOOLEAN"
    elif isinstance(value, int):
        return "INTEGER"
    elif isinstance(value, float):
        return "REAL"
    elif isinstance(value, (list, dict)):
        return "JSON"
    elif isinstance(value, str):
        if len(value) > 1000:
            return "TEXT"
        return "VARCHAR(255)"
    else:
        return "TEXT"

def sanitize_identifier(name: str) -> str:
    """
    Sanitize table and column names to be SQL-safe.
    
    Args:
        name: Raw identifier name
        
    Returns:
        str: Sanitized identifier name
    """
    sanitized = ''.join(c if c.isalnum() else '_' for c in name)
    if sanitized[0].isdigit():
        sanitized = f"t_{sanitized}"
    return sanitized.lower()

def generate_schema(table_name: str, data: Any, parent_table: str = None) -> List[str]:
    """
    Recursively generate SQL schema from data.
    
    Args:
        table_name: Name of the table to create
        data: Data to analyze for schema generation
        parent_table: Name of the parent table if this is a nested structure
        
    Returns:
        List[str]: Tables DDL statements with inline foreign key constraints
    """
    table_name = sanitize_identifier(table_name)
    tables = []
    columns = []
    
    columns.append("id INTEGER PRIMARY KEY AUTOINCREMENT")
    if parent_table:
        parent_fk = f"{sanitize_identifier(parent_table)}_id INTEGER"
        columns.append(f"{parent_fk} REFERENCES {parent_table}(id)")
    
    if isinstance(data, dict):
        for key, value in data.items():
            col_name = sanitize_identifier(key)
            
            if isinstance(value, dict):
                if value:  # Non-empty dictionary
                    nested_table_name = f"{table_name}_{col_name}"
                    nested_tables = generate_schema(nested_table_name, value, table_name)
                    tables.extend(nested_tables)
                    columns.append(f"{col_name}_id INTEGER REFERENCES {nested_table_name}(id)")
                else:  # Empty dictionary
                    sql_type = infer_sql_type(value)
                    nullable = "NOT NULL" if value is not None else "NULL"
                    columns.append(f"{col_name} {sql_type} {nullable}")
            else:
                sql_type = infer_sql_type(value)
                nullable = "NOT NULL" if value is not None else "NULL"
                columns.append(f"{col_name} {sql_type} {nullable}")
    
    columns_sql = ",\n    ".join(columns)
    create_table = f"""CREATE TABLE IF NOT EXISTS {table_name} (
    {columns_sql}
);"""
    tables.insert(0, create_table)
    return tables

def generate_sql_schema(data: Any, base_table_name: str) -> str:
    """
    Generate complete SQL schema including tables with inline constraints.
    
    Args:
        data: Data to analyze for schema generation
        base_table_name: Name of the root table
        
    Returns:
        str: Complete SQL schema
    """
    schema = ["PRAGMA foreign_keys = ON;", ""]
    schema.append("-- Table Definitions")
    tables = generate_schema(base_table_name, data)
    schema.extend(tables)
    return "\n\n".join(schema) + "\n"

# Example usage
if __name__ == "__main__":
    # Read JSON file
    with open("/home/tourist/neu/INFO7500-cryptocurrency/hw3/block_data/block_0.json", "r") as f:
        json_obj = json.load(f)
    
    # Generate schema
    sql_schema = generate_sql_schema(json_obj["result"], "block")
    
    # Write to file
    with open("/home/tourist/neu/INFO7500-cryptocurrency/hw4/schema.sql", "w") as f:
        f.write(sql_schema)
```
### SQL Schema:
The generated SQL schema for the given JSON data would look like:
```sql
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
```

## 2. Keeping Database Updated

### Approach:
- Write a program that calls `getblocks` RPC periodically.
- Extracts block and transaction data.
- Converts JSON into SQL INSERT statements.
- Ensures data consistency.

### Implementation:

```python
import modal
from modal import App, Volume, Secret
import os
import requests
import sqlite3
import json
import time
from typing import Dict, Any

app = App(name="chongchen-bitcoin-explorer")  # Use modal.App

# Define the volume and Docker image
volume = Volume.from_name("chongchen-bitcoin-data", create_if_missing=True)
bitcoin_image = modal.Image.debian_slim().pip_install("requests")

class BitcoinRPC:
    """Handles RPC communication with Bitcoin node via Chainstack"""
    def __init__(self):
        self.rpc_username = os.environ["RPC_USERNAME"]
        self.rpc_password = os.environ["RPC_PASSWORD"]
        self.rpc_host = os.environ["RPC_HOST"]
        self.rpc_port = os.environ["RPC_PORT"]
        self.rpc_path = os.environ["RPC_PATH"]
        self.rpc_endpoint = f"https://{self.rpc_host}:{self.rpc_port}{self.rpc_path}"
        self.auth = (self.rpc_username, self.rpc_password)

    def make_rpc_call(self, method: str, params: list) -> Dict[str, Any]:
        """Execute JSON-RPC call"""
        payload = {
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": 1
        }
        try:
            response = requests.post(
                self.rpc_endpoint,
                auth=self.auth,
                json=payload,
                headers={'Content-Type': 'application/json'},
                timeout=10
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"RPC Error: {e}")
            raise

    def get_block_count(self) -> int:
        """Fetch current blockchain height"""
        resp = self.make_rpc_call("getblockcount", [])
        return resp["result"]

    def get_block_hash(self, height: int) -> str:
        """Get block hash by height"""
        resp = self.make_rpc_call("getblockhash", [height])
        return resp["result"]

    def get_block(self, block_hash: str) -> Dict:
        """Retrieve block data with transactions"""
        resp = self.make_rpc_call("getblock", [block_hash, 2])
        return resp["result"]

def get_db_connection():
    """Connect to SQLite database in Modal Volume"""
    return sqlite3.connect('/data/bitcoin.db')

def init_db():
    """Initialize database schema if not exists"""
    with get_db_connection() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS block (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                hash VARCHAR(255) NOT NULL,
                confirmations INTEGER NOT NULL,
                height INTEGER NOT NULL,
                version INTEGER NOT NULL,
                versionHex VARCHAR(255) NOT NULL,
                merkleroot VARCHAR(255) NOT NULL,
                time INTEGER NOT NULL,
                mediantime INTEGER NOT NULL,
                nonce INTEGER NOT NULL,
                bits VARCHAR(255) NOT NULL,
                difficulty REAL NOT NULL,
                chainwork VARCHAR(255) NOT NULL,
                nTx INTEGER NOT NULL,
                previousblockhash VARCHAR(255) NOT NULL,
                nextblockhash VARCHAR(255) NOT NULL,
                strippedsize INTEGER NOT NULL,
                size INTEGER NOT NULL,
                weight INTEGER NOT NULL,
                tx JSON NOT NULL
            );
        """)
        conn.commit()

def get_max_height() -> int:
    """Get the highest block height from the database"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT MAX(height) AS max_height FROM block")
        row = cursor.fetchone()
        return row[0] if row[0] is not None else -1

def save_block(block_data: Dict):
    """Save block to database and Volume"""
    # Insert into SQLite
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO block (
                hash, confirmations, height, version, versionHex, merkleroot,
                time, mediantime, nonce, bits, difficulty, chainwork, nTx,
                previousblockhash, nextblockhash, strippedsize, size, weight, tx
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            block_data['hash'],
            block_data.get('confirmations', 0),
            block_data['height'],
            block_data['version'],
            block_data['versionHex'],
            block_data['merkleroot'],
            block_data['time'],
            block_data.get('mediantime', block_data['time']),
            block_data['nonce'],
            block_data['bits'],
            block_data['difficulty'],
            block_data['chainwork'],
            block_data['nTx'],
            block_data.get('previousblockhash', ''),
            block_data.get('nextblockhash', ''),
            block_data['strippedsize'],
            block_data['size'],
            block_data['weight'],
            json.dumps(block_data['tx'])
        ))
        conn.commit()
    
    # Save JSON to Volume
    # block_dir = "/data/blocks"
    # os.makedirs(block_dir, exist_ok=True)
    # with open(f"{block_dir}/block_{block_data['height']}.json", 'w') as f:
    #     json.dump(block_data, f)

@app.function(
    volumes={"/data": volume},
    image=bitcoin_image,
    secrets=[Secret.from_name("chongchen-bitcoin-chainstack")],
    timeout=86400  # Extend timeout for long syncing
)
def sync_blocks():
    """Main function to sync blocks continuously"""
    init_db()
    rpc = BitcoinRPC()
    
    while True:
        current_height = rpc.get_block_count()
        max_synced = get_max_height()
        
        if max_synced >= current_height:
            print("All blocks synced. Sleeping for 10 minutes.")
            time.sleep(600)
            continue
        
        print(f"Syncing blocks {max_synced + 1} to {current_height}")
        for height in range(max_synced + 1, current_height + 1):
            try:
                block_hash = rpc.get_block_hash(height)
                block_data = rpc.get_block(block_hash)
                save_block(block_data)
                print(f"Block {height} synced")
            except Exception as e:
                print(f"Failed to sync block {height}: {e}")
                break  # Retry from current height on next iteration

if __name__ == "__main__":
    with app.run():
        sync_blocks.call()
```
The program synchronizes Bitcoin blockchain data using RPC calls, ensuring the database remains up-to-date and consistent. It fetches the latest block height with:  

```python
current_height = rpc.get_block_count()
```  

Then, it checks the highest stored block:  

```python
max_synced = get_max_height()
```  

If new blocks exist, it retrieves and stores them using:  

```python
block_hash = rpc.get_block_hash(height)  
block_data = rpc.get_block(block_hash)  
save_block(block_data)
```  

The process runs every few minutes, sleeping if no new blocks are found:  

```python
time.sleep(600)
```  

## 3. Natural Language to SQL Queries

### Steps:
1. Extract SQL schema dynamically from the SQLite database.
2. Construct a prompt for OpenAI API.
3. Generate SQL queries based on natural language input.

### Python Implementation:

```python
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
```

### Key Points:

#### 1. Inputs
- **Natural language question**
- **SQLite database path**

#### 2. Prompt Generation
- **System prompt** defines the task.
- **Database schema** is extracted dynamically using `get_schema(conn)`.
- **User query and schema** form the input for OpenAI API.

#### 3. LLM API Usage
- Uses LLM model.
- Authenticated via **Modal Secrets** (`chongchen-llm-api-key`).

#### 4. SQL Execution
- Runs the generated SQL query using `execute_sql(conn, sql)`.
- Returns **results or error messages**.

#### 5. Logging
- Stores **queries, SQL, results, and errors** in Modal Volume `/data/qa_history`.


## 4. 10 Normal Test Cases

The below code use 10 normal test cases to validate the functionality of **Text-to-SQL** implementation.

```python
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
```
The full QA historial is logged in the volume: https://modal.com/storage/neu-info5100-oak-spr-2025/main/chongchen-bitcoin-data/sql_tests/normal.

This implementation evaluates the accuracy of a natural language-to-SQL conversion system for querying Bitcoin blockchain data stored in SQLite. It uses OpenAI’s LLM API to generate SQL queries from user questions, executes them, and compares the results with predefined correct answers. The system includes 10 test cases covering various SQL functionalities, such as counting, filtering, aggregation, and ordering. Each test logs the expected SQL, generated SQL, expected answer, and actual answer for validation. By automating query execution and result comparison, the implementation ensures accuracy and reliability in translating Bitcoin-related questions into precise SQL queries.

### Test Case 1

**Question:** What is the hash of the genesis block (block at height 0)?

**Expected SQL:**
```sql
SELECT hash FROM block WHERE height = 0;
```

**Expected Result:** 000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f

**Generated SQL:**
```sql
SELECT hash FROM block WHERE height = 0;
```

**Actual Result:** 000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f

---

### Test Case 2

**Question:** How many confirmations does block #100000 have?

**Expected SQL:**
```sql
SELECT confirmations FROM block WHERE height = 100000;
```

**Expected Result:** 785648

**Generated SQL:**
```sql
SELECT confirmations FROM block WHERE height = 100000;
```

**Actual Result:** 785648

---

### Test Case 3

**Question:** What is the average block size for blocks between height 50000 and 55000?

**Expected SQL:**
```sql
SELECT AVG(size) FROM block WHERE height BETWEEN 50000 AND 55000;
```

**Expected Result:** 496.68886222755447

**Generated SQL:**
```sql
SELECT AVG(size) 
FROM block 
WHERE height BETWEEN 50000 AND 55000;
```

**Actual Result:** 496.68886222755447

---

### Test Case 4

**Question:** Which block has the highest difficulty between blocks 150000 and 160000?

**Expected SQL:**
```sql
SELECT hash, height, difficulty FROM block WHERE height BETWEEN 150000 AND 160000 ORDER BY difficulty DESC LIMIT 1;
```

**Expected Result:** [('0000000000000a3290f20e75860d505ce0e948a1d1d846bec7e39015d242884b', 150000, 1468195.427220831)]

**Generated SQL:**
```sql
SELECT hash, difficulty
FROM block
WHERE height BETWEEN 150000 AND 160000
ORDER BY difficulty DESC
LIMIT 1
```

**Actual Result:** [('0000000000000a3290f20e75860d505ce0e948a1d1d846bec7e39015d242884b', 1468195.427220831)]

---

### Test Case 5

**Question:** How many transactions (ntx) were there in total across all blocks in the range 123000 to 123100?

**Expected SQL:**
```sql
SELECT SUM(ntx) FROM block WHERE height BETWEEN 123000 AND 123100;
```

**Expected Result:** 1596

**Generated SQL:**
```sql
SELECT SUM(nTx) 
FROM block 
WHERE height BETWEEN 123000 AND 123100
```

**Actual Result:** 1596

---

### Test Case 6

**Question:** What is the timestamp (time) of the latest block in the database?

**Expected SQL:**
```sql
SELECT time, height FROM block ORDER BY height DESC LIMIT 1;
```

**Expected Result:** [(1366117453, 231644)]

**Generated SQL:**
```sql
SELECT time FROM block ORDER BY height DESC LIMIT 1
```

**Actual Result:** 1366117453

---

### Test Case 7

**Question:** Find the 5 blocks with the largest size difference compared to their previous block between heights 75000 and 80000.

**Expected SQL:**
```sql
SELECT b.height, b.hash, b.size, p.size AS prev_size, (b.size - p.size) AS size_diff FROM block b JOIN block p ON b.previousblockhash = p.hash WHERE b.height BETWEEN 75000 AND 80000 ORDER BY ABS(b.size - p.size) DESC LIMIT 5;
```

**Expected Result:** [(76159, '000000000005560bafd779f7a68cac34d8bfd7862bbae3eb25761a97244458f2', 77018, 440, 76578), (76160, '00000000003110b77de74d891a29ecd76298cf9fff812b70466bf57927eb46be', 1159, 77018, -75859), (77289, '000000000014e61addbe1d35dac5be43a9ed4a36018037580c3b7c8f2fd9477a', 215, 41130, -40915), (77288, '0000000000442f240d796f1eaf66ff4c52bd5875dcff334508cecfaacb0fc505', 41130, 2709, 38421), (77469, '0000000000393b038f47d7bcd64b3823f49715f5f980248b922dd7e91bfa37af', 22509, 216, 22293)]

**Generated SQL:**
```sql
SELECT b1.hash, b1.height, b1.size, b2.size AS prev_size, (b1.size - b2.size) AS size_diff
FROM block b1
JOIN block b2 ON b1.previousblockhash = b2.hash
WHERE b1.height BETWEEN 75000 AND 80000
ORDER BY size_diff DESC
LIMIT 5
```

**Actual Result:** [('000000000005560bafd779f7a68cac34d8bfd7862bbae3eb25761a97244458f2', 76159, 77018, 440, 76578), ('0000000000442f240d796f1eaf66ff4c52bd5875dcff334508cecfaacb0fc505', 77288, 41130, 2709, 38421), ('0000000000393b038f47d7bcd64b3823f49715f5f980248b922dd7e91bfa37af', 77469, 22509, 216, 22293), ('00000000005cd2bca975d46d05d638942137725fbb691a5a2f7f53e3a4e2b7ac', 76584, 20657, 489, 20168), ('00000000005eb1280e6aaa91dfa5a417315b283e51a4000f1d8527be03903cce', 77554, 14740, 475, 14265)]

---

### Test Case 8

**Question:** What was the average time (in seconds) between blocks from height 140000 to 140100?

**Expected SQL:**
```sql
WITH block_times AS (SELECT height, time, LAG(time) OVER (ORDER BY height) AS prev_time FROM block WHERE height BETWEEN 140000 AND 140100) SELECT AVG(time - prev_time) FROM block_times WHERE prev_time IS NOT NULL;
```

**Expected Result:** 683.99

**Generated SQL:**
```sql
SELECT AVG(b2.time - b1.time)
FROM block b1
JOIN block b2 ON b1.height + 1 = b2.height
WHERE b1.height BETWEEN 140000 AND 140100 - 1;
```

**Actual Result:** 683.99

---

### Test Case 9

**Question:** How many blocks have a nonce value greater than 3000000000 between heights 50000 and 60000?

**Expected SQL:**
```sql
SELECT COUNT(*) FROM block WHERE height BETWEEN 50000 AND 60000 AND nonce > 3000000000;
```

**Expected Result:** 353

**Generated SQL:**
```sql
SELECT COUNT(*) 
FROM block 
WHERE nonce > 3000000000 
AND height BETWEEN 50000 AND 60000
```

**Actual Result:** 353

---

### Test Case 10

**Question:** What is the distribution of block sizes by month in 2012? Show the month, average size, min size, and max size.

**Expected SQL:**
```sql
SELECT strftime('%Y-%m', datetime(time, 'unixepoch')) AS month, AVG(size) AS avg_size, MIN(size) AS min_size, MAX(size) AS max_size FROM block WHERE strftime('%Y', datetime(time, 'unixepoch')) = '2012' GROUP BY month ORDER BY month;
```

**Expected Result:** [('2012-01', 20554.389544688027, 195, 334262), ('2012-02', 21596.938231917335, 213, 218762), ('2012-03', 20485.796958663526, 213, 211123), ('2012-04', 24840.587885985748, 190, 327826), ('2012-05', 66805.68305391935, 190, 499240)]... (showing 5 of 12 rows)

**Generated SQL:**
```sql
SELECT 
    strftime('%m', datetime(time, 'unixepoch')) AS month,
    AVG(size) AS avg_size,
    MIN(size) AS min_size,
    MAX(size) AS max_size
FROM block
WHERE strftime('%Y', datetime(time, 'unixepoch')) = '2012'
GROUP BY strftime('%m', datetime(time, 'unixepoch'))
ORDER BY month
```

**Actual Result:** [('01', 20554.389544688027, 195, 334262), ('02', 21596.938231917335, 213, 218762), ('03', 20485.796958663526, 213, 211123), ('04', 24840.587885985748, 190, 327826), ('05', 66805.68305391935, 190, 499240)]... (showing 5 of 12 rows)

---

### Test Case 11

**Question:** Find blocks where the difficulty increased by more than 10% compared to the previous block in the range 80000 to 90000.

**Expected SQL:**
```sql
SELECT b.height, b.hash, b.difficulty, p.difficulty AS prev_difficulty, (b.difficulty - p.difficulty)/p.difficulty*100 AS difficulty_increase_pct FROM block b JOIN block p ON b.previousblockhash = p.hash WHERE b.height BETWEEN 80000 AND 90000 AND (b.difficulty - p.difficulty)/p.difficulty > 0.1 ORDER BY difficulty_increase_pct DESC;
```

**Expected Result:** [(86688, '000000000015bfe777e893c4ebd1307541792630c2932278bfe8cf3ae82668ce', 2149.021814946726, 1378.028165037326, 55.94904875463966), (88704, '000000000012384edfbd167c7778aec3e84bb1795b907cc795912e643c2cff04', 3091.736890411797, 2149.021814946726, 43.86717105002682), (82656, '000000000024fc69f5415908b1960092a8e81b9d3b9a03c1133f5cb0a2d3c2af', 1318.670050153592, 917.8307413015116, 43.67246495619423), (80640, '0000000000307c80b87edf9f6a0697e2f01db67e518c8a4d6065d1d859a3a659', 917.8307413015116, 712.8848645520973, 28.74880460229451)]

**Generated SQL:**
```sql
SELECT b1.hash, b1.height, b1.difficulty, b2.difficulty AS prev_difficulty, 
       ((b1.difficulty - b2.difficulty) / b2.difficulty * 100) AS difficulty_increase
FROM block b1
JOIN block b2 ON b1.previousblockhash = b2.hash
WHERE b1.height BETWEEN 80000 AND 90000
AND ((b1.difficulty - b2.difficulty) / b2.difficulty * 100) > 10
```

**Actual Result:** [('0000000000307c80b87edf9f6a0697e2f01db67e518c8a4d6065d1d859a3a659', 80640, 917.8307413015116, 712.8848645520973, 28.74880460229451), ('000000000024fc69f5415908b1960092a8e81b9d3b9a03c1133f5cb0a2d3c2af', 82656, 1318.670050153592, 917.8307413015116, 43.67246495619423), ('000000000015bfe777e893c4ebd1307541792630c2932278bfe8cf3ae82668ce', 86688, 2149.021814946726, 1378.028165037326, 55.94904875463966), ('000000000012384edfbd167c7778aec3e84bb1795b907cc795912e643c2cff04', 88704, 3091.736890411797, 2149.021814946726, 43.86717105002682)]

---

### Test Case 12

**Question:** What is the correlation between block size and number of transactions (ntx) for blocks 100000 to 110000?

**Expected SQL:**
```sql
SELECT (COUNT(*) * SUM(size * ntx) - SUM(size) * SUM(ntx)) / (SQRT(COUNT(*) * SUM(size * size) - SUM(size) * SUM(size)) * SQRT(COUNT(*) * SUM(ntx * ntx) - SUM(ntx) * SUM(ntx))) AS correlation FROM block WHERE height BETWEEN 100000 AND 110000;
```

**Expected Result:** 0.7257125719443465

**Generated SQL:**
```sql
SELECT 
    (COUNT(*) * SUM(size * nTx) - SUM(size) * SUM(nTx)) / 
    SQRT((COUNT(*) * SUM(size * size) - SUM(size) * SUM(size)) * 
         (COUNT(*) * SUM(nTx * nTx) - SUM(nTx) * SUM(nTx)))
FROM block 
WHERE height BETWEEN 100000 AND 110000
```

**Actual Result:** 0.7257125719443465

---

### Test Case 13

**Question:** How has the average block size changed each year from 2009 to 2015?

**Expected SQL:**
```sql
SELECT strftime('%Y', datetime(time, 'unixepoch')) AS year, AVG(size) AS avg_size FROM block WHERE strftime('%Y', datetime(time, 'unixepoch')) BETWEEN '2009' AND '2015' GROUP BY year ORDER BY year;
```

**Expected Result:** [('2009', 226.58307171437366), ('2010', 777.7929034157833), ('2011', 13445.744461401713), ('2012', 69627.1657741261), ('2013', 156263.41400304413)]

**Generated SQL:**
```sql
SELECT 
    strftime('%Y', datetime(time, 'unixepoch')) as year,
    AVG(size) as avg_block_size
FROM block
WHERE year BETWEEN '2009' AND '2015'
GROUP BY year
ORDER BY year;
```

**Actual Result:** [('2009', 226.58307171437366), ('2010', 777.7929034157833), ('2011', 13445.744461401713), ('2012', 69627.1657741261), ('2013', 156263.41400304413)]

---

### Test Case 14

**Question:** Find the top 5 blocks with the most transactions (ntx) between height 160000 and 170000.

**Expected SQL:**
```sql
SELECT height, hash, ntx FROM block WHERE height BETWEEN 160000 AND 170000 ORDER BY ntx DESC LIMIT 5;
```

**Expected Result:** [(166966, '00000000000007eaeaefaf88bc9c055011e3f71df490556df289545f891421e0', 233), (166723, '0000000000000a56b4dff35485f5e42ebe518bcc60ea2b1f6f7bc3916e33ce9a', 226), (166221, '000000000000097b7c075ccc95aa2f99e326aa5e48192ac00888f989a501d111', 218), (162928, '0000000000000c861e7811237029484dab6ec704b76b328af1560a7cda640d5d', 216), (166105, '00000000000008e772f92b56b79031b7000848a112912cdd7ede464202ff5c19', 202)]

**Generated SQL:**
```sql
SELECT hash, height, nTx
FROM block
WHERE height BETWEEN 160000 AND 170000
ORDER BY nTx DESC
LIMIT 5
```

**Actual Result:** [('00000000000007eaeaefaf88bc9c055011e3f71df490556df289545f891421e0', 166966, 233), ('0000000000000a56b4dff35485f5e42ebe518bcc60ea2b1f6f7bc3916e33ce9a', 166723, 226), ('000000000000097b7c075ccc95aa2f99e326aa5e48192ac00888f989a501d111', 166221, 218), ('0000000000000c861e7811237029484dab6ec704b76b328af1560a7cda640d5d', 162928, 216), ('00000000000008e772f92b56b79031b7000848a112912cdd7ede464202ff5c19', 166105, 202)]

---


## 5. 3 Hard Test Cases

Below code write three very hard test cases that are so hard that the system is not able to answer correctly. The purpose of this is to find the limit of what’s possible for this task.
```python
import modal
import sqlite3
import os
from openai import OpenAI
from datetime import datetime

app = modal.App("bitcoin-sql-qa")
volume = modal.Volume.from_name("chongchen-bitcoin-data", create_if_missing=True)
image = modal.Image.debian_slim().pip_install("openai")

hard_test_cases = [
    {
        "question": "What is the median nonce value for blocks mined in February 2013?",
        "expected_sql": """
            SELECT AVG(nonce) 
            FROM (
                SELECT nonce 
                FROM block 
                WHERE strftime('%Y-%m', datetime(time, 'unixepoch')) = '2013-02' 
                ORDER BY nonce 
                LIMIT 2 - (
                    SELECT COUNT(*) 
                    FROM block 
                    WHERE strftime('%Y-%m', datetime(time, 'unixepoch')) = '2013-02'
                ) % 2 
                OFFSET (
                    SELECT COUNT(*) 
                    FROM block 
                    WHERE strftime('%Y-%m', datetime(time, 'unixepoch')) = '2013-02'
                ) / 2
            );
        """
    },
    {
        "question": "Analyze the 'fee market' development by calculating the implicit fee per transaction in satoshis for each block from 150000 to 160000. For this, estimate the mining reward by using the formula: (block_reward_bitcoins * 10^8 + (block_size - 80) * 10). Then calculate fee = (reward - expected_subsidy) / ntx where expected_subsidy is 50 BTC per block multiplied by 10^8 to convert to satoshis. Show the top 10 blocks with highest average fee per transaction, including block height, time (formatted as date), number of transactions, and average fee per transaction.",
        "expected_sql": """
            WITH block_rewards AS (
                SELECT
                    height,
                    hash,
                    ntx,
                    size,
                    datetime(time, 'unixepoch') AS block_date,
                    (size - 80) * 10 AS size_reward_satoshis,
                    CASE
                        WHEN height < 210000 THEN 5000000000 -- 50 BTC in satoshis
                        WHEN height < 420000 THEN 2500000000 -- 25 BTC in satoshis
                        WHEN height < 630000 THEN 1250000000 -- 12.5 BTC in satoshis
                        ELSE 625000000 -- 6.25 BTC in satoshis
                    END AS block_subsidy_satoshis
                FROM block
                WHERE height BETWEEN 150000 AND 160000 AND ntx > 1
            )
            SELECT
                height,
                hash,
                block_date,
                ntx,
                size,
                block_subsidy_satoshis,
                size_reward_satoshis,
                CASE
                    WHEN ntx > 1 THEN ROUND((size_reward_satoshis - block_subsidy_satoshis) / (ntx - 1), 2)
                    ELSE 0
                END AS avg_fee_per_tx_satoshis
            FROM block_rewards
            ORDER BY avg_fee_per_tx_satoshis DESC
            LIMIT 10;
        """
    },
    {
        "question": "Calculate the mining difficulty adjustment pattern by finding the percentage change in difficulty between each difficulty adjustment period (every 2016 blocks) from block 50000 to 100000. Show the starting block of each period, the average block time in minutes for that period, and the percentage difficulty change.",
        "expected_sql": """
            WITH adjustment_periods AS (
                SELECT 
                    height, 
                    difficulty,
                    time,
                    height / 2016 AS period_number
                FROM block 
                WHERE height BETWEEN 50000 AND 100000
            ),
            period_stats AS (
                SELECT 
                    period_number,
                    MIN(height) AS start_block,
                    MAX(difficulty) AS difficulty,
                    (MAX(time) - MIN(time)) / (COUNT(*) - 1) / 60.0 AS avg_block_time_minutes,
                    LAG(MAX(difficulty)) OVER (ORDER BY period_number) AS prev_difficulty
                FROM adjustment_periods
                GROUP BY period_number
            )
            SELECT 
                start_block,
                avg_block_time_minutes,
                difficulty,
                prev_difficulty,
                CASE
                    WHEN prev_difficulty IS NULL THEN NULL
                    ELSE ROUND((difficulty - prev_difficulty) / prev_difficulty * 100, 2)
                END AS difficulty_change_percent
            FROM period_stats
            ORDER BY start_block;
        """
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
        temperature=0.2,
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

def log_test_result(test_type: str, content: str, filename: str):
    log_dir = f"/data/sql_tests/{test_type}"
    os.makedirs(log_dir, exist_ok=True)
    # timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"{filename}.txt")
    
    with open(log_file, 'w') as f:
        f.write(content)
    volume.commit()

@app.function(
    image=image,
    volumes={"/data": volume},
    secrets=[modal.Secret.from_name("chongchen-llm-api-key")]
)
def test_hard_cases(db_path = "/data/bitcoin.db"):
    conn = sqlite3.connect(db_path)
    for test_id, case in enumerate(hard_test_cases, start=1):
        question = case["question"]
        expected_sql = case["expected_sql"]
        
        # Get expected answer
        expected_answer, _ = execute_sql(conn, expected_sql)
        
        # Get system's response
        response = answer_question.remote(question, db_path)
        generated_sql = response["generated_sql"]
        generated_answer = response["result"]
        error = response["error"]
        
        # Build log content
        log_content = (
            f"Question: {question}\n"
            f"Expected SQL: {expected_sql}\n"
            f"Expected Answer: {expected_answer}\n"
            f"Generated SQL: {generated_sql}\n"
            f"Generated Answer: {generated_answer}\n"
        )
        if error:
            log_content += f"Error: {error}\n"
        
        log_test_result("hard", log_content, f"test_{test_id}")
    conn.close()
```

The full QA historial is logged in the volume: https://modal.com/storage/neu-info5100-oak-spr-2025/main/chongchen-bitcoin-data/sql_tests/hard.

### Test Case 1

**Question**: What is the median nonce value for blocks mined in February 2013?
**Expected SQL**:
```sql 
SELECT AVG(nonce) 
FROM (
    SELECT nonce 
    FROM block 
    WHERE strftime('%Y-%m', datetime(time, 'unixepoch')) = '2013-02' 
    ORDER BY nonce 
    LIMIT 2 - (
        SELECT COUNT(*) 
        FROM block 
        WHERE strftime('%Y-%m', datetime(time, 'unixepoch')) = '2013-02'
    ) % 2 
    OFFSET (
        SELECT COUNT(*) 
        FROM block 
        WHERE strftime('%Y-%m', datetime(time, 'unixepoch')) = '2013-02'
    ) / 2
);
```
        
**Expected Answer**: [(2114258196.5,)]
**Generated SQL**: 
```sql
SELECT median(nonce) 
FROM block 
WHERE time >= 1359676800 AND time < 1362096000
```
**Generated Answer**: 
None
Error: no such function: median

---

### Test Case 2

**Question**: Analyze the 'fee market' development by calculating the implicit fee per transaction in satoshis for each block from 150000 to 160000. For this, estimate the mining reward by using the formula: (block_reward_bitcoins * 10^8 + (block_size - 80) * 10). Then calculate fee = (reward - expected_subsidy) / ntx where expected_subsidy is 50 BTC per block multiplied by 10^8 to convert to satoshis. Show the top 10 blocks with highest average fee per transaction, including block height, time (formatted as date), number of transactions, and average fee per transaction.

**Expected SQL**:
```sql 
WITH block_rewards AS (
    SELECT
        height,
        hash,
        ntx,
        size,
        datetime(time, 'unixepoch') AS block_date,
        (size - 80) * 10 AS size_reward_satoshis,
        CASE
            WHEN height < 210000 THEN 5000000000 -- 50 BTC in satoshis
            WHEN height < 420000 THEN 2500000000 -- 25 BTC in satoshis
            WHEN height < 630000 THEN 1250000000 -- 12.5 BTC in satoshis
            ELSE 625000000 -- 6.25 BTC in satoshis
        END AS block_subsidy_satoshis
    FROM block
    WHERE height BETWEEN 150000 AND 160000 AND ntx > 1
)
SELECT
    height,
    hash,
    block_date,
    ntx,
    size,
    block_subsidy_satoshis,
    size_reward_satoshis,
    CASE
        WHEN ntx > 1 THEN ROUND((size_reward_satoshis - block_subsidy_satoshis) / (ntx - 1), 2)
        ELSE 0
    END AS avg_fee_per_tx_satoshis
FROM block_rewards
ORDER BY avg_fee_per_tx_satoshis DESC
LIMIT 10;
```
        
**Expected Answer**: [(154723, '00000000000003bfc715be0afb06486c325c12dea913766564fd7e9bc453889d', '2011-11-25 12:21:16', 398, 107002, 5000000000, 1069220, -12591765.0), (156869, '00000000000002bd9cc33fbf8cfeb874a79bc51295c3c14a583178c258c1784f', '2011-12-10 04:35:39', 379, 123336, 5000000000, 1232560, -13224252.0), (154725, '00000000000008c67bc9ac7eba82450a38a94051a0f3751490ecd0d837545b24', '2011-11-25 13:04:15', 239, 69926, 5000000000, 698460, -21005468.0), (155303, '0000000000000054cafde5ade84adf4cc7b7f7cdf63bf4ba983a80f6fa1ce5c8', '2011-11-30 02:16:01', 209, 49038, 5000000000, 489580, -24036107.0), (155544, '0000000000000c86066cdc2dc8f6961da85b390e9bae9dd4e5b700830dc20f01', '2011-12-01 12:09:22', 199, 48770, 5000000000, 486900, -25250066.0), (154432, '00000000000004611ff254ba52111a14a98de7167f79feae9fdb87399e18cca0', '2011-11-23 04:06:37', 198, 49174, 5000000000, 490940, -25378218.0), (158212, '000000000000084f15663b602830d00964347643f212f44deb882b301d4d9663', '2011-12-19 20:24:27', 197, 72987, 5000000000, 729070, -25506484.0), (154385, '00000000000008f209cf9ecbfa522b0b4f0ce4a9e3bf840328b695813d89f4c9', '2011-11-22 20:02:44', 196, 76011, 5000000000, 759310, -25637131.0), (157270, '0000000000000940c5c3d1e0820806370fae3254313f2c45cab7ede2a28f880e', '2011-12-13 00:04:17', 193, 49073, 5000000000, 489930, -26039114.0), (151992, '0000000000000a544d3ba541dddae74e46469e38b1f8ba4681e0b5f722bb9670', '2011-11-05 15:11:30', 190, 56993, 5000000000, 569130, -26452015.0)]

**Generated SQL**: 
```sql
SELECT 
    height,
    DATETIME(time, 'unixepoch') AS block_time,
    nTx AS num_transactions,
    (((50 * POW(10,8) + (size - 80) * 10) - (50 * POW(10,8))) / nTx) AS avg_fee_per_tx
FROM block
WHERE height BETWEEN 150000 AND 160000
ORDER BY avg_fee_per_tx DESC
LIMIT 10
```

**Generated Answer**: [(157101, '2011-12-11 17:27:34', 2, 353710.0), (154034, '2011-11-20 05:44:54', 2, 226750.0), (152680, '2011-11-10 09:23:34', 5, 153044.0), (154642, '2011-11-24 21:34:38', 3, 135970.0), (154764, '2011-11-25 20:14:16', 2, 120665.0), (157155, '2011-12-12 01:51:46', 3, 91793.33333333333), (152752, '2011-11-10 21:12:23', 5, 70412.0), (154761, '2011-11-25 20:00:19', 7, 70192.85714285714), (153176, '2011-11-14 00:54:35', 9, 68177.77777777778), (152461, '2011-11-08 23:50:28', 2, 68120.0)]

---

### Test Case 3

**Question**: Calculate the mining difficulty adjustment pattern by finding the percentage change in difficulty between each difficulty adjustment period (every 2016 blocks) from block 50000 to 100000. Show the starting block of each period, the average block time in minutes for that period, and the percentage difficulty change.

**Expected SQL**: 
```sql
WITH adjustment_periods AS (
    SELECT 
        height, 
        difficulty,
        time,
        height / 2016 AS period_number
    FROM block 
    WHERE height BETWEEN 50000 AND 100000
),
period_stats AS (
    SELECT 
        period_number,
        MIN(height) AS start_block,
        MAX(difficulty) AS difficulty,
        (MAX(time) - MIN(time)) / (COUNT(*) - 1) / 60.0 AS avg_block_time_minutes,
        LAG(MAX(difficulty)) OVER (ORDER BY period_number) AS prev_difficulty
    FROM adjustment_periods
    GROUP BY period_number
)
SELECT 
    start_block,
    avg_block_time_minutes,
    difficulty,
    prev_difficulty,
    CASE
        WHEN prev_difficulty IS NULL THEN NULL
        ELSE ROUND((difficulty - prev_difficulty) / prev_difficulty * 100, 2)
    END AS difficulty_change_percent
FROM period_stats
ORDER BY start_block;
```
        
**Expected Answer**: [(50000, 6.033333333333333, 6.085476906000794, None, None), (50400, 6.816666666666666, 7.819796993353832, 6.085476906000794, 28.5), (52416, 8.916666666666666, 11.46431580551412, 7.819796993353832, 46.61), (54432, 10.85, 12.84918314782378, 11.46431580551412, 12.08), (56448, 7.116666666666666, 11.84622814970471, 12.84918314782378, -7.81), (58464, 9.55, 16.61907875185736, 11.84622814970471, 40.29), (60480, 8.95, 17.38148815814011, 16.61907875185736, 4.59), (62496, 8.25, 19.40479632838217, 17.38148815814011, 11.64), (64512, 5.166666666666667, 23.50125722290317, 19.40479632838217, 21.11), (66528, 2.3833333333333333, 45.38582234101263, 23.50125722290317, 93.12), (68544, 7.433333333333334, 181.5432893640505, 45.38582234101263, 300.0), (70560, 6.933333333333334, 244.2132230923753, 181.5432893640505, 34.52), (72576, 6.883333333333334, 352.1612090680101, 244.2132230923753, 44.2), (74592, 8.233333333333333, 511.7735342566043, 352.1612090680101, 45.32), (76608, 8.733333333333333, 623.3869598689275, 511.7735342566043, 21.81), (78624, 7.766666666666667, 712.8848645520973, 623.3869598689275, 14.36), (80640, 6.95, 917.8307413015116, 712.8848645520973, 28.75), (82656, 9.566666666666666, 1318.670050153592, 917.8307413015116, 43.67), (84672, 6.4, 1378.028165037326, 1318.670050153592, 4.5), (86688, 6.95, 2149.021814946726, 1378.028165037326, 55.95), (88704, 6.816666666666666, 3091.736890411797, 2149.021814946726, 43.87), (90720, 6.6, 4536.353723275037, 3091.736890411797, 46.73), (92736, 8.5, 6866.898648972739, 4536.353723275037, 51.37), (94752, 6.583333333333333, 8078.195257925088, 6866.898648972739, 17.64), (96768, 8.45, 12251.9997603745, 8078.195257925088, 51.67), (98784, 9.133333333333333, 14484.1623612254, 12251.9997603745, 18.22)]

**Generated SQL**: 
```sql
SELECT 
    b1.height AS period_start,
    (CAST(AVG(b2.time - b1.time) AS REAL) / 2016 * 60) AS avg_block_time_minutes,
    ((b2.difficulty - b1.difficulty) / b1.difficulty * 100) AS difficulty_change_percent
FROM block b1
JOIN block b2 ON b2.height = b1.height + 2015
WHERE b1.height % 2016 = 0 
AND b1.height BETWEEN 50000 AND 100000 - 2015
GROUP BY b1.height, b1.difficulty, b2.difficulty
ORDER BY b1.height;
```


**Generated Answer**: [(50400, 24555.565476190473, 0.0), (52416, 32119.97023809524, 0.0), (54432, 39047.94642857143, 0.0), (56448, 25661.13095238095, 0.0), (58464, 34420.95238095238, 0.0), (60480, 32246.339285714283, 0.0), (62496, 29724.940476190473, 0.0), (64512, 18641.190476190477, 0.0), (66528, 8614.107142857143, 0.0), (68544, 26761.75595238095, 0.0), (70560, 24965.32738095238, 0.0), (72576, 24772.916666666668, 0.0), (74592, 29554.434523809523, 0.0), (76608, 31480.446428571428, 0.0), (78624, 27961.428571428572, 0.0), (80640, 25056.99404761905, 0.0), (82656, 34449.31547619047, 0.0), (84672, 23084.464285714286, 0.0), (86688, 25023.095238095237, 0.0), (88704, 24535.684523809527, 0.0), (90720, 23782.053571428572, 0.0), (92736, 30601.964285714283, 0.0), (94752, 23736.160714285714, 0.0), (96768, 30452.113095238095, 0.0)]

---

## 6. Sources and Links

**All codes**: https://github.com/chongchen1999/INFO7500-cryptocurrency/tree/main/hw4

**Bitcoin database on Modal Volume**: https://modal.com/api/volumes/neu-info5100-oak-spr-2025/main/chongchen-bitcoin-data/files/content?path=bitcoin.db

**Test cases**: https://modal.com/storage/neu-info5100-oak-spr-2025/main/chongchen-bitcoin-data/sql_tests