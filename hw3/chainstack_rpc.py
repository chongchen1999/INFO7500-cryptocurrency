import requests
import json
from datetime import datetime
import os
from dotenv import load_dotenv

def get_block_verbose(block_hash, endpoint, username, password):
    """
    Make a getblock RPC call with verbosity=2
    
    Args:
        block_hash (str): The hash of the block to retrieve
        endpoint (str): The Chainstack endpoint URL
        username (str): Chainstack username
        password (str): Chainstack password
    """
    
    payload = {
        "jsonrpc": "2.0",
        "method": "getblock",
        "params": [block_hash, 2],
        "id": 1
    }
    
    try:
        response = requests.post(
            endpoint,
            auth=(username, password),
            json=payload,
            headers={'Content-Type': 'application/json'}
        )
        
        response.raise_for_status()
        return response.json()
        
    except requests.exceptions.RequestException as e:
        print(f"Error making RPC call: {e}")
        return None

def save_block_data(block_data, output_dir="block_data"):
    """
    Save block data to a JSON file
    """
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Get block height or hash for filename
    block_info = block_data.get('result', {})
    block_height = block_info.get('height', 'unknown')
    block_hash = block_info.get('hash', 'unknown')
    
    # Create filename with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"block_{block_height}_{block_hash[:8]}_{timestamp}.json"
    filepath = os.path.join(output_dir, filename)
    
    # Save to file with pretty printing
    with open(filepath, 'w') as f:
        json.dump(block_data, f, indent=2)
    
    return filepath

def main():
    # Load environment variables from .env file
    load_dotenv()
    
    # Get Chainstack credentials from environment variables
    ENDPOINT = os.getenv("chainstack_https_endpoint")
    USERNAME = os.getenv("chainstack_username")
    PASSWORD = os.getenv("chainstack_password")
    
    # Check if environment variables are loaded properly
    if not all([ENDPOINT, USERNAME, PASSWORD]):
        print("Error: Missing environment variables. Make sure .env file exists with required variables.")
        return
    
    # Example block hash (Bitcoin genesis block)
    BLOCK_HASH = "000000000000000000003fb9a79c6b9c73831537eb31b469ad113d6a99176a97"
    
    # Make the call
    print("Fetching block data...")
    result = get_block_verbose(BLOCK_HASH, ENDPOINT, USERNAME, PASSWORD)
    
    if result and 'result' in result:
        # Save to file
        filepath = save_block_data(result)
        print(f"Block data saved to: {filepath}")
    elif result:
        print("Error in response:", result.get('error'))
    else:
        print("Failed to get response")

if __name__ == "__main__":
    main()