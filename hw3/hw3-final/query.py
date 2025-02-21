import modal
import click
from tabulate import tabulate
import json

app = modal.App("bitcoin-explorer")  # Must match your existing app name

@app.function(volumes={"/data": modal.Volume.from_name("bitcoin-data")})
def query(sql: str):
    import sqlite3
    from contextlib import closing
    
    with closing(sqlite3.connect('/data/bitcoin.db')) as conn:
        conn.row_factory = sqlite3.Row
        with closing(conn.cursor()) as cursor:
            cursor.execute(sql)
            results = [dict(row) for row in cursor.fetchall()]
            return results

@click.command()
@click.argument('sql', required=False)
@click.option('--format', '-f', default='table', 
              help='Output format (table, json)')
@click.option('--latest', '-l', is_flag=True, 
              help='Get latest block')
@click.option('--block', '-b', type=int,
              help='Get block by height')
def main(sql, format, latest, block):
    """Query Bitcoin blockchain data from your Modal volume
    
    Examples:
    
    query.py "SELECT * FROM blocks ORDER BY height DESC LIMIT 5"
    
    query.py --latest
    
    query.py --block 800000
    
    query.py -b 123456 -f json
    """
    try:
        if latest:
            result = query.remote("SELECT * FROM blocks ORDER BY height DESC LIMIT 1")
        elif block is not None:
            result = query.remote(f"SELECT * FROM blocks WHERE height = {block}")
        elif sql:
            result = query.remote(sql)
        else:
            raise click.UsageError("Must provide SQL query or use a flag")

        if not result:
            click.echo("No results found")
            return

        if format == 'json':
            click.echo(json.dumps(result, indent=2))
        else:
            headers = result[0].keys()
            rows = [list(row.values()) for row in result]
            click.echo(tabulate(rows, headers=headers, tablefmt="github"))
            
    except modal.exception.NotFoundError:
        click.echo("Error: Database not found. Have you synced blocks?")
    except Exception as e:
        click.echo(f"Query error: {str(e)}")

@app.local_entrypoint()
def cli():
    # Pass sys.argv to click while excluding Modal-specific arguments
    import sys
    filtered_args = [arg for arg in sys.argv if not arg.startswith("--modal")]
    sys.exit(main(args=filtered_args[2:]))  # Skip script name and Modal args

# Add this at the bottom of query.py
@app.local_entrypoint()
def run_query():
    main()

if __name__ == "__main__":
    main()