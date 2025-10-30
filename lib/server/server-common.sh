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

function get_vm_status() {
	local vmid="$1"
	sudo qm status "$vmid" | awk '{print $2}' || return
}

function _is_vm_status() {
	local vmid="$1"
	local status_to_check="$2"
	local status_actual
	status_actual="$(get_vm_status "$vmid")" || return
	[[ "$status_to_check" == "$status_actual" ]]
}

function is_vm_stopped() {
	_is_vm_status "$1" 'stopped'
}

function is_vm_running() {
	_is_vm_status "$1" 'running'
}

function _wait_until_vm_is() {
	local vmid="$1"
	local status="$2"
	local timeout="$3"
	local i status_actual

	if (( $# < 3 )); then
		log error "Usage: wait_until_vm_is <vmid> <status> <timeout>"
		return 255
	fi

	log debug "Waiting $timeout seconds for VM $vmid to be $status..."
	for (( i = 0; i < timeout; i++ )); do
		if is_vm_status "$vmid" "$status"; then
			return
		fi
		sleep 1
	done

	if ! is_vm_status "$vmid" "$status"; then
		log error "Timed out waiting for VM to be '$status'"
		return 1
	fi
}

function wait_until_vm_is_stopped() {
	_wait_until_vm_is "$1" 'stopped' "$2"
}

function wait_until_vm_is_running() {
	_wait_until_vm_is "$1" 'running' "$2"
}

# -------------------------- ASSERTIONS ---------------------------------------

# -------------------------- CHECKS -------------------------------------------
