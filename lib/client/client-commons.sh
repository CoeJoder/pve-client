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

# VM status
VM_STATUS_RUNNING='running'
VM_STATUS_STOPPED='stopped'
VM_STATUS_PAUSED='paused'
VM_STATUS_SUSPENDED='suspended'

# Commands that work for both qemu & lxc
VM_COMMAND_CLONE='clone'
VM_COMMAND_CONFIG='config'
VM_COMMAND_CREATE='create'
VM_COMMAND_DELSNAPSHOT='delsnapshot'
VM_COMMAND_DESTROY='destroy'
VM_COMMAND_HELP='help'
VM_COMMAND_LIST='list'
VM_COMMAND_LISTSNAPSHOT='listsnapshot'
VM_COMMAND_MIGRATE='migrate'
VM_COMMAND_PENDING='pending'
VM_COMMAND_REBOOT='reboot'
VM_COMMAND_REMOTE_MIGRATE='remote-migrate'
VM_COMMAND_RESCAN='rescan'
VM_COMMAND_RESIZE='resize'
VM_COMMAND_RESUME='resume'
VM_COMMAND_ROLLBACK='rollback'
VM_COMMAND_SET='set'
VM_COMMAND_SHUTDOWN='shutdown'
VM_COMMAND_SNAPSHOT='snapshot'
VM_COMMAND_START='start'
VM_COMMAND_STATUS='status'
VM_COMMAND_STOP='stop'
VM_COMMAND_SUSPEND='suspend'
VM_COMMAND_TEMPLATE='template'
VM_COMMAND_TERMINAL='terminal'
VM_COMMAND_UNLOCK='unlock'

ALL_VM_COMMANDS=(
	"$VM_COMMAND_CLONE"
	"$VM_COMMAND_CONFIG"
	"$VM_COMMAND_CREATE"
	"$VM_COMMAND_DELSNAPSHOT"
	"$VM_COMMAND_DESTROY"
	"$VM_COMMAND_HELP"
	"$VM_COMMAND_LIST"
	"$VM_COMMAND_LISTSNAPSHOT"
	"$VM_COMMAND_MIGRATE"
	"$VM_COMMAND_PENDING"
	"$VM_COMMAND_REBOOT"
	"$VM_COMMAND_REMOTE_MIGRATE"
	"$VM_COMMAND_RESCAN"
	"$VM_COMMAND_RESIZE"
	"$VM_COMMAND_RESUME"
	"$VM_COMMAND_ROLLBACK"
	"$VM_COMMAND_SET"
	"$VM_COMMAND_SHUTDOWN"
	"$VM_COMMAND_SNAPSHOT"
	"$VM_COMMAND_START"
	"$VM_COMMAND_STATUS"
	"$VM_COMMAND_STOP"
	"$VM_COMMAND_SUSPEND"
	"$VM_COMMAND_TEMPLATE"
	"$VM_COMMAND_TERMINAL"
	"$VM_COMMAND_UNLOCK"
)

# -------------------------- UTILITIES ----------------------------------------

# test whether this is dev env
function is_devmode() {
	[[ -n $_TOOLS_DIR ]] &>/dev/null
}
readonly -f is_devmode

# RPC wrapper for `qm`
function qm() {
	functrace "$@"
	if (($# < 2)); then
		log error "Usage: qm <command> <vmid> [options]"
		return 255
	fi
	local qm_command=('sudo' 'qm')
	local vmid

	qm_command+=("$@")
	log trace "RPC: \`${qm_command[*]}\`"
	ssh "$PVE_SSH_HOST" "${qm_command[@]}" || return
}
readonly -f qm

# RPC wrapper for `pct`
function pct() {
	functrace "$@"
	if (($# < 2)); then
		log error "Usage: pct <command> <vmid> [options]"
		return 255
	fi
	local pct_command=('sudo' 'pct')
	local vmid

	pct_command+=("$@")
	log trace "RPC: \`${pct_command[*]}\`"
	ssh "$PVE_SSH_HOST" "${pct_command[@]}" || return
}
readonly -f pct

# RPC wrapper for `pvesh`
function pvesh() {
	functrace "$@"
	if (($# < 1)); then
		log error "Usage: pvesh <command> [args] [options]"
		return 255
	fi
	local pvesh_command=('sudo' 'pvesh')
	local vmid

	pvesh_command+=("$@")
	log trace "RPC: \`${pvesh_command[*]}\`"
	ssh "$PVE_SSH_HOST" "${pvesh_command[@]}" || return
}
readonly -f pvesh

# Usage:
#   is_valid_vmid <vmid>
#
# Returns true if arg is within valid numerical range.
function is_valid_vmid() {
	functrace "$@"
	local vmid="$1"
	[[ "$vmid" =~ ^[[:digit:]]+$ ]] && ((vmid >= 100 && vmid <= 1000000))
}
readonly -f is_valid_vmid

# Usage:
#   manage_guest <command> <vmid-or-name> [args] [options]
#
# Unified qemu/LXC remote guest management interface.
function manage_guest() {
	functrace "$@"
	if (($# < 2)); then
		log error "Usage: manage_guest <command> <vmid-or-name> [args] [options]"
		return 255
	fi
	local vm_command="$1"
	local vmid_or_name="$2"
	shift 2

	local -A guests
	local id name status type node

	local vmid
	local vmtype # 'qemu' or 'lxc'
	local wrapped_command

	if is_valid_vmid "$vmid_or_name"; then
		vmid="$vmid_or_name"
	fi

	# find the vmtype, and the vmid if not given
	get_all_guests guests
	for id in "${!guests[@]}"; do
		IFS=' ' read -r name status type node <<<"${guests[$id]}"
		if [[ -z "$vmid" ]]; then
			if [[ "$vmid_or_name" == "$name" ]]; then
				vmid="$id"
				vmtype="$type"
				break
			fi
		elif [[ "$vmid" == "$id" ]]; then
			vmtype="$type"
			break
		fi
	done

	if [[ -z "$vmid" || -z "$vmtype" ]]; then
		log error "Guest not found: $vmid_or_name"
		return 1
	fi

	# Perform RPC depending on vmtype
	case "$vmtype" in
	'qemu')
		qm "$vm_command" "$vmid" "$@" || return
		;;
	'lxc')
		pct "$vm_command" "$vmid" "$@" || return
		;;
	*)
		log error "Unknown guest type: $vmtype"
		return 1
		;;
	esac
}
readonly -f manage_guest

# get VM status
function get_vm_status() {
	functrace "$@"
	local vmid="$1"
	ssh "$PVE_SSH_HOST" "sudo qm status '$vmid'" | awk '{print $2}' || return
}
readonly -f get_vm_status

function is_vm_status() {
	functrace "$@"
	local vmid="$1"
	local status_to_check="$2"
	local status_actual
	status_actual="$(get_vm_status "$vmid")" || return
	[[ "$status_to_check" == "$status_actual" ]]
}
readonly -f is_vm_status

function is_vm_stopped() {
	functrace "$@"
	is_vm_status "$1" "$VM_STATUS_STOPPED"
}
readonly -f is_vm_stopped

function is_vm_running() {
	functrace "$@"
	is_vm_status "$1" "$VM_STATUS_RUNNING"
}
readonly -f is_vm_running

# Usage:
#   wait_until_vm_is <vmid> <status> <timeout>
#
# Waits the given number of seconds for VM to be of given status.
function wait_until_vm_is() {
	functrace "$@"
	if (($# < 3)); then
		log error "Usage: wait_until_vm_is <vmid> <status> <timeout>"
		return 255
	fi
	local vmid="$1"
	local status="$2"
	local timeout="$3"
	local i status_actual

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
readonly -f wait_until_vm_is

function wait_until_vm_is_stopped() {
	functrace "$@"
	wait_until_vm_is "$1" "$VM_STATUS_STOPPED" "$2"
}
readonly -f wait_until_vm_is_stopped

function wait_until_vm_is_running() {
	functrace "$@"
	wait_until_vm_is "$1" "$VM_STATUS_RUNNING" "$2"
}
readonly -f wait_until_vm_is_running

# Usage:
#   get_guest_id <guest-name>
#
# Looks up the ID of a Proxmox guest (VM or container) by name.
function get_guest_id() {
	functrace "$@"
	if (($# != 1)); then
		log error "Usage: get_guest_id <guest-name>"
		return 1
	fi
	local guest_name="$1"
	local vmid

	vmid=$(ssh "$PVE_SSH_HOST" "sudo pvesh get /cluster/resources --output-format json" |
		jq -r --arg name "$guest_name" '
			.[] | 
			select(.name == $name and (.type == "qemu" or .type == "lxc")) | 
			.vmid
		')
	if [[ -z "$vmid" ]]; then
		log error "No guest found with the name '$guest_name'."
		return 1
	else
		printf '%s' "$vmid"
	fi
}
readonly -f get_guest_id

# Usage:
#   get_all_guests <assoc_array_name> [status] [type]
#
# Populates an associative array with entries like:
#   [VMID]="name status type node"
#
# Optional filters:
#   status = running | stopped | paused | etc.
#   type   = qemu | lxc
#
# Examples:
#   get_all_guests guests              # all guests
#   get_all_guests guests running      # only running (VMs + LXCs)
#   get_all_guests guests "" lxc       # all containers
#   get_all_guests guests running qemu # only running VMs
function get_all_guests() {
	functrace "$@"
	if (($# < 1)); then
		log error "Usage: get_all_guests <assoc_array_name> [status] [type]"
		return 255
	fi
	local -n _out=$1
	local filter_status=${2:-}
	local filter_type=${3:-}
	local vmid name status type node

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
readonly -f get_all_guests

# -------------------------- ASSERTIONS ---------------------------------------

# -------------------------- CHECKS -------------------------------------------
