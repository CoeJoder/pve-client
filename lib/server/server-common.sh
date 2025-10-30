#!/bin/bash

# server-common.sh
#
# Constants and utility functions used by the server scripts.

# -------------------------- HEADER -------------------------------------------

# ignore unused variable warnings (source'd script)
# shellcheck disable=SC2034

# source the global commons
source "$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")/global-common.sh" || exit

# -------------------------- CONSTANTS ----------------------------------------

# The server deployment filesystem:
#  - resolve project paths based on filesystem position of this script
#  - env vars prefixed with '_' do not exist in all envs

#  server                      | env vars
# -----------------------------|-----------------------------------------------
# <deployment/>                | _DEPLOYMENT_DIR
# ├── external/                | 
# │   └── bash-tools/          | 
# │       └──src/              | EXT_BASHTOOLS_SRC_DIR
# │          └──bash-tools.sh  | 
# ├── server/                  | LIB_SERVER_DIR
# │   └── server-common.sh     | (this script)
# ├── global-common.sh         | 
# └── .env                     | DOTENV

# resolve server paths relative to this script
LIB_SERVER_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
declare -r LIB_SERVER_DIR

DEPLOYMENT_DIR="$(realpath "$LIB_SERVER_DIR/..")"
declare -r DEPLOYMENT_DIR

declare -r EXT_BASHTOOLS_SRC_DIR="$DEPLOYMENT_DIR/external/bash-tools/src"
declare -r PVE_ROOT_CA="$CLIENT_CACHE_DIR/pve-root-ca.pem"

# -------------------------- IMPORTS ----------------------------------------

# import external libs
source "$EXT_BASHTOOLS_SRC_DIR/bash-tools.sh"

# -------------------------- PRECONDITIONS ----------------------------------

# exit shell if this script was executed directly rather than being source'd
assert_sourced

# -------------------------- UTILITIES ----------------------------------------

# -------------------------- ASSERTIONS ---------------------------------------

# -------------------------- CHECKS -------------------------------------------
