import os
import modal
import requests
from requests.auth import HTTPBasicAuth
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Initialize the FastAPI app
fastapi_app = FastAPI()

# Define the Modal image with FastAPI installed
image = modal.Image.debian_slim().pip_install("fastapi[standard]", "requests", "python-dotenv")

# Initialize the Modal app with the specified image
app = modal.App(image=image)

# RPC credentials and URL
RPC_USER = os.getenv("RPC_USER")
RPC_PASSWORD = os.getenv("RPC_PASSWORD")
RPC_HOST = os.getenv("RPC_HOST", "127.0.0.1")
RPC_PORT = os.getenv("RPC_PORT", "8332")
RPC_URL = f"http://{RPC_HOST}:{RPC_PORT}/"

# Define the request model
class BlockRequest(BaseModel):
    block_num: int

@fastapi_app.post("/get_block")
def get_block(request: BlockRequest):
    """
    Retrieve information about a specific block by its number.
    """
    # RPC payload
    payload = {
        "jsonrpc": "1.0",
        "id": "curltest",
        "method": "getblockbynumber",
        "params": [request.block_num]
    }

    try:
        # Make the RPC call to bitcoind
        response = requests.post(
            RPC_URL,
            json=payload,
            auth=HTTPBasicAuth(RPC_USER, RPC_PASSWORD)
        )
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail=str(e))

    # Return the JSON response from bitcoind
    return response.json()

# Serve the FastAPI app using Modal
@app.function()
@modal.asgi_app()
def fastapi_app():
    return fastapi_app
