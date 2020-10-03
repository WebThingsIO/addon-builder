#!/bin/bash -e

ADDON_ARCH="$1"
LANGUAGE_NAME="$2"
LANGUAGE_VERSION="$3"

# Ensure that ADAPTERS is an array.
if [[ "${ADAPTERS}" =~ " " ]]; then
  ADAPTERS=(${ADAPTERS})
fi

# Set up GNU utils as defaults on Darwin
if [[ "$(uname -s)" == "Darwin" ]]; then
  tar() {
    gtar "$@"
    return $!
  }
  export -f tar

  readlink() {
    greadlink "$@"
    return $!
  }
  export -f readlink

  find() {
    gfind "$@"
    return $!
  }
  export -f find
fi

# Pull latest versions of all submodules
git submodule update --init --remote
git submodule status

# Create the output directory
mkdir -p builder

# If no adapters were provided via the environment, build them all
if [ -z "${ADAPTERS}" ]; then
  ADAPTERS=(
    awox-mesh-light-adapter:python
    blinkt-adapter:node
    bmp280-adapter:node
    Candle-manager-addon:python
    generic-sensors-adapter:node
    insteon-adapter:node
    max-adapter:node
    medisana-ks250-adapter:node
    microblocks-adapter:node
    mi-flora-adapter:node
    mysensors-adapter:python
    p1-adapter:python
    sense-hat-adapter:python
    sensor-tag-adapter:node
    x10-cm11-adapter:node
  )
fi

SKIP_ADAPTERS=()

# Set up architecture overrides
case "${ADDON_ARCH}" in
  darwin-x64)
    RPXC=
    SKIP_ADAPTERS+=(
      awox-mesh-light-adapter
      blinkt-adapter
      bmp280-adapter
      generic-sensors-adapter
      sense-hat-adapter
    )
    ;;

  linux-arm)
    RPXC="docker run --rm -t -v $PWD:/build webthingsio/toolchain-${ADDON_ARCH}-${LANGUAGE_NAME}-${LANGUAGE_VERSION}"
    ;;

  linux-arm64)
    RPXC="docker run --rm -t -v $PWD:/build webthingsio/toolchain-${ADDON_ARCH}-${LANGUAGE_NAME}-${LANGUAGE_VERSION}"
    SKIP_ADAPTERS+=(
      blinkt-adapter
      sense-hat-adapter
    )
    ;;

  linux-x64)
    RPXC="docker run --rm -t -v $PWD:/build webthingsio/toolchain-${ADDON_ARCH}-${LANGUAGE_NAME}-${LANGUAGE_VERSION}"
    SKIP_ADAPTERS+=(
      blinkt-adapter
      sense-hat-adapter
    )
    ;;

  *)
    RPXC=
    ;;
esac

# Build the adapter(s)
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
    ${RPXC} bash -c "cd /build/${adapter}; ../build-adapter.sh ${ADDON_ARCH}"
  else
    pushd ${adapter}
    ../build-adapter.sh ${ADDON_ARCH}
    popd
  fi
done

# Report on the generated tarballs
if compgen -G "builder/*.tgz" >/dev/null; then
  echo "Download links:"
  for FILE in builder/*.tgz; do
    CHECKSUM=$(cat ${FILE}.sha256sum | cut -f 1 -d ' ')
    FNAME=$(basename ${FILE})
    echo "  https://s3-us-west-2.amazonaws.com/mozilla-gateway-addons/builder/${FNAME} ${CHECKSUM}"
  done
fi
