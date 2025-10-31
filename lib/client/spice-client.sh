#!/bin/bash
#
# spice-client.sh
# Launch a SPICE client connected to the VM or container by the following:
#
# 1. SSH into the Proxmox host and:
#   a. Set the QXL display driver if not already.
#   b. Start & stop the VM if it was running while the setting was changed.
#   c. Generate a secure, one-time SPICE ticket.
# 2. Then locally:
#   a. Convert the JSON ticket into a VirtViewer INI temp file.
#   b. Launch VirtViewer GUI with the INI file, which is then deleted.
#
# Usage:
#   spice-client.sh [options] <vm>
# -------------------------- HEADER -------------------------------------------

# set -eEo pipefail
# shopt -s inherit_errexit

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/client-commons.sh"
housekeeping

function show_usage() {
	cat >&2 <<-EOF
		Usage: $(basename "${BASH_SOURCE[0]}") [options] <guest-name>
		Options:
		--timeout ${underline}val${nounderline}   The VM restart timeout in seconds (default: 15)
		--no-banner     Skip banner display
		--help, -h      Show this message
	EOF
}

_parsed_args=$(getopt \
	--options='h,t:' \
	--longoptions='help,no-banner,timeout:' \
	--name "$(basename "${BASH_SOURCE[0]}")" -- "$@")
eval set -- "$_parsed_args"
unset _parsed_args

timeout=15
no_banner=0

while true; do
	case "$1" in
	-t | --timeout)
		timeout="$2"
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

check_is_defined PVE_HOST
check_is_valid_port PVE_PORT
check_is_defined PVE_NODE
check_is_defined PVE_SSH_HOST

for _command in jq remote-viewer; do
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

# -------------------------- EXECUTION ----------------------------------------

# Enable SPICE for VM by setting the display adapter to 'qxl'.
function set_display_spice() {
	local qm_config

	log info "Checking VGA config..."
	qm_config="$(ssh "$PVE_SSH_HOST" "sudo qm config '$vmid'")" || return
	if ! grep -q '^vga: qxl' <<<"$qm_config"; then
		log info 'Setting QXL display driver...'
		ssh "$PVE_SSH_HOST" "sudo qm set '$vmid' --vga qxl --memory 32" || return
	fi
}

# Get the SPICE ticket in JSON format via pvesh
function get_spice_ticket() {
	log ingo "Requesting SPICE ticket via pvesh..."
	if ! ssh "$PVE_SSH_HOST" "sudo pvesh create "/nodes/$PVE_NODE/qemu/$vmid/spiceproxy" --output-format json-pretty"; then
		log error "Failed to retrieve SPICE ticket."
		return 1
	fi
}

function main() {
	local status
	local spice_json
	local vv_temp_file

	set_display_spice "$vmid" "$timeout" || return
	
	status="$(get_vm_status "$vmid")"
	if [[ "$status" == "$VM_STATUS_STOPPED" ]]; then
		log info 'Starting VM...'
		ssh "$PVE_SSH_HOST" "sudo qm start '$vmid'" || return
		wait_until_vm_is_running "$vmid" "$timeout" || return
	elif [[ "$status" == "$VM_STATUS_RUNNING" ]]; then
		log info 'Restarting VM to apply changes...'
		sudo qm stop "$vmid" || return
		wait_until_vm_is_stopped "$vmid" "$timeout" || return
		sudo qm start "$vmid" || return
		wait_until_vm_is_running "$vmid" "$timeout" || return
	else
		log warn "VM is ${status}."
		yes_or_no --default-yes "Launch SPICE client anyway?" || return
	fi
	
	spice_json="$(get_spice_ticket)" || return
	vv_temp_file="$(mktemp)" || return
	echo "$spice_json" | jq -r 'def kv: to_entries[] | "\(.key)=\(.value)"; "[virt-viewer]", kv' >"$vv_temp_file"
	if [[ ! -s "$vv_temp_file" ]]; then
		echo "✗ Failed to create VirtViewer connection file." >&2
		return 1
	fi

	echo "→ Launching VirtViewer..."
	remote-viewer -- "$vv_temp_file" &
}

trap 'on_err' ERR


if [[ -z "$HOST" || -z "$NODE" || -z "$VMID" || -z "$USER" ]]; then
	cat "Usage: pve_client_utils__connect_vm_spice " >&2
	return 1
fi

echo "
	set -e
	source ~/scripts/common.sh || exit
	source ~/scripts/pve_host_utils.sh || exit

	pve_host_utils__set_display_spice '$vmid' '$timeout' || exit
	pve_host_utils__get_spice_ticket '$NODE' '$vmid' || exit
	"

# spice_json="$(ssh "$PVE_SSH_HOST" "
# 	$_pve_client_utils__host_init_script

# 	pve_host_utils__set_display_spice '$vmid' '$timeout' || exit
# 	pve_host_utils__get_spice_ticket '$NODE' '$vmid' || exit
# 	")" || return



# -------------------------- POSTCONDITIONS -----------------------------------
