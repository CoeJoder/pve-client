#!/bin/bash
#
# spice-client.sh
# Launch a SPICE client connection to VM or container.
#
# Algorithm:
#   1a. If SPICE is not enabled:
#     a. If VM is running, stop it.
#     b. Enable SPICE driver.
#     c. Start the VM.
#   1b. Else:
#     a. If VM is stopped, start it.
#   2. Generate a secure, one-time SPICE ticket.
#   3. Convert the SPICE ticket JSON into a VirtViewer INI temp file.
#   4. Launch VirtViewer GUI with the INI file, which is then deleted.
#
# Usage:
#   spice-client.sh [options] <vm>
# -------------------------- HEADER -------------------------------------------

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/client-commons.sh"
housekeeping

function show_usage() {
	cat >&2 <<-EOF
		Usage: $(basename "${BASH_SOURCE[0]}") [options] <guest-name>
		Options:
		--timeout ${underline}val${nounderline}     The VM restart timeout in seconds (default: 15)
		--log-level ${underline}val${nounderline}   The log-level (default: info)
		--no-banner       Skip banner display
		--help, -h        Show this message
	EOF
}

_parsed_args=$(getopt \
	--options='h,t:' \
	--longoptions='help,no-banner,timeout:,log-level:' \
	--name "$(basename "${BASH_SOURCE[0]}")" -- "$@")
eval set -- "$_parsed_args"
unset _parsed_args

timeout=15
loglevel=info
no_banner=0

while true; do
	case "$1" in
	-t | --timeout)
		timeout="$2"
		shift 2
		continue
		;;
	--log-level)
		loglevel="$2"
		shift 2
		continue
		;;
	--no-banner)
		no_banner=1
		shift 1
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
		log error "unknown argument: $1"
		exit 1
		;;
	esac
done

if (($# < 1)); then
	show_usage
	exit 1
fi
guest="$1"
shift

# -------------------------- PRECONDITIONS ------------------------------------

assert_not_sourced

reset_checks
check_is_defined guest
check_is_positive_integer timeout
check_is_valid_loglevel loglevel

check_is_defined PVE_HOST
check_is_valid_port PVE_PORT
check_is_defined PVE_NODE
check_is_defined PVE_SSH_HOST

for _command in jq remote-viewer grep; do
	check_command_exists_on_path _command
done
print_failed_checks --error || exit

# -------------------------- BANNER -------------------------------------------

if (( ! "$no_banner" )); then
	show_banner "${color_lightgray}" <<EOF
${color_red}███████╗██████╗ ██╗ ██████╗███████╗ ${color_lightgray}   ██╗███████╗    ███╗   ██╗██╗ ██████╗███████╗
${color_red}██╔════╝██╔══██╗██║██╔════╝██╔════╝ ${color_lightgray}   ██║██╔════╝    ████╗  ██║██║██╔════╝██╔════╝
${color_red}███████╗██████╔╝██║██║     █████╗   ${color_lightgray}   ██║███████╗    ██╔██╗ ██║██║██║     █████╗  
${color_red}╚════██║██╔═══╝ ██║██║     ██╔══╝   ${color_lightgray}   ██║╚════██║    ██║╚██╗██║██║██║     ██╔══╝  
${color_red}███████║██║     ██║╚██████╗███████╗ ${color_lightgray}   ██║███████║    ██║ ╚████║██║╚██████╗███████╗
${color_red}╚══════╝╚═╝     ╚═╝ ╚═════╝╚══════╝ ${color_lightgray}   ╚═╝╚══════╝    ╚═╝  ╚═══╝╚═╝ ╚═════╝╚══════╝
EOF
fi

# -------------------------- PREAMBLE -----------------------------------------

# -------------------------- RECONNAISSANCE -----------------------------------

set_loglevel "$loglevel"

vmid="$(get_guest_id "$guest")"

# -------------------------- EXECUTION ----------------------------------------

# Test if 'qxl' display driver is set.
function is_display_spice() {
	functrace
	local qm_config

	log info "Checking if SPICE driver is set..."
	qm_config="$(manage_guest config "$vmid")" || return
	if ! grep -q '^vga: qxl' <<<"$qm_config"; then
		log info 'SPICE driver not set.'
		return 1
	fi
}

# Set the 'qxl' display driver.
function set_display_spice() {
	functrace

	log info 'Setting display to SPICE...'
	manage_guest set "$vmid" --vga qxl || return
}

# Get the SPICE ticket in JSON format via pvesh
function get_spice_ticket() {
	functrace

	log info "Requesting SPICE ticket via pvesh..."
	if ! pvesh create "/nodes/$PVE_NODE/qemu/$vmid/spiceproxy" --output-format json-pretty; then
		log error "Failed to retrieve SPICE ticket."
		return 1
	fi
}

# Stop VM and wait for it to be stopped.
function stop_vm() {
	functrace

	log info "Stopping VM..."
	manage_guest stop "$vmid" || return
	wait_until_vm_is_stopped "$vmid" "$timeout" || return
}

# Start VM and wait for it to be running.
function start_vm() {
	functrace

	log info 'Starting VM...'
	manage_guest start "$vmid" || return
	wait_until_vm_is_running "$vmid" "$timeout" || return
}

set -E
trap 'on_err' ERR

status="$(get_vm_status "$vmid")"

if ! is_display_spice; then
	if [[ "$status" == "$VM_STATUS_RUNNING" ]]; then
		stop_vm || exit
	fi
	set_display_spice || exit
	start_vm || exit
else
	if [[ "$status" == "$VM_STATUS_STOPPED" ]]; then
		start_vm || exit
	fi
fi

spice_json="$(get_spice_ticket)" || exit
vv_temp_file="$(mktemp)" || exit
echo "$spice_json" | jq -r 'def kv: to_entries[] | "\(.key)=\(.value)"; "[virt-viewer]", kv' >"$vv_temp_file"
if [[ ! -s "$vv_temp_file" ]]; then
	log error "Failed to create VirtViewer connection file."
	exit 1
fi

log info "Launching VirtViewer..."
if ! (remote-viewer -- "$vv_temp_file" &>/dev/null &); then
	# Ensure temp file is deleted even if remote-viewer fails.
	if [[ -n "$vv_temp_file" ]]; then
		rm -rf --interactive=never "$vv_temp_file" &>/dev/null
	fi
fi

# -------------------------- POSTCONDITIONS -----------------------------------
