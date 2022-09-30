#!/bin/bash
FILE2CHECK=temp-check-file
if [ ! -z "$1" ]; then
	FILE2CHECK=$1
fi
# list of changed files in the last commit
filelist=$(echo $(git log -p | grep commit | head -2 | cut -f2 -d' ') | while read s e; do git diff --name-only $s..$e; done)
if [[ $filelist == *"${FILE2CHECK}"* ]]; then
    echo "Got file interested in!"
else
    echo "==== File $FILE2CHECK not found! ===="
    echo "==== Exiting with ERR 99 ===="
    exit 99
fi
