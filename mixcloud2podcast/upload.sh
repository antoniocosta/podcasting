#!/bin/bash

# Uploads audio file, corresponding json and a cover jpg to the Internet Archive
#
# Usage: ./upload.sh podcast.conf ../path/to/audio_file.ext
# Requires:
# brew install internetarchive (Internet Archive's command line interface)
# ia configure (configure ia with your credentials)
# ------------------------------------------------------------------------

function print_usage {
    local msg="Uploads audio file, corresponding json and a cover jpg to the Internet Archive
Usage: ./upload.sh podcast.conf ../path/to/audio_file.ext
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

[[ $# -lt 2 ]] && print_usage
requirements

source $1 # Include the podcast config file passed as 1st argument

# ------------------------------------------------------------------------
echo "Starting `basename $0`..."

audio_file=$2 # 2nd argument is the file to upload
audio_file_ext="${audio_file##*.}" # just the extension (without dot)
json=${audio_file%'.'$audio_file_ext}.info.json # the metadata json file to upload (full path)
custom_cover_img=${audio_file%'.'$audio_file_ext}.jpg # the custom cover image file to upload (full path)
if [ -f "$custom_cover_img" ]; then # if custom cover img exists, overwrite conf var $IA_COVER_IMG
    IA_COVER_IMG=$custom_cover_img
fi

IA_IDENTIFIER=$(jq --raw-output '.id' $json) # get data from json
IA_TITLE=$(jq --raw-output '.title' $json) # get data from json
IA_DESCRIPTION=$(jq --raw-output '.description' $json) # get data from json
IA_DESCRIPTION=${IA_DESCRIPTION//$'\n'/ <br />} # convert newlines /n to html <br />
IA_DESCRIPTION=$(echo $IA_DESCRIPTION | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g') # convert special characters to HTML entities
IA_ARTIST=$(jq --raw-output '.artist' $json) # get data from json
IA_DATE=$(jq --raw-output '.timestamp' $json) # get data from json
if [ "$(uname)" == "Darwin" ]; then # Mac OS X platform 
	IA_DATE=$(date -j -f "%s" $IA_DATE "+%F") # convert timestamp to date string
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then # GNU/Linux platform
	IA_DATE=$(date -d @$IA_DATE "+%F") # convert timestamp to date string
fi	
IA_LICENSEURL='http://creativecommons.org/licenses/by-nc-sa/4.0/'


if [ -z "$IA_DESCRIPTION" ]
then # empty
      IA_DESCRIPTION=$IA_DESCRIPTION' '
fi

if [ -z "$IA_ARTIST" ]
then # empty
      IA_ARTIST=$IA_ARTIST' '
fi


# Upload files. mediatype and collection has to be set as it cannot be changed afterwards. 
# See: https://archive.org/services/docs/api/internetarchive/cli.html#upload
function ia_upload {

    # audio_file=$(realpath $audio_file)
    # json=$(realpath $json)
    # IA_COVER_IMG=$(realpath $IA_COVER_IMG)

    echo '[DEBUG] IA_IDENTIFIER: '$IA_IDENTIFIER
    echo '[DEBUG] audio_file: '$audio_file
    echo '[DEBUG] json: '$json
    echo '[DEBUG] IA_COVER_IMG: '$IA_COVER_IMG

    # ia --debug \
    ia \
    upload $IA_IDENTIFIER "$audio_file" "$json" "$IA_COVER_IMG" --retries 10 \
    -H x-archive-keep-old-version:0 \
    --metadata="mediatype:$IA_MEDIATYPE" \
    --metadata="collection:$IA_COLLECTION" \
    --metadata="title:$IA_TITLE" \
    --metadata="description:$IA_DESCRIPTION " \
    --metadata="artist:$IA_ARTIST" \
    --metadata="author:$IA_AUTHOR" \
    --metadata="contributor:$IA_CONTRIBUTOR" \
    --metadata="creator:$IA_CREATOR" \
    --metadata="source:$IA_SOURCE" \
    --metadata="subject:$IA_SUBJECT" \
    --metadata="date:$IA_DATE" \
    --metadata="language:$IA_LANGUAGE" \
    --metadata="licenseurl:$IA_LICENSEURL"
}

# Modify metadata. mediatype and collection cannot be modified.
# See: https://archive.org/services/docs/api/internetarchive/cli.html#upload
function ia_metadata {
    #ia --debug \
    ia \
    metadata $IA_IDENTIFIER \
    --modify="title:$IA_TITLE" \
    --modify="description:$IA_DESCRIPTION " \
    --modify="artist:$IA_ARTIST" \
    --modify="author:$IA_AUTHOR" \
    --modify="contributor:$IA_CONTRIBUTOR" \
    --modify="creator:$IA_CREATOR" \
    --modify="source:$IA_SOURCE" \
    --modify="subject:$IA_SUBJECT" \
    --modify="date:$IA_DATE" \
    --modify="language:$IA_LANGUAGE" \
    --modify="licenseurl:$IA_LICENSEURL"    
}

ia_upload
#ia_metadata

echo "All done with `basename $0`."

