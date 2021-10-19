#!/bin/bash

# Uploads audio file and corresponding json to the Internet Archive
#
# Usage: ./upload.sh [config.conf] [./full/path/audio_file.ext]
# Requires:
# brew install internetarchive (Internet Archive's command line interface)
# ia configure (configure ia with your credentials)
# ------------------------------------------------------------------------

function print_usage {
    local msg="Uploads audio file and corresponding json to the Internet Archive
Usage: ./upload.sh [config.conf] [./full/path/audio_file.ext]
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

source $1 # Include the config file passed as 1st argument


# ------------------------------------------------------------------------

audio_file=$2 # 2nd argument is the file to upload
audio_file_ext="${audio_file##*.}" # just the extension (without dot)
json=${audio_file%'.'$audio_file_ext}.info.json # the metadata json file (full path)
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

#ia --debug upload $IA_IDENTIFIER "$audio_file" "$json" --retries 100 \
ia upload $IA_IDENTIFIER "$audio_file" "$json" --retries 100 \
--metadata="mediatype:$IA_MEDIATYPE" \
--metadata="title:$IA_TITLE" \
--metadata="collection:$IA_COLLECTION" \
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


