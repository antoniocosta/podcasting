#!/bin/bash

# Downloads all m4a and json metadata for a mixcloud playlist or user
#	1. Downloads all m4a and json metadata for a mixcloud playlist or user
#	2. uploads mp4a to the internet archive 
#	3. Generates podcast rss file
#
# Usage: ./download.sh [mixcloud2podcast.conf]
# Requires:
# brew install youtube-dl (to download files from mixcloud)
# brew install atomicparsley (so thumbnail can be embedded into m4a file)
# ------------------------------------------------------------------------

function print_usage {
    local msg="Converts closed mixcloud to open podcast format.
Usage: ./download.sh [mixcloud2podcast.conf]
Requires: youtube-dl ffmpeg jq ia"
    printf "%s\n" "$msg"
    exit 127
}

function requirements {
	for p in youtube-dl ffmpeg jq ia; do 
	    if [[ -z $(command -v $p) ]]; then
	        echo "$p is not installed"
	        exit 1
	    fi
	done 
}

[[ $# = 0 ]] && print_usage
requirements

source $1 # Include the config file passed as argument

# Don't edit below this line unless you know what you are doing.
# ------------------------------------------------------------------------

# If there are new files on mixcloud it will...
#   1. download each file 
#   2. upload each file to the Internet Archive
#   3. generate rss 

echo "starting..."

# count the number of files in archive dir
archive_file_count=$(ls -1q $ARCHIVE_DIR | wc -l | sed 's/ //g')

echo $archive_file_count
echo $MIXCLOUD_URL

# Download and upload each file
#youtube-dl \
youtube-dl --simulate \
--audio-format best \
--download-archive $ARCHIVE_FILE \
-o $ARCHIVE_DIR/'%(id)s.%(ext)s' --write-info-json \
--add-metadata \
$MIXCLOUD_URL

# --exec "./upload.sh $1 {}" \

# Generate rss (expensive) but only if there are new files
if [ "$archive_file_count" != $(ls -1q $ARCHIVE_DIR | wc -l | sed 's/ //g') ] ; then
	echo "Nmber of files in archive dir changed. Regenerating RSS..."
	./rss.sh "$1"
fi

# Removed because this would force expensive rss regeneration for every download 
# --exec "./upload.sh $1 {} && ./rss.sh $1" \

# disabled because not working on linux for some reason
# --embed-thumbnail \ 

