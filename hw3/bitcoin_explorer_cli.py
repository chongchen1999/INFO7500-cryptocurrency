import argparse
import json
from datetime import datetime
from typing import Dict, List, Optional, Union
from query import BitcoinExplorerQueries

class BitcoinExplorerCLI:
    def __init__(self, db_path: str):
        self.queries = BitcoinExplorerQueries(db_path)
    
    def format_timestamp(self, timestamp: int) -> str:
        """Convert Unix timestamp to readable format"""
        return datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M:%S')
    
    def format_btc(self, satoshis: float) -> str:
        """Format satoshis as BTC with 8 decimal places"""
        return f"{satoshis:.8f} BTC"
    
    def cmd_blockchain_info(self) -> None:
        """Display general blockchain information"""
        info = self.queries.get_blockchain_info()
        print("\nBlockchain Information:")
        print(f"Total Blocks: {info['total_blocks']:,}")
        print(f"Total Transactions: {info['total_transactions']:,}")
        print(f"Latest Height: {info['latest_height']:,}")
        print(f"Latest Block Time: {self.format_timestamp(info['latest_block_time'])}")
        print(f"Current Difficulty: {info['current_difficulty']:,.2f}")
    
    def cmd_block_info(self, height: Optional[int] = None, hash: Optional[str] = None) -> None:
        """Display block information by height or hash"""
        block = self.queries.get_block_info(height, hash)
        if not block:
            print(f"Block not found")
            return
            
        print("\nBlock Information:")
        print(f"Hash: {block['hash']}")
        print(f"Height: {block['height']:,}")
        print(f"Time: {self.format_timestamp(block['time'])}")
        print(f"Transactions: {block['num_tx']:,}")
        print(f"Size: {block['size']:,} bytes")
        print(f"Weight: {block['weight']:,}")
        print(f"Version: {block['version']}")
        print(f"Merkle Root: {block['merkleroot']}")
        print(f"Difficulty: {block['difficulty']:,.2f}")
        
        if block['previousblockhash']:
            print(f"Previous Block: {block['previousblockhash']}")
        if block['nextblockhash']:
            print(f"Next Block: {block['nextblockhash']}")
    
    def cmd_transaction_info(self, txid: Optional[str] = None, 
                           block_hash: Optional[str] = None, 
                           position: Optional[int] = None) -> None:
        """Display transaction information"""
        if txid:
            tx = self.queries.get_transaction_by_txid(txid)
        elif block_hash and position is not None:
            tx = self.queries.get_transaction_by_position(block_hash, position)
        else:
            print("Either txid or block_hash+position must be provided")
            return
            
        if not tx:
            print("Transaction not found")
            return
            
        print("\nTransaction Information:")
        print(f"TXID: {tx['txid']}")
        print(f"Version: {tx['version']}")
        print(f"Size: {tx['size']} bytes")
        print(f"Weight: {tx['weight']}")
        print(f"Locktime: {tx['locktime']}")
        
        print("\nInputs:")
        for inp in tx['inputs']:
            print(f"  - Index: {inp['index']}")
            if inp['prevout_txid']:
                print(f"    Previous TX: {inp['prevout_txid']}:{inp['prevout_index']}")
            else:
                print("    Coinbase Transaction")
        
        print("\nOutputs:")
        for out in tx['outputs']:
            print(f"  - Index: {out['index']}")
            print(f"    Value: {self.format_btc(out['value'])}")
            print(f"    Type: {out['script_type']}")
            if out['addresses']:
                addresses = json.loads(out['addresses'])
                for addr in addresses:
                    print(f"    Address: {addr}")

def main():
    parser = argparse.ArgumentParser(description='Bitcoin Explorer CLI')
    parser.add_argument('--db', default='bitcoin_explorer.db',
                       help='Path to the SQLite database')
    
    subparsers = parser.add_subparsers(dest='command', help='Command to execute')
    
    # Blockchain info command
    subparsers.add_parser('info', help='Show blockchain information')
    
    # Block info command
    block_parser = subparsers.add_parser('block', help='Show block information')
    group = block_parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--height', type=int, help='Block height')
    group.add_argument('--hash', help='Block hash')
    
    # Transaction info command
    tx_parser = subparsers.add_parser('tx', help='Show transaction information')
    group = tx_parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--txid', help='Transaction ID')
    group.add_argument('--block', nargs=2, metavar=('HASH', 'POS'),
                      help='Block hash and transaction position')
    
    args = parser.parse_args()
    explorer = BitcoinExplorerCLI(args.db)
    
    if args.command == 'info':
        explorer.cmd_blockchain_info()
    elif args.command == 'block':
        explorer.cmd_block_info(height=args.height, hash=args.hash)
    elif args.command == 'tx':
        if args.txid:
            explorer.cmd_transaction_info(txid=args.txid)
        else:
            block_hash, pos = args.block
            explorer.cmd_transaction_info(block_hash=block_hash, 
                                       position=int(pos))

if __name__ == "__main__":
    main()