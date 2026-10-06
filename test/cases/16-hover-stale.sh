#!/bin/bash
# v0.3.65 and v0.3.84: the underline of a hovered URL stayed on the screen
# after the program had drawn something else there. v0.3.65 cured it while
# output kept coming. A screen that changed once and then stood still kept
# the line until v0.3.84.
. "$LIB"
printf '\e[H\e[2J  https://example.com/gone\n'; settle
size; ch=$((H / ROWS)); cw=$((W / COLS))
xdotool mousemove --window "$WIN" $((cw * 11)) $((ch / 2)); settle
case $(colours $((cw * 11)) $((cw * 11 + 1)) 0 $ch) in
    *ff00ff*) ok "the URL is underlined to start with" ;;
    *)        bad "the URL is underlined to start with: no underline" ;;
esac
printf '\e[H\e[2J  plain words, no link here\n'; settle
case $(colours $((cw * 11)) $((cw * 11 + 1)) 0 $ch) in
    *ff00ff*) bad "the underline goes when the URL goes: it is still there" ;;
    *)        ok "the underline goes when the URL goes" ;;
esac
