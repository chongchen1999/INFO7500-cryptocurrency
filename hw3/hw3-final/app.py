import modal

app = modal.App("bitcoin-explorer")

bitcoin_volume = modal.Volume.from_name("bitcoin-data", create_if_missing = True)
bitcoin_image = modal.Image.from_dockerfile("Dockerfile")

@app.function(
    volumes={"/data": bitcoin_volume},
    image=bitcoin_image,
    timeout=86400,
    secrets=[modal.Secret.from_name("bitcoin-rpcauth")]
)
def sync_blocks():
    import sync
    sync.sync_blocks()

@app.function(
    volumes={"/data": bitcoin_volume}
)
def query(sql: str):
    import sqlite3
    from contextlib import closing
    
    with closing(sqlite3.connect('/data/bitcoin.db')) as conn:
        conn.row_factory = sqlite3.Row
        with closing(conn.cursor()) as cursor:
            cursor.execute(sql)
            return [dict(row) for row in cursor.fetchall()]

# For local testing
if __name__ == "__main__":
    with app.run():
        sync_blocks.remote()