#!/bin/bash

set -e

OWRT_DIR="./bin"
OWRT_RPI="${OWRT_DIR}/owrt-arm_cortex-a7_neon-vfpv4"
OWRT_OMNIA="${OWRT_DIR}/owrt-arm_cortex-a9_vfpv3"

mkdir -p ${OWRT_DIR}

# Build the docker raspberry pi cross compiler
echo "Creating ${OWRT_RPI}"
docker run -t dhylands/openwrt-toolchain-rpi:toolchain-rpi | tr -d $'\r' > ${OWRT_RPI}
sed -i 's/docker run -i -t/docker run -t/' ${OWRT_RPI}
chmod +x ${OWRT_RPI}

# Build the turris omnia cross compiler
echo "Creating ${OWRT_OMNIA}"
docker run -t dhylands/openwrt-toolchain-arm_cortex-a9-vfpv3:toolchain-arm_cortex-a9-vfpv3 | tr -d $'\r' > ${OWRT_OMNIA}
sed -i 's/docker run -i -t/docker run -t/' ${OWRT_OMNIA}
chmod +x ${OWRT_OMNIA}
