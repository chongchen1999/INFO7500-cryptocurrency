import modal

app = modal.App("chongchen-bitcoin-node")
volume = modal.Volume.from_name("chongchen-bitcoin-data", create_if_missing=True)
# volume = modal.Volume.persistent("chongchen-bitcoin-data")  # Modal volume for persistence

# Build image from Dockerfile
image = modal.Image.from_dockerfile("docker/Dockerfile")

@app.function(
    image=image,
    volumes={"/data": volume},  # Mount Modal volume to container
    timeout=86400 * 5,          # 4-day timeout
    keep_warm=1,                # Keep warm for faster restarts
)
def run_bitcoind():
    import subprocess
    subprocess.run(["bitcoind", "-datadir=/data"])

if __name__ == "__main__":
    with app.run():
        run_bitcoind.remote()
