#!/bin/bash

# client-common.sh
#
# Constants and utility functions used by the client scripts.

# -------------------------- HEADER -------------------------------------------

# ignore unused variable warnings (source'd script)
# shellcheck disable=SC2034

# source the global commons
source "$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")/global-common.sh" || exit

# -------------------------- CONSTANTS ----------------------------------------

declare -r SERVER_DEPLOYMENT_PARENT_DIR="\$HOME/.local/bin/$PROJECT_NAME"
declare -r SERVER_CACHE_DIR="/var/tmp/pve-client-cache"

# resolve project paths based on 'dev' (source) or 'prod' (deployment)
#  - env is dynamically determined based on filesystem position of this script
#  - prod dirs are overridable per XDG base dir spec
#  - env vars prefixed with '_' do not exist in all envs

# if grandparent directory of this script is $PROJECT_NAME, then this is prod
if [[ "$(basename "$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")")" == "$PROJECT_NAME" ]]; then
	#  prod                                 | env vars
	# --------------------------------------|------------------------------------
	#  ~                                    |
	#  ├── .cache/                          | _XDG_CACHE_DIR
	#  │   └── pve-client/                  | CLIENT_CACHE_DIR
	#  │       └── pve-root-ca.pem          | PVE_ROOT_CA
	#  ├── .config/                         | _XDG_CONFIG_DIR
	#  │   └── pve-client/                  |
	#  │       ├── .env                     | DOTENV
	#  │       └── pve-api-token            | PVE_API_TOKEN
	#  ├── .local/                          |
	#  │   └── .share/                      | _XDG_DATA_DIR
	#  │       └── pve-client/              |
	#  │           ├── external/            |
	#  │           │   └── bash-tools/      |
	#  │           │       └── src          | EXT_BASHTOOLS_SRC_DIR
	#  │           ├── client/              | LIB_CLIENT_DIR
	#  |           |   └── client-common.sh | (this script)
	#  │           ├── server/              | LIB_SERVER_DIR
	#  |           └── global-common.sh     | 
	#  └── .local/                          | 
	#      └── bin/                         | _XDG_BIN_DIR
	#          └── pve.sh                   | PVECLIENT_BIN

	declare -r _XDG_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
	declare -r _XDG_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
	declare -r _XDG_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
	declare -r _XDG_BIN_DIR="$HOME/.local/bin"

	declare -r CLIENT_CACHE_DIR="$_XDG_CACHE_DIR/$PROJECT_NAME"
	declare -r PVE_ROOT_CA="$CLIENT_CACHE_DIR/pve-root-ca.pem"
	declare -r DOTENV="$_XDG_CONFIG_DIR/$PROJECT_NAME/.env"
	declare -r EXT_BASHTOOLS_SRC_DIR="$_XDG_DATA_DIR/$PROJECT_NAME/external/bash-tools/src"
	declare -r LIB_CLIENT_DIR="$_XDG_DATA_DIR/$PROJECT_NAME/client"
	declare -r LIB_SERVER_DIR="$_XDG_DATA_DIR/$PROJECT_NAME/server"
	declare -r PVECLIENT_BIN="$_XDG_BIN_DIR/pve.sh"

	# TODO delete this and always generate on-the-fly
	declare -r PVE_API_TOKEN="$_XDG_CONFIG_DIR/$PROJECT_NAME/pve-api-token"
else
	#  dev                                  | env vars
	# --------------------------------------|------------------------------------
	#  pve-client/                          | _PROJ_DIR
	#  ├── external/                        |
	#  │   └── bash-tools/                  |
	#  │       └── src                      | EXT_BASHTOOLS_SRC_DIR
	#  ├── lib/                             |
	#  │   ├── client/                      | LIB_CLIENT_DIR
	#  |   |   └── client-common.sh         | (this script)
	#  │   └── server/                      | LIB_SERVER_DIR
	#  |   └── global-common.sh             | GLOBAL_COMMON_SH
	#  ├── src/                             |
	#  │   └── pve.sh                       | PVECLIENT_BIN
	#  ├── tools/                           | _TOOLS_DIR
	#  ├── cache/                           | CLIENT_CACHE_DIR
	#  │   └── pve-root-ca.pem              | PVE_ROOT_CA
	#  ├── .env                             | DOTENV
	#  ├── pve-api-token                    | PVE_API_TOKEN

	_PROJ_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")"
	declare -r _PROJ_DIR
	declare -r _TOOLS_DIR="$_PROJ_DIR/tools"

	declare -r CLIENT_CACHE_DIR="$_PROJ_DIR/cache"
	declare -r PVE_ROOT_CA="$CLIENT_CACHE_DIR/pve-root-ca.pem"
	declare -r DOTENV="$_PROJ_DIR/.env"
	declare -r EXT_BASHTOOLS_SRC_DIR="$_PROJ_DIR/external/bash-tools/src"
	declare -r LIB_CLIENT_DIR="$_PROJ_DIR/lib/client"
	declare -r LIB_SERVER_DIR="$_PROJ_DIR/lib/server"
	declare -r PVECLIENT_BIN="$_PROJ_DIR/src/pve.sh"

	# TODO delete this and always generate on-the-fly
	declare -r PVE_API_TOKEN="$_PROJ_DIR/pve-api-token"
fi

# -------------------------- IMPORTS ------------------------------------------

# import external libs
source "$EXT_BASHTOOLS_SRC_DIR/bash-tools.sh"

# -------------------------- PRECONDITIONS ------------------------------------

# exit shell if this script was executed directly rather than being source'd
assert_sourced

# -------------------------- UTILITIES ----------------------------------------

# set the project environment variables
function set_env() {
	reset_checks
	check_file_exists DOTENV
	print_failed_checks --error || return

	# shellcheck source=.env
	source "$DOTENV"
}
readonly -f set_env

# common script setup tasks
function housekeeping() {
	set_env
}

# test whether this is dev env
function is_devmode() {
	[[ -n $_TOOLS_DIR ]] &>/dev/null
}
readonly -f is_devmode

# -------------------------- ASSERTIONS ---------------------------------------

# -------------------------- CHECKS -------------------------------------------
