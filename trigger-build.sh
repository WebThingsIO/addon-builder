#!/bin/bash
set -e

SCRIPT_NAME=$(basename $0)

usage() {
  echo "Usage: ${SCRIPT_NAME} [--pr PR] ADAPTER-NAME..."
}

ENV=
addEnv() {
  if [ -z "${ENV}" ]; then
    ENV="\"$1\": \"$2\""
  else
    ENV="${ENV}, \"$1\": \"$2\""
  fi
}

VERBOSE=0

while getopts "hv-:" opt "$@"; do
  case ${opt} in

    -)
      case ${OPTARG} in
        pr)
          PULL_REQUEST="${!OPTIND}"
          OPTIND=$(( $OPTIND + 1 ))
          ;;

        help)
          usage
          exit 1
          ;;

        *)
          echo "Unrecognized option: ${OPTARG}"
          exit 1
          ;;
      esac
      ;;

    h)
      usage
      exit 1
      ;;

    v)
      VERBOSE=1
      ;;

    *)
      echo "Unrecognized option: ${opt}"
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

ADAPTERS="$@"

if [ "${VERBOSE}" == 1 ]; then
  echo "ADAPTERS = '${ADAPTERS}'"
  echo "PULL_REQUEST = '${PULL_REQUEST}'"
fi

if [ -n "${PULL_REQUEST}" ]; then
  if ! [[ "${PULL_REQUEST}" =~ ^[0-9]+$ ]]; then
    echo "Expecting numeric pull request; Got '${PULL_REQUEST}'"
    exit 1
  fi
  if [ "${#ADAPTERS[@]}" != 1 ]; then
    echo "Must specify exactly one adapter when using pull request option."
    exit 1
  fi
fi

if [ -n "${ADAPTERS}" ]; then
  addEnv ADAPTERS "${ADAPTERS}"
fi

if [ -n "${PULL_REQUEST}" ]; then
  addEnv PULL_REQUEST "${PULL_REQUEST}"
fi

if [ "${VERBOSE}" == 1 ]; then
  echo "ENV = ${ENV}"
fi

# Make sure that the travis command line utility is installed. This is
# required in order to get an authorization token used to access github.
if [[ ! $(type -P travis) ]]; then
  echo "travis utility doesn't seem to be installed."
  echo "See https://github.com/travis-ci/travis.rb#installation for intructions on installing travis."
  exit 1
fi

# See if the user has previsouly created a token. This is normally cached
# in ~/.travis/config.yml
TOKEN=$(travis token --org --no-interactive)
while [ -z "${TOKEN}" ]; do
  # No token - prompt the user
  echo ""
  echo "No travis token - please enter github credentials"
  echo ""
  travis login --org
  TOKEN=$(travis token --org --no-interactive)
done

BODY='{
  "request": {
    "message": "Manually triggered build via trigger-build.sh",
    "branch": "master",
    "config": {
      "env": {
        "global": {
          '${ENV}'
        }
      }
    }
  }
}'

curl -s -X POST \
   -H "Content-Type: application/json" \
   -H "Accept: application/json" \
   -H "Travis-API-Version: 3" \
   -H "Authorization: token ${TOKEN}" \
   -d "${BODY}" \
   https://api.travis-ci.org/repo/mozilla-iot%2Faddon-builder/requests
