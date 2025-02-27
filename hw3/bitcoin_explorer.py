import modal
from modal import App, Volume, Secret
import os
import requests
import sqlite3
import json
import time
from typing import Dict, Any

app = App(name="bitcoin-block-explorer")  # Use modal.App

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
    block_dir = "/data/blocks"
    os.makedirs(block_dir, exist_ok=True)
    with open(f"{block_dir}/block_{block_data['height']}.json", 'w') as f:
        json.dump(block_data, f)

@app.function(
    volumes={"/data": volume},
    image=bitcoin_image,
    secrets=[Secret.from_name("chongchen-bitcoin-rpcauth")],
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