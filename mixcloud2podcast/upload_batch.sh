#!/bin/bash

# Utility to batch upload multiple files (audio+json pairs) to the Internet Archive
#
# Usage: ./upload_batch.sh podcast.conf ../path/to/audio/file/dir
# Requires:
# upload.sh (uploads a single file)
#
# TODO:
# - Broken! Need to pass podcast.conf to upload.sh for this to work
# ------------------------------------------------------------------------

function print_usage {
    local msg="Utility to batch upload multiple files (audio+json pairs) to the internet archive
Usage: ./upload_batch.sh podcast.conf ../path/to/audio/file/dir
Requires: ia"
    printf "%s\n" "$msg"
    exit 127
}

function requirements {
        for p in ia; do 
            if [[ -z $(command -v $p) ]]; then
                echo "$p is not installed"
                exit 1
            fi
        done 
}

[[ $# -lt 2 ]] && print_usage
requirements

source $1 # Include the podcast config file passed as argument


# ------------------------------------------------------------------------
echo "Starting `basename "$0"`..."

IFS=$'\n' # newline as the delimiter
arr_audio_files=( $(ls -r "$ARCHIVE_DIR"/*."$RSS_AUDIO_FORMAT") )
items_total=$(ls "$ARCHIVE_DIR"/*."$RSS_AUDIO_FORMAT" | wc -l | tr -d ' ')
echo "Uploading $items_total items..."
item_num=0
for audio_file in "${arr_audio_files[@]}"; do
        let item_num+=1
        echo "Uploading item $item_num/$items_total"
        # $m4a is the audio file (full path)
#        echo "upload $m4a"
        ./upload.sh $1 $audio_file
done
echo "All done with `basename "$0"`."
exit
