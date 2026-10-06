#!/bin/bash
# v0.3.80: with kitty keyboard flag 4 on (Claude Code pushes 5), Alt+b,
# Alt+t and the font keys went to the app and glass never saw them.
. "$LIB"
printf '\e[>5u'; focus; settle
before=$(pix 40 40)
xdotool key alt+b; settle
is "Alt+b is not sent to the app" "$(ask '' u)" ''
is "Alt+b changed the background" "$(pix 40 40)" 00ffff
[ "$before" != 00ffff ] || bad "the background was already the second colour"
