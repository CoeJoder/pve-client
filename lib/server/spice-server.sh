#!/bin/bash
#
# spice-server.sh
# Set the VM's display to 'qxl', start or restart the VM to apply settings, and
# return a SPICE ticket in JSON format to be parsed by the client.

# -------------------------- HEADER -------------------------------------------

set -eEo pipefail
shopt -s inherit_errexit

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/server-commons.sh"
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
print_failed_checks --error || exit

# -------------------------- BANNER -------------------------------------------
# -------------------------- PREAMBLE -----------------------------------------
# -------------------------- RECONNAISSANCE -----------------------------------
# -------------------------- EXECUTION ----------------------------------------

# TODO read client's command and run one of the above functions

trap 'on_err' ERR

main "$@"


# -------------------------- POSTCONDITIONS -----------------------------------
