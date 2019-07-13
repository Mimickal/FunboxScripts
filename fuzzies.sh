#!/bin/bash
# This file contains a bunch of bash functions that use fzf (fuzzy find) to
# create more interactive UIs for existing utilities.

# cd into directory the selected file lives in
function fcd() {
	file="$(locate --nofollow /* | fzf)"
	path=$(dirname "$file")
	cd "$path"
}

# Kills selected process by ID
function fkill() {
	kill $(ps fux | fzf | sed 's/[a-zA-Z]* *\([0-9]*\).*/\1/')
}


