import modal

# Connect to your deployed app
app = modal.App("chongchen-bitcoin-node")  # Must match exactly

# Get reference to the class
BitcoinNode = modal.Cls.lookup(
    "chongchen-bitcoin-node",  # App name
    "BitcoinNode",             # Class name
    mount=modal.Mount.from_local_file("./bitcoin.conf")
)

def main():
    # Call the remote method directly on the class
    try:
        block_0 = BitcoinNode.getblock.remote(0)
        print("Genesis block:", block_0)
        
        block_count = BitcoinNode.getblock.remote("count")
        print("Current block height:", block_count)
    except modal.exception.ExecutionError as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    with app.run():
        main()