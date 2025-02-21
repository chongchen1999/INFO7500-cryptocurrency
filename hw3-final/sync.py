import os
import sqlite3
import requests
from tqdm import tqdm

def init_db(conn):
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS blocks (
            height INTEGER PRIMARY KEY,
            hash TEXT UNIQUE,
            timestamp INTEGER,
            version INTEGER,
            previous_block_hash TEXT,
            merkle_root TEXT,
            difficulty REAL,
            nonce INTEGER,
            tx_count INTEGER
        )
    ''')
    conn.commit()

def get_rpc(method, params=[]):
    auth = (
        os.environ["BITCOIN_RPC_USERNAME"],
        os.environ["BITCOIN_RPC_PASSWORD"]
    )
    url = "https://bitcoin-mainnet.core.chainstack.com/33c7e6e3370a6b6c4e4dcf41f2746c59"
    
    payload = {
        "jsonrpc": "2.0",
        "id": "chainstack",
        "method": method,
        "params": params
    }
    
    response = requests.post(url, json=payload, auth=auth)
    response.raise_for_status()
    return response.json()["result"]

def sync_blocks():
    # Database setup
    conn = sqlite3.connect('/data/bitcoin.db')
    init_db(conn)
    
    # Get current blockchain status
    best_height = get_rpc("getblockcount")
    
    # Get last synced height
    cursor = conn.cursor()
    cursor.execute("SELECT MAX(height) FROM blocks")
    last_height = cursor.fetchone()[0] or 0
    
    # Sync new blocks
    for height in tqdm(range(last_height + 1, best_height + 1)):
        block_hash = get_rpc("getblockhash", [height])
        block = get_rpc("getblock", [block_hash, 1])  # Verbosity level 1
        
        cursor.execute('''
            INSERT INTO blocks VALUES (
                ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
        ''', (
            height,
            block_hash,
            block["time"],
            block["version"],
            block["previousblockhash"],
            block["merkleroot"],
            block["difficulty"],
            block["nonce"],
            block["nTx"]
        ))
        
        conn.commit()
    
    conn.close()

if __name__ == "__main__":
    sync_blocks()