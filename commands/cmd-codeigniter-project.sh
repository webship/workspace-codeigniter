#!/usr/bin/env bash

# workspace-name: CodeIgniter (app starter)

# Installed by the CodeIgniter plugin (plugins.sh --install codeigniter); __WORKSPACE__ is the workspace it was installed into.
#
# Build a CodeIgniter app in a container from the official app starter, at https://<name>.ddev.site
# (DDEV project type php, docroot public). With --shield it gets the official auth library, set up by
# its own command, with CSRF protection on for every form; with --install its database is migrated and
# the workspace account is its first account; with --add-users it also gets the default accounts.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="codeigniter";
distribution_title="CodeIgniter";
distribution_webroot="public";

ARGPARSE_DESCRIPTION="Build a ${distribution_title} app in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/codeigniter/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/codeigniter/args/arg-codeigniter.sh || exit 1 ;

shift $#;

codeigniter_build ;
