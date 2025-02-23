-- Create a new database
CREATE DATABASE bitcoin_blockchain;

-- Switch to the new database
\c bitcoin_blockchain;

-- Main configuration table to track sync state
CREATE TABLE sync_state (
    id INTEGER PRIMARY KEY CHECK (id = 1),  -- Ensure only one row
    current_height INTEGER NOT NULL,
    last_sync_time TIMESTAMP NOT NULL
);

-- Create the blocks table
CREATE TABLE blocks (
    hash VARCHAR(64) PRIMARY KEY,
    height INT NOT NULL,
    version INT NOT NULL,
    versionHex VARCHAR(16),
    previousblockhash VARCHAR(64),
    nextblockhash VARCHAR(64),
    merkleroot VARCHAR(64),
    time INT NOT NULL,
    mediantime INT NOT NULL,
    nonce BIGINT NOT NULL,
    bits VARCHAR(16),
    difficulty DOUBLE PRECISION,
    chainwork VARCHAR(64),
    confirmations INT,
    size INT,
    strippedsize INT,
    weight INT,
    nTx INT
);

-- Create the transactions table
CREATE TABLE transactions (
    txid VARCHAR(64) PRIMARY KEY,
    block_hash VARCHAR(64) REFERENCES blocks(hash),
    version INT NOT NULL,
    locktime INT NOT NULL,
    size INT NOT NULL,
    vsize INT NOT NULL,
    weight INT NOT NULL,
    hex TEXT,
    fee DOUBLE PRECISION,
    FOREIGN KEY (block_hash) REFERENCES blocks(hash)
);

-- Create the vin table (transaction inputs)
CREATE TABLE vin (
    id SERIAL PRIMARY KEY,
    txid VARCHAR(64) REFERENCES transactions(txid),
    vout INT,
    coinbase TEXT,
    txinwitness TEXT[],
    scriptSig_asm TEXT,
    scriptSig_hex TEXT,
    sequence BIGINT,
    FOREIGN KEY (txid) REFERENCES transactions(txid)
);

-- Create the vout table (transaction outputs)
CREATE TABLE vout (
    id SERIAL PRIMARY KEY,
    txid VARCHAR(64) REFERENCES transactions(txid),
    n INT NOT NULL,
    value DOUBLE PRECISION NOT NULL,
    scriptPubKey_asm TEXT,
    scriptPubKey_hex TEXT,
    scriptPubKey_type VARCHAR(32),
    scriptPubKey_address VARCHAR(64),
    scriptPubKey_desc TEXT,
    FOREIGN KEY (txid) REFERENCES transactions(txid)
);

-- Create the witness table for storing SegWit data
CREATE TABLE witness (
    id SERIAL PRIMARY KEY,
    vin_id INT REFERENCES vin(id),
    witness_data TEXT,
    FOREIGN KEY (vin_id) REFERENCES vin(id)
);