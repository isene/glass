#!/bin/bash
# v0.3.109: at some sizes a letter lost its lower part. glass cut every
# bottom row with one lit pixel off a glyph, meant for a stray dot under
# '›', so a stroke one pixel wide went too: at size 13 'f' kept only its
# top and '|' vanished. Alt+minus takes the test font from 15 to 13.
. "$LIB"
focus
xdotool key alt+minus; settle
read -r ROWS COLS < <(stty size </dev/tty)
ch=$((H / ROWS)); cw=$((W / COLS))
printf '\e[H\e[2J\n%*s' "$COLS" '' | tr ' ' '|' >/dev/tty; settle
lit=$(colours $((cw * 5)) $((cw * 7)) $((ch + ch * 2 / 3)) $((ch * 2))  | grep -vc '^000000$')
[ "$lit" -gt 0 ] && ok "'|' at size 13 reaches the bottom of its cell" \
    || bad "'|' at size 13 reaches the bottom of its cell: nothing drawn there"
