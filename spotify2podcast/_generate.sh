#!/bin/bash

# Generates a podcast episode mp3 from a Spotify playlist
# Downloads all mp3s using Spotdl, converts m3u playlist to one big mp3, adds an intro and outro and mp3 metadata too
#
# Usage: 
# Requires: 
# TODO: 
# - Add path to spotdl with -o option
# - Add external config file (see https://github.com/Flowm/spotify-api-bash/blob/master/create_playlist_from_artists_list.sh)

# Configure the access_token in config.cfg
# source ./config.cfg

SPOTIFY_PLAYLIST_URL='https://open.spotify.com/playlist/1THAmDIAPYkW2YurvltIDz'

M3U_RENAME=false # rename playlist?
M3U_FILE='_playlist.m3u' # m3u playlist filename to rename to

MP3_FILE='allmyfavoritesongs_001_weezer.mp3' # merged podcast mp3 filename

META_TITLE='#001 - Weezer: All My Favorite Songs' # Episode id3 title
META_ARTIST='All My Favorite Songs' # Episode id3 artist
META_DESC='allmyfavoritesongs.com' # Episode id3 description
META_DATE='2021' # Episode id3 date

INTRO_MP3='_intro.mp3' # intro mp3 filename
OUTRO_MP3='_outro.mp3' # outro mp3 filename

TTS_GENERATE=true
TTS_INTRO="Have you ever been curious, as to what others are listening to? <break time="0.4s"/>All My Favorite Songs is a podcast of hidden music gems dug up from unexpected places, and exclusively curated by others.<break time="1s"/>This is episode number 1.<break time="0.4s"/>8 songs, for 28 minutes and 36 seconds, of uninterrupted music, curated by the American rock band, Weezer." # ttsmp3.com intro speech
TTS_OUTRO='Thank you for listening! Good bye for now.' # ttsmp3.com outro speech
TTS_LANG='Brian' # US/en voices: Salli | Joey | Kimberly | Justin | Joanna | Kendra | Ivy | Matthew

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
    local tts=$(curl "${opts[@]}" 'https://ttsmp3.com/makemp3_new.php' | jq -r '.URL' ) # mp3 file url
    echo "Downloading tts from $tts as $2 with curl" 
    curl --silent --output "$2" $tts # download mp3
    echo "Converting $INTRO_MP3 to higher quality with ffmpeg..."
    # convert to higher frequency, bitrate and (from mono) to stereo
    ffmpeg -hide_banner -loglevel error -i "$2" -b:a 256k -ar 48000 -af "pan=stereo|c0=c0|c1=c0" tmp.mp3 && mv tmp.mp3 "$2"
}

# Download all mp3s from a Spotify playlist
echo "Downloading all playlist's songs with spotdl"
pipx run spotdl $SPOTIFY_PLAYLIST_URL --m3u
#pipx run spotdl $SPOTIFY_PLAYLIST_URL -o "mp3" --m3u

if [ "$M3U_RENAME" = true ] ; then
    echo "Renaming playlist to $M3U_FILE"
    find . -type f -name '*.m3u' -exec mv {} "$M3U_FILE" \; # rename m3u to fixed name
else
    #M3U_FILE=$(find . -type f -name "*.m3u" )
    M3U_FILE=$(find . -type f -name "*.m3u") # Works but only if find command will return exactly 1 file
    M3U_FILE=$(basename -- "$M3U_FILE")
    echo "Playlist filename is $M3U_FILE"
fi

# Generate intro and outro mp3s
if [[ ! -e "$INTRO_MP3" ]]; then
    get_tts "$TTS_INTRO" "$INTRO_MP3" # generate because file "$INTRO_MP3" does not exist
fi
if [[ ! -e "$OUTRO_MP3" ]]; then
    get_tts "$TTS_OUTRO" "$OUTRO_MP3" # generate because file "$OUTRO_MP3" does not exist
fi

# Prepend intro mp3 to beginning of m3u but only if it doesn't exist (uses tmp file). Ref: https://stackoverflow.com/questions/54365/shell-one-liner-to-prepend-to-a-file?page=1&tab=votes#tab-top
grep -qxF "$INTRO_MP3" "$M3U_FILE" || (echo "$INTRO_MP3" | cat - "$M3U_FILE" > tmp.txt && mv tmp.txt "$M3U_FILE")
# Append outro mp3 to end of m3u but only if it doesn't exist. Ref: https://stackoverflow.com/questions/3557037/appending-a-line-to-a-file-only-if-it-does-not-already-exist
grep -qxF "$OUTRO_MP3" "$M3U_FILE" || echo "$OUTRO_MP3" >> "$M3U_FILE"  

# Merge (same codec) mp3 files using ffmpeg concat 
# ref: https://superuser.com/questions/314239/how-to-join-merge-many-mp3-files
# ref: https://trac.ffmpeg.org/wiki/Concatenate#samecodec
#
# Create txt file from m3u in format ffmpeg concat expects
while read -r line; do 
    # replace single quote (ex: O'Connor with O'\''Connor) so ffmpeg doesn't fail 
    # ref: https://ffmpeg.org/ffmpeg-formats.html#Examples
    # ref: https://askubuntu.com/questions/648759/replace-with-sed-a-character-with-backslash-and-use-this-in-a-variable
    echo "file '$line'"; 
    line=$(echo $line | sed 's/'\''/&\\&&/g') 
done < "$M3U_FILE" > tmp.txt 

# Concat with ffmpeg using tmp txt file as input and then get rid of txt file
echo "Concatenating all playlist's songs as $MP3_FILE with ffmpeg..."
ffmpeg -hide_banner -y -f concat -safe 0 -i tmp.txt -b:a 256k -ar 48000 \
-metadata title="$META_TITLE" \
-metadata artist="$META_ARTIST" \
-metadata description="$META_DESC" \
-metadata date="$META_DATE" \
"$MP3_FILE" && rm tmp.txt

echo 'All done.'
