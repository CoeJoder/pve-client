#!/bin/bash
#
# client-commons.sh
# Constants and utility functions used by the client scripts.

# -------------------------- HEADER -------------------------------------------

# ignore unused variable warnings (source'd script)
# shellcheck disable=SC2034

# source the global commons
source "$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")/global-commons.sh" || exit

# -------------------------- PATHS --------------------------------------------

declare -r SERVER_DEPLOYMENT_PARENT_DIR="\$HOME/.local/bin/$PROJECT_NAME"
declare -r SERVER_CACHE_DIR="/var/tmp/pve-client-cache"

# The client can be installed or run directly from the source project dir.
# The client filesystem:
#   - resolve project paths based on 'prod' (installed) or 'dev' (source)
#     - dynamically determined based on filesystem position of this script
#   - prod dirs are overridable per XDG base dir spec
#   - env vars prefixed with '_' do not exist in all envs

# if grandparent directory of this script is $PROJECT_NAME, then this is prod
if [[ "$(basename "$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")")" == "$PROJECT_NAME" ]]; then
	#  prod                                  | env vars
	# ---------------------------------------|-----------------------------------
	#  ~                                     |
	#  ├── .cache/                           | _XDG_CACHE_DIR
	#  │   └── pve-client/                   | CLIENT_CACHE_DIR
	#  │       └── pve-root-ca.pem           | PVE_ROOT_CA
	#  ├── .config/                          | _XDG_CONFIG_DIR
	#  │   └── pve-client/                   |
	#  │       ├── .env                      | DOTENV
	#  │       └── pve-api-token             | PVE_API_TOKEN
	#  ├── .local/                           |
	#  │   └── .share/                       | _XDG_DATA_DIR
	#  │       └── pve-client/               |
	#  │           ├── external/             |
	#  │           │   └── bash-tools/       |
	#  │           │       └── src           | EXT_BASHTOOLS_SRC_DIR
	#  │           ├── client/               | LIB_CLIENT_DIR
	#  |           |   └── client-commons.sh | (this script)
	#  │           ├── server/               | LIB_SERVER_DIR
	#  |           └── global-commons.sh     |
	#  └── .local/                           |
	#      └── bin/                          | _XDG_BIN_DIR
	#          └── pve.sh                    | PVECLIENT_BIN

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
	#  dev                                   | env vars
	# ---------------------------------------|-----------------------------------
	#  pve-client/                           | _PROJ_DIR
	#  ├── external/                         |
	#  │   └── bash-tools/                   |
	#  │       └── src                       | EXT_BASHTOOLS_SRC_DIR
	#  ├── lib/                              |
	#  │   ├── client/                       | LIB_CLIENT_DIR
	#  |   |   └── client-commons.sh         | (this script)
	#  │   ├── server/                       | LIB_SERVER_DIR
	#  |   └── global-commons.sh             | GLOBAL_COMMON_SH
	#  ├── src/                              |
	#  │   └── pve.sh                        | PVECLIENT_BIN
	#  ├── tools/                            | _TOOLS_DIR
	#  ├── cache/                            | CLIENT_CACHE_DIR
	#  │   └── pve-root-ca.pem               | PVE_ROOT_CA
	#  ├── .env                              | DOTENV
	#  └── pve-api-token                     | PVE_API_TOKEN

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

# check that required client programs are installed
reset_checks
for _command in ssh jq grep awk; do
	check_command_exists_on_path _command
done
print_failed_checks --error || exit

# -------------------------- CONSTANTS ----------------------------------------

VM_STATUS_RUNNING='running'
VM_STATUS_STOPPED='stopped'
VM_STATUS_PAUSED='paused'
VM_STATUS_SUSPENDED='suspended'

# -------------------------- UTILITIES ----------------------------------------

# test whether this is dev env
function is_devmode() {
	[[ -n $_TOOLS_DIR ]] &>/dev/null
}
readonly -f is_devmode

function get_vm_status() {
	local vmid="$1"
	ssh "$PVE_SSH_HOST" "sudo qm status '$vmid'" | awk '{print $2}' || return
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

# get_proxmox_guests <assoc_array_name> [status] [type]
#
# Populates an associative array with entries like:
#   [VMID]="name status type node"
#
# Optional filters:
#   status = running | stopped | paused | etc.
#   type   = qemu | lxc
#
# Examples:
#   get_proxmox_guests guests              # all guests
#   get_proxmox_guests guests running      # only running (VMs + LXCs)
#   get_proxmox_guests guests "" lxc       # all containers
#   get_proxmox_guests guests running qemu # only running VMs
function get_proxmox_guests() {
	local -n _out=$1
	local filter_status=${2:-}
	local filter_type=${3:-}
	local vmid name status type node

	if (( $# < 1 )); then
		log error "Usage: get_proxmox_guests <assoc_array_name> [status] [type]"
		return 255
	fi

	_out=()
	while IFS=$'\t' read -r vmid name status type node; do
		if ! [[ $vmid =~ ^[0-9]+$ ]]; then
			log warn "Encountered non-numeric VMID: $vmid"
			continue
		fi
		_out["$vmid"]="$name $status $type $node"
	done < <(
		ssh "$PVE_SSH_HOST" "sudo pvesh get /cluster/resources --type vm --output-format json" |
			jq -r --arg fs "$filter_status" --arg ft "$filter_type" '
				.[] |
				select(
					($fs == "" or .status == $fs) and
					($ft == "" or .type == $ft)
				) |
				"\(.vmid)\t\(.name // "unknown")\t\(.status)\t\(.type)\t\(.node)"
			'
	)
}

# -------------------------- ASSERTIONS ---------------------------------------

# -------------------------- CHECKS -------------------------------------------
