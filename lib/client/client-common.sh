#!/bin/bash

# client-common.sh
#
# Constants and utility functions used by the client scripts.

# -------------------------- HEADER -------------------------------------------

# ignore unused variable warnings (source'd script)
# shellcheck disable=SC2034

# -------------------------- CONSTANTS ----------------------------------------

PROJECT_NAME='pve-client'
REMOTE_PVE_ROOT_CA='/etc/pve/pve-root-ca.pem'

# resolve project paths based on 'dev' (source) or 'prod' (deployment)
#  - env is dynamically determined based on filesystem position of this script
#  - prod dirs are overridable per XDG base dir spec
#  - env vars prefixed with '_' do not exist in all envs

# if grandparent directory of this script is $PROJECT_NAME, then this is prod
if [[ "$(basename "$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")")" == "$PROJECT_NAME" ]]; then
	#  prod                                 | env vars
	# --------------------------------------|------------------------------------
	#  ~                                    |
	#  ├── .cache                           | _XDG_CACHE_DIR
	#  │   └── pve-client                   |
	#  │       └── pve-root-ca.pem          | PVE_ROOT_CA
	#  ├── .config                          | _XDG_CONFIG_DIR
	#  │   └── pve-client                   |
	#  │       ├── .env                     | DOTENV
	#  │       └── pve-api-token            | PVE_API_TOKEN
	#  ├── .local                           |
	#  │   └── .share                       | _XDG_DATA_DIR
	#  │       └── pve-client               |
	#  │           ├── external             |
	#  │           │   └── bash-tools       |
	#  │           │       └── src          | EXT_BASH_TOOLS_SRC_DIR
	#  │           ├── client               | LIB_CLIENT_DIR
	#  |           |   └── client-common.sh | (this script)
	#  │           └── server               | LIB_SERVER_DIR
	#  └── .local                           |
	#      └── bin                          | _XDG_BIN_DIR
	#          └── pve.sh                   | PVECLIENT_BIN

	_XDG_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
	_XDG_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
	_XDG_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
	_XDG_BIN_DIR="$HOME/.local/bin"

	PVE_ROOT_CA="$_XDG_CACHE_DIR/$PROJECT_NAME/pve-root-ca.pem"
	DOTENV="$_XDG_CONFIG_DIR/$PROJECT_NAME/.env"
	EXT_BASH_TOOLS_SRC_DIR="$_XDG_DATA_DIR/$PROJECT_NAME/external/bash-tools/src"
	LIB_CLIENT_DIR="$_XDG_DATA_DIR/$PROJECT_NAME/client"
	LIB_SERVER_DIR="$_XDG_DATA_DIR/$PROJECT_NAME/server"
	PVECLIENT_BIN="$_XDG_BIN_DIR/pve.sh"

	# TODO delete this and always generate on-the-fly
	PVE_API_TOKEN="$_XDG_CONFIG_DIR/$PROJECT_NAME/pve-api-token"
else
	#  dev                                  | env vars
	# --------------------------------------|------------------------------------
	#  pve-client                           | _PROJ_DIR
	#  ├── external                         |
	#  │   └── bash-tools                   |
	#  │       └── src                      | EXT_BASH_TOOLS_SRC_DIR
	#  ├── lib                              |
	#  │   ├── client                       | LIB_CLIENT_DIR
	#  |   |   └── client-common.sh         | (this script)
	#  │   └── server                       | LIB_SERVER_DIR
	#  ├── src                              |
	#  │   └── pve.sh                       | PVECLIENT_BIN
	#  ├── tools                            | _TOOLS_DIR
	#  ├── .env                             | DOTENV
	#  ├── pve-api-token                    | PVE_API_TOKEN
	#  └── pve-root-ca.pem                  | PVE_ROOT_CA

	_PROJ_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")"
	_TOOLS_DIR="$_PROJ_DIR/tools"

	PVE_ROOT_CA="$_PROJ_DIR/pve-root-ca.pem"
	DOTENV="$_PROJ_DIR/.env"
	EXT_BASH_TOOLS_SRC_DIR="$_PROJ_DIR/external/bash-tools/src"
	LIB_CLIENT_DIR="$_PROJ_DIR/lib/client"
	LIB_SERVER_DIR="$_PROJ_DIR/lib/server"
	PVECLIENT_BIN="$_PROJ_DIR/src/pve.sh"

	# TODO delete this and always generate on-the-fly
	PVE_API_TOKEN="$_PROJ_DIR/pve-api-token"
fi

# -------------------------- IMPORTS ------------------------------------------

# import external libs
source "$EXT_BASH_TOOLS_SRC_DIR/bash-tools.sh"

# -------------------------- PRECONDITIONS ------------------------------------

# exit shell if this script was executed directly rather than being source'd
assert_sourced

# -------------------------- UTILITIES ----------------------------------------

# set the project environment variables
function set_env() {
	reset_checks
	check_file_exists dotenv
	print_failed_checks --error || return

	# shellcheck source=.env
	source "$DOTENV"
}

# test whether this is dev env
function is_devmode() {
	[[ -n $_TOOLS_DIR ]] &>/dev/null
}

# -------------------------- ASSERTIONS ---------------------------------------

# -------------------------- CHECKS -------------------------------------------
