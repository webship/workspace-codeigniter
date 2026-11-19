#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The CodeIgniter app in this workspace.')
parser.add_argument('-r', '--run',
                    default="_none_",
                    help='A spark command to run in the app, without the leading spark. Example: --run "routes"')
parser.add_argument('-u', '--update',
                    action='store_true',
                    default=False,
                    help='Update the Composer packages within their constraints and run the new migrations.')
parser.add_argument('-e', '--environment',
                    default="",
                    choices=['development', 'production', 'testing'],
                    help='Switch the environment of the app (CI_ENVIRONMENT in its .env). Example: --environment production')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Add the default accounts. An account that is already there gets its name, password, groups and state back.')
parser.add_argument('-c', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Delete the default accounts.')
ARGEOF
