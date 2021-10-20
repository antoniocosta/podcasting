#!/bin/bash

# Prepares a generated episode to be uploaded:
#   1. Moves merged mp3 from download subdir to one dir up
#   2. Cleans up tmp files from download subdir
#   3. Generates json from merged mp3 and episode config file
#
# Usage: ./prepare.sh [podcast.conf] [episode.conf]
# Requires:
#
# ------------------------------------------------------------------------

function print_usage {
    local msg="Generates a podcast mp3 episode from a Spotify playlist.
Usage: ./download.sh [podcast.conf] [episode.conf]
    printf "%s\n" "$msg"
    exit 127
}

[[ $# -lt 2 ]] && print_usage

source $1 # Include the podcast config file passed as argument
source $2 # Include the episode config file passed as argument

# ------------------------------------------------------------------------

echo "Starting..."

# 1. Move merged mp3 from download subdir to one dir up
mv $ARCHIVE_DIR'/'$EP_FILE $ARCHIVE_DIR # Move ep mp3 file one dir up (to the main download folder)

# 2. Clean up tmp files from download subdir
echo "Cleaning up..."
rm $ARCHIVE_DIR'/.spotdl-cache' # spot-dl auth file
rm $ARCHIVE_DIR'/tmp.txt' # The ffmpeg temp merge file
rm $ARCHIVE_DIR'/_cover.jpg' # The id3 cover image

# 3. Generate json from merged mp3 and episode config file
function print_json {
    local id=${EP_FILE%'.'$RSS_AUDIO_FORMAT} # Same as mp3 filename (minus extension)
    local title="$RSS_TITLE $ID3_TITLE"
    local timestamp=$(date -r "$EP_FILE" "+%s")
    local webpage_url=$RSS_LINK'/episode/'$EP_NUM
    # convert band names from m3u to / delimited single line. Ignore intro and outro (any line without ' -')
    local description=$(cat "$M3U_FILE" | sed '/ -/!d' | sed 's/ -.*//' | sed -e :a -e '$!N; s/\n/ \/ /; ta')
    local json_fmt='{"id": "%s", "title": "%s", "timestamp": %s, "webpage_url": "%s", "description": "%s"}\n'
    printf "$json_fmt" "$id" "$title" "$timestamp" "$webpage_url" "$description"
}
echo "Generating JSON..."
JSON_FILE=${EP_FILE%.mp3}.info.json # json filename from mp3 file
print_json > $ARCHIVE_DIR'/'$JSON_FILE

# Generate RSS. This project shares rss.sh with mixcloud2podcast as a symlink
###./rss.sh "$1"

echo 'All done.'
