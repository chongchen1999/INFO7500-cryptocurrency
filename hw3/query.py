import sqlite3
from typing import Dict, List, Optional, Union

class BitcoinExplorerQueries:
    def __init__(self, db_path: str):
        self.db_path = db_path
    
    def _get_connection(self) -> sqlite3.Connection:
        return sqlite3.connect(self.db_path)
    
    def get_blockchain_height(self) -> int:
        """Get the current blockchain height in our database"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT MAX(height) FROM blocks")
            return cursor.fetchone()[0]
    
    def get_block_hash(self, height: int) -> Optional[str]:
        """Get block hash for given height"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT hash FROM blocks WHERE height = ?", (height,))
            result = cursor.fetchone()
            return result[0] if result else None
    
    def get_block_info(self, height: Optional[int] = None, block_hash: Optional[str] = None) -> Optional[Dict]:
        """
        Get detailed block information by either height or hash
        
        Args:
            height: Block height (optional)
            block_hash: Block hash (optional)
            
        Returns:
            Dictionary containing block information or None if not found
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            if height is not None:
                cursor.execute("""
                    SELECT hash, height, version, time, nonce, bits, difficulty,
                           merkleroot, chainwork, previousblockhash, nextblockhash,
                           size, weight, num_tx
                    FROM blocks WHERE height = ?
                """, (height,))
            elif block_hash is not None:
                cursor.execute("""
                    SELECT hash, height, version, time, nonce, bits, difficulty,
                           merkleroot, chainwork, previousblockhash, nextblockhash,
                           size, weight, num_tx
                    FROM blocks WHERE hash = ?
                """, (block_hash,))
            else:
                return None
                
            row = cursor.fetchone()
            if not row:
                return None
                
            return {
                'hash': row[0],
                'height': row[1],
                'version': row[2],
                'time': row[3],
                'nonce': row[4],
                'bits': row[5],
                'difficulty': row[6],
                'merkleroot': row[7],
                'chainwork': row[8],
                'previousblockhash': row[9],
                'nextblockhash': row[10],
                'size': row[11],
                'weight': row[12],
                'num_tx': row[13]
            }

def main():
    # Example usage
    explorer = BitcoinExplorerQueries("bitcoin_explorer.db")
    print("Connected to database.")
    
    # Get current height
    height = explorer.get_blockchain_height()
    print(f"Current blockchain height: {height}")
    
    # Get block hash for height 15
    block_hash = explorer.get_block_hash(15)
    if block_hash:
        print(f"Block hash for height 15: {block_hash}")
        
        # Get first transaction in that block
        tx = explorer.get_transaction_by_position(block_hash, 0)
        if tx:
            print(f"First transaction in block: {tx['txid']}")
    
    # Get general blockchain info
    info = explorer.get_blockchain_info()
    print("\nBlockchain Information:")