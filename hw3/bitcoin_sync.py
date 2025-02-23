import sqlite3
import requests
import json
import time
import logging
from datetime import datetime
import sys
from typing import Optional, Dict, Any

class BitcoinExplorer:
    def __init__(self, db_path: str, rpc_endpoint: str, rpc_user: str, rpc_pass: str, max_height: Optional[int] = None):
        self.db_path = db_path
        self.rpc_endpoint = rpc_endpoint
        self.rpc_auth = (rpc_user, rpc_pass)
        self.max_height = max_height
        self.setup_logging()
        
    def setup_logging(self):
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('bitcoin_explorer.log'),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)

    def make_rpc_call(self, method: str, params: list) -> Dict[str, Any]:
        """Make RPC call to Bitcoin node"""
        payload = {
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": 1
        }
        
        try:
            response = requests.post(
                self.rpc_endpoint,
                auth=self.rpc_auth,
                json=payload,
                headers={'Content-Type': 'application/json'}
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            self.logger.error(f"RPC call failed: {e}")
            raise

    def get_current_chain_height(self) -> int:
        """Get current blockchain height"""
        result = self.make_rpc_call("getblockcount", [])
        return result['result']

    def get_block_by_height(self, height: int) -> Dict[str, Any]:
        """Get block data by height"""
        # First get block hash
        result = self.make_rpc_call("getblockhash", [height])
        block_hash = result['result']
        
        # Then get full block data
        result = self.make_rpc_call("getblock", [block_hash, 2])
        return result['result']

    def insert_block_data(self, conn: sqlite3.Connection, block_data: Dict[str, Any]):
        """Insert block and its transactions into database"""
        cursor = conn.cursor()
        
        # Insert block
        cursor.execute("""
            INSERT OR REPLACE INTO blocks (
                hash, height, version, time, nonce, bits, difficulty,
                merkleroot, chainwork, previousblockhash, nextblockhash,
                size, weight, num_tx
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            block_data['hash'], block_data['height'], block_data['version'],
            block_data['time'], block_data['nonce'], block_data['bits'],
            block_data['difficulty'], block_data['merkleroot'],
            block_data['chainwork'], block_data.get('previousblockhash'),
            block_data.get('nextblockhash'), block_data['size'],
            block_data['weight'], len(block_data['tx'])
        ))
        
        # Insert transactions
        for tx_index, tx in enumerate(block_data['tx']):
            # Insert transaction
            cursor.execute("""
                INSERT OR REPLACE INTO transactions (
                    txid, block_hash, position_in_block, version,
                    size, weight, locktime
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                tx['txid'], block_data['hash'], tx_index, tx['version'],
                tx['size'], tx['weight'], tx['locktime']
            ))
            
            # Insert inputs
            for vin_index, vin in enumerate(tx['vin']):
                cursor.execute("""
                    INSERT OR REPLACE INTO tx_inputs (
                        txid, input_index, prevout_txid, prevout_index,
                        script, sequence, witness
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """, (
                    tx['txid'], vin_index,
                    vin.get('txid'), vin.get('vout'),
                    vin.get('scriptSig', {}).get('hex'),
                    vin.get('sequence'),
                    json.dumps(vin.get('txinwitness', []))
                ))
            
            # Insert outputs
            for vout_index, vout in enumerate(tx['vout']):
                cursor.execute("""
                    INSERT OR REPLACE INTO tx_outputs (
                        txid, output_index, value, script_type,
                        script_pubkey, addresses
                    ) VALUES (?, ?, ?, ?, ?, ?)
                """, (
                    tx['txid'], vout_index, vout['value'],
                    vout['scriptPubKey'].get('type'),
                    vout['scriptPubKey'].get('hex'),
                    json.dumps(vout['scriptPubKey'].get('addresses', []))
                ))

    def sync_blockchain(self):
        """Main sync function"""
        conn = sqlite3.connect(self.db_path)
        try:
            cursor = conn.cursor()
            
            # Get current sync state
            cursor.execute("""
                INSERT OR IGNORE INTO sync_state (id, current_height, last_sync_time)
                VALUES (1, -1, CURRENT_TIMESTAMP)
            """)
            cursor.execute("SELECT current_height FROM sync_state WHERE id = 1")
            local_height = cursor.fetchone()[0]
            
            # Get current blockchain height
            chain_height = self.get_current_chain_height()
            
            # Apply pruning if configured
            if self.max_height is not None:
                chain_height = min(chain_height, self.max_height)
            
            self.logger.info(f"Local height: {local_height}, Chain height: {chain_height}")
            
            # Sync new blocks
            for height in range(local_height + 1, chain_height + 1):
                block_data = self.get_block_by_height(height)
                self.insert_block_data(conn, block_data)
                
                # Update sync state
                cursor.execute("""
                    UPDATE sync_state 
                    SET current_height = ?, last_sync_time = CURRENT_TIMESTAMP 
                    WHERE id = 1
                """, (height,))
                
                conn.commit()
                self.logger.info(f"Synced block {height}")
                
                # Add small delay to avoid overwhelming the RPC server
                time.sleep(0.1)
                
        except Exception as e:
            self.logger.error(f"Sync failed: {e}")
            conn.rollback()
            raise
        finally:
            conn.close()

def main():
    # Configuration
    DB_PATH = "bitcoin_explorer.db"
    RPC_ENDPOINT = "https://bitcoin-mainnet.core.chainstack.com/33c7e6e3370a6b6c4e4dcf41f2746c59"
    RPC_USER = "focused-fermi"
    RPC_PASS = "unsaid-cleft-errant-ample-sister-garnet"
    MAX_HEIGHT = 50  # Optional: set to None for no pruning
    
    explorer = BitcoinExplorer(DB_PATH, RPC_ENDPOINT, RPC_USER, RPC_PASS, MAX_HEIGHT)
    
    while True:
        try:
            explorer.sync_blockchain()
            time.sleep(10)
            # time.sleep(300)  # Wait 5 minutes before next sync
        except KeyboardInterrupt:
            break
        except Exception as e:
            explorer.logger.error(f"Sync cycle failed: {e}")
            time.sleep(60)  # Wait 1 minute before retry on error

if __name__ == "__main__":
    main()