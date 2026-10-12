#!/bin/bash
# v0.3.91: a double-click on the last word of a sentence took the full
# stop along, so a pasted file name ended in a dot.
. "$LIB"
printf '\e[H\e[2J'
printf '  Now edit glass.asm. Then wait... or go to ../up now\n'
focus
ch=$((H / ROWS)); cw=$((W / COLS))
# dbl COL: two clicks on that cell of the first row (counted from 0).
dbl() {
    xdotool mousemove --window "$WIN" $((cw * $1 + cw / 2)) $((ch / 2)) click --repeat 2 --delay 60 1
    settle
    timeout 2 xclip -o -selection primary
}
is "the full stop behind a file name stays out" "$(dbl 12)" 'glass.asm'
is "so do three of them" "$(dbl 28)" 'wait'
is "a click on a full stop keeps them" "$(dbl 32)" 'wait...'
is "dots at the front of a word stay in" "$(dbl 46)" '../up'
