import json
from typing import List, Any

def infer_sql_type(value: Any) -> str:
    """
    Infer SQL data type from a Python value with improved type mapping.
    
    Args:
        value: Any Python value to analyze
        
    Returns:
        str: Corresponding SQL data type
    """
    if value is None:
        return "TEXT"
    elif isinstance(value, bool):
        return "BOOLEAN"
    elif isinstance(value, int):
        return "INTEGER"
    elif isinstance(value, float):
        return "REAL"
    elif isinstance(value, (list, dict)):
        return "JSON"
    elif isinstance(value, str):
        if len(value) > 1000:
            return "TEXT"
        return "VARCHAR(255)"
    else:
        return "TEXT"

def sanitize_identifier(name: str) -> str:
    """
    Sanitize table and column names to be SQL-safe.
    
    Args:
        name: Raw identifier name
        
    Returns:
        str: Sanitized identifier name
    """
    sanitized = ''.join(c if c.isalnum() else '_' for c in name)
    if sanitized[0].isdigit():
        sanitized = f"t_{sanitized}"
    return sanitized.lower()

def generate_schema(table_name: str, data: Any, parent_table: str = None) -> List[str]:
    """
    Recursively generate SQL schema from data.
    
    Args:
        table_name: Name of the table to create
        data: Data to analyze for schema generation
        parent_table: Name of the parent table if this is a nested structure
        
    Returns:
        List[str]: Tables DDL statements with inline foreign key constraints
    """
    table_name = sanitize_identifier(table_name)
    tables = []
    columns = []
    
    columns.append("id INTEGER PRIMARY KEY AUTOINCREMENT")
    if parent_table:
        parent_fk = f"{sanitize_identifier(parent_table)}_id INTEGER"
        columns.append(f"{parent_fk} REFERENCES {parent_table}(id)")
    
    if isinstance(data, dict):
        for key, value in data.items():
            col_name = sanitize_identifier(key)
            
            if isinstance(value, dict):
                if value:  # Non-empty dictionary
                    nested_table_name = f"{table_name}_{col_name}"
                    nested_tables = generate_schema(nested_table_name, value, table_name)
                    tables.extend(nested_tables)
                    columns.append(f"{col_name}_id INTEGER REFERENCES {nested_table_name}(id)")
                else:  # Empty dictionary
                    sql_type = infer_sql_type(value)
                    nullable = "NOT NULL" if value is not None else "NULL"
                    columns.append(f"{col_name} {sql_type} {nullable}")
            else:
                sql_type = infer_sql_type(value)
                nullable = "NOT NULL" if value is not None else "NULL"
                columns.append(f"{col_name} {sql_type} {nullable}")
    
    columns_sql = ",\n    ".join(columns)
    create_table = f"""CREATE TABLE IF NOT EXISTS {table_name} (
    {columns_sql}
);"""
    tables.insert(0, create_table)
    return tables

def generate_sql_schema(data: Any, base_table_name: str) -> str:
    """
    Generate complete SQL schema including tables with inline constraints.
    
    Args:
        data: Data to analyze for schema generation
        base_table_name: Name of the root table
        
    Returns:
        str: Complete SQL schema
    """
    schema = ["PRAGMA foreign_keys = ON;", ""]
    schema.append("-- Table Definitions")
    tables = generate_schema(base_table_name, data)
    schema.extend(tables)
    return "\n\n".join(schema) + "\n"

# Example usage
if __name__ == "__main__":
    # Read JSON file
    with open("/home/tourist/neu/INFO7500-cryptocurrency/hw3/block_data/block_0.json", "r") as f:
        json_obj = json.load(f)
    
    # Generate schema
    sql_schema = generate_sql_schema(json_obj["result"], "block")
    
    # Write to file
    with open("/home/tourist/neu/INFO7500-cryptocurrency/hw4/schema.sql", "w") as f:
        f.write(sql_schema)