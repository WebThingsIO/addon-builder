#!/bin/bash

set -e

RPXC="./bin/rpxc"

mkdir -p $(dirname ${RPXC})

# Build the docker raspberry pi cross compiler
echo "Creating rpxc"
docker run -t dhylands/raspberry-pi-cross-compiler-stretch | tr -d $'\r' > ${RPXC}
sed -i 's/docker run -i -t/docker run -t/' ${RPXC}
chmod +x ${RPXC}
