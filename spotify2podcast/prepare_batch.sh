#!/bin/bash

# Utility to batch prepares multiple generated audio file episodes to be uploaded
# Usage: ./prepare_batch.sh [../path/to/dir]
# Requires:
# prepare.sh (prepares a single file episode)
#
# TODO: 
# - Broken! Change prepare.sh to support audio file as 2nd param
# ------------------------------------------------------------------------

function print_usage {
    local msg="Utility to batch prepares multiple generated audio file episodes to be uploaded
Usage: ./prepare_batch.sh [../path/to/dir]
Requires: ia"
    printf "%s\n" "$msg"
    exit 127
}

[[ $# = 0 ]] && print_usage

# ------------------------------------------------------------------------

# File path where the audio and json metadata files have been saved
ARCHIVE_DIR=$1