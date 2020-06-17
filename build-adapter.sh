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
PULL_REQUEST="$2"

if [ -z "${ADDON_ARCH}" ]; then
  echo "Usage: ${SCRIPT_NAME} addon-arch"
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

# Remove .nvmrc to prevent nvm issues below
if [ -f .nvmrc ]; then
  rm -f .nvmrc
fi

# Load nvm
if [ -d "${HOME}/.nvm" ]; then
  export NVM_DIR="${HOME}/.nvm"
  [ -s "${NVM_DIR}/nvm.sh" ] && source "${NVM_DIR}/nvm.sh"
fi

# Clean up any Node modules left behind
if [ -f "package.json" ]; then
  rm -rf node_modules
fi

# For zwave, we need to build patchelf and OpenZWave
if [ "${ADAPTER}" == "zwave-adapter" ]; then
  if [[ "${ADDON_ARCH}" =~ "linux" ]]; then
    rm -rf patchelf
    git clone https://github.com/NixOS/patchelf
    (cd patchelf && ./bootstrap.sh && ./configure && make && sudo make install)
  fi

  # We use our own fork of openzwave so that we can apply some patches.
  OPEN_ZWAVE="open-zwave"
  OZW_FLAGS=
  OZW_BRANCH=moziot
  rm -rf ${OPEN_ZWAVE}
  git clone -b ${OZW_BRANCH} --single-branch --depth=1 https://github.com/mozilla-iot/open-zwave ${OPEN_ZWAVE}
  CFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0" make -C ${OPEN_ZWAVE} ${OZW_FLAGS}
  sudo make -C ${OPEN_ZWAVE} ${OZW_FLAGS} install
fi

# Build the addon dependencies
umask 0
which npm && npm config set cache /tmp/.npm
ADDON_ARCH=${ADDON_ARCH} ./package.sh

# Collect the results into a tarball.
for TARFILE in *-${ADDON_ARCH}*.tgz; do
  if [ -n "${PULL_REQUEST}" ]; then
    NEW_TARFILE="${TARFILE/${ADDON_ARCH}/pr-${PULL_REQUEST}-${ADDON_ARCH}}"
    mv "${TARFILE}" "${NEW_TARFILE}"
    TARFILE="${NEW_TARFILE}"
  fi
  shasum --algorithm 256 "${TARFILE}" > "${TARFILE}.sha256sum"
  mv "${TARFILE}" ../builder/
  mv "${TARFILE}.sha256sum" ../builder/
done
