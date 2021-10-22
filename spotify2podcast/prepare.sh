#!/bin/bash

# Prepares a generated audio file episode to be uploaded:
#   1. Moves merged mp3 from download subdir to one dir up (if not already there)
#   2. Cleans up tmp files from download subdir
#   3. Generates json from merged mp3 and episode config file
#
# Usage: ./prepare.sh podcast.conf ./full/path/audio_file.ext 
# Requires: None
# ------------------------------------------------------------------------

function print_usage {
    local msg="Prepares a generated audio file episode to be uploaded
Usage: ./prepare.sh podcast.conf ./full/path/audio_file.ext"
    printf "%s\n" "$msg"
    exit 127
}

[[ $# -lt 2 ]] && print_usage

source $1 # Include the podcast config file passed as argument

# ------------------------------------------------------------------------
echo "Starting `basename "$0"`..."

# Calculate necessary variables just from audio filename

audio_file=$2 # 2nd argument is the file to upload
audio_file_ext="${audio_file##*.}" # just the extension (without dot). Example: mp3
audio_file_basename=$(basename "$audio_file" ".$audio_file_ext") # Just the filename without path or extension. Example: all-my-favorite-songs-001-weezer
audio_file_ep_num=$(echo $audio_file_basename | sed 's/[^0-9]*//g') # Just the episode num (with trailing zeros) Example: 001
audio_file_before_num=$(echo $audio_file_basename | sed 's/[0-9].*//' | sed 's/\(.*\)-/\1/') # Remove rest of string after number AND remove last occurence of dash. Example: all-my-favorite-songs . See: https://unix.stackexchange.com/questions/257514/how-to-delete-the-rest-of-each-line-after-a-certain-pattern-or-a-string-in-a-fil and https://unix.stackexchange.com/questions/187889/how-do-i-replace-the-last-occurrence-of-a-character-in-a-string-using-sed
ep_config_filename=$audio_file_before_num'-ep-'$audio_file_ep_num'.conf' # the episode config filename. Example: all-my-favorite-songs-ep-001.conf)
#echo $audio_file_ext
#echo $audio_file_basename
#echo $audio_file_ep_num
#echo $audio_file_before_num
#echo $ep_config_filename
source $ep_config_filename # Include the episode config file (as deducted from mp3 filename)

# Do the actual work

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
echo "Generating JSON..."
function print_json {
    local id=${EP_FILE%'.'$RSS_AUDIO_FORMAT} # Same as mp3 filename (minus extension)
    local title="$RSS_TITLE $ID3_TITLE"
    #local timestamp=$(date -r "$EP_FULLPATH" "+%s") # Use file timestamp
    if [ "$(uname)" == "Darwin" ]; then # Mac OS X platform 
        local timestamp=$(date -j -u -f "%Y/%m/%d %H:%M:%S" "$EP_PUBDATE" "+%s") # Use hardcoded date
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then # GNU/Linux platform
        local timestamp=$(date -d "$EP_PUBDATE" +"%s") # Use hardcoded date
    fi
    local webpage_url=$RSS_LINK'/episode/'$EP_NUM
    local description=$EP_DESCRIPTION
    # convert band names from m3u to / delimited single line. Ignore intro and outro (any line without ' -')
#    local description=$EP_DESCRIPTION" <br /> <br /> Lineup:<br /> "$(cat "$M3U_FILE" | sed '/ -/!d' | sed 's/ -.*//' | sed -e :a -e '$!N; s/\n/ \/ /; ta')
    local artist=$(cat "$M3U_FILE" | sed '/ -/!d' | sed 's/ -.*//' | sed -e :a -e '$!N; s/\n/, /; ta')
    local json_fmt='{\n"id": \n"%s", \n"title": "%s", \n"timestamp": %s, \n"webpage_url": "%s", \n"description": "%s", \n"artist": "%s"\n}'
    printf "$json_fmt" "$id" "$title" "$timestamp" "$webpage_url" "$description" "$artist"
}
M3U_FILE=$(find $ARCHIVE_DIR'/'$EP_SUBDIR -type f -name "*.m3u") # Works but only if find command will return exactly 1 file
echo "Episode info.json saved: $M3U_FILE"
JSON_FILE=${EP_FILE%.mp3}.info.json # json filename from mp3 file
print_json > $ARCHIVE_DIR'/'$JSON_FILE

# Generate RSS. This project shares rss.sh with mixcloud2podcast as a symlink
# ./rss.sh "$1"

echo "All done with `basename "$0"`."

