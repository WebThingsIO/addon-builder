#!/bin/bash

set -e

RPXC="./bin/rpxc"

mkdir -p $(dirname ${RPXC})

# Build the docker raspberry pi cross compiler
echo "Creating rpxc"
docker run -t mozillaiot/raspberry-pi-cross-compiler-stretch | tr -d $'\r' > ${RPXC}
chmod +x ${RPXC}
