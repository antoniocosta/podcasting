#!/bin/bash

# Prepares a generated audio file episode to be uploaded:
#   1. Moves merged mp3 from download subdir to one dir up
#   2. Cleans up tmp files from download subdir
#   3. Generates json from merged mp3 and episode config file
#
# Usage: ./prepare.sh [podcast.conf] [./full/path/audio_file.ext]
# Requires:
#
# TODO:
# - Use audio file as 2nd param instead of ep config file (for consistency with upload.sh)
# ------------------------------------------------------------------------

function print_usage {
    local msg="Prepares a generated audio file episode to be uploaded
Usage: ./prepare.sh [podcast.conf] [episode.conf]"
    printf "%s\n" "$msg"
    exit 127
}

[[ $# -lt 2 ]] && print_usage

source $1 # Include the podcast config file passed as argument

#source $2 # Include the episode config file passed as argument

# ------------------------------------------------------------------------

echo "Starting..."

audio_file=$2 # 2nd argument is the file to upload
audio_file_ext="${audio_file##*.}" # just the extension (without dot)
audio_file_basename=$(basename "$audio_file" ".$audio_file_ext") # Just the filename without path or extension
audio_file_ep_num=$(echo $audio_file | sed 's/[^0-9]*//g') # Just the episode num (with trailing zeros: 001)

echo $audio_file_ext
echo $audio_file_basename
echo $audio_file_ep_num


echo 'All done.'
