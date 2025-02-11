import modal
import requests

app = modal.App("chongchen-bitcoin-node")

# Create (or get) a persistent volume for Bitcoin data
volume = modal.Volume.from_name("chongchen-bitcoin-data", create_if_missing=True)

# Build the image from our Dockerfile
image = modal.Image.from_dockerfile("Dockerfile")

# Function to run bitcoind as a long-running service
@app.function(
    image=image,
    volumes={"/data": volume},
    timeout=86400,
    keep_warm=1,  # Keep the container warm for quick RPC responses
)
def run_bitcoind():
    import subprocess
    subprocess.run(["bitcoind", "-datadir=/data"])

# Function to make an RPC call to get block details at a given height
@app.function(image=image, timeout=60)
def getblock(num: int):
    """
    Retrieves the block details for the block at height `num`
    by making two JSON-RPC calls:
      1. getblockhash (to obtain the block hash for the given height)
      2. getblock (to obtain block details using that hash)
    """
    # Step 1: Get the block hash for the specified height
    payload_hash = {
        "jsonrpc": "1.0",
        "id": "modal",
        "method": "getblockhash",
        "params": [num]
    }
    response = requests.post(
        "http://127.0.0.1:8332/rpc",
        json=payload_hash,
        
    )
    response.raise_for_status()  # Raise an error if the request failed
    block_hash = response.json()["result"]

    # Step 2: Get the block details using the block hash
    payload_block = {
        "jsonrpc": "1.0",
        "id": "modal",
        "method": "getblock",
        "params": [block_hash]
    }
    response2 = requests.post(
        "http://127.0.0.1:8332/rpc",
        json=payload_block,
        auth=("admin", "@dmin123456")
    )
    response2.raise_for_status()
    return response2.json()["result"]

# Example entry point for local testing
if __name__ == "__main__":
    with app.run():
        # Start the Bitcoin daemon in the background
        run_bitcoind.remote()

        # Example: Retrieve block details for block at height 100
        # (Replace 100 with any block height of interest)
        # result = getblock.call(100)
        # print(result)
