#!/bin/bash
if ! [ -e "$1" ]
then
	echo "Converts a subtitle file to UTF-8 encoding"
	echo "Usage: $0 subtitle/file.whatever"
	exit 0
fi
outfile="utf8.$1"
ffmpeg \
	-sub_charenc $(uchardet $1) \
	-i $1 \
	$outfile
echo "UTF-8 converted subs written to $outfile"

