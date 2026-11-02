#!/bin/bash
# v0.3.102: Alt+d dims the window by half until the next key, and so does
# OSC 7702;1 (deck sends it when its session goes idle). A modifier alone,
# like the Alt of Alt+d, keeps the dim.
. "$LIB"
stty -echo </dev/tty
printf '\e[?25l'; paint 1 "$ROWS" 200 100 0
focus; settle
x=$((W / 2)); y=$((H / 2))
is "the window before the dim" "$(pix $x $y)" c86400
printf '\e]7702;1\e\\'; settle
is "OSC 7702;1 dims it by half" "$(pix $x $y)" 633100
xdotool key Shift_L; settle
is "Shift alone keeps the dim" "$(pix $x $y)" 633100
xdotool key a; settle
is "a key lifts it" "$(pix $x $y)" c86400
xdotool key alt+d; settle
is "Alt+d dims it" "$(pix $x $y)" 633100
paint 1 1 0 200 0; settle
is "a row drawn while dimmed is dimmed too" "$(pix $x $((H / ROWS / 2)))" 006300
xdotool key alt+d; settle
is "Alt+d again lifts it" "$(pix $x $y) $(pix $x $((H / ROWS / 2)))" "c86400 00c800"
printf '\e]7702;1\e\\\e]7702;0\e\\'; settle
is "OSC 7702;0 lifts it" "$(pix $x $y)" c86400
