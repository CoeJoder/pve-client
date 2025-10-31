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

# -------------------------- IMPORTS ----------------------------------------

# import external libs
source "$EXT_BASHTOOLS_SRC_DIR/bash-tools.sh"

# -------------------------- PRECONDITIONS ----------------------------------

# exit shell if this script was executed directly rather than being source'd
assert_sourced

# -------------------------- CONSTANTS --------------------------------------------

VM_STATUS_RUNNING='running'
VM_STATUS_STOPPED='stopped'
VM_STATUS_PAUSED='paused'
VM_STATUS_SUSPENDED='suspended'

# -------------------------- UTILITIES ----------------------------------------

function get_vm_status() {
	local vmid="$1"
	sudo qm status "$vmid" | awk '{print $2}' || return
}

function is_vm_status() {
	local vmid="$1"
	local status_to_check="$2"
	local status_actual
	status_actual="$(get_vm_status "$vmid")" || return
	[[ "$status_to_check" == "$status_actual" ]]
}

function is_vm_stopped() {
	is_vm_status "$1" "$VM_STATUS_STOPPED"
}

function is_vm_running() {
	is_vm_status "$1" "$VM_STATUS_RUNNING"
}

function wait_until_vm_is() {
	local vmid="$1"
	local status="$2"
	local timeout="$3"
	local i status_actual

	if (($# < 3)); then
		log error "Usage: wait_until_vm_is <vmid> <status> <timeout>"
		return 255
	fi

	log debug "Waiting $timeout seconds for VM $vmid to be $status..."
	for ((i = 0; i < timeout; i++)); do
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
	wait_until_vm_is "$1" "$VM_STATUS_STOPPED" "$2"
}

function wait_until_vm_is_running() {
	wait_until_vm_is "$1" "$VM_STATUS_RUNNING" "$2"
}

# # Get the VM/CT name using pvesh and filter with jq (requires 'jq' package to be installed: apt install jq)
# # This command lists all resources and selects the one with the matching VMID
# VM_NAME=$(pvesh get /cluster/resources --type vm --output-format json | jq -r --arg VMID_ARG "$VMID" '.[] | select(.vmid == ($VMID_ARG|tonumber)) | .name')

# if [ -n "$VM_NAME" ]; then
# 	echo "Guest Name for ID $VMID: $VM_NAME"
# else
# 	# Check for containers (lxc) if not found as a VM
# 	VM_NAME=$(pvesh get /cluster/resources --type lxc --output-format json | jq -r --arg VMID_ARG "$VMID" '.[] | select(.vmid == ($VMID_ARG|tonumber)) | .name')
# 	if [ -n "$VM_NAME" ]; then
# 		echo "Guest Name for ID $VMID: $VM_NAME (LXC Container)"
# 	else
# 		echo "No guest found with ID $VMID."
# 	fi
# fi

# -------------------------- ASSERTIONS ---------------------------------------

# -------------------------- CHECKS -------------------------------------------
