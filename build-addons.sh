#!/bin/bash

set -e

if [ -z "${TRAVIS_OS_NAME}" ]; then
  # This means we're running locally. Fake out TRAVIS_OS_NAME.
  UNAME=$(uname -s)
  case "$(uname -s)" in

    Linux)
      TRAVIS_OS_NAME=linux
      ;;

    Darwin)
      TRAVIS_OS_NAME=osx
      ;;

    *)
      echo "Unrecognized uname -s: ${UNAME}"
      exit 1
      ;;
  esac
  echo "Faking TRAVIS_OS_NAME = ${TRAVIS_OS_NAME}"
else
  echo "TRAVIS_OS_NAME = ${TRAVIS_OS_NAME}"
fi

case "${TRAVIS_OS_NAME}" in

  linux)
    ADDON_ARCHS="linux-arm linux-x64"
    ;;

  osx)
    ADDON_ARCHS="darwin-x64"
    mkdir -p ./bin
    ln -sf $(which gsha256sum) ./bin/sha256sum
    export PATH=$(pwd)/bin:${PATH}
    ;;

  *)
    echo "Unsupported TRAVIS_OS_NAME = ${TRAVIS_OS_NAME}"
    exit 1
    ;;

esac

git submodule update --init --remote
git submodule status
mkdir -p builder

if [ -z "${ADAPTERS}" ]; then
  # No adapters were provided via the environment, build them all
  ADAPTERS=(
    gpio-adapter
    serial-adapter
    thing-url-adapter
    zigbee-adapter
    zwave-adapter
  )
fi

for ADDON_ARCH in ${ADDON_ARCHS}; do
  if [ "${ADDON_ARCH}" == "linux-arm" ]; then
    RPXC="./bin/rpxc"
  else
    RPXC=
  fi
  for ADAPTER in ${ADAPTERS[@]}; do
    ${RPXC} bash -c "cd ${ADAPTER}; ../build-adapter.sh ${ADDON_ARCH}"
  done
done

ls -l builder
echo "Download links:"
for FILE in builder/*.tgz; do
  CHECKSUM=$(cat ${FILE}.sha256sum | cut -f 1 -d ' ')
  echo "  https://s3-us-west-2.amazonaws.com/mozilla-gateway-addons/builder/$(basename ${FILE}) ${CHECKSUM}"
done
