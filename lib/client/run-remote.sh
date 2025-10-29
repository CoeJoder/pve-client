#!/bin/bash

# run-remote.sh
# Securely deploy and execute server-side code on Proxmox host.
#
# Usage:
#   run-remote.sh [options] [remote_entry_script]
#
# Example:
#   run-remote.sh --non-interactive ./lib/server/some-task.sh
#
# Features:
#   - Auto-detects and bundles server scripts
#   - Deploys only when contents change (hash-based caching)
#   - Supports interactive and non-interactive modes
#
# See inline comments for the directory structure of the deployment.

set -eEo pipefail
shopt -s inherit_errexit
trap 'on_err' ERR

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
lib_dir="$(realpath "$this_dir/..")"
source "$this_dir/client-common.sh"
housekeeping

function show_usage() {
	cat >&2 <<-EOF
		Usage: $(basename "${BASH_SOURCE[0]}") <entry-script> [options]
		Options:
		--non-interactive   Disable SSH pseudo-terminal
		--verbose, -v       Change log-level to 'trace' (default: .env/BASHTOOLS_LOGLEVEL)
		--help, -h          Show this message
	EOF
}

_parsed_args=$(getopt \
	--options='h,v' \
	--longoptions='help,verbose,non-interactive' \
	--name "$(basename "${BASH_SOURCE[0]}")" -- "$@")
eval set -- "$_parsed_args"
unset _parsed_args

non_interactive=0

while true; do
	case "$1" in
	--non-interactive)
		non_interactive=1
		shift 1
		continue
		;;
	-v | --verbose)
		BASHTOOLS_LOGLEVEL='trace'
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

entry_script="$1"

# search local filesystem for files to deploy
function collect_files() {
	{
		# public shell scripts of external libs
		find "$EXT_BASH_TOOLS_SRC_DIR" -type f \( -name '*.sh' -a -not -name '_*.sh' \) -print0

		# public shell scripts run on server
		find "$LIB_SERVER_DIR" -type f \( -name '*.sh' -a -not -name '_*.sh' \) -print0

		# public shell scripts shared by client and server
		find "$lib_dir" -maxdepth 1 -mindepth 1 -type f \( -name '*.sh' -a -not -name '_*.sh' \) -print0

	} 2>/dev/null | sort -z
}

# package the deployment files and save to given location, and print the hash
function package_files() {
	local tmp_tar="$1"
	local files
	
	# Server deployment structure:
	# <temp>
	# ├── external/
	# │   └── bash-tools/
	# │       └──src/
	# │          └──bash-tools.sh
	# ├── server/
	# ├── global-common.sh
	# └── ...

	readarray -td '' files < <(collect_files)

	# package and tee it out
	# regex has leading slashes removed to match output of tar's default transformation
	tar -cf - \
		--transform "s|${LIB_SERVER_DIR#/}/\(.*\)|server/\1|" \
		--transform "s|${EXT_BASH_TOOLS_SRC_DIR#/}/\(.*\)|external/bash-tools/src/\1|" \
		--transform "s|${lib_dir#/}/\(.*\)|\1|" \
		"${files[@]}" 2>/dev/null | tee "$tmp_tar" | compute_hash
}

# computer the hash of a file from stdin
function compute_hash() {
	sha256sum | awk '{print $1}'
}

# Deploy server-side code if changed
function deploy_if_changed() {
	local tmp_tar="$1"
	local remote_dir="$2"
	local files

	if ssh -q "$PVE_SSH_HOST" "[[ -d '$remote_dir' ]]"; then
		log info "Reusing cached copy on host: $remote_dir"
	else
		log info "New changes detected!"
		log info "Preparing remote destination: $remote_dir"
		ssh -q "$PVE_SSH_HOST" "mkdir -p '$remote_dir'"
		log info "Uploading latest server scripts..."
		scp -q "$tmp_tar" "${PVE_SSH_HOST}:${remote_dir}/bundle.tar"
		log info "Extracting remote deployment..."
		ssh -q "$PVE_SSH_HOST" "
      cd '$remote_dir'
      tar -xf bundle.tar && rm bundle.tar
      chmod -R 700 .
    "
		rm -f "$tmp_tar"
	fi
}

# Execute the remote entrypoint
function execute_remote() {
	local remote_dir="$1"
	local entry_rel

	entry_rel=$(realpath --relative-to="$LIB_SERVER_DIR" "$entry_script")
	if (("$non_interactive")); then
		ssh -T "$PVE_SSH_HOST" "cd '$remote_dir/server' && bash '$entry_rel'"
	else
		ssh -t "$PVE_SSH_HOST" "cd '$remote_dir/server' && bash '$entry_rel'"
	fi
}

function main() {
	local hash
	local remote_dir
	local tmp_tar

	if [[ ! -f "$entry_script" ]]; then
		log error "Entry script not found: $entry_script"
		exit 1
	fi
	log info "Preparing local cache dir: $CLIENT_CACHE_DIR"
	mkdir -p "$CLIENT_CACHE_DIR"

	log info "Preparing deployment for host: $PVE_SSH_HOST"
	tmp_tar="${CLIENT_CACHE_DIR}/${hash}.tar"
	hash=$(package_files "$tmp_tar")
	remote_dir="${SERVER_CACHE_DIR}/${hash}"

	log info "Deploying to remote dir: $remote_dir"
	deploy_if_changed "$tmp_tar" "$remote_dir"

	log info "Executing script remotely: $entry_script"
	execute_remote "$remote_dir"
}

main "$@"
