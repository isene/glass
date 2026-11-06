#!/bin/bash
# v0.3.106: an OSC 8 link wrapped over two rows, whose first row also shows
# "https://" (deck draws a long URL this way), underlines both rows with the
# pointer on the first. Before, the http text on that row won, and it held
# only that row's part, so the second row stayed plain.
. "$LIB"
printf '\e[H\e[2J  \e]8;;https://example.org/aaaa/bbbb\e\\https://example.org/aaaa/\e]8;;\e\\\n'
printf '  \e]8;;https://example.org/aaaa/bbbb\e\\bbbb\e]8;;\e\\\n'
focus
ch=$((H / ROWS)); cw=$((W / COLS))
xdotool mousemove --window "$WIN" $((cw * 6)) $((ch / 2)); settle
case $(colours $((cw * 3)) $((cw * 3 + 1)) $ch $((2 * ch))) in
    *ff00ff*) ok "the pointer on an OSC 8 link's first row underlines its second" ;;
    *)        bad "the pointer on an OSC 8 link's first row underlines its second: no underline there" ;;
esac
case $(colours $((cw * 6)) $((cw * 6 + 1)) 0 $ch) in
    *ff00ff*) ok "and the first row too" ;;
    *)        bad "and the first row too: no underline there" ;;
esac
