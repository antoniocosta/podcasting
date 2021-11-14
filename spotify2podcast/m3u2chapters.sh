#!/bin/bash

# Utility to generate ffmpeg chapter metadata file from an m3u playlist
#
# Usage: ./m3u2chapters.sh podcast.conf episode.conf
# Requires: mediainfo
# ------------------------------------------------------------------------

function print_usage {
    local msg="Generates ffmpeg chapter metadata for an episode
Usage: ./m3u2chapters.sh podcast.conf episode.conf"
    printf "%s\n" "$msg"
    exit 127
}

function requirements {
    for p in mediainfo; do
        if [[ -z $(command -v $p) ]]; then
            echo "$p is not installed"
            exit 1
        fi
    done
}

[[ $# -lt 2 ]] && print_usage
requirements

source $1 # Include the podcast config file passed as argument
source $2 # Include the episode config file passed as argument

# ------------------------------------------------------------------------
echo "Starting `basename $0`..."

# References:
# https://medium.com/@dathanbennett/adding-chapters-to-an-mp4-file-using-ffmpeg-5e43df269687
# https://ffmpeg.org/ffmpeg-formats.html#Metadata-1

M3U_FILE=$(find $ARCHIVE_DIR'/'$EP_SUBDIR -type f -name "*.m3u") # Works but only if find command will return only one file
metadata_file=$ARCHIVE_DIR'/'$EP_SUBDIR'/'_ffmetadata.txt

# Metadata keys or values containing special characters (‘=’, ‘;’, ‘#’, ‘\’ and a newline) must be escaped with a backslash ‘\’. See:  https://ffmpeg.org/ffmpeg-formats.html#Metadata-1
# Escape =;#\ chars
echo ";FFMETADATA1
title=$(echo "$ID3_TITLE" | sed 's/[=;#\]/\\&/g')
artist=$(echo "$ID3_ARTIST" | sed 's/[=;#\]/\\&/g')
comment=$(echo "$ID3_DESC" | sed 's/[=;#\]/\\&/g')
description=$(echo "$ID3_DESC" | sed 's/[=;#\]/\\&/g')
date=$ID3_YEAR" > $metadata_file

total_duration=0
item_num=0
items_total=$(cat "$M3U_FILE" | wc -l) # total number of lines in m3u playlist

while read mp3; do # reading each line
	let item_num+=1
	echo -ne "Adding chapter metadata for mp3 $item_num/$items_total"\\r
	mp3_without_extension="${mp3%.*}"
	# Buggy! Disabled. Because mp3info only return seconds the missing millisendds add up to a lot in long playlists
	#mp3_duration_seconds=$(mp3info -p %S $ARCHIVE_DIR'/'$EP_SUBDIR'/'"$mp3")
	#mp3_duration_milliseconds=$(($mp3_duration_seconds * 1000))
	# use mediainfo instead
	mp3_duration_milliseconds=$(mediainfo --Inform="Audio;%Duration%" $ARCHIVE_DIR'/'$EP_SUBDIR'/'"$mp3")
	echo '' >> $metadata_file
	echo '[CHAPTER]' >> $metadata_file
	echo 'TIMEBASE=1/1000' >> $metadata_file
	echo 'START='$total_duration >> $metadata_file
	total_duration=$((total_duration + $mp3_duration_milliseconds - 50)) # Remove 50 ms per song to adjust because ffmpeg seems to add about 50 ms per song (correct value, tested on playlist with about 60 songs)
	echo 'END='$((total_duration - 1 )) >> $metadata_file # remove 1 milisecond. Durations cannot overlap.
	if [[ "$mp3_without_extension" == '_intro' ]]; then
		mp3_without_extension='Intro'
	elif [[ "$mp3_without_extension" == '_outro' ]]; then
		mp3_without_extension='Outro'
	fi

	mp3_without_extension=$(echo "$mp3_without_extension" | sed 's/[=;#\]/\\&/g') # Escape =;#\ chars
	mp3_without_extension=${mp3_without_extension:0:220} # Limit to 220 chars or less. This is important ! 224 breaks it
	echo 'title='$mp3_without_extension'' >> $metadata_file
done < "$M3U_FILE" 

# Escape =;#\ chars
echo '
[STREAM]
title='$(echo "$ID3_TITLE" | sed 's/[=;#\]/\\&/g') >> $metadata_file

echo ''
echo "All done with `basename $0`."


