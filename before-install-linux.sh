#!/bin/bash -e

# This script is run from .travis.yml before_install section

set -x

sudo apt-get -qq update
sudo apt-get install libudev-dev
./create-rpxc.sh
./create-owrt.sh
docker ps -a
