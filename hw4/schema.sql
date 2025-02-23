PRAGMA foreign_keys = ON;



-- Table Definitions

CREATE TABLE IF NOT EXISTS block (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hash VARCHAR(255) NOT NULL,
    confirmations INTEGER NOT NULL,
    height INTEGER NOT NULL,
    version INTEGER NOT NULL,
    versionhex VARCHAR(255) NOT NULL,
    merkleroot VARCHAR(255) NOT NULL,
    time INTEGER NOT NULL,
    mediantime INTEGER NOT NULL,
    nonce INTEGER NOT NULL,
    bits VARCHAR(255) NOT NULL,
    difficulty REAL NOT NULL,
    chainwork VARCHAR(255) NOT NULL,
    ntx INTEGER NOT NULL,
    previousblockhash VARCHAR(255) NOT NULL,
    nextblockhash VARCHAR(255) NOT NULL,
    strippedsize INTEGER NOT NULL,
    size INTEGER NOT NULL,
    weight INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS block_tx (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    block_id INTEGER REFERENCES block(id),
    txid VARCHAR(255) NOT NULL,
    hash VARCHAR(255) NOT NULL,
    version INTEGER NOT NULL,
    size INTEGER NOT NULL,
    vsize INTEGER NOT NULL,
    weight INTEGER NOT NULL,
    locktime INTEGER NOT NULL,
    hex VARCHAR(255) NOT NULL
);

CREATE TABLE IF NOT EXISTS block_tx_vin (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    block_tx_id INTEGER REFERENCES block_tx(id),
    coinbase VARCHAR(255) NOT NULL,
    txinwitness JSON NOT NULL,
    sequence INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS block_tx_vout (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    block_tx_id INTEGER REFERENCES block_tx(id),
    value REAL NOT NULL,
    n INTEGER NOT NULL,
    scriptpubkey_id INTEGER REFERENCES block_tx_vout_scriptpubkey(id)
);

CREATE TABLE IF NOT EXISTS block_tx_vout_scriptpubkey (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    block_tx_vout_id INTEGER REFERENCES block_tx_vout(id),
    asm VARCHAR(255) NOT NULL,
    desc VARCHAR(255) NOT NULL,
    hex VARCHAR(255) NOT NULL,
    address VARCHAR(255) NOT NULL,
    type VARCHAR(255) NOT NULL
);
