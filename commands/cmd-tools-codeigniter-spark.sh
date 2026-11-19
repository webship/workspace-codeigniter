#!/usr/bin/env bash

# Installed by the CodeIgniter plugin (plugins.sh --install codeigniter); __WORKSPACE__ is the workspace it was installed into.
#
# spark for one CodeIgniter app of this workspace, in its container: say what the app is, run a spark
# command, update its packages, switch its environment, add or remove the default accounts. Nothing
# here runs on the host.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="codeigniter";

ARGPARSE_DESCRIPTION="Run spark on a CodeIgniter app of __WORKSPACE__: status, a command, updates, the environment, the default accounts"
# The args file comes with the plugin: core/scripts/plugins/codeigniter/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/codeigniter/args/arg-codeigniter-spark.sh || exit 1 ;

shift $#;

codeigniter_spark_tool ;
