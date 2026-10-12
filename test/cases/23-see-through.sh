#!/bin/bash
# v0.3.90: Alt+t did nothing under a compositor such as frame. glass set a
# window property that frame does not read. Now the window carries the
# see-through value in its own pixels: the background gets it, text and
# coloured cells stay solid.
. "$LIB"
focus
printf '\e[H\e[2J\e[41m    \e[0m'; settle
screen() { xpix -s "$1" "$2"; }           # what the screen shows at a point
region() { xprop -id "$WIN" -f _NET_WM_OPAQUE_REGION 32c _NET_WM_OPAQUE_REGION 2>&1 | sed 's/.*= //'; }
solid=$(pix 300 300)
is "at 100% the screen shows the background as it is" "$(screen 300 300)" "$solid"
is "and glass tells the compositor it is solid all over" "$(region)" "0, 0, $W, $H"
xdotool key alt+t; settle
if [ "$(screen 300 300)" != "$solid" ]; then ok "Alt+t makes the background see-through"
else bad "Alt+t makes the background see-through: the screen still shows $solid"; fi
is "a coloured cell stays solid" "$(screen 5 5)" "$(pix 5 5)"
if [ $((W % (W / COLS))) -gt 0 ] && [ "$(screen $((W - 1)) 300)" = "$solid" ]; then
    bad "the strip beside the last column is see-through too: it shows $solid"
else ok "the strip beside the last column is see-through too"; fi
case $(region) in _NET_WM_OPAQUE_REGION:*"not found"*) ok "a see-through glass no longer says it is solid" ;;
    *) bad "a see-through glass no longer says it is solid: $(region)" ;; esac
xdotool key alt+b; settle                 # the next colour of the test config: 00ffff
half=$(screen 300 300); g=$((16#${half:2:2}))
if [ "$g" -gt 96 ] && [ "$g" -lt 160 ]; then ok "a new background colour (Alt+b) keeps the see-through value"
else bad "a new background colour (Alt+b) keeps the see-through value: wanted about 008080, got $half"; fi
xdotool key alt+t; settle
is "Alt+t again makes it solid" "$(screen 300 300)" 00ffff
