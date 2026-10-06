#!/bin/bash
# v0.3.83: glass painted in the middle of a synchronized update (DECSET
# 2026), so a Claude Code screen that arrived in pieces showed half-drawn.
. "$LIB"
paint 1 "$ROWS" 255 0 0; settle
is "a red screen to start from" "$(pix 40 40)" ff0000
printf '\e[?2026h'; paint 1 $((ROWS / 2)) 0 255 0; sleep 0.4
is "half an update is not shown" "$(pix 40 40)" ff0000
paint $((ROWS / 2 + 1)) "$ROWS" 0 255 0; printf '\e[?2026l'; settle
is "the finished update is shown" "$(pix 40 40)" 00ff00
printf '\e[?2026h'; paint 1 1 0 0 255; sleep 1.4
is "an update left open is shown after 1 s" "$(pix 40 8)" 0000ff
