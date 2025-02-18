from bitcoinrpc.authproxy import AuthServiceProxy, JSONRPCException
import os
from dotenv import load_dotenv
import requests
from requests.auth import HTTPBasicAuth

# Load environment variables
load_dotenv()

def get_modal_endpoint():
    """Get the Modal endpoint from environment variables or configuration"""
    return os.getenv('MODAL_ENDPOINT', '').rstrip('/')

def test_endpoint_connection():
    """Test the Modal endpoint connection"""
    modal_endpoint = get_modal_endpoint()
    rpc_user = os.getenv('RPC_USER', 'admin')
    rpc_password = os.getenv('RPC_PASSWORD')
    
    try:
        response = requests.get(
            f"{modal_endpoint}/v1/health",
            auth=HTTPBasicAuth(rpc_user, rpc_password),
            verify=True  # Enable SSL verification
        )
        print(f"Endpoint test response: {response.status_code}")
        print(f"Response content: {response.text}")
        return response.status_code == 200
    except Exception as e:
        print(f"Failed to connect to endpoint: {str(e)}")
        return False

def create_rpc_connection():
    """Create a connection to the Bitcoin RPC server"""
    rpc_user = os.getenv('RPC_USER', 'admin')
    rpc_password = os.getenv('RPC_PASSWORD', '@dmin123456')
    modal_endpoint = get_modal_endpoint()
    
    # Use HTTP instead of HTTPS for the RPC connection
    rpc_url = f"http://{rpc_user}:{rpc_password}@{modal_endpoint.replace('https://', '')}/v1"
    
    return AuthServiceProxy(
        rpc_url,
        timeout=120,
        ssl_verify=False  # Disable SSL verification for the RPC connection
    )

def main():
    try:
        print("Testing endpoint connection...")
        if not test_endpoint_connection():
            print("Failed to connect to the endpoint. Please check your configuration.")
            return

        print("Creating RPC connection...")
        rpc_conn = create_rpc_connection()
        
        print("Getting blockchain info...")
        try:
            blockchain_info = rpc_conn.getblockchaininfo()
            print(f"Current Block Height: {blockchain_info['blocks']}")
            print(f"Chain: {blockchain_info['chain']}")
        except JSONRPCException as e:
            print(f"RPC Error: {str(e)}")
            
    except Exception as e:
        print(f"Error: {str(e)}")
        print("\nDebugging tips:")
        print("1. Check your .env file has the correct values:")
        print("   MODAL_ENDPOINT=https://your-modal-endpoint")
        print("   RPC_USER=admin")
        print("   RPC_PASSWORD=your-password")
        print("2. Verify the password matches the rpcauth in bitcoin.conf")
        print("3. Make sure bitcoind is running in Modal")
        print("4. Try accessing the endpoint in a browser first")

if __name__ == "__main__":
    # Print current configuration (without password)
    print("Current configuration:")
    print(f"Endpoint: {get_modal_endpoint()}")
    print(f"RPC User: {os.getenv('RPC_USER')}")
    print("RPC Password: [hidden]")
    print("\nStarting connection test...\n")
    main()