import sqlite3
import json

DB_PATH = "/home/tourist/neu/INFO7500-cryptocurrency/hw4/blockchain.db"

def execute_query(query, params=None, fetch=False):
    """Executes a given SQL query and optionally fetches results."""
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = ON")
    cursor = conn.cursor()
    
    try:
        if params:
            cursor.execute(query, params)
        else:
            cursor.execute(query)
        
        if fetch:
            result = cursor.fetchall()
            conn.close()
            return result
        else:
            conn.commit()
    
    except sqlite3.Error as e:
        print(f"Database error: {e}")
        conn.rollback()
    
    finally:
        conn.close()

# 1. Insert a test block
test_block_1 = {
    "hash": "000000000000000000076d286d8bcf76d9e84f4df5de2d5b2f3e0b8b7ec3a891",
    "confirmations": 100,
    "height": 700000,
    "version": 536870912,
    "versionhex": "20000000",
    "merkleroot": "3a5fbdcb21fc96aa45fcd78b3b7bb378b90eb49eaa75cc631a9c68e07c1c7af7",
    "time": 1633000000,
    "mediantime": 1632995000,
    "nonce": 123456789,
    "bits": "170d3a22",
    "difficulty": 2000000000000.0,
    "chainwork": "0000000000000000000000000000000000000000000000100000000000000000",
    "ntx": 2500,
    "previousblockhash": "0000000000000000000a4c0db58de5f7c1f3e4a80e23a1dd0b9d9c8a482fbcf2",
    "nextblockhash": "0000000000000000000132a4b6e5d3c2f8a9e2d5b7c8e3f1a0b9d9c7e6d5c4a3",
    "strippedsize": 1000000,
    "size": 1200000,
    "weight": 4000000,
    "tx": json.dumps(["tx1", "tx2", "tx3"])
}

insert_block_query = """
    INSERT INTO block (
        hash, confirmations, height, version, versionhex, merkleroot, time, mediantime,
        nonce, bits, difficulty, chainwork, ntx, previousblockhash, nextblockhash, 
        strippedsize, size, weight, tx
    ) VALUES (
        :hash, :confirmations, :height, :version, :versionhex, :merkleroot, :time, :mediantime,
        :nonce, :bits, :difficulty, :chainwork, :ntx, :previousblockhash, :nextblockhash,
        :strippedsize, :size, :weight, :tx
    )
"""
execute_query(insert_block_query, test_block_1)

# 2. Select all blocks
select_all_blocks = "SELECT * FROM block"
print("All Blocks:", execute_query(select_all_blocks, fetch=True))

# 3. Select block by height
select_by_height = "SELECT * FROM block WHERE height = ?"
print("Block at height 700000:", execute_query(select_by_height, (700000,), fetch=True))

# 4. Select block by hash
select_by_hash = "SELECT * FROM block WHERE hash = ?"
print("Block with specific hash:", execute_query(select_by_hash, 
    ("000000000000000000076d286d8bcf76d9e84f4df5de2d5b2f3e0b8b7ec3a891",), fetch=True))

# 5. Count number of blocks
count_blocks_query = "SELECT COUNT(*) FROM block"
print("Total blocks:", execute_query(count_blocks_query, fetch=True))

# 6. Get block with the highest difficulty
highest_difficulty_query = "SELECT * FROM block ORDER BY difficulty DESC LIMIT 1"
print("Block with highest difficulty:", execute_query(highest_difficulty_query, fetch=True))

# 7. Update block confirmations
update_confirmations_query = "UPDATE block SET confirmations = confirmations + 1 WHERE height = ?"
execute_query(update_confirmations_query, (700000,))

# 8. Delete block by hash
delete_block_query = "DELETE FROM block WHERE hash = ?"
execute_query(delete_block_query, ("000000000000000000076d286d8bcf76d9e84f4df5de2d5b2f3e0b8b7ec3a891",))

# 9. Verify block deletion
verify_deletion_query = "SELECT * FROM block WHERE hash = ?"
print("Block after deletion (should be empty):", execute_query(verify_deletion_query, 
    ("000000000000000000076d286d8bcf76d9e84f4df5de2d5b2f3e0b8b7ec3a891",), fetch=True))

# 10. Get the latest block (highest height)
latest_block_query = "SELECT * FROM block ORDER BY height DESC LIMIT 1"
print("Latest block in chain:", execute_query(latest_block_query, fetch=True))
