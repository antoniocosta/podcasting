#!/bin/bash

# Publishes (copies and git pushes) podcast website:
# 1. Rsyncs ../docs/podcast-name folder to a ../../podcast-name.github.io repo folder
# 2. git pushes to podcast-name.github.io repo
#
# Usage: ./publish.sh ../docs/podcast-name ../../podcast-name.github.io
# Requires:
# rsync
# git
# ------------------------------------------------------------------------

function print_usage {
    local msg="Publishes (copies and git pushes) podcast website:
Usage: ./publish.sh ../docs/podcast-name ../../podcast-name.github.io
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

echo "Rsync'ing..."
# Rsync the two folders but exclude hidden dot files
# u - 'update' - only copy newer files.
# a - 'archive'
# n - 'dry-run` - don't copy, just list what it would do.
# --progress - show progress of copy
# --exclude=".*" - exclude files that begin with a dot
rsync -uan --progress --exclude=".*" $1 $2

gitpush () {
        echo "Pushing to git..."
        cd $1
        git add .
        git commit -m "Updated website"
        git push
}
gitpush

echo "All done with `basename $0`."

