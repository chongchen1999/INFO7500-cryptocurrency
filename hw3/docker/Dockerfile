# Build bitcoind from source
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      libtool \
      autotools-dev \
      automake \
      pkg-config \
      bsdmainutils \
      python3 \
      libssl-dev \
      libevent-dev \
      libboost-system-dev \
      libboost-filesystem-dev \
      libboost-chrono-dev \
      libboost-test-dev \
      libboost-thread-dev \
      libzmq3-dev \
      git \
      wget

# Download and verify Bitcoin Core
WORKDIR /bitcoin
RUN wget https://bitcoincore.org/bin/bitcoin-core-25.1/bitcoin-25.1.tar.gz && \
    wget https://bitcoincore.org/bin/bitcoin-core-25.1/SHA256SUMS && \
    sha256sum --ignore-missing --check SHA256SUMS

# Extract and build
RUN tar -xzvf bitcoin-25.1.tar.gz && \
    mv bitcoin-25.1/* . && \
    rm -r bitcoin-25.1*

RUN ./autogen.sh && \
    ./configure --disable-wallet --without-gui && \
    make -j$(nproc) && \
    make install

# Copy config file to container
COPY bitcoin.conf /root/.bitcoin/bitcoin.conf

# Run bitcoind with data directory flag
CMD ["bitcoind", "-datadir=/data"]