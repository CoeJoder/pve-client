#!/bin/bash

# global-common.sh
#
# Constants used project-wide.

# -------------------------- HEADER -------------------------------------------

# ignore unused variable warnings (source'd script)
# shellcheck disable=SC2034

# -------------------------- CONSTANTS ----------------------------------------

declare -r PROJECT_NAME='pve-client'
declare -r SERVER_PVE_ROOT_CA='/etc/pve/pve-root-ca.pem'

# -------------------------- IMPORTS ----------------------------------------
# -------------------------- PRECONDITIONS ----------------------------------
# -------------------------- UTILITIES ----------------------------------------

# set the project environment variables
function set_env() {
	reset_checks
	check_file_exists DOTENV
	print_failed_checks --error || return

	# shellcheck source=.env
	source "$DOTENV"
}
readonly -f set_env

# common script setup tasks
function housekeeping() {
	set_env
}
readonly -f housekeeping

# -------------------------- ASSERTIONS ---------------------------------------

function assert_on_server() {
	reset_checks
	check_is_defined PVE_HOST
	print_failed_checks --error || exit

	assert_on_host "$PVE_HOST"
}
readonly -f assert_on_server

function assert_not_on_server() {
	reset_checks
	check_is_defined PVE_HOST
	print_failed_checks --error || exit

	assert_not_on_host "$PVE_HOST"
}
readonly -f assert_not_on_server

# -------------------------- CHECKS -------------------------------------------
