#!/bin/bash

# spice-server.sh
# Set the VM's display to 'qxl', start or restart the VM to apply settings, and
# return a SPICE ticket in JSON format to be parsed by the client.

# -------------------------- HEADER -------------------------------------------

set -eEo pipefail
shopt -s inherit_errexit

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/server-common.sh"
housekeeping

function show_usage() {
	cat >&2 <<-EOF
		Usage: $(basename "${BASH_SOURCE[0]}") [options]
		Options:
		--vmid ${underline}val${nounderline}         The virtual machine ID
		--timeout, -t ${underline}val${nounderline}  The VM restart timeout in seconds (default: 15)
		--help, -h         Show this message
	EOF
}

_parsed_args=$(getopt \
	--options='h,t' \
	--longoptions='help,vmid:,timeout:' \
	--name "$(basename "${BASH_SOURCE[0]}")" -- "$@")
eval set -- "$_parsed_args"
unset _parsed_args

vmid=''
timeout=15

while true; do
	case "$1" in
	--vmid)
		vmid="$2"
		shift 2
		continue
		;;
	-t | --timeout)
		timeout="$2"
		shift 2
		continue
		;;
	-h | --help)
		show_usage
		exit 0
		;;
	--)
		shift
		break
		;;
	*)
		printerr "unknown argument: $1"
		exit 1
		;;
	esac
done

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_server
assert_not_sourced

reset_checks
check_is_positive_integer vmid
check_is_positive_integer timeout

check_is_defined PVE_HOST
check_is_valid_port PVE_PORT
check_is_defined PVE_NODE
check_is_defined PVE_SSH_HOST

for _command in jq; do
	check_command_exists_on_path _command
done
print_failed_checks --error || exit

# -------------------------- BANNER -------------------------------------------
# -------------------------- PREAMBLE -----------------------------------------
# -------------------------- RECONNAISSANCE -----------------------------------
# -------------------------- EXECUTION ----------------------------------------

# Enable SPICE for VM by setting the display adapter to 'qxl'.
function set_display_spice() {
	log info "Checking VGA config..."
	if ! sudo qm config "$vmid" | grep -q '^vga: qxl'; then
		log info 'Setting QXL display driver...'
		sudo qm set 100 --vga qxl --memory 32 || return
	fi
}

# Get the SPICE ticket in JSON format via pvesh
function get_spice_ticket() {
	log ingo "Requesting SPICE ticket via pvesh..."
	if ! sudo pvesh create "/nodes/$PVE_NODE/qemu/$vmid/spiceproxy" --output-format json-pretty; then
		log error "Failed to retrieve SPICE ticket."
		return 1
	fi
}

function main() {
	set_display_spice "$vmid" "$timeout"

	if is_vm_stopped "$vmid"; then
		log info 'Starting VM...'
		sudo qm start "$vmid" || return
		wait_until_vm_is_running "$vmid" "$timeout" || return
	elif is_vm_running "$vmid"; then
		log info 'Restarting VM to apply changes...'
		sudo qm stop "$vmid" || return
		wait_until_vm_is_stopped "$vmid" "$timeout" || return
		sudo qm start "$vmid" || return
		wait_until_vm_is_running "$vmid" "$timeout" || return
	else
		log error "VM not started.  Status: $(get_vm_status "$vmid")"
		continue_or_exit 1 "Launch SPICE client anyway?"
	fi
	
	get_spice_ticket || return
}

trap 'on_err' ERR

main "$@"


# -------------------------- POSTCONDITIONS -----------------------------------
