#!/bin/bash

set -e

# Ensure that ADAPTERS is an array.
if [[ "${ADAPTERS}" =~ " " ]]; then
  ADAPTERS=(${ADAPTERS})
fi

NODE_VERSION=$1
PYTHON_VERSION=$2

if [[ ( "$NODE_VERSION" == "" && "$PYTHON_VERSION" == "" ) ||
      ( "$NODE_VERSION" != "" && "$PYTHON_VERSION" != "" ) ]]; then
  echo "Skipping overlapping matrix builds"
  exit 0
fi

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
    ADDON_ARCHS="linux-x64 linux-arm linux-arm64"
    ;;

  osx)
    ADDON_ARCHS="darwin-x64"
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
    blinkt-adapter:node
    bmp280-adapter:node
    enocean-adapter:node
    generic-sensors-adapter:node
    gpio-adapter:node
    homekit-adapter:node
    insteon-adapter:node
    lg-tv-adapter:node
    max-adapter:node
    medisana-ks250-adapter:node
    microblocks-adapter:node
    mi-flora-adapter:node
    piface-adapter:node
    rf433-adapter:node
    ruuvitag-adapter:node
    sensor-tag-adapter:node
    serial-adapter:node
    tradfri-adapter:node
    x10-cm11-adapter:node
    xiaomi-temperature-humidity-sensor-adapter:node
    zigbee-adapter:node
    zwave-adapter:node
  )
fi

for ADDON_ARCH in ${ADDON_ARCHS}; do
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
      )
      ;;

    linux-arm)
      RPXC="docker run --rm -t -v $PWD:/build mozillaiot/toolchain-${ADDON_ARCH}-{{language}}-{{version}}"
      ;;

    linux-arm64)
      RPXC="docker run --rm -t -v $PWD:/build mozillaiot/toolchain-${ADDON_ARCH}-{{language}}-{{version}}"
      SKIP_ADAPTERS+=(
        blinkt-adapter
        piface-adapter
        rf433-adapter
      )
      ;;

    linux-x64)
      RPXC="docker run --rm -t -v $PWD:/build mozillaiot/toolchain-${ADDON_ARCH}-{{language}}-{{version}}"
      SKIP_ADAPTERS+=(
        blinkt-adapter
        piface-adapter
        rf433-adapter
      )
      ;;

    *)
      RPXC=
      ;;
  esac

  if [[ ${NODE_VERSION} != 8 ]]; then
    # rf433-adapter isn't dependent on a specific node version. rather, we
    # build it with the addon-builder in order to cross-compile a single native
    # (non-node) dependency.
    SKIP_ADAPTERS+=(
      rf433-adapter
    )
  fi

  for ADAPTER in ${ADAPTERS[@]}; do
    adapter=$(echo "$ADAPTER" | cut -d: -f1)
    adapter_language=$(echo "$ADAPTER" | cut -d: -f2)
    language_version="$NODE_VERSION"
    if [ "$adapter_language" = "python" ]; then
      language_version="$PYTHON_VERSION"
    fi

    if [[ ( "$adapter_language" == "node" && "$NODE_VERSION" == "" ) ||
          ( "$adapter_language" == "python" && "$PYTHON_VERSION" == "" ) ]]; then
      continue
    fi

    if [[ " ${SKIP_ADAPTERS[@]} " =~ " ${adapter} " ]]; then
      echo "====="
      echo "===== Skipping ${adapter} for ${ADDON_ARCH} ====="
      echo "====="
    elif [ -n "$RPXC" ]; then
      rpxc=$(echo "$RPXC" | sed -e "s/{{language}}/$adapter_language/" -e "s/{{version}}/$language_version/")
      ${rpxc} bash -c "cd /build/${adapter}; ../build-adapter.sh ${ADDON_ARCH} '${PULL_REQUEST}'"
    else
      here=$(pwd)
      cd ${adapter}
      ../build-adapter.sh ${ADDON_ARCH} ${PULL_REQUEST}
      cd "${here}"
    fi
  done
done

ls -l builder
echo "Download links:"
for FILE in builder/*.tgz; do
  CHECKSUM=$(cat ${FILE}.sha256sum | cut -f 1 -d ' ')
  echo "  https://s3-us-west-2.amazonaws.com/mozilla-gateway-addons/builder/$(basename ${FILE}) ${CHECKSUM}"
done
