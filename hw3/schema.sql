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
    weight INTEGER NOT NULL,
    tx JSON NOT NULL
);
