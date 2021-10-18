#!/bin/bash

# Utility to batch upload multiple mixcloud .m4a files to the Internet Archive
#
# Usage: ./upload_batch.sh [../full/path/m4adir]
# Requires:
# upload.sh (uploads a single file)
# ------------------------------------------------------------------------

function print_usage {
    local msg="Utility to batch upload multiple mixcloud .m4a files to the internet archive
Usage: ./upload_batch.sh [../full/path/m4adir]
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

[[ $# = 0 ]] && print_usage
requirements

# ------------------------------------------------------------------------
# File path where the audio and json metadata files have been saved
#ARCHIVE_DIR=../docs/just-a-blip/downloads
ARCHIVE_DIR=$1


IFS=$'\n' # newline as the delimiter
arr_m4a=( $(ls -r "$ARCHIVE_DIR"/*.m4a) )
items_total=$(ls "$ARCHIVE_DIR"/*.m4a | wc -l | tr -d ' ')
echo "Uploading $items_total items..."
item_num=0
for m4a in "${arr_m4a[@]}"; do
        let item_num+=1
        echo "Uploading item $item_num/$items_total"
        # $m4a is the audio file (full path)
#        echo "upload $m4a"
        ./upload.sh $m4a
done
echo "All files uploaded."
exit