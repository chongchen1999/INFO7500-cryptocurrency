-- Main configuration table to track sync state
CREATE TABLE sync_state (
    id INTEGER PRIMARY KEY CHECK (id = 1),  -- Ensure only one row
    current_height INTEGER NOT NULL,
    last_sync_time TIMESTAMP NOT NULL
);

-- Blocks table with indices optimized for common queries
CREATE TABLE blocks (
    hash TEXT PRIMARY KEY,
    height INTEGER UNIQUE NOT NULL,
    version INTEGER,
    time INTEGER,
    nonce INTEGER,
    bits TEXT,
    difficulty REAL,
    merkleroot TEXT,
    chainwork TEXT,
    previousblockhash TEXT,
    nextblockhash TEXT,
    size INTEGER,
    weight INTEGER,
    num_tx INTEGER
);

-- Transactions table with position tracking
CREATE TABLE transactions (
    txid TEXT PRIMARY KEY,
    block_hash TEXT NOT NULL,
    position_in_block INTEGER NOT NULL,  -- Track position within block
    version INTEGER,
    size INTEGER,
    weight INTEGER,
    locktime INTEGER,
    fee REAL,
    FOREIGN KEY (block_hash) REFERENCES blocks(hash),
    UNIQUE (block_hash, position_in_block)  -- Ensure unique positioning
);

-- Transaction inputs
CREATE TABLE tx_inputs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    txid TEXT NOT NULL,
    input_index INTEGER NOT NULL,
    prevout_txid TEXT,
    prevout_index INTEGER,
    script TEXT,
    sequence INTEGER,
    witness TEXT,  -- Store witness data as JSON
    FOREIGN KEY (txid) REFERENCES transactions(txid),
    UNIQUE (txid, input_index)
);

-- Transaction outputs
CREATE TABLE tx_outputs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    txid TEXT NOT NULL,
    output_index INTEGER NOT NULL,
    value REAL NOT NULL,
    script_type TEXT,
    script_pubkey TEXT,
    addresses TEXT,  -- Store as JSON array
    FOREIGN KEY (txid) REFERENCES transactions(txid),
    UNIQUE (txid, output_index)
);

-- Create indices for better query performance
CREATE INDEX idx_blocks_height ON blocks(height);
CREATE INDEX idx_transactions_block_pos ON transactions(block_hash, position_in_block);
CREATE INDEX idx_tx_inputs_prevout ON tx_inputs(prevout_txid, prevout_index);
CREATE INDEX idx_tx_outputs_addresses ON tx_outputs(addresses);