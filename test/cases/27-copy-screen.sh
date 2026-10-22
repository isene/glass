#!/bin/bash
# v0.3.94: Alt+c copies every row in view to PRIMARY and CLIPBOARD,
# without the spaces and empty rows at the end.
. "$LIB"
printf '\e[H\e[2J'
printf 'first line   \n\n  third line\n'
focus
xdotool key alt+c
settle
want=$'first line\n\n  third line'
is "the clipboard has the screen" "$(timeout 2 xclip -o -selection clipboard)" "$want"
is "so does the selection" "$(timeout 2 xclip -o -selection primary)" "$want"
