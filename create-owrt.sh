#!/bin/bash
set -e

OWRT="./bin/owrt"

mkdir -p $(dirname ${OWRT})

# Build the docker raspberry pi cross compiler
echo "Creating owrt"
docker run dhylands/openwrt-toolchain-rpi:toolchain-rpi > ${OWRT}
chmod +x ${OWRT}
