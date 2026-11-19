#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, its DDEV project and its host name.')
parser.add_argument('-s', '--shield',
                    action='store_true',
                    default=False,
                    help='Add the official auth library (Shield), set up by its own command, with CSRF protection on for every form.')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Migrate the database; with --shield, the workspace account is the first account of the app (the superadmin group).')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install and --shield, add the default accounts: the ones the test scenarios log in as.')
parser.add_argument('-p', '--production',
                    action='store_true',
                    default=False,
                    help='Run the app as a live app runs: CI_ENVIRONMENT = production (the plain error pages instead of the debug page, no debug toolbar).')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the app in a browser when it is ready.')
parser.add_argument('--php-version',
                    default="",
                    choices=['8.4', '8.3', '8.2'],
                    help='PHP version for the project container; empty means the default of the container tool. Example: --php-version 8.4')
ARGEOF
