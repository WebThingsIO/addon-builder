#!/bin/bash -e
#
# This script builds a single adapter and its dependencies.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.*

SCRIPT_NAME=$(basename $0)
ADAPTER="$(basename $(pwd))"
ADDON_ARCH="$1"

if [ -z "${ADDON_ARCH}" ]; then
  echo "Usage: ${SCRIPT_NAME} addon-arch"
  exit 1
fi

echo
echo "============================================================="
echo "Building ADDON_ARCH=${ADDON_ARCH} ADAPTER=${ADAPTER}"
echo "============================================================="
echo

# Remove .nvmrc to prevent nvm issues below
[ -f .nvmrc ] && rm -f .nvmrc

# Setup environment for building inside Dockerized toolchain
export NVM_DIR="${HOME}/.nvm"
[ -s "${NVM_DIR}/nvm.sh" ] && source "${NVM_DIR}/nvm.sh"
[ $(id -u) = 0 ] && umask 0

# Clean up any Node modules left behind
[ -d node_modules ] && rm -rf node_modules

# Build the addon dependencies
ADDON_ARCH=${ADDON_ARCH} ./package.sh

# Collect the results into a tarball.
for TARFILE in *-${ADDON_ARCH}*.tgz; do
  shasum --algorithm 256 "${TARFILE}" > "${TARFILE}.sha256sum"
  mv "${TARFILE}" ../builder/
  mv "${TARFILE}.sha256sum" ../builder/
done
