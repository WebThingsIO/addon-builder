#!/bin/bash
#
# This script builds a single adapter and its dependencies.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.*

set -e

SCRIPT_NAME=$(basename $0)
ADDON_ARCH="$1"

NVM_VERSION="v0.33.8"
NODE_VERSION="$2"
PULL_REQUEST="$3"

if [ -z "${ADDON_ARCH}" ]; then
  echo "Usage: ${SCRIPTNAME} addon-arch"
  exit 1
fi

ADAPTER="$(basename $(pwd))"

echo "============================================================="
if [ -n "${PULL_REQUEST}" ]; then
  echo "Building ADDON_ARCH=${ADDON_ARCH} ADAPTER=${ADAPTER} PULL_REQUEST=${PULL_REQUEST}"
else
  echo "Building ADDON_ARCH=${ADDON_ARCH} ADAPTER=${ADAPTER}"
fi
echo "============================================================="

if [ -f "package.json" ]; then
  if [[ "${ADDON_ARCH}" =~ "linux-arm" ]]; then
    # Install and configure nvm & node inside the docker container we're running in
    curl -o- https://raw.githubusercontent.com/creationix/nvm/${NVM_VERSION}/install.sh | bash

    # The following 2 lines are installed into ~/.bashrc by the above,
    # but on the RPi, sourcing ~/.bashrc winds up being a no-op (when sourced
    # from a script), so we just run it here.
    export NVM_DIR="${HOME}/.nvm"
    [ -s "${NVM_DIR}/nvm.sh" ] && source "${NVM_DIR}/nvm.sh"  # This loads nvm
    # We need to install the version of node into the container
    nvm install ${NODE_VERSION}
    nvm use ${NODE_VERSION}
  fi

  rm -rf node_modules
fi

case "${ADDON_ARCH}" in

  openwrt-linux-arm)
    # The ~/.owrt file is created as part of docker-openwrt-toolchain-builder
    # (look in the Dockerfile).
    source ~/.owrt
    ;;

  linux-arm)
    # Setup some cross compiler variables
    SYSROOT=/rpxc/sysroot
    CROSS_COMPILE="arm-linux-gnueabihf-"

    # Under rpxc /rpxc/sysroot/usr/lib/arm-linux-gnueabihf/libudev.so is
    # a symlink back to /lib/arm-linux-gnueabihf/libudev.so.1.5.0 which
    # doesn't exist. So we go ahead and create a symlink there and point
    # it to the same path under /rpxc/sysroot
    #
    # My guess is that this would be fine for chrooted apps, but I don't
    # think that the cross compilers run chrooted.
    LIBUDEV_SO=/lib/arm-linux-gnueabihf/libudev.so.1.5.0
    sudo mkdir -p $(dirname ${LIBUDEV_SO})
    sudo ln -s ${SYSROOT}/${LIBUDEV_SO} ${LIBUDEV_SO}
    ;;
esac

if [ "${ADAPTER}" == "zwave-adapter" ]; then
  # Build and install the OpenZWave library.
  # We use our own fork of openzwave so that we can apply some patches which are
  # OpenWRT specific.

  OPEN_ZWAVE="open-zwave"
  if [[ "${ADDON_ARCH}" =~ ^openwrt-.* ]]; then
    OZW_BRANCH=moziot-openwrt
  else
    OZW_BRANCH=moziot
  fi
  rm -rf ${OPEN_ZWAVE}
  git clone -b ${OZW_BRANCH} --single-branch --depth=1 https://github.com/mozilla-iot/open-zwave ${OPEN_ZWAVE}

  if [[ "${ADDON_ARCH}" =~ "linux-arm" ]]; then
    ARCH="armv6l"
    PREFIX=/usr CFLAGS="--sysroot=${SYSROOT} -D_GLIBCXX_USE_CXX11_ABI=0" LDFLAGS="-v --sysroot=${SYSROOT}" make -C ${OPEN_ZWAVE} CROSS_COMPILE=${CROSS_COMPILE} MACHINE=${ARCH}

    # Technically, this is incorrect. We should be setting DESTDIR to ${SYSROOT}.
    # By not setting DESTDIR we wind up installing the ARM version of
    # libopenzwave into the host tree. The openzwave-shared node module uses
    # pkg-config to determine where openzwave is installed and expects that the
    # build tree and the install tree are the same. The host build doesn't need to
    # use openzwave, so we can get away with this sleight of hand for now.
    INSTALL_OPENZWAVE="PREFIX=/usr make -C ${OPEN_ZWAVE} CROSS_COMPILE=${CROSS_COMPILE} MACHINE=${ARCH} install"
    sudo ${INSTALL_OPENZWAVE}
    sudo DESTDIR=${SYSROOT} ${INSTALL_OPENZWAVE}
  else
    make -C ${OPEN_ZWAVE}
    sudo make -C ${OPEN_ZWAVE} install
  fi
fi

if [ "${ADDON_ARCH}" == "linux-arm" ]; then
  # setup cross-compiler for node. This needs to be kept after
  # the openzwave build so that the CC and CXX defines don't mess
  # up anything done by the openzwave Makefile.
  OPTS="--sysroot=${SYSROOT}"
  export CC="${CROSS_COMPILE}gcc ${OPTS}"
  export CXX="${CROSS_COMPILE}g++ ${OPTS}"
fi

# Build the addon dependencies
ADDON_ARCH=${ADDON_ARCH} ./package.sh

# Collect the results into a tarball.
for TARFILE in *-${ADDON_ARCH}*.tgz; do
  if [ -n "${PULL_REQUEST}" ]; then
    NEW_TARFILE="${TARFILE/${ADDON_ARCH}/pr-${PULL_REQUEST}-${ADDON_ARCH}}"
    mv "${TARFILE}" "${NEW_TARFILE}"
    TARFILE="${NEW_TARFILE}"
  fi
  sha256sum "${TARFILE}" > "${TARFILE}.sha256sum"
  mv "${TARFILE}" ../builder/
  mv "${TARFILE}.sha256sum" ../builder/
done
