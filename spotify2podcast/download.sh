#!/bin/bash

# Generates a podcast mp3 episode from a Spotify playlist
#   1. Downloads all mp3s using Spotdl
#   2. Generates intro and outro mp3 files using text to speech service
#   3. Merges all mp3s in a m3u playlist to one big mp3
#   4. Adds id3 metadata to merged mp3
#   5. Adds chapter metadata to merged mp3
#
# Usage: ./download.sh podcast.conf episode.conf
# Requires:
# python3 -m pip install --user pipx && python3 -m pipx ensurepath
# brew install ffmpeg
# brew install eye-d3
# brew install internetarchive (Internet Archive's command line interface)
# ia configure (configure ia with your credentials)
#
# TODO:
# - Make so that if an .m3u exists in folder we don't download it again (might not be possible with spotDL)
# ------------------------------------------------------------------------

function print_usage {
    local msg="Generates a podcast mp3 episode from a Spotify playlist.
Usage: ./download.sh podcast.conf episode.conf
Requires: 'pipx run spotdl' ffmpeg eyeD3 jq ia imagemagick"
    printf "%s\n" "$msg"
    exit 127
}

function requirements {
    for p in 'pipx run spotdl' ffmpeg eyeD3 jq ia convert; do
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

# Utility function to generate intro and outro mp3 files using text to speech service
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
    echo "Converting $2 to higher quality with ffmpeg..."
    # convert to higher frequency, bitrate and (from mono) to stereo
    ffmpeg -hide_banner -loglevel error -i "$2" -b:a $BITRATE'k' -ar 48000 -af "pan=stereo|c0=c0|c1=c0" tmp.mp3 && mv tmp.mp3 "$2"
}

# Step 1 function
#Downloads all mp3s and m3u using Spotdl (if configured it also renames m3u)
function download_playlist {
    read -p "Type 'Y' to confirm download of all mp3s and m3u from Spotify. Skip with 'Return' or 'N' (in case you edited m3u). [Y|N]" -n 1 -r
    echo    # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Download
        echo "Downloading all playlist's songs with spotdl..."
        pipx run spotdl $SPOTIFY_PLAYLIST_URL -o . --m3u
    fi

    if [ "$M3U_RENAME" = true ] ; then # rename m3u to fixed name?
        find . -type f -name '*.m3u' -exec mv {} "$M3U_FILE" \; # rename it
        echo "Renamed playlist to $M3U_FILE"
    else
        M3U_FILE=$(find . -type f -name "*.m3u") # works but only if find command will return exactly 1 file
        M3U_FILE=$(basename -- "$M3U_FILE")
        echo "Playlist filename is $M3U_FILE"
    fi
}

# Step 2 function
# Generates intro and outro mp3 files (if they dont exist already) using text to speech service and add to playlist (if not there already)
function intro_outro {

    if [[ ! -e "$INTRO_MP3" ]]; then # $INTRO_MP3 does not exist?
        get_tts "$TTS_INTRO" "$INTRO_MP3" # generate
    fi
    if [[ ! -e "$OUTRO_MP3" ]]; then # $OUTRO_MP" does not exist?
        get_tts "$TTS_OUTRO" "$OUTRO_MP3" # generate
    fi

    # Prepend intro mp3 to beginning of m3u but only if it's not there already (uses tmp file). Ref: https://stackoverflow.com/questions/54365/shell-one-liner-to-prepend-to-a-file?page=1&tab=votes#tab-top
    grep -qxF "$INTRO_MP3" "$M3U_FILE" || (echo "$INTRO_MP3" | cat - "$M3U_FILE" > _tmp.txt && mv _tmp.txt "$M3U_FILE")
    # Append outro mp3 to end of m3u but only if it's not there already. Ref: https://stackoverflow.com/questions/3557037/appending-a-line-to-a-file-only-if-it-does-not-already-exist
    grep -qxF "$OUTRO_MP3" "$M3U_FILE" || echo "$OUTRO_MP3" >> "$M3U_FILE"

}

# Step 3 function
# Merges all mp3s in a m3u playlist to one big mp3
function merge_audio {

    # Create txt file from m3u in format ffmpeg concat expects
    while read -r line; do
        # replace single quote (ex: O'Connor with O'\''Connor) so ffmpeg doesn't fail
        # ref: https://ffmpeg.org/ffmpeg-formats.html#Examples
        # ref: https://www.ffmpeg.org/ffmpeg-utils.html#Quoting-and-escaping
        # ref: https://askubuntu.com/questions/648759/replace-with-sed-a-character-with-backslash-and-use-this-in-a-variable
        line=$(echo "$line" | sed 's/'\''/&\\&&/g')
        echo "file '$line'";
    done < "$M3U_FILE" > _tmp.txt

    # Merge (same codec) mp3 files using ffmpeg concat using tmp txt file as input and then get rid of txt file
    # ref: https://superuser.com/questions/314239/how-to-join-merge-many-mp3-files
    # ref: https://trac.ffmpeg.org/wiki/Concatenate#samecodec
    echo "Merging all playlist's songs as $EP_FILE with ffmpeg..."
    ffmpeg -hide_banner -y -f concat -safe 0 -i ./_tmp.txt -b:a $BITRATE'k' -ar 48000 "$EP_FILE"
}

# Step 4 function
# Adds id3 metadata to merged mp3
function add_id3 {

    # get the cover art
    if [[ ! -e '_cover.jpg' ]]; then # tmp _cover.jpg does not exist?
    
        # Check if an episode cover exists on disk and use it instead default
        local id=${EP_FILE%'.'$RSS_AUDIO_FORMAT} # Same as mp3 filename (minus extension). Ex: all-my-favorite-songs-000-weezer
        custom_cover_img="../$id.jpg" # the custom cover image file to upload (full path)
        if [ -f "$custom_cover_img" ]; then # if custom cover img exists, overwrite conf var 
            echo "Found episode cover art: $custom_cover_img"
            cp $custom_cover_img '_cover.jpg' # copy cover to subdir
        else
            # use default conf $ID3_COVER url instead
            echo "Downloading episode cover: $ID3_COVER"
            curl --silent -L -o '_cover.jpg' $ID3_COVER # download default cover img 
        fi
        echo "Resizing episode cover to 600x600"
        convert '_cover.jpg' -resize 600x600 '_cover.jpg' # resize cover art to 600x600 (should stay below 200 KB)
    fi

    echo "Adding ID3..."
    # add cover art and other id3 data
    eyeD3 --add-image '_cover.jpg:FRONT_COVER' "$EP_FILE" \
    --title "$ID3_TITLE" \
    --artist "$ID3_ARTIST" \
    --comment "$ID3_DESC" \
    --release-year "$ID3_YEAR"

    echo "Finished adding ID3."
    # we don't need id3 cover anymore/ prepare.sh will remove it later.
}

# Step 5 function
# Generates chapter metadata file _ffmetadata.txt and add to mp3
function add_chapters {
    ./m3u2chapters.sh $1 $2
    local mp3_file=$ARCHIVE_DIR'/'$EP_SUBDIR'/'$EP_FILE # The mp3 file without chapter metadata
    local tmp_mp3_file_with_chapters=$ARCHIVE_DIR'/'$EP_SUBDIR'/_ffmetadata-'$EP_FILE # The tmp mp3 file with chapter metadata. We will overwrite original with this one.
    local metadata_file=$ARCHIVE_DIR'/'$EP_SUBDIR'/'_ffmetadata.txt # The temp metadata file itself
    echo "Adding chapter metadata from _ffmetadata.txt to $EP_FILE"
    ffmpeg -hide_banner -loglevel warning -i $mp3_file -i "$metadata_file" -map_metadata 1 -codec copy $tmp_mp3_file_with_chapters
    mv $tmp_mp3_file_with_chapters $mp3_file # Overwrite chapterless file
}

### Start doing stuff...

# change dir TODO: get rid of this changing dir stuff
cd "$ARCHIVE_DIR" # every command from here forward is relative to this
if [ ! -d "$EP_SUBDIR" ]; then # create dir (to hold all downloaded mp3s) if it doesn't exist already
    mkdir -p "$EP_SUBDIR"
fi
cd "$EP_SUBDIR" # every command from here forward is relative to this

### 1. Download all mp3s and m3u using Spotdl (if configured it also renames m3u)
download_playlist
### 2. Generate intro and outro mp3 files and add to playlist (only if not already done)
intro_outro 
### 3. Merge all mp3s in a m3u playlist to one big mp3
merge_audio
### 4. Add id3 metadata to merged mp3 
add_id3 
### Change back from episode subdir to our project main dir TODO: get rid of this changing dir stuff
cd '../../../../spotify2podcast' 
### 5. Generate chapter metadata file _ffmetadata.txt and add to mp3
add_chapters $1 $2 
### 6. Prepare generated audio file episode to be uploaded
./prepare.sh $1 "$ARCHIVE_DIR/$EP_SUBDIR/$EP_FILE"

echo "All done with `basename $0`."


