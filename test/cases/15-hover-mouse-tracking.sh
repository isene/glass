#!/bin/bash
# v0.3.64: once a program asked for mouse reports, URLs stopped lighting up
# under the pointer. Claude Code asks, so no link in it could be hovered.
. "$LIB"
printf '\e[H\e[2J  https://example.com/tracked\n\e[?1003h'; settle
size; ch=$((H / ROWS)); cw=$((W / COLS))
xdotool mousemove --window "$WIN" $((cw * 11)) $((ch / 2)); settle
printf '\e[?1003l'
case $(colours $((cw * 11)) $((cw * 11 + 1)) 0 $ch) in
    *ff00ff*) ok "the URL is underlined while the program tracks the mouse" ;;
    *)        bad "the URL is underlined while the program tracks the mouse: no underline" ;;
esac
