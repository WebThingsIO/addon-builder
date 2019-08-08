#!/bin/bash

set -e

# Ensure that ADAPTERS is an array.
if [[ "${ADAPTERS}" =~ " " ]]; then
  ADAPTERS=(${ADAPTERS})
fi

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
    # Raspberry Pi 2/3 arch is arm_cortex-a7_neon-vfpv4
    # Turris Omnia arch is arm_cortex-a9_vfpv3
    if [ "${NODE_VERSION}" == 8 ]; then
      ADDON_ARCHS="linux-arm linux-x64 openwrt-linux-arm_cortex-a7_neon-vfpv4 openwrt-linux-arm_cortex-a9_vfpv3"
    else
      ADDON_ARCHS="linux-arm linux-x64"
    fi
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
  ADAPTERS=(
    enocean-adapter
    gpio-adapter
    homekit-adapter
    lg-tv-adapter
    max-adapter
    medisana-ks250-adapter
    microblocks-adapter
    mi-flora-adapter
    ruuvitag-adapter
    sensor-tag-adapter
    serial-adapter
    xiaomi-temperature-humidity-sensor-adapter
    zigbee-adapter
    zwave-adapter
  )
fi

SKIP_ADAPTERS=()
for ADDON_ARCH in ${ADDON_ARCHS}; do
  case "${ADDON_ARCH}" in

    linux-arm)
      RPXC="./bin/rpxc"
      ;;

    openwrt-linux-*)
      RPXC="./bin/owrt-${ADDON_ARCH/openwrt-linux-/}"

      # Skip the following Bluetooth adapters, as noble does not currently
      # work on OpenWrt.
      SKIP_ADAPTERS=(
        homekit-adapter
        medisana-ks250-adapter
        mi-flora-adapter
        ruuvitag-adapter
        sensor-tag-adapter
        xiaomi-temperature-humidity-sensor-adapter
      )
      ;;

    *)
      RPXC=
      ;;
  esac
  for ADAPTER in ${ADAPTERS[@]}; do
    if [[ " ${SKIP_ADAPTERS[@]} " =~ " ${ADAPTER} " ]]; then
      echo "====="
      echo "===== Skipping ${ADAPTER} for ${ADDON_ARCH} ====="
      echo "====="
    else
      ${RPXC} bash -c "cd ${ADAPTER}; ../build-adapter.sh ${ADDON_ARCH} ${NODE_VERSION} '${PULL_REQUEST}'"
    fi
  done
done

ls -l builder
echo "Download links:"
for FILE in builder/*.tgz; do
  CHECKSUM=$(cat ${FILE}.sha256sum | cut -f 1 -d ' ')
  echo "  https://s3-us-west-2.amazonaws.com/mozilla-gateway-addons/builder/$(basename ${FILE}) ${CHECKSUM}"
done
