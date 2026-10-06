#!/bin/bash
# v0.3.79: a selection dragged out of the window read past the grid and
# glass crashed.
. "$LIB"
echo "some text to select"; size
xdotool windowmove "$WIN" 0 700; sleep 0.2
xdotool mousemove --window "$WIN" 60 10 mousedown 1; sleep 0.1
xdotool mousemove 60 5; sleep 0.1
xdotool mouseup 1; settle
is "glass still answers after the drag" "$(ask '\e[c' c)" 'ESC[?62;22c'
