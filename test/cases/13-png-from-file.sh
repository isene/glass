#!/bin/bash
# v0.3.71: a PNG could only come inline. Sent as a file (t=f) it was dropped.
. "$LIB"
paint 1 "$ROWS" 0 0 0
echo iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAD0lEQVR4nGNg+M8AQhAKABvyA/1tVLjHAAAAAElFTkSuQmCC | base64 -d > "$RESULT.png"
printf '\e[H\e_Ga=T,i=1,f=100,t=f,c=40,r=10,q=2;%s\e\\' "$(printf '%s' "$RESULT.png" | base64 -w0)"; settle
size
is "a PNG named by its path is shown" "$(pix $((W / COLS * 20)) $((H / ROWS * 5)))" 00ff00
