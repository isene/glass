#!/bin/bash
# v0.3.107: new text in selected cells drops the selection. deck rewrites
# its rows while Claude Code answers, and the highlight stayed on the same
# cells, over text the user never chose.
. "$LIB"
printf '\e[H\e[2J'
paint 2 2 0 0 255
focus
ch=$((H / ROWS)); cw=$((W / COLS))
at() { pix $((cw * 10 + cw / 2)) $((ch + ch / 2)); }   # row 2, col 11
xdotool mousemove --window "$WIN" $((cw * 2 + cw / 2)) $((ch + ch / 2)) mousedown 1; sleep 0.1
xdotool mousemove --window "$WIN" $((cw * 20 + cw / 2)) $((ch + ch / 2)); sleep 0.1
xdotool mouseup 1; settle
[ "$(at)" != 0000ff ] && ok "a drag selects part of the row" || bad "a drag selects part of the row: still blue"
paint 2 2 0 0 255; settle
[ "$(at)" != 0000ff ] && ok "the same text written again keeps the selection" \
    || bad "the same text written again keeps the selection: it was dropped"
printf '\e[2;40HX'; settle
[ "$(at)" != 0000ff ] && ok "a change beside the selection keeps it" \
    || bad "a change beside the selection keeps it: it was dropped"
paint 2 2 0 255 0; settle
is "new text in the selected cells drops the selection" "$(at)" 00ff00
