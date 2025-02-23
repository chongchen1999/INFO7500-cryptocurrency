import sqlite3
import json
from typing import Dict, Any
from pathlib import Path

class BlockDBInserter:
    def __init__(self, db_path: str):
        """Initialize database connection.
        
        Args:
            db_path (str): Path to SQLite database file
        """
        self.conn = sqlite3.connect(db_path)
        self.conn.execute("PRAGMA foreign_keys = ON")
        self.cursor = self.conn.cursor()
        
        # Ensure the block table exists
        self._create_table()

    def _create_table(self):
        """Ensure the block table exists before inserting data."""
        self.cursor.execute("""
            CREATE TABLE IF NOT EXISTS block (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                hash TEXT UNIQUE NOT NULL,
                confirmations INTEGER,
                height INTEGER NOT NULL,
                version INTEGER,
                versionhex TEXT,
                merkleroot TEXT,
                time INTEGER,
                mediantime INTEGER,
                nonce INTEGER,
                bits TEXT,
                difficulty REAL,
                chainwork TEXT,
                ntx INTEGER,
                previousblockhash TEXT,
                nextblockhash TEXT,
                strippedsize INTEGER,
                size INTEGER,
                weight INTEGER,
                tx TEXT
            )
        """)
        self.conn.commit()

    def insert_block(self, block_data: Dict[str, Any]) -> int:
        """Insert a block record into the database.
        
        Args:
            block_data (Dict[str, Any]): Dictionary containing block data
            
        Returns:
            int: ID of the inserted block record
        """
        try:
            # Convert TX data to JSON string if it isn't already
            block_data['tx'] = json.dumps(block_data.get('tx', []))

            # SQL query with named parameters
            sql = """
                INSERT INTO block (
                    hash, confirmations, height, version, versionhex,
                    merkleroot, time, mediantime, nonce, bits,
                    difficulty, chainwork, ntx, previousblockhash,
                    nextblockhash, strippedsize, size, weight, tx
                ) VALUES (
                    :hash, :confirmations, :height, :version, :versionhex,
                    :merkleroot, :time, :mediantime, :nonce, :bits,
                    :difficulty, :chainwork, :ntx, :previousblockhash,
                    :nextblockhash, :strippedsize, :size, :weight, :tx
                )
            """
            
            # Execute the insert
            self.cursor.execute(sql, {
                'hash': block_data.get('hash'),
                'confirmations': block_data.get('confirmations', 0),
                'height': block_data.get('height'),
                'version': block_data.get('version'),
                'versionhex': block_data.get('versionHex'),
                'merkleroot': block_data.get('merkleroot'),
                'time': block_data.get('time'),
                'mediantime': block_data.get('mediantime'),
                'nonce': block_data.get('nonce'),
                'bits': block_data.get('bits'),
                'difficulty': block_data.get('difficulty'),
                'chainwork': block_data.get('chainwork'),
                'ntx': block_data.get('nTx'),
                'previousblockhash': block_data.get('previousblockhash'),
                'nextblockhash': block_data.get('nextblockhash', None),
                'strippedsize': block_data.get('strippedsize'),
                'size': block_data.get('size'),
                'weight': block_data.get('weight'),
                'tx': block_data['tx']
            })
            self.conn.commit()
            
            return self.cursor.lastrowid
            
        except sqlite3.IntegrityError as e:
            self.conn.rollback()
            raise Exception(f"Integrity error: {str(e)}")
        except sqlite3.Error as e:
            self.conn.rollback()
            raise Exception(f"Database error: {str(e)}")
        except Exception as e:
            self.conn.rollback()
            raise Exception(f"Error inserting block: {str(e)}")

    def close(self):
        """Close the database connection."""
        if self.conn:
            self.conn.close()

# Example usage
if __name__ == "__main__":
    # Read JSON file
    json_file = Path("/home/tourist/neu/INFO7500-cryptocurrency/hw3/block_data/block_0.json")
    db_file = Path("/home/tourist/neu/INFO7500-cryptocurrency/hw4/blockchain.db")
    
    try:
        with open(json_file, "r") as f:
            json_obj = json.load(f)

        # Initialize the inserter with the correct DB path
        inserter = BlockDBInserter(str(db_file))
        
        # Insert the block
        block_id = inserter.insert_block(json_obj["result"])
        print(f"Successfully inserted block with ID: {block_id}")
        
    except Exception as e:
        print(f"Error: {str(e)}")
        
    finally:
        inserter.close()
