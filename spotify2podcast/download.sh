#!/bin/bash

# Generates a podcast mp3 episode from a Spotify playlist
#   1. Downloads all mp3s using Spotdl
#   2. converts m3u playlist to one big mp3
#   3. Adds an intro and outro and mp3 id3 metadata too
#
# Usage: ./download.sh [podcast.conf] [episode.conf]
# Requires: 
# python3 -m pip install --user pipx && python3 -m pipx ensurepath
# brew install ffmpeg
# brew install eye-d3
# brew install internetarchive (Internet Archive's command line interface)
# ia configure (configure ia with your credentials)
#
# TODO: 
# - Add path to spotdl with -o option
# - Add external config file (see https://github.com/Flowm/spotify-api-bash/blob/master/create_playlist_from_artists_list.sh)
# ------------------------------------------------------------------------

function print_usage {
    local msg="Generates a podcast mp3 episode from a Spotify playlist.
Usage: ./download.sh [podcast.conf] [episode.conf]
Requires: 'pipx run spotdl' ffmpeg eyeD3 jq ia"
    printf "%s\n" "$msg"
    exit 127
}

function requirements {
    for p in 'pipx run spotdl' ffmpeg eyeD3 jq ia; do 
        if [[ -z $(command -v $p) ]]; then
            echo "$p is not installed"
            exit 1
        fi
    done 
}

[[ $# != 2 ]] && print_usage
requirements

source $1 # Include the podcast config file passed as argument
source $2 # Include the episode config file passed as argument

# ------------------------------------------------------------------------

echo "Starting..."

function get_tts { # generate ttsmp3.com mp3 file from text
    local opts=( 
    --silent
    -H 'Content-type: application/x-www-form-urlencoded'
    -H 'Accept: */*'
    -H 'Origin: https://ttsmp3.com'
    -H 'Referer: https://ttsmp3.com/'
    --data-raw "msg=$1&lang=$TTS_LANG&source=ttsmp3"
    --compressed
    )
    local tts_url=$(curl "${opts[@]}" 'https://ttsmp3.com/makemp3_new.php' | jq -r '.URL' ) # mp3 file url
    echo "Downloading tts from $tts_url as $2 with curl" 
    curl --silent -L --output "$2" $tts_url # download mp3
    echo "Converting $INTRO_MP3 to higher quality with ffmpeg..."
    # convert to higher frequency, bitrate and (from mono) to stereo
    ffmpeg -hide_banner -loglevel error -i "$2" -b:a 256k -ar 48000 -af "pan=stereo|c0=c0|c1=c0" tmp.mp3 && mv tmp.mp3 "$2"
}

cd "$ARCHIVE_DIR" # every command from here forward is relative to this
if [ ! -d "$EP_SUBDIR" ]; then # create dir (to hold all downloaded mp3s) if it doesn't exist already
  mkdir -p "$EP_SUBDIR"
fi
cd "$EP_SUBDIR" # every command from here forward is relative to this

# Download all mp3s from a Spotify playlist
echo "Downloading all playlist's songs with spotdl"
pipx run spotdl $SPOTIFY_PLAYLIST_URL -o . --m3u
#pipx run spotdl $SPOTIFY_PLAYLIST_URL -o "mp3" --m3u

if [ "$M3U_RENAME" = true ] ; then
    find . -type f -name '*.m3u' -exec mv {} "$M3U_FILE" \; # rename m3u to fixed name
    echo "Renamed playlist to $M3U_FILE"
else
    M3U_FILE=$(find . -type f -name "*.m3u") # Works but only if find command will return exactly 1 file
    M3U_FILE=$(basename -- "$M3U_FILE")
    echo "Playlist filename is $M3U_FILE"
fi

# Generate intro and outro mp3s
if [[ ! -e "$INTRO_MP3" ]]; then # $INTRO_MP3 does not exist?
    get_tts "$TTS_INTRO" "$INTRO_MP3" # generate
fi
if [[ ! -e "$OUTRO_MP3" ]]; then # $OUTRO_MP" does not exist?
    get_tts "$TTS_OUTRO" "$OUTRO_MP3" # generate 
fi

# Prepend intro mp3 to beginning of m3u but only if it's not there already (uses tmp file). Ref: https://stackoverflow.com/questions/54365/shell-one-liner-to-prepend-to-a-file?page=1&tab=votes#tab-top
grep -qxF "$INTRO_MP3" "$M3U_FILE" || (echo "$INTRO_MP3" | cat - "$M3U_FILE" > tmp.txt && mv tmp.txt "$M3U_FILE")
# Append outro mp3 to end of m3u but only if it's not there already. Ref: https://stackoverflow.com/questions/3557037/appending-a-line-to-a-file-only-if-it-does-not-already-exist
grep -qxF "$OUTRO_MP3" "$M3U_FILE" || echo "$OUTRO_MP3" >> "$M3U_FILE"  

function normalize_all_names {
    echo "Normalizing all names..."
    # Replaces anything that isn't a letter, number, space, period, underscore, or dash with nothing
    # See: https://stackoverflow.com/questions/27232839/how-to-rename-a-bunch-of-files-to-eliminate-quote-marks
    # See: https://serverfault.com/questions/348482/how-to-remove-invalid-characters-from-filenames
    # Rename all mp3 files
    for f in *.mp3; do mv --force -i "$f" "${f//[^A-Za-z0-9[:space:]._-]}"; done
    # Rename all string in m3u
    sed -i 's/[^A-Za-z0-9[:space:]._-]//g' "$M3U_FILE"
}
# BUGGY... disabled
#normalize_all_names

function merge_audio {
    # Create txt file from m3u in format ffmpeg concat expects
    while read -r line; do 
        # replace single quote (ex: O'Connor with O'\''Connor) so ffmpeg doesn't fail 
        # ref: https://ffmpeg.org/ffmpeg-formats.html#Examples
        # ref: https://askubuntu.com/questions/648759/replace-with-sed-a-character-with-backslash-and-use-this-in-a-variable
        line=$(echo $line | sed 's/'\''/&\\&&/g')
        echo "file '$line'"; 
    done < "$M3U_FILE" > tmp.txt 

    # Merge (same codec) mp3 files using ffmpeg concat using tmp txt file as input and then get rid of txt file
    # ref: https://superuser.com/questions/314239/how-to-join-merge-many-mp3-files
    # ref: https://trac.ffmpeg.org/wiki/Concatenate#samecodec
    echo "Merging all playlist's songs as $EP_FILE with ffmpeg..."
    ffmpeg -hide_banner -y -f concat -safe 0 -i ./tmp.txt -b:a 256k -ar 48000 \
    "$EP_FILE"    

    # get the cover art
    if [[ ! -e '_cover.jpg' ]]; then # _cover.jpg does not exist?
        curl --silent -L -o '_cover.jpg' $ID3_COVER # download it
    fi
    # add cover art and other id3 data
    eyeD3 --add-image '_cover.jpg:FRONT_COVER' "$EP_FILE" \
    --title "$ID3_TITLE" \
    --artist "$ID3_ARTIST" \
    --comment "$ID3_DESC" \
    --release-year "$ID3_YEAR"
}
merge_audio

function print_json {
    echo "Generating JSON..."
    local id=${EP_FILE%.mp3}
    local title="$RSS_TITLE $ID3_TITLE"
    local timestamp=$(date -r "$EP_FILE" "+%s")
    local webpage_url=$RSS_LINK'/episode/'$EP_NUM
    local description=''

    local json_fmt='{"id": "%s", "title": "%s", "timestamp": %s, "webpage_url":"%s", "description":"%s"}\n'
    printf "$json_fmt" "$id" "$title" "$timestamp" "$webpage_url" "$description"
}

JSON_FILE=${EP_FILE%.mp3}.info.json # json filename from mp3 file
print_json > $JSON_FILE

# Cleanup
echo "Cleaning up..."
rm -rf '.spotdl-cache' # spot-dl auth file
#rm 'tmp.txt' # The ffmpeg temp merge file
rm '_cover.jpg' # The id3 cover image
mv $EP_FILE '../' # Move ep mp3 file one dir up (to the main download folder)
mv $JSON_FILE '../' # Move json file one dir up (to the main download folder)

# Change back from episode subdir to our project main dir
cd ../../../../spotify2podcast
# Generate RSS. This project shares rss.sh with mixcloud2podcast as a symlink
./rss.sh "$1"

echo 'All done.'

