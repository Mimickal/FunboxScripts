#!/bin/bash
# This file contains a bunch of bash functions that
# improve existing utilities with fzf (fuzzy find)

function fcd() {
	file="$(locate --nofollow /* | fzf)"
	path=$(dirname "$file")
	cd "$path"
}

function fkill() {
	kill $(ps fux | fzf | sed 's/[a-zA-Z]* *\([0-9]*\).*/\1/')
}


