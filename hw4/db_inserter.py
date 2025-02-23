import json
import sqlite3
from typing import Any, Dict, List, Tuple
from pathlib import Path

class DatabaseInserter:
    def __init__(self, db_path: str):
        """Initialize database connection."""
        self.conn = sqlite3.connect(db_path)
        self.conn.row_factory = sqlite3.Row
        self.cursor = self.conn.cursor()
        
    def __enter__(self):
        return self
        
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Ensure proper cleanup of database connection."""
        if exc_type is None:
            self.conn.commit()
        else:
            self.conn.rollback()
        self.cursor.close()
        self.conn.close()

    def insert_data(self, table_name: str, data: Dict[str, Any], parent_id: int = None) -> int:
        """
        Recursively insert data into the database.
        
        Args:
            table_name: Name of the target table
            data: Dictionary containing the data to insert
            parent_id: ID of the parent record for nested structures
            
        Returns:
            int: ID of the inserted record
        """
        # Prepare the data for insertion
        insert_data = {}
        nested_data = {}
        
        # Handle parent relationship
        if parent_id is not None:
            parent_table = table_name.rsplit('_', 1)[0]
            insert_data[f"{parent_table}_id"] = parent_id
            
        # Process each field
        for key, value in data.items():
            if isinstance(value, dict):
                # Handle nested objects
                nested_data[f"{table_name}_{key}"] = value
            elif isinstance(value, list) and value and isinstance(value[0], dict):
                # Handle arrays of objects
                nested_data[f"{table_name}_{key}"] = value
            elif isinstance(value, list):
                # Convert lists to JSON string
                insert_data[key] = json.dumps(value)
            else:
                # Handle primitive types
                insert_data[key] = value
                
        # Construct and execute INSERT statement
        columns = ', '.join(insert_data.keys())
        placeholders = ', '.join(['?' for _ in insert_data])
        values = tuple(insert_data.values())
        
        insert_sql = f"INSERT INTO {table_name} ({columns}) VALUES ({placeholders})"
        try:
            self.cursor.execute(insert_sql, values)
        except:
            print(insert_sql)
            print(values)
        record_id = self.cursor.lastrowid
        # Handle nested structures
        for nested_table, nested_value in nested_data.items():
            if isinstance(nested_value, list):
                # Insert array of objects
                for item in nested_value:
                    self.insert_data(nested_table, item, record_id)
            else:
                # Insert single nested object
                nested_id = self.insert_data(nested_table, nested_value, record_id)
                # Update foreign key in parent
                self.cursor.execute(
                    f"UPDATE {table_name} SET {nested_table.split('_')[-1]}_id = ? WHERE id = ?",
                    (nested_id, record_id)
                )
                
        return record_id

def process_json_files(json_dir: str, db_path: str):
    """
    Process all JSON files in a directory and insert them into the database.
    
    Args:
        json_dir: Directory containing JSON files
        db_path: Path to the SQLite database
    """
    json_path = Path(json_dir)
    
    with DatabaseInserter(db_path) as inserter:
        # Process each JSON file
        for json_file in json_path.glob('block_*.json'):
            print(f"Processing {json_file}")
            
            try:
                with open(json_file, 'r') as f:
                    data = json.load(f)
                
                # Insert the block data
                inserter.insert_data('block', data['result'])
                print(f"Successfully processed {json_file}")
                
            except Exception as e:
                print(f"Error processing {json_file}: {str(e)}")
                raise

if __name__ == "__main__":
    # Configuration
    JSON_DIR = "/home/tourist/neu/INFO7500-cryptocurrency/hw3/block_data"
    DB_PATH = "/home/tourist/neu/INFO7500-cryptocurrency/hw4/blockchain.db"
    
    # Create database and insert data
    process_json_files(JSON_DIR, DB_PATH)