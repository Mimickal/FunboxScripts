#!/bin/sh
# Version 1.0
echo "Converting $1"
ffmpeg -i "$1" -ab 320k -map_metadata 0 -id3v2_version 3 "$(basename "$1" .flac).mp3"
