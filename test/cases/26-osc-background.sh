#!/bin/bash
# v0.3.93: OSC 11 sets the background and OSC 111 puts it back, so a
# program such as prism can show its colour on the whole window.
. "$LIB"
focus
printf '\e[H\e[2J'; settle
before=$(pix 300 300)
printf '\e]11;#2050a0\a'; settle
is "OSC 11 paints the background in the colour asked for" "$(pix 300 300)" 2050a0
printf '\e]11;#a05020\e\\'; settle
is "a second OSC 11, ended by ESC \\, paints the new colour" "$(pix 300 300)" a05020
printf '\e]11;?\a'; settle
is "a query changes nothing" "$(pix 300 300)" a05020
printf '\e]111\a'; settle
is "OSC 111 puts the old background back" "$(pix 300 300)" "$before"
xdotool key alt+b; settle
is "Alt+b still steps the background" "$(pix 300 300)" 00ffff
printf '\e]11;#2050a0\a'; settle; printf '\e]111\a'; settle
is "OSC 111 puts back the colour Alt+b chose" "$(pix 300 300)" 00ffff
