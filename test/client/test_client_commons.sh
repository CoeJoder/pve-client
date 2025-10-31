#!/bin/bash
#
# test_client_commons.sh

# -------------------------- HEADER -------------------------------------------

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

# import script under test (which imports `bash-tools`)
source "$this_dir/../../lib/client/client-commons.sh"

# import `bash-tools` test framework
source "$this_dir/../../external/bash-tools/test/test_framework.sh"

# .env setup
housekeeping
BASHTOOLS_LOGLEVEL='trace'

# -------------------------- TEST CASES ---------------------------------------

# kick the tires on `get_proxmox_guests`
function kicktire_get_proxmox_guests() {
	declare -A guests
	get_proxmox_guests guests

	for id in "${!guests[@]}"; do
			IFS=' ' read -r name status type node <<<"${guests[$id]}"
			printf "ID: %-5s  Name: %-10s  Status: %-8s  Type: %-5s  Node: %s\n" \
					"$id" "$name" "$status" "$type" "$node"
	done
}

# -------------------------- TEST RUNNER --------------------------------------

kicktire_get_proxmox_guests
