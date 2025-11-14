#!/bin/bash
#
# server-commons.sh
# Constants and utility functions used by the server scripts.

# -------------------------- HEADER -------------------------------------------

# ignore unused variable warnings (source'd script)
# shellcheck disable=SC2034

# source the global commons
source "$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")/global-commons.sh" || exit

# -------------------------- PATHS --------------------------------------------

# The server is deployed on-the-fly to ~/$PROJECT_NAME/<tempdir>.
# The server filesystem:
#   - resolve project paths based on filesystem position of this script
#   - env vars prefixed with '_' do not exist in all envs

#  server                      | env vars
# -----------------------------|-----------------------------------------------
# <tempdir>                    | _DEPLOYMENT_DIR
# ├── external/                |
# │   └── bash-tools/          |
# │       └──src/              | EXT_BASHTOOLS_SRC_DIR
# │          └──bash-tools.sh  |
# ├── server/                  | LIB_SERVER_DIR
# │   └── server-commons.sh    | (this script)
# ├── global-commons.sh        |
# └── .env                     | DOTENV

# resolve server paths relative to this script
LIB_SERVER_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
declare -r LIB_SERVER_DIR

DEPLOYMENT_DIR="$(realpath "$LIB_SERVER_DIR/..")"
declare -r DEPLOYMENT_DIR

declare -r EXT_BASHTOOLS_SRC_DIR="$DEPLOYMENT_DIR/external/bash-tools/src"
declare -r PVE_ROOT_CA="$CLIENT_CACHE_DIR/pve-root-ca.pem"
declare -r DOTENV="$DEPLOYMENT_DIR/.env"

# -------------------------- IMPORTS ------------------------------------------

# import external libs
source "$EXT_BASHTOOLS_SRC_DIR/bash-tools.sh"

# -------------------------- PRECONDITIONS ------------------------------------

# exit shell if this script was executed directly rather than being source'd
assert_sourced

# -------------------------- CONSTANTS ----------------------------------------

# -------------------------- UTILITIES ----------------------------------------

# -------------------------- ASSERTIONS ---------------------------------------

# -------------------------- CHECKS -------------------------------------------
