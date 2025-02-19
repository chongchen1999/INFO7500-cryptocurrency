# Use Ubuntu 22.04 as base image
FROM ubuntu:22.04

# Set Bitcoin version
ENV BITCOIN_VERSION=28.1
ENV BITCOIN_USER=bitcoin
ENV BITCOIN_HOME=/home/${BITCOIN_USER}
ENV BITCOIN_DATA=${BITCOIN_HOME}/.bitcoin

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

# Create Bitcoin user
RUN useradd -m -s /bin/bash ${BITCOIN_USER}

# Download and install Bitcoin Core
RUN set -ex \
    && BITCOIN_TAR="bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz" \
    && curl -fSLO "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/${BITCOIN_TAR}" \
    && tar -xzf "${BITCOIN_TAR}" -C /usr/local --strip-components=1 \
    && rm "${BITCOIN_TAR}"

# Create Bitcoin data directory and set permissions
RUN mkdir -p "${BITCOIN_DATA}" \
    && chown -R ${BITCOIN_USER}:${BITCOIN_USER} "${BITCOIN_HOME}"

# Copy configuration file
COPY bitcoin.conf "${BITCOIN_DATA}/"
RUN chown ${BITCOIN_USER}:${BITCOIN_USER} "${BITCOIN_DATA}/bitcoin.conf"

# Switch to non-root user
USER ${BITCOIN_USER}

# Expose ports
EXPOSE 8332 8333

# Start bitcoind
CMD ["bitcoind", "-datadir=/home/bitcoin/.bitcoin"]

