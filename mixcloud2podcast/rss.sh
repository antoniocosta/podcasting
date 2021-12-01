#!/bin/bash

# Creates a podcast rss file from a folder of m4a (or mp3) and metadata json files 
# (downloaded from mixcloud using youtube-dl or generated). Also pushes to a git repository.
#
# Heavily adapted from https://github.com/maxhebditch/rss-roller
#
# Usage: ./rss.sh config.conf]
# Requires:
# brew install jq (command-line JSON processor)
# ------------------------------------------------------------------------

function print_usage {
    local msg="Creates a podcast rss file from a folder of m4a (or mp3) files and metadata json files 
Usage: ./rss.sh config.conf
Requires: jq"
    printf "%s\n" "$msg"
    exit 127
}

function requirements {
        for p in jq; do 
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
echo "Starting `basename $0`..."

# The copyright: © 2021 FirstName LastName
RSS_COPYRIGHT="&#xA9; $(date +"%Y") $RSS_AUTHOR"

RSS_DATE=$(date -R) # now

header () {
echo """<?xml version='1.0' encoding='UTF-8'?>
<rss xmlns:atom='http://www.w3.org/2005/Atom' xmlns:content='http://purl.org/rss/1.0/modules/content/' xmlns:googleplay='http://www.google.com/schemas/play-podcasts/1.0' xmlns:itunes='http://www.itunes.com/dtds/podcast-1.0.dtd' version='2.0'>
""" > ./feedtop
echo """<channel>
        <atom:link href='$RSS_LINK_SELF' rel='self' type='application/rss+xml' />
        <title>$RSS_TITLE</title>
        <link>$RSS_LINK</link>
        <description>$RSS_DESCRIPTION</description>
        <lastBuildDate>$RSS_DATE</lastBuildDate>
        <language>$RSS_LANGUAGE</language>
        <copyright>$RSS_COPYRIGHT</copyright>
        <ttl>60</ttl>
        <image>
                <link>$RSS_LINK</link>
                <url>$RSS_IMAGE</url>
                <title>$RSS_TITLE</title>
        </image>
        <itunes:image href='$RSS_IMAGE' />
        <itunes:subtitle>$RSS_SUBTITLE</itunes:subtitle>
        <itunes:summary>$RSS_DESCRIPTION</itunes:summary>        
        <itunes:category text='$RSS_CATEGORY' />
        <itunes:keywords>$RSS_KEYWORDS</itunes:keywords>
        <itunes:author>$RSS_AUTHOR</itunes:author>
        <itunes:owner>
                <itunes:name>$RSS_AUTHOR</itunes:name>
                <itunes:email>$RSS_EMAIL</itunes:email>
        </itunes:owner>
        <itunes:explicit>$RSS_EXPLICIT</itunes:explicit>
        <itunes:type>$RSS_TYPE</itunes:type>

""" >> ./feedtop
echo "Adding the header"
}

footer () {
echo """
</channel>

</rss>
""" >> ./feedbottom
echo "Adding the footer"
}

item () {
        echo """
        <item>
                <title>$item_title</title>
                <link>$item_link</link>
                <guid>$item_guid</guid>
                <enclosure url=\"$item_enclosure\" length=\"$item_enclosure_length\" type=\"$item_enclosure_type\" />
                $item_image_tag
                <description>$item_description</description>
                <pubDate>$item_date</pubDate>
        </item>
        """ >> ./feed
}

combine () {
        header
        footer
        cat ./feedtop ./feed > ./feedtb
        cat ./feedtb ./feedbottom > $RSS_FILE
        rm ./feedtop ./feed ./feedtb ./feedbottom
}

# delete feed xml file
if [[ -f $RSS_FILE ]]; then
        rm $RSS_FILE
fi
# create feed xml file
touch $RSS_FILE

IFS=$'\n' # newline as the delimiter
arr_json=( $(ls -t "$ARCHIVE_DIR"/*.json) ) # an array of all the json files
items_total=$(ls "$ARCHIVE_DIR"/*.json | wc -l | tr -d ' ')
echo "Processing $items_total items..."
item_num=0

for json in "${arr_json[@]}"; do
        let item_num+=1
        echo -ne "Checking item $item_num/$items_total"\\r

        audio_file=${json%.info.json}.$RSS_AUDIO_FORMAT # full path to audio file (from json file path)

        # add data to json (so we dont need the audio file anymore)
        if [ "$(jq --raw-output '.length' $json)" = null ]; then # if var is empty
                echo 'Adding length to $json'
                if [ "$(uname)" == "Darwin" ]; then # Mac OS X platform
                        length=$(stat -f%z $audio_file) # get audio file size in bytes
                elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then # GNU/Linux platform
                        length=$(stat -c%s $audio_file) # get audio file size in bytes
                fi
                cat $json | jq --arg length $length '. + {length: $length}' > $json.tmp # Add file size to a json.tmp file
                mv $json.tmp $json # overwite original json with new json.tmp file
        fi

        # fix timestamps: make audio file and json file have timestamp when it was published
        file_timestamp=$(date -r $json "+%s") # system date of file as timestamp
        pub_timestamp=$(jq --raw-output '.timestamp' $json) # real timestamp when file was published

        if [ $file_timestamp != $pub_timestamp ]; then 
                echo "Fixing file creation time for $json"
                echo "Fixing file creation time for $audio_file"
                if [ "$(uname)" == "Darwin" ]; then # Mac OS X platform 
                        touch_time_str=$(date -j -f "%s" $pub_timestamp "+%Y%m%d%H%M.%S") # time string in format used by touch command
                elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then # GNU/Linux platform
                        touch_time_str=$(date -d @$pub_timestamp "+%Y%m%d%H%M.%S") # time string in format used by touch command
                fi
                # echo "touch -t $touch_time_str [file]"
                touch -t $touch_time_str $json
                touch -t $touch_time_str $audio_file
        fi
done

echo ''
item_num=0
for json in "${arr_json[@]}"; do
        let item_num+=1
        echo -ne "Adding item $item_num/$items_total"\\r

        audio_file=${json%.info.json}.$RSS_AUDIO_FORMAT # full path to audio file (from json file path)

        item_id=$(jq --raw-output '.id' $json) # the item's id from json file
        item_title=$(jq --raw-output '.title' $json) # get data from json
        item_date=$(jq --raw-output '.timestamp' $json) # get data from json
        if [ "$(uname)" == "Darwin" ]; then # Mac OS X platform 
                item_date=$(date -j -f "%s" $item_date "+%a, %d %b %Y %H:%M:%S %z") # convert timestamp to date string
        elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then # GNU/Linux platform
                item_date=$(date -d @$item_date "+%a, %d %b %Y %H:%M:%S %z") # convert timestamp to date string
        fi
        item_link=$(jq --raw-output '.webpage_url' $json) # get data from json
        item_guid='https://archive.org/details/'$item_id # use archive.org permalink
        item_enclosure='https://archive.org/download/'$item_id'/'$item_id'.'$RSS_AUDIO_FORMAT
        #item_enclosure_length=$(stat -f%z $audio_file) # get file size in bytes
        item_enclosure_length=$(jq --raw-output '.length' $json) # get file size in bytes (we added this data to the json above)
        if [ "$RSS_AUDIO_FORMAT" == "m4a" ]; then 
                item_enclosure_type='audio/x-m4a'
        elif [ "$RSS_AUDIO_FORMAT" == "mp3" ]; then  
                item_enclosure_type='audio/mpeg'
        fi
        item_description=$(jq --raw-output '.description' $json) # get data from json
        item_description=${item_description//$'\n'/ <br>} # convert newlines /n to html <br>
        item_description=$(echo $item_description | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g') # convert special characters to HTML entities. See: https://stackoverflow.com/questions/12873682/short-way-to-escape-html-in-bash
        #item_description="![CDATA[ $item_description ]]" # add cdata tag

        item_image_tag='' # emtpy by default
        if [ -f "$ARCHIVE_DIR/$item_id.jpg" ]; then # if custom cover img exists, overwrite conf var $IA_COVER_IMG
                item_image='https://archive.org/download/'$item_id'/'$item_id'.jpg'
                item_image_tag="<itunes:image href='$item_image' />"
        fi

        item
done
combine
echo "RSS file saved"

function gitpush {
        echo "Pushing to git..."
        cd ..
        git add .
        git commit -m "Updated feed"
        git push
}
gitpush
echo "All done with `basename $0`."
exit

