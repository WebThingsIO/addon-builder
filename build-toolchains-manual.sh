#!/bin/bash -e

###############################################################################
# GitHub Actions time out after 6 hours. That tends to not be long enough to  #
# build certain toolchains.                                                   #
#                                                                             #
# To build and push them manually, uncomment the desired toolchains below and #
# run the script.                                                             #
###############################################################################

languages=(
  #node:linux-arm:8
  #node:linux-arm:10
  #node:linux-arm:12
  #node:linux-arm:14
  #node:linux-arm:20
  #node:linux-arm64:8
  #node:linux-arm64:10
  #node:linux-arm64:12
  #node:linux-arm64:14
  #node:linux-arm64:20
  #node:linux-x64:8
  #node:linux-x64:10
  #node:linux-x64:12
  #node:linux-x64:14
  node:linux-x64:20
  #python:linux-arm:3.5.10
  #python:linux-arm:3.6.12
  #python:linux-arm:3.7.9
  #python:linux-arm:3.8.6
  #python:linux-arm:3.9.0
  #python:linux-arm64:3.5.10
  #python:linux-arm64:3.6.12
  #python:linux-arm64:3.7.9
  #python:linux-arm64:3.8.6
  #python:linux-arm64:3.9.0
  #python:linux-x64:3.5.10
  #python:linux-x64:3.6.12
  #python:linux-x64:3.7.9
  #python:linux-x64:3.8.6
  #python:linux-x64:3.9.0
)

for lang in ${languages[@]}; do
  language=$(echo "$lang" | cut -d: -f1)
  architecture=$(echo "$lang" | cut -d: -f2)
  version=$(echo "$lang" | cut -d: -f3)
  short_version=$(echo "$version" | cut -d. -f 1-2)

  for toolchain in toolchain/$architecture; do
    image=$(echo "$toolchain" | sed 's/\//-/g')
    image=${image}-${language}-${short_version}

    echo "Building: $image"

    if [ $language = node ]; then
      docker build --build-arg NODE_VERSION=${version} -t ${image} ${toolchain}/${language}
    else
      docker build --build-arg PYTHON_VERSION=${version} -t ${image} ${toolchain}/${language}
    fi

    docker tag ${image} webthingsio/${image}:latest
    docker push webthingsio/${image}:latest

    echo
  done
done
