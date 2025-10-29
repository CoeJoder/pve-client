#!/bin/bash

# create-env.sh
#
# Generates an editable file containing the project's environment variables.

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/client-common.sh"

# -------------------------- PRECONDITIONS ------------------------------------

reset_checks
check_is_defined DOTENV
print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Generates the project's environment variables at ${theme_filename}$DOTENV${color_reset}
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

# confirm overwrite
if [[ -f $DOTENV ]]; then
	printwarn "Found existing ${theme_filename}$DOTENV${color_reset}"
	yes_or_no --default-no "Overwrite?" || exit
fi
printinfo "Generating new ${theme_filename}$DOTENV${color_reset}...\n"

# -------------------------- EXECUTION ----------------------------------------

printinfo "Enter the values to use when accessing the PVE host CLI and REST API"

declare bashtools_loglevel
choose_from_menu "Select log level" bashtools_loglevel "${_BASHTOOLS_LOGLEVELS_KEYS[@]}"

declare pve_host
read_no_default "PVE host" pve_host

declare pve_port
read_default "PVE port" '8006' pve_port

declare pve_node
read_default "PVE node" 'pve' pve_node

declare pve_user
read_default "PVE user" 'root' pve_user

declare pve_realm
read_default "PVE realm" 'pam' pve_realm

printf '\n'
printinfo "Enter the values to use when generating the REST API token"

declare pve_token_id
read_default "PVE API token ID" 'auto' pve_token_id

declare pve_token_ttl_days
read_default "PVE API token TTL days" '1' pve_token_ttl_days

declare pve_token_path
read_default "PVE API token path" '/' pve_token_path

declare pve_token_roles
read_default "PVE API token roles" 'PVEAuditor' pve_token_roles

declare pve_token_propagate
read_default "PVE API token propagate" '1' pve_token_propagate

printf '\n'
printinfo "Generating ${theme_filename}$DOTENV${color_reset}:"

cat <<EOF | tee "$DOTENV"
# .env
#
# Environment variables used by \`pve-client\` client scripts.

# -------------------------- CONFIGURABLE; EDIT AS NEEDED ---------------------

# the log-level used by default in all scripts
BASHTOOLS_LOGLEVEL='$bashtools_loglevel'

# used when accessing PVE host CLI (SSH) and REST API (HTTP)
PVE_HOST='$pve_host'
PVE_PORT='$pve_port'
PVE_NODE='$pve_node'
PVE_USER='$pve_user'
PVE_REALM='$pve_realm'

# used when generating the API token
PVE_API_TOKEN_ID='$pve_token_id'
PVE_API_TOKEN_TTL_DAYS='$pve_token_ttl_days'
PVE_API_TOKEN_PATH='$pve_token_path'
PVE_API_TOKEN_ROLES='$pve_token_roles'
PVE_API_TOKEN_PROPAGATE='$pve_token_propagate'

# -------------------------- NON-CONFIGURABLE; DO NOT EDIT --------------------

PVE_SSH_HOST="\${PVE_USER}@\${PVE_HOST}"
PVE_SSL_HOST="\${PVE_HOST}:\${PVE_PORT}"

EOF

# -------------------------- POSTCONDITIONS -----------------------------------

reset_checks
check_file_exists DOTENV
if ! print_failed_checks --error; then
	printerr "try creating the file manually or running the script again"
	exit 1
fi

cat <<EOF
Success!  Generated ${theme_filename}$DOTENV${color_reset}
EOF
