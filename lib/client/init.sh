#!/bin/bash

# init.sh
#
# Initializes the current shell with the project vars and functions.
#
# This script must be sourced, not executed directly.

source "$(realpath "$(dirname "${BASH_SOURCE[0]}")")/client-commons.sh"
set_env

# -------------------------- HEADER -------------------------------------------

# -------------------------- PRECONDITIONS ------------------------------------

assert_sourced

# -------------------------- BANNER -------------------------------------------

# -------------------------- PREAMBLE -----------------------------------------

# -------------------------- RECONNAISSANCE -----------------------------------

# -------------------------- EXECUTION ----------------------------------------

# -------------------------- POSTCONDITIONS -----------------------------------

printinfo "Shell has been initialized with project vars and functions."
