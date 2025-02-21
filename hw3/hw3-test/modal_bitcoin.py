# modal_bitcoin.py
import modal
import os
import time
import subprocess
from typing import Optional
from fastapi import HTTPException, Security
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from modal import Image, App, Volume, NetworkFileSystem, forward

app = App("bitcoin-full-node")  # Initialize Modal app
security = HTTPBasic()

# Configuration constants
BITCOIN_DATA_DIR = "/home/bitcoin/.bitcoin"
VOLUME_NAME = "bitcoin-chaindata"
RPC_PORT = 8332

# Create persistent volume for blockchain data
# blockchain_volume = Volume.persisted(VOLUME_NAME)
blockchain_volume = modal.Volume.from_name(VOLUME_NAME, create_if_missing=True)

# Build custom Docker image with Bitcoin Core
bitcoin_image = Image.from_dockerfile("Dockerfile")

@app.function(
    image=bitcoin_image,
    gpu="any",
    volumes={BITCOIN_DATA_DIR: blockchain_volume},
    timeout=86400,  # 4 days
)
def run_bitcoind():
    # Start Bitcoin Core with configuration
    bitcoind_process = subprocess.Popen(
        ["bitcoind", f"-datadir={BITCOIN_DATA_DIR}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT
    )
    
    # Monitor process and logs
    try:
        while True:
            output = bitcoind_process.stdout.readline()
            if output:
                print(output.decode().strip())
            time.sleep(60)
    except KeyboardInterrupt:
        bitcoind_process.terminate()

@app.function()
@forward(port=RPC_PORT)
def rpc_endpoint():
    pass

@app.function(secret=modal.Secret.from_name("bitcoin-rpc-auth"))
def get_block(num: int, credentials: HTTPBasicCredentials = Security(security)):
    # Validate credentials
    correct_username = os.environ["BITCOIN_RPC_USER"]
    correct_password = os.environ["BITCOIN_RPC_PASSWORD"]
    
    if (credentials.username != correct_username or 
        credentials.password != correct_password):
        raise HTTPException(
            status_code=401,
            detail="Incorrect RPC credentials"
        )
    
    # Execute RPC command
    from bitcoinrpc.authproxy import AuthServiceProxy
    rpc_connection = AuthServiceProxy(
        f"http://{correct_username}:{correct_password}@127.0.0.1:{RPC_PORT}"
    )
    
    try:
        return rpc_connection.getblock(rpc_connection.getblockhash(num))
    except Exception as e:
        return {"error": str(e)}

@app.function(network_file_systems={BITCOIN_DATA_DIR: blockchain_volume})
def monitor_sync():
    from bitcoinrpc.authproxy import AuthServiceProxy
    
    while True:
        try:
            rpc_connection = AuthServiceProxy(
                f"http://{os.environ['BITCOIN_RPC_USER']}:{os.environ['BITCOIN_RPC_PASSWORD']}@127.0.0.1:{RPC_PORT}"
            )
            info = rpc_connection.getblockchaininfo()
            print(f"Current block height: {info['blocks']}")
            print(f"Verification progress: {info['verificationprogress']*100:.2f}%")
            time.sleep(600)  # Check every 10 minutes
        except Exception as e:
            print(f"Monitoring error: {str(e)}")
            time.sleep(60)

if __name__ == "__main__":
    # Deploy with:
    # modal deploy modal_bitcoin.py
    
    # Start sync process (detached):
    # modal run modal_bitcoin.py::run_bitcoind --detach
    
    # Monitor progress:
    # modal run modal_bitcoin.py::monitor_sync
    
    # Query blocks (after deployment):
    # curl -X POST https://<your-endpoint>/get_block \
    #      -u "admin:<password>" \
    #      -H "Content-Type: application/json" \
    #      -d '{"num": 12345}'
    pass
