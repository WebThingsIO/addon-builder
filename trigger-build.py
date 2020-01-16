#!/usr/bin/env python3

import argparse
import requests
import sys

BASE_URL = 'https://api.github.com/repos/mozilla-iot/addon-builder/dispatches'


def main(token, adapter):
    """Script entry point."""
    data = {
        'event_type': 'build-adapter',
        'client_payload': {
            'adapter': adapter,
        },
    }

    response = requests.post(
        BASE_URL,
        headers={
            'Accept': 'application/vnd.github.everest-preview+json',
            'Authorization': 'token {}'.format(token),
        },
        json=data,
    )

    if response.status_code == 204:
        print('Build successfully triggered.')
        return True

    print('Failed to trigger build.')
    return False


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Trigger add-on build')
    parser.add_argument('--token', help='GitHub API token', required=True)
    args, remaining = parser.parse_known_args()

    if len(remaining) != 1:
        print('You must specify one adapter to build')
        sys.exit(1)

    main(args.token, remaining[0])
