#!/bin/bash
# v0.3.100: a row painted only because the row above or below changed was
# painted across the whole width, so glass copied full-width strips to the
# window. drain's power core changes 13 columns at the left of 45 rows, and
# frame composited 1.8 million pixels five times a second for it. A change
# at the left must leave the right of the window alone.
. "$LIB"
printf '\e[?25l'; paint 1 "$ROWS" 0 0 0
printf '\e[5;1HA'; settle
size; ch=$((H / ROWS))
xpix -f $((W / 2)) $((3 * ch)) $((W / 2)) $((4 * ch)) ff0000   # rows 4 to 7, right half
printf '\e[5;1HB'; settle
is "the row below a change keeps the right half" "$(pix $((W - 20)) $((5 * ch + ch / 2)))" ff0000
is "the row above a change keeps the right half" "$(pix $((W - 20)) $((3 * ch + ch / 2)))" ff0000
