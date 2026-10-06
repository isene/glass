#!/bin/bash
# v0.3.85: a double-click on a word you had scrolled back to found the
# word's ends in the live screen row behind it, so it picked a piece of
# the word, or one letter.
. "$LIB"
printf '\e[H\e[2J  Run /tmp/run-this-now.sh now\n'
for ((i = 0; i < ROWS + 5; i++)); do echo "ab cd ef gh ij kl mn op qr st uv wx yz"; done
printf '  see ~/bin/some-tool here'
focus
ch=$((H / ROWS)); cw=$((W / COLS))
dbl() { xdotool mousemove --window "$WIN" $((cw * 14 + cw / 2)) "$1" click --repeat 2 --delay 60 1; settle; }
dbl $((ch * (ROWS - 1) + ch / 2))
is "a double-click picks the whole word on the live screen" "$(timeout 2 xclip -o -selection primary)" '~/bin/some-tool'
xdotool key shift+Prior; settle
dbl $((ch / 2))
is "and the whole word in the scrollback" "$(timeout 2 xclip -o -selection primary)" '/tmp/run-this-now.sh'
