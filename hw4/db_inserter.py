import json
import sqlite3
from typing import Any, Dict, List, Tuple
from pathlib import Path

def sanitize_identifier(name: str) -> str:
    """
    Sanitize table and column names to be SQL-safe.
    Keeping this consistent with schema generator.
    """
    sanitized = ''.join(c if c.isalnum() else '_' for c in name)
    if sanitized[0].isdigit():
        sanitized = f"t_{sanitized}"
    return sanitized.lower()

def flatten_data(data: Any) -> Dict[str, Any]:
    """
    Flatten nested data into a single-level dictionary for insertion.
    Returns flattened data and a dict of nested objects/arrays to process separately.
    """
    flat_data = {}
    nested_data = {}
    
    if isinstance(data, dict):
        for key, value in data.items():
            col_name = sanitize_identifier(key)
            
            if isinstance(value, dict) and value:
                nested_data[col_name] = ('object', value)
                flat_data[f"{col_name}_id"] = None  # Will be updated with foreign key
            elif isinstance(value, list) and value and isinstance(value[0], dict):
                nested_data[col_name] = ('array', value)
            else:
                flat_data[col_name] = value
                
    return flat_data, nested_data

def insert_data(cursor: sqlite3.Cursor, table_name: str, data: Any, 
                parent_table: str = None, parent_id: int = None) -> int:
    """
    Recursively insert data into the database, handling nested structures.
    Returns the ID of the inserted record.
    """
    table_name = sanitize_identifier(table_name)
    flat_data, nested_data = flatten_data(data)
    
    # Add parent reference if this is a nested table
    if parent_table and parent_id:
        flat_data[f"{sanitize_identifier(parent_table)}_id"] = parent_id
    
    # Prepare and execute INSERT statement
    columns = list(flat_data.keys())
    placeholders = ['?' for _ in columns]
    values = [flat_data[col] for col in columns]
    
    if columns:  # Only insert if we have data
        columns_str = ', '.join(columns)
        placeholders_str = ', '.join(placeholders)
        insert_sql = f"""
        INSERT INTO {table_name} ({columns_str})
        VALUES ({placeholders_str})
        """
        try:
            cursor.execute(insert_sql, values)
        except:
            print(insert_sql)
            print(values)
        current_id = cursor.lastrowid
    else:
        # Handle empty object case
        cursor.execute(f"INSERT INTO {table_name} DEFAULT VALUES")
        current_id = cursor.lastrowid

    # Process nested data
    for key, (data_type, nested_value) in nested_data.items():
        nested_table = f"{table_name}_{key}"
        
        if data_type == 'object':
            # Insert single nested object and update foreign key
            nested_id = insert_data(cursor, nested_table, nested_value, table_name, current_id)
            cursor.execute(f"""
                UPDATE {table_name} 
                SET {key}_id = ?
                WHERE id = ?
            """, (nested_id, current_id))
            
        elif data_type == 'array':
            # Insert each object in the array
            for item in nested_value:
                insert_data(cursor, nested_table, item, table_name, current_id)
    
    return current_id

def insert_json_to_db(db_path: str, json_data: Any, base_table_name: str):
    """
    Insert JSON data into SQLite database according to the generated schema.
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Enable foreign keys
        cursor.execute("PRAGMA foreign_keys = ON")
        
        # Begin transaction
        cursor.execute("BEGIN TRANSACTION")
        
        # Insert data recursively
        insert_data(cursor, base_table_name, json_data)
        
        # Commit transaction
        conn.commit()
        print(f"Successfully inserted data into {db_path}")
        
    except Exception as e:
        conn.rollback()
        print(f"Error inserting data: {str(e)}")
        raise
    
    finally:
        conn.close()

# Example usage
if __name__ == "__main__":
    # Read JSON file
    json_file = Path("/home/tourist/neu/INFO7500-cryptocurrency/hw3/block_data/block_0.json")
    db_file = Path("/home/tourist/neu/INFO7500-cryptocurrency/hw4/blockchain.db")
    
    with open(json_file, "r") as f:
        json_obj = json.load(f)
    
    # Insert data
    insert_json_to_db(str(db_file), json_obj["result"], "block")