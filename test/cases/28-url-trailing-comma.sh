#!/bin/bash
# v0.3.95: a link followed by a comma took the comma with it, in the
# underline and in what a click opened.
. "$LIB"
printf '\e[H\e[2J  https://example.com/a, then\n'
focus
ch=$((H / ROWS)); cw=$((W / COLS))
xdotool mousemove --window "$WIN" $((cw * 11)) $((ch / 2)); settle
case $(colours $((cw * 22)) $((cw * 22 + 1)) 0 $ch) in
    *ff00ff*) ok "the link's last letter is underlined" ;;
    *)        bad "the link's last letter is underlined: no underline colour in its cell" ;;
esac
case $(colours $((cw * 23)) $((cw * 24 - 1)) 0 $ch) in
    *ff00ff*) bad "the comma after the link is left out: it is underlined" ;;
    *)        ok "the comma after the link is left out" ;;
esac
