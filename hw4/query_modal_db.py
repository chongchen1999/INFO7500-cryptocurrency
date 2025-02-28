import sqlite3
from modal import App, Volume

app = App("chongchen-bitcoin-rpc")
volume = Volume.from_name("chongchen-bitcoin-data")

sql_statement = '''
    SELECT 
        b1.height,
        b1.hash,
        b1.difficulty,
        b2.difficulty AS previous_difficulty,
        (b1.difficulty - b2.difficulty) / b2.difficulty * 100 AS difficulty_increase_percent,
        b1.time - b1.mediantime AS time_diff_seconds,
        (b1.time - b1.mediantime) / 3600.0 AS time_diff_hours
    FROM 
        block b1
    JOIN 
        block b2 ON b1.previousblockhash = b2.hash
    WHERE 
        -- Difficulty increased by more than 10%
        (b1.difficulty - b2.difficulty) / b2.difficulty > 0.1
        
        -- Block was mined at least 2 hours after median time
        AND (b1.time - b1.mediantime) >= 7200
    ORDER BY 
        b1.height;
'''

@app.function(volumes={"/data": volume})
def query_bitcoin_db():
    """Query the Bitcoin blockchain database stored in Modal Volume."""
    conn = sqlite3.connect("/data/bitcoin.db")
    cursor = conn.cursor()

    # Execute the query
    cursor.execute(sql_statement)
    
    # Fetch all results
    results = cursor.fetchall()
    
    # Print header
    print("Height | Block Hash | Difficulty | Previous Diff | % Increase | Time Diff (sec) | Time Diff (hrs)")
    print("-" * 120)
    
    # Print results
    for row in results:
        print(f"{row[0]} | {row[1][:8]}... | {row[2]} | {row[3]} | {row[4]:.2f}% | {row[5]} | {row[6]:.2f}")
    
    # Print summary
    print(f"\nTotal blocks found: {len(results)}")
    
    conn.close()
    
    return results

if __name__ == "__main__":
    query_bitcoin_db.call()