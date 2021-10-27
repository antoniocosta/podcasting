#!/bin/bash

# Publishes (copies and git pushes) podcast website:
# 1. Rsyncs ../docs/podcast-name folder to a ../../podcast-name.github.io repo folder
# 2. git pushes to podcast-name.github.io repo
#
# Usage: ./publish.sh ../docs/podcast-name/ ../../podcast-name.github.io
# Requires: rsync git
#
# TODO:
# - Make it use podcast.conf instead of directory names . Move dir names to podcast.conf.
# ------------------------------------------------------------------------

function print_usage {
    local msg="Publishes (copies and git pushes) podcast website:
Note: Source path must end with / so we copy only the contents instead of the folder itself!
Usage: ./publish.sh ../docs/podcast-name/ ../../podcast-name.github.io
Requires: rsync git"
    printf "%s\n" "$msg"
    exit 127
}

function requirements {
        for p in rsync git; do 
            if [[ -z $(command -v $p) ]]; then
                echo "$p is not installed"
                exit 1
            fi
        done 
}

[[ $# -lt 2 ]] && print_usage
requirements

# ------------------------------------------------------------------------
echo "Starting `basename $0`..."

function rsyncing {
    echo "Rsync'ing..."
    local source=$1
    local dest=$2
    local source_length=${#source}
    local source_last_char=${source:length-1:1}
    if [[ $source_last_char != "/" ]]; then 
        echo "ERROR: No / found at end of source path. This is probably not what you want!"
        echo "NOTE: Source path must end with / so we copy only the contents instead of the folder itself."
        echo "Exiting `basename $0`"
        exit
    fi

    # Rsync the two folders but exclude hidden dot files
    # u - 'update' - only copy newer files. 
    # r - recursive - means it copies directories and sub directories
    # a - 'archive' - causes rsync to recurse the directory copying all the files and directories and perserving things like case, permissions, and ownership on the target
    # n - 'dry-run` - don't copy, just list what it would do.
    # --delete - deletes any files that exist in your target directories but that do not exist in the source directory struction
    # --progress - show progress of copy
    # --exclude=".*" - exclude files that begin with a dot
    rsync -ra \
    --delete \
    --progress \
    --exclude=".*" \
    --exclude='downloads/' \
    --exclude='downloaded.txt' \
    --exclude="psd/" \
    --exclude="CNAME" \
    "$source" "$dest"
}
rsyncing $1 $2

function gitpush {
        local dest=$1
        echo "Pushing $dest to git..."
        cd $dest
        git add .
        git commit -m "Updated website"
        git push
}
gitpush $2

echo "All done with `basename $0`."

