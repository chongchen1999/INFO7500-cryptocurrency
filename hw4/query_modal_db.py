import sqlite3
from modal import App, Volume

app = App()
volume = Volume.from_name("chongchen-bitcoin-data")

@app.function(volumes={"/data": volume})
def query_bitcoin_db():
    """Query the Bitcoin blockchain database stored in Modal Volume."""
    conn = sqlite3.connect("/data/bitcoin.db")
    cursor = conn.cursor()

    # Example 1: Get the latest block information
    cursor.execute("SELECT * FROM block ORDER BY height DESC LIMIT 1;")
    latest_block = cursor.fetchone()
    print("Latest Block:", latest_block)

    # Example 2: Count total number of blocks in the database
    cursor.execute("SELECT COUNT(*) FROM block;")
    total_blocks = cursor.fetchone()[0]
    print("Total Blocks:", total_blocks)

    # Example 3: Get the block with the highest difficulty
    cursor.execute("SELECT * FROM block ORDER BY difficulty DESC LIMIT 1;")
    highest_difficulty_block = cursor.fetchone()
    print("Block with Highest Difficulty:", highest_difficulty_block)

    conn.close()

if __name__ == "__main__":
    query_bitcoin_db.call()
