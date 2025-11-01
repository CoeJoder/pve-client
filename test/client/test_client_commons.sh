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

function kicktires_get_guest_id() {
	local guest_id
	guest_id="$(get_guest_id jira)"
	echo "Guest ID: $guest_id"
}

function kicktires_get_all_guests() {
	declare -A guests
	get_all_guests guests

	for id in "${!guests[@]}"; do
		IFS=' ' read -r name status type node <<<"${guests[$id]}"
		printf "ID: %-5s  Name: %-10s  Status: %-8s  Type: %-5s  Node: %s\n" \
			"$id" "$name" "$status" "$type" "$node"
	done
}

function kicktires_qm() {
	qm status "$(get_guest_id jira)"
}

function kicktires_manage_guest() {
	manage_guest status jira
}

# -------------------------- TEST RUNNER --------------------------------------

kicktires_get_guest_id
printf '\n'
kicktires_get_all_guests
printf '\n'
kicktires_qm
printf '\n'
kicktires_manage_guest
printf '\n'
