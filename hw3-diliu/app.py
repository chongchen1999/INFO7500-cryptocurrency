import os
import time
import subprocess
import shutil
from fastapi import FastAPI, HTTPException
from bitcoinrpc.authproxy import AuthServiceProxy
import modal
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

app = modal.App("chongchen-bitcoin-node")
VOLUME_NAME = "chongchen-bitcoin-data"
volume = modal.Volume.from_name(VOLUME_NAME, create_if_missing=True)
bitcoin_image = modal.Image.from_dockerfile("Dockerfile")

fastapi_app = FastAPI()

def get_rpc_connection():
    try:
        username = os.getenv('RPC_USER')
        password = os.getenv('RPC_PASSWORD')
        rpc_url = f"http://{username}:{password}@127.0.0.1:8332/"
        return AuthServiceProxy(rpc_url)
    except Exception as e:
        raise Exception(f"Failed to create RPC connection: {str(e)}")

@fastapi_app.get("/v1/health")
async def health():
    try:
        rpc = get_rpc_connection()
        info = rpc.getnetworkinfo()
        return {"status": "healthy", "version": info["version"], "connections": info["connections"]}
    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e))

@fastapi_app.get("/v1/block_count")
async def get_block_count():
    try:
        rpc = get_rpc_connection()
        count = rpc.getblockcount()
        return {"block_count": count}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")

@app.function(
    name="bitcoin_run",
    volumes={"/data": volume},
    image=bitcoin_image,
    timeout=86400,
    keep_warm=1,                # Keep warm for faster restarts
    # secrets=[modal.Secret.from_name("bitcoin-rpcauth")]
)
@modal.asgi_app()
def bitcoin_run():
    ip_addr = subprocess.getoutput("hostname -I")
    print(f"Modal instance IP: {ip_addr}")
    # Ensure the /data directory exists and copy the configuration file
    os.makedirs("/data", exist_ok=True)
    config_path = "/data/bitcoin.conf"
    if not os.path.exists(config_path):
        shutil.copy("/root/.bitcoin/bitcoin.conf", config_path)
        print("Copied bitcoin.conf to /data")
    
    # Start bitcoind as a subprocess
    subprocess.Popen(["bitcoind", "-datadir=/data", "-printtoconsole"])
    print("bitcoind is starting...")
    
    # Return FastAPI app to keep the container process running
    return fastapi_app
