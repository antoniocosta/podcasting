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
Usage: ./download.sh [podcast.conf] [episode.conf]"
    printf "%s\n" "$msg"
    exit 127
}

[[ $# -lt 2 ]] && print_usage

source $1 # Include the podcast config file passed as argument
source $2 # Include the episode config file passed as argument

# ------------------------------------------------------------------------

echo "Starting..."

if [ -f $ARCHIVE_DIR'/'$EP_FILE ]; then
    EP_FULLPATH=$ARCHIVE_DIR'/'$EP_FILE
elif [ -f $ARCHIVE_DIR'/'$EP_SUBDIR'/'$EP_FILE ]; then
    EP_FULLPATH=$ARCHIVE_DIR'/'$EP_SUBDIR'/'$EP_FILE

    # 1. Move merged mp3 from download subdir to one dir up
    mv $EP_FULLPATH $ARCHIVE_DIR # Move ep mp3 file one dir up (to the main download folder)
    EP_FULLPATH=$ARCHIVE_DIR'/'$EP_FILE
else
    echo "ERROR: Mp3 episode file $EP_FILE not found in $ARCHIVE_DIR or $EP_SUBDIR subdir"
    echo "Exiting!"
    exit
fi
echo "Episode mp3 found: $EP_FULLPATH"

# 2. Clean up tmp files from download subdir
echo "Cleaning up..."
rm -f $ARCHIVE_DIR'/'$EP_SUBDIR'/.spotdl-cache' # Remove spot-dl auth file (dont show error if doesnt exist)
rm -f $ARCHIVE_DIR'/'$EP_SUBDIR'/tmp.txt' # Remove ffmpeg temp merge file (dont show error if it doenst exist)

# 3. Generate json from merged mp3 and episode config file
function print_json {
    local id=${EP_FILE%'.'$RSS_AUDIO_FORMAT} # Same as mp3 filename (minus extension)
    local title="$RSS_TITLE $ID3_TITLE"
    #local timestamp=$(date -r "$EP_FULLPATH" "+%s") # Use file timestamp
    if [ "$(uname)" == "Darwin" ]; then # Mac OS X platform 
        local timestamp=$(date -j -u -f "%Y/%m/%d %H:%M:%S" "2021/10/20 12:34:56" "+%s")
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then # GNU/Linux platform
        local timestamp=$(date -d '2021/10/20 12:34:56' +"%s")
    fi
    local webpage_url=$RSS_LINK'/episode/'$EP_NUM
    local description=$EP_DESCRIPTION
    # convert band names from m3u to / delimited single line. Ignore intro and outro (any line without ' -')
#    local description=$EP_DESCRIPTION" <br /> <br /> Lineup:<br /> "$(cat "$M3U_FILE" | sed '/ -/!d' | sed 's/ -.*//' | sed -e :a -e '$!N; s/\n/ \/ /; ta')
    local artist=$(cat "$M3U_FILE" | sed '/ -/!d' | sed 's/ -.*//' | sed -e :a -e '$!N; s/\n/, /; ta')
    local json_fmt='{"id": "%s", "title": "%s", "timestamp": %s, "webpage_url": "%s", "description": "%s", "artist": "%s"}\n'
    printf "$json_fmt" "$id" "$title" "$timestamp" "$webpage_url" "$description" "$artist"
}
echo "Generating JSON..."
M3U_FILE=$(find $ARCHIVE_DIR'/'$EP_SUBDIR -type f -name "*.m3u") # Works but only if find command will return exactly 1 file
echo "Episode m3u found: $M3U_FILE"
JSON_FILE=${EP_FILE%.mp3}.info.json # json filename from mp3 file
print_json > $ARCHIVE_DIR'/'$JSON_FILE

# Generate RSS. This project shares rss.sh with mixcloud2podcast as a symlink
# ./rss.sh "$1"

echo 'All done.'
