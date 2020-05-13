#!/bin/bash

set -e

# Ensure that ADAPTERS is an array.
if [[ "${ADAPTERS}" =~ " " ]]; then
  ADAPTERS=(${ADAPTERS})
fi

ADDON_ARCH="$1"
LANGUAGE_NAME="$2"
LANGUAGE_VERSION="$3"

if [[ "$(uname -s)" == "Darwin" ]]; then
  tar() {
    gtar "$@"
    return $!
  }
  export -f tar
fi

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
    blinkt-adapter:node
    bmp280-adapter:node
    enocean-adapter:node
    eufy-adapter:python
    generic-sensors-adapter:node
    gpio-adapter:node
    homekit-adapter:node
    insteon-adapter:node
    kafka-bridge:node
    lg-tv-adapter:node
    max-adapter:node
    medisana-ks250-adapter:node
    microblocks-adapter:node
    mi-flora-adapter:node
    piface-adapter:node
    rf433-adapter:node
    ruuvitag-adapter:node
    sense-hat-adapter:python
    sensor-tag-adapter:node
    serial-adapter:node
    tradfri-adapter:node
    x10-cm11-adapter:node
    xiaomi-temperature-humidity-sensor-adapter:node
    zigbee-adapter:node
    zwave-adapter:node
  )
fi

SKIP_ADAPTERS=()

case "${ADDON_ARCH}" in

  darwin-x64)
    RPXC=
    SKIP_ADAPTERS+=(
      blinkt-adapter
      bmp280-adapter
      generic-sensors-adapter
      gpio-adapter
      piface-adapter
      rf433-adapter
      sense-hat-adapter
    )
    ;;

  linux-arm)
    RPXC="docker run --rm -t -v $PWD:/build mozillaiot/toolchain-${ADDON_ARCH}-${LANGUAGE_NAME}-${LANGUAGE_VERSION}"
    ;;

  linux-arm64)
    RPXC="docker run --rm -t -v $PWD:/build mozillaiot/toolchain-${ADDON_ARCH}-${LANGUAGE_NAME}-${LANGUAGE_VERSION}"
    SKIP_ADAPTERS+=(
      blinkt-adapter
      piface-adapter
      rf433-adapter
      sense-hat-adapter
    )
    ;;

  linux-x64)
    RPXC="docker run --rm -t -v $PWD:/build mozillaiot/toolchain-${ADDON_ARCH}-${LANGUAGE_NAME}-${LANGUAGE_VERSION}"
    SKIP_ADAPTERS+=(
      blinkt-adapter
      piface-adapter
      rf433-adapter
      sense-hat-adapter
    )
    ;;

  *)
    RPXC=
    ;;
esac

if [[ "${LANGUAGE_NAME}" == "node" && "${LANGUAGE_VERSION}" != "8" ]]; then
  # rf433-adapter isn't dependent on a specific node version. Rather, we
  # build it with the addon-builder in order to cross-compile a single native
  # (non-node) dependency.
  SKIP_ADAPTERS+=(
    rf433-adapter
  )
fi

for ADAPTER in ${ADAPTERS[@]}; do
  adapter=$(echo "$ADAPTER" | cut -d: -f1)
  adapter_language=$(echo "$ADAPTER" | cut -d: -f2)

  if [[ "$adapter_language" != "$LANGUAGE_NAME" ]]; then
    continue
  fi

  if [[ " ${SKIP_ADAPTERS[@]} " =~ " ${adapter} " ]]; then
    echo "====="
    echo "===== Skipping ${adapter} for ${ADDON_ARCH} ====="
    echo "====="
  elif [ -n "$RPXC" ]; then
    ${RPXC} bash -c "cd /build/${adapter}; ../build-adapter.sh ${ADDON_ARCH} '${PULL_REQUEST}'"
  else
    here=$(pwd)
    cd ${adapter}
    ../build-adapter.sh ${ADDON_ARCH} ${PULL_REQUEST}
    cd "${here}"
  fi
done

if compgen -G "builder/*.tgz" >/dev/null; then
  echo "Download links:"
  for FILE in builder/*.tgz; do
    CHECKSUM=$(cat ${FILE}.sha256sum | cut -f 1 -d ' ')
    echo "  https://s3-us-west-2.amazonaws.com/mozilla-gateway-addons/builder/$(basename ${FILE}) ${CHECKSUM}"
  done
fi
