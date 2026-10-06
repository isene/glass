#!/bin/bash
# v0.3.76 and v0.3.84: a URL you had scrolled back to got no underline and
# no click. v0.3.76 brought the click back; the underline stayed off until
# v0.3.84.
. "$LIB"
printf '\e[H\e[2J  https://example.com/scrolled\n'
for ((i = 0; i < ROWS + 5; i++)); do echo; done
focus
xdotool key shift+Prior; settle
ch=$((H / ROWS)); cw=$((W / COLS))
xdotool mousemove --window "$WIN" $((cw * 11)) $((ch / 2)); settle
case $(colours $((cw * 11)) $((cw * 11 + 1)) 0 $ch) in
    *ff00ff*) ok "the URL is underlined under the pointer" ;;
    *)        bad "the URL is underlined under the pointer: no underline colour in its cell" ;;
esac
