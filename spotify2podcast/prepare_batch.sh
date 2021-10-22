#!/bin/bash

# Utility to batch prepares multiple generated audio file episodes to be uploaded
# Usage: ./prepare_batch.sh podcast.conf ../path/to/audio/file/dir
# Requires:
# prepare.sh (prepares a single file episode)
#
# ------------------------------------------------------------------------

function print_usage {
    local msg="Utility to batch prepares multiple generated audio file episodes to be uploaded
Usage: ./prepare_batch.sh podcast.conf ../path/to/audio/file/dir
Requires: ia"
    printf "%s\n" "$msg"
    exit 127
}

[[ $# -lt 2 ]] && print_usage

source $1 # Include the podcast config file passed as argument

# ------------------------------------------------------------------------
echo "Starting `basename "$0"`..."

IFS=$'\n' # newline as the delimiter
arr_audio_files=( $(ls -r "$ARCHIVE_DIR"/*."$RSS_AUDIO_FORMAT") )
items_total=$(ls "$ARCHIVE_DIR"/*."$RSS_AUDIO_FORMAT" | wc -l | tr -d ' ')
echo "Preparing $items_total items..."
item_num=0
for audio_file in "${arr_audio_files[@]}"; do
        let item_num+=1
        echo "Preparing item $item_num/$items_total"
        # $audio_file is the audio file (full path)
#        echo "Prepare $audio_file"
        ./prepare.sh $1 $audio_file
done
echo "All files prepared."
exit
