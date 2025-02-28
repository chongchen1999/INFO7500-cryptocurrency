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

normal_test_cases = [
    {
        "question": "How many blocks are there between height 1000 and 10000?",
        "correct_sql": "SELECT COUNT(*) FROM block WHERE height BETWEEN 1000 AND 10000;"
    },
    {
        "question": "How many blocks have exactly 100 confirmations (for blocks below height 50000)?",
        "correct_sql": "SELECT COUNT(*) FROM block WHERE confirmations = 100 AND height < 50000;"
    },
    {
        "question": "What is the average difficulty of the first 1000 blocks?",
        "correct_sql": "SELECT AVG(difficulty) FROM block WHERE height <= 1000;"
    },
    {
        "question": "List the top 5 smallest blocks by size (where size > 0 bytes).",
        "correct_sql": "SELECT * FROM block WHERE size > 0 ORDER BY size ASC LIMIT 5;"
    },
    {
        "question": "What is the previous block hash of the block at height 60000?",
        "correct_sql": "SELECT previousblockhash FROM block WHERE height = 60000;"
    },
    {
        "question": "How many blocks have a nonce value between 1000 and 2000?",
        "correct_sql": "SELECT COUNT(*) FROM block WHERE nonce BETWEEN 1000 AND 2000;"
    },
    {
        "question": "What is the earliest timestamp (time) of a block with exactly 200 transactions?",
        "correct_sql": "SELECT MIN(time) FROM block WHERE ntx = 200;"
    },
    {
        "question": "What is the total weight of blocks mined in the last 1000 blocks?",
        "correct_sql": "SELECT SUM(weight) FROM block WHERE height >= 59000;"
    },
    {
        "question": "Which block has the highest difficulty among the first 1000 blocks?",
        "correct_sql": "SELECT * FROM block WHERE height <= 1000 ORDER BY difficulty DESC LIMIT 1;"
    },
    {
        "question": "List blocks where the merkleroot starts with '0000' (limited to 10).",
        "correct_sql": "SELECT * FROM block WHERE merkleroot LIKE '0000%' LIMIT 10;"
    }
]

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
def test_normal_cases(db_path = "/data/bitcoin.db"):
    conn = sqlite3.connect(db_path)
    for test_id, case in enumerate(normal_test_cases):
        question = case["question"]
        correct_sql = case["correct_sql"]
        
        # Get expected answer
        expected_answer, _ = execute_sql(conn, correct_sql)
        
        # Get system's response
        response = answer_question.remote(question, db_path)
        generated_sql = response["generated_sql"]
        generated_answer = response["result"]
        error = response["error"]
        
        # Build log content
        log_content = (
            f"Question: {question}\n"
            f"Correct SQL: {correct_sql}\n"
            f"Expected Answer: {expected_answer}\n"
            f"Generated SQL: {generated_sql}\n"
            f"Generated Answer: {generated_answer}\n"
        )
        if error:
            log_content += f"Error: {error}\n"
        
        log_test_result("normal", log_content, f"test_{test_id}")
    conn.close()
```
The full QA historial is logged in the volume: https://modal.com/storage/neu-info5100-oak-spr-2025/main/chongchen-bitcoin-data/sql_tests/normal.

This implementation evaluates the accuracy of a natural language-to-SQL conversion system for querying Bitcoin blockchain data stored in SQLite. It uses OpenAI’s LLM API to generate SQL queries from user questions, executes them, and compares the results with predefined correct answers. The system includes 10 test cases covering various SQL functionalities, such as counting, filtering, aggregation, and ordering. Each test logs the expected SQL, generated SQL, expected answer, and actual answer for validation. By automating query execution and result comparison, the implementation ensures accuracy and reliability in translating Bitcoin-related questions into precise SQL queries.

## 5. 3 Hard Test Cases



## 6. Implementation Details

**All codes**: https://github.com/chongchen1999/INFO7500-cryptocurrency/tree/main/hw4

**Bitcoin database on Modal Volume**: https://modal.com/api/volumes/neu-info5100-oak-spr-2025/main/chongchen-bitcoin-data/files/content?path=bitcoin.db

**Test cases**: https://modal.com/storage/neu-info5100-oak-spr-2025/main/chongchen-bitcoin-data/sql_tests