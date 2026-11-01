#!/bin/bash
# v0.3.101: glass copied one rectangle around every change in a frame, so
# a change at the top left and one at the bottom right copied the whole
# window. drain's power core and its once-a-second text sit far apart in
# the same way. Two changes far apart must leave the middle alone.
. "$LIB"
printf '\e[?25l'; paint 1 "$ROWS" 0 0 0
printf '\e[2;2HA\e[%d;%dHB' $((ROWS - 1)) $((COLS - 2)); settle
size
xpix -f $((W / 4)) $((H / 4)) $((W / 2)) $((H / 2)) ff0000   # the middle
g='\e[48;2;0;255;0m \e[0m'                                  # a green cell
printf "\e[?2026h\e[2;2H$g\e[%d;%dH$g\e[?2026l" $((ROWS - 1)) $((COLS - 2)); settle
cw=$((W / COLS)); ch=$((H / ROWS))
is "two changes far apart leave the middle alone" "$(pix $((W / 2)) $((H / 2)))" ff0000
is "and both changes show" "$(pix $((cw + cw / 2)) $((ch + ch / 2))) $(pix $(((COLS - 3) * cw + cw / 2)) $(((ROWS - 2) * ch + ch / 2)))" "00ff00 00ff00"
