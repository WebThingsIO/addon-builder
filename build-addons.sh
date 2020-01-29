#!/bin/bash

set -e

# Ensure that ADAPTERS is an array.
if [[ "${ADAPTERS}" =~ " " ]]; then
  ADAPTERS=(${ADAPTERS})
fi

NODE_VERSION=$(node --version | cut -d. -f1 | sed 's/^v//')

case "$(uname -s)" in
  Linux)
    OS_NAME=linux
    ;;

  Darwin)
    OS_NAME=osx
    ;;

  *)
    echo "Unrecognized uname -s: $(uname -s)"
    exit 1
    ;;
esac

case "${OS_NAME}" in
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
    tar() {
      gtar "$@"
      return $!
    }
    export -f tar
    ;;

  *)
    echo "Unsupported OS_NAME = ${OS_NAME}"
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
    blinkt-adapter
    bmp280-adapter
    enocean-adapter
    generic-sensors-adapter
    gpio-adapter
    homekit-adapter
    insteon-adapter
    lg-tv-adapter
    max-adapter
    medisana-ks250-adapter
    microblocks-adapter
    mi-flora-adapter
    rf433-adapter
    ruuvitag-adapter
    sensor-tag-adapter
    serial-adapter
    tradfri-adapter
    x10-cm11-adapter
    xiaomi-temperature-humidity-sensor-adapter
    zigbee-adapter
    zwave-adapter
  )
fi

SKIP_ADAPTERS=(
  enocean-adapter
)
for ADDON_ARCH in ${ADDON_ARCHS}; do
  case "${ADDON_ARCH}" in

    darwin-x64)
      SKIP_ADAPTERS+=(
        blinkt-adapter
        bmp280-adapter
        generic-sensors-adapter
        gpio-adapter
        rf433-adapter
      )
      ;;

    linux-arm)
      RPXC="./bin/rpxc"
      ;;

    linux-x64)
      SKIP_ADAPTERS+=(
        blinkt-adapter
        rf433-adapter
      )
      ;;

    openwrt-linux-*)
      RPXC="./bin/owrt-${ADDON_ARCH/openwrt-linux-/}"

      SKIP_ADAPTERS+=(
        blinkt-adapter
        rf433-adapter
      )

      # Skip the following Bluetooth adapters, as noble does not currently
      # work on OpenWrt.
      SKIP_ADAPTERS+=(
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

  if [ "${NODE_VERSION}" == 12 ]; then
    SKIP_ADAPTERS+=(
      bmp280-adapter
    )
  fi

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
