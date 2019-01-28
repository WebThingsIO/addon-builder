#!/bin/bash

set -e

NODE_VERSION=$(node --version | cut -d. -f1 | sed 's/^v//')

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
    brew install gnu-tar
    tar() {
      gtar "$@"
      return $!
    }
    export -f tar
    ;;

  *)
    echo "Unsupported TRAVIS_OS_NAME = ${TRAVIS_OS_NAME}"
    exit 1
    ;;

esac

if [ -n "${PULL_REQUEST}" ]; then
  if [ "${#ADAPTERS[@]}" != 1 ]; then
    echo "Must specify exactly one adapter when using pull request option."
    exit 1
  fi
  if ! [[ "${PULL_REQUEST}" =~ ^[0-9]+$ ]]; then
    echo "Expecting numeric pull request; Got '${PULL_REQUEST}'"
    exit 1
  fi
fi

git submodule update --init --remote
git submodule status

if [ -n "${PULL_REQUEST}" ]; then
  (
    cd ${ADAPTERS}
    git fetch -fu origin pull/${PULL_REQUEST}/head:pr/origin/${PULL_REQUEST}
    git checkout pr/origin/${PULL_REQUEST}
  )
fi

mkdir -p builder

if [ -z "${ADAPTERS}" ]; then
  # No adapters were provided via the environment, build them all
  case "${NODE_VERSION}" in
    8)
      ADAPTERS=(
        gpio-adapter
        homekit-adapter
        lg-tv-adapter
        microblocks-adapter
        serial-adapter
        thing-url-adapter
        zigbee-adapter
        zwave-adapter
      )
      ;;
    10)
      # Disable adapters which depend on noble for now, as it fails to build
      # with Node v10.
      #
      # See: https://github.com/noble/noble/issues/805
      ADAPTERS=(
        gpio-adapter
        lg-tv-adapter
        microblocks-adapter
        serial-adapter
        zigbee-adapter
        zwave-adapter
      )
      ;;
    *)
      echo "Unsupported NODE_VERSION = ${NODE_VERSION}"
      exit 1
      ;;
  esac
fi

for ADDON_ARCH in ${ADDON_ARCHS}; do
  if [ "${ADDON_ARCH}" == "linux-arm" ]; then
    RPXC="./bin/rpxc"
  else
    RPXC=
  fi
  for ADAPTER in ${ADAPTERS[@]}; do
    ${RPXC} bash -c "cd ${ADAPTER}; ../build-adapter.sh ${ADDON_ARCH} ${NODE_VERSION} '${PULL_REQUEST}'"
  done
done

ls -l builder
echo "Download links:"
for FILE in builder/*.tgz; do
  CHECKSUM=$(cat ${FILE}.sha256sum | cut -f 1 -d ' ')
  echo "  https://s3-us-west-2.amazonaws.com/mozilla-gateway-addons/builder/$(basename ${FILE}) ${CHECKSUM}"
done
