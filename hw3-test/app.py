import modal
import time
import os

app = modal.App("bitcoin-node")
volume = modal.Volume.from_name("bitcoin-data", create_if_missing=True)

# Create image with Bitcoin dependencies
image = modal.Image.from_dockerfile("Dockerfile")

@app.function(
    image=image,
    volumes={"/root/.bitcoin": volume},
    gpu=False,
    timeout=86400,  # 5 days
    keep_warm=1      # Keep warm for faster restarts
)
def run_bitcoin_node():
    import subprocess
    import time
    
    # Start bitcoind with specific data directory
    process = subprocess.Popen(["bitcoind", "-datadir=/root/.bitcoin"])
    
    while True:
        # Check blockchain info every 10 minutes
        time.sleep(600)
        try:
            info = subprocess.check_output([
                "bitcoin-cli", "-datadir=/root/.bitcoin", "getblockchaininfo"
            ]).decode()
            print(f"Current blockchain info: {info}")
        except Exception as e:
            print(f"Error checking blockchain info: {e}")

@app.function(image=image)
def get_block_count():
    import subprocess
    return subprocess.check_output([
        "bitcoin-cli", 
        "-datadir=/root/.bitcoin", 
        "getblockcount"
    ]).decode()

@app.function(image=image)
def get_block(block_num: int):
    import subprocess
    block_hash = subprocess.check_output([
        "bitcoin-cli",
        "-datadir=/root/.bitcoin",
        "getblockhash",
        str(block_num)
    ]).decode().strip()
    return subprocess.check_output([
        "bitcoin-cli",
        "-datadir=/root/.bitcoin",
        "getblock",
        block_hash
    ]).decode()

if __name__ == "__main__":
    with app.run():
        # Run the node in detached mode
        run_bitcoin_node.remote()