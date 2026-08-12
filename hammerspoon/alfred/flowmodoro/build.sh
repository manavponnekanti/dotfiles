#!/bin/zsh
set -euo pipefail

workflow_dir=${0:A:h}
dist_dir="$workflow_dir/dist"
artifact="$dist_dir/Flowmodoro.alfredworkflow"

mkdir -p "$dist_dir"
rm -f "$artifact"
(
    cd "$workflow_dir"
    /usr/bin/zip -q -r "$artifact" info.plist flowmodoro.py icon.png README.md \
        'Flowmodoro Break.shortcut' 'Flowmodoro Focus.shortcut'
)
echo "$artifact"
