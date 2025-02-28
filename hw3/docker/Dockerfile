FROM ubuntu:22.04

ENV BITCOIN_VERSION=28.1
ENV BITCOIN_DATA=/data

RUN apt-get update && apt-get install -y \
    curl \
    libssl3 \
    libevent-2.1-7 \
    libzmq5 \
    python3 \
    python3-pip \
    && ln -s /usr/bin/python3 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install python-bitcoinrpc fastapi[standard]

RUN set -ex \
    && BITCOIN_TAR="bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz" \
    && curl -fSLO "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/${BITCOIN_TAR}" \
    && tar -xzf "${BITCOIN_TAR}" -C /usr/local --strip-components=1 \
    && rm "${BITCOIN_TAR}"

RUN mkdir -p "${BITCOIN_DATA}"
COPY bitcoin.conf "${BITCOIN_DATA}/"

EXPOSE 8332 8333