# Use Python 3.11 as base image
FROM python:3.11

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      libtool \
      autotools-dev \
      automake \
      pkg-config \
      bsdmainutils \
      libssl-dev \
      libevent-dev \
      libboost-system-dev \
      libboost-filesystem-dev \
      libboost-chrono-dev \
      libboost-test-dev \
      libboost-thread-dev \
      libzmq3-dev \
      git \
      wget && \
    rm -rf /var/lib/apt/lists/*  # Cleanup to reduce image size

# Set working directory for Bitcoin Core
WORKDIR /bitcoin

# Download and verify Bitcoin Core
RUN wget https://bitcoincore.org/bin/bitcoin-core-25.1/bitcoin-25.1.tar.gz && \
    wget https://bitcoincore.org/bin/bitcoin-core-25.1/SHA256SUMS && \
    sha256sum --ignore-missing --check SHA256SUMS

# Extract and build Bitcoin Core
RUN tar -xzvf bitcoin-25.1.tar.gz && \
    mv bitcoin-25.1/* . && \
    rm -r bitcoin-25.1*

RUN ./autogen.sh && \
    ./configure --disable-wallet --without-gui && \
    make -j$(nproc) && \
    make install

# Set working directory for Bitcoin configuration
WORKDIR /root/.bitcoin/

# Copy config file to container
COPY bitcoin.conf bitcoin.conf

# Create Bitcoin data directory
RUN mkdir -p /data

# Expose default Bitcoin Core ports
EXPOSE 8333 8332

# Run bitcoind with data directory flag
CMD ["bitcoind", "-datadir=/data"]
