# Use Ubuntu 22.04
FROM ubuntu:22.04

# Set Bitcoin version
ENV BITCOIN_VERSION=28.1
ENV BITCOIN_DATA=/root/.bitcoin

# Install system dependencies (essential runtime libraries)

RUN apt-get update && apt-get install -y \
    curl \
    libssl3 \
    libevent-2.1-7 \
    libzmq5 \
    python3 \
    python3-pip \
    && ln -s /usr/bin/python3 /usr/bin/python \ 
    && rm -rf /var/lib/apt/lists/*

# Install Python Bitcoin RPC library
RUN pip3 install python-bitcoinrpc fastapi[standard]

# Download and install Bitcoin Core
RUN set -ex \
    && BITCOIN_TAR="bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz" \
    && curl -fSLO "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/${BITCOIN_TAR}" \
    && tar -xzf "${BITCOIN_TAR}" -C /usr/local --strip-components=1 \
    && rm "${BITCOIN_TAR}"

# Verify installation path
RUN ls -l /usr/local/bin/bitcoind

# Create data directory
RUN mkdir -p "${BITCOIN_DATA}"

# Copy configuration file
COPY bitcoin.conf "${BITCOIN_DATA}/"

# Expose ports
EXPOSE 8332 8333

# CMD ["bitcoind", "-datadir=/data"]
