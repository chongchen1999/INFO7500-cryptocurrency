import json

def extract_keys(data, parent_key=""):
    """ Recursively extract all key paths from a JSON object. """
    keys = set()
    
    if isinstance(data, dict):
        for key, value in data.items():
            full_key = f"{parent_key}.{key}" if parent_key else key
            keys.add(full_key)
            keys.update(extract_keys(value, full_key))
    
    elif isinstance(data, list):
        for item in data:
            keys.update(extract_keys(item, parent_key))
    
    return keys

# Load JSON file
with open("hw3/block_data/block_0.json", "r") as f:
    block_data = json.load(f)

# Extract keys
all_keys = extract_keys(block_data)

with open("hw3/block_data/block_0_fields.txt", "w") as f:
    for key in sorted(all_keys):
        f.write(key + "\n")