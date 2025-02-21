# Use a lightweight Python base image
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies directly in Dockerfile
RUN pip install --no-cache-dir \
    requests==2.31.0 \
    python-bitcoinlib==0.12.2 \
    tqdm==4.66.1

# Copy sync script
COPY sync.py .

# Set default command (optional, modify as needed)
CMD ["python", "sync.py"]
