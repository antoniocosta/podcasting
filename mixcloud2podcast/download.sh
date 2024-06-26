#!/bin/bash

# Downloads all m4a and json metadata for a mixcloud playlist or user
#	1. Downloads all m4a and json metadata for a mixcloud playlist or user
#	2. uploads mp4a to the internet archive 
#	3. Generates podcast rss file
#
# Usage: ./download.sh podcast.conf
# Requires:
# brew install youtube-dl (to download files from mixcloud)
# brew install ffmpeg
# brew install internetarchive (Internet Archive's command line interface)
# ia configure (configure ia with your credentials)
#
# TODO:
# Add publish.sh so it gets actually published to website
# ------------------------------------------------------------------------

function print_usage {
    local msg="Converts closed mixcloud to open podcast format.
Usage: ./download.sh podcast.conf
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

# ------------------------------------------------------------------------

# If there are new files on mixcloud it will...
#   1. download each file 
#   2. upload each file to the Internet Archive
#   3. generate rss 

echo "Starting `basename $0`..."

# Count the number of files in archive dir
archive_file_count=$(ls -1q $ARCHIVE_DIR | wc -l | sed 's/ //g')

# Download and upload each file
#youtube-dl --simulate \
#youtube-dl \ # deprecated Apr 1, 2024
yt-dlp \
--audio-format best \
-f 'bestaudio[ext=m4a]' \
--download-archive $ARCHIVE_FILE \
-o $ARCHIVE_DIR/'%(id)s.%(ext)s' \
--write-info-json \
--add-metadata \
--exec "./upload.sh $1 {}" \
$MIXCLOUD_URL

# Generate rss (expensive) but only if there are new files. Also pushes to git.
if [ "$archive_file_count" != $(ls -1q $ARCHIVE_DIR | wc -l | sed 's/ //g') ] ; then
	echo "Number of files in archive dir changed. Regenerating RSS..."
	./rss.sh "$1"
fi


# Notes:

# To only list formats:
# --list-formats 

# Removed because this would force expensive rss regeneration for every download 
# --exec "./upload.sh $1 {} && ./rss.sh $1" \

# disabled because not working on linux for some reason
# --embed-thumbnail \ 
# Requires:
# brew install atomicparsley (if you want thumbnail to be embedded into m4a file)

echo "All done with `basename $0`."

