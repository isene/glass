#!/bin/bash
# v0.3.105: a URL glass wraps onto the next row is one link. The pointer on
# its second row underlines both rows, and a click opens all of it. Before,
# each row was a link of its own, and the second, with no "https://", was
# no link at all. An OSC 8 link a program wrapped over two rows (deck does)
# underlined only the row under the pointer.
. "$LIB"
printf '\e[H\e[2J%*shttps://example.com/one/two/three/four/five\n' $((COLS - 20)) ''
printf '\n  \e]8;;https://example.org/a\e\\first part\e]8;;\e\\\n'
printf '  \e]8;;https://example.org/a\e\\second part\e]8;;\e\\\n'
focus
ch=$((H / ROWS)); cw=$((W / COLS))
xdotool mousemove --window "$WIN" $((cw * 5)) $((ch + ch / 2)); settle
case $(colours $((cw * (COLS - 10))) $((cw * (COLS - 10) + 1)) 0 $ch) in
    *ff00ff*) ok "the pointer on the second row underlines the first" ;;
    *)        bad "the pointer on the second row underlines the first: no underline there" ;;
esac
case $(colours $((cw * 5)) $((cw * 5 + 1)) $ch $((2 * ch))) in
    *ff00ff*) ok "and the second row too" ;;
    *)        bad "and the second row too: no underline there" ;;
esac
xdotool mousemove --window "$WIN" $((cw * 5)) $((4 * ch + ch / 2)); settle
case $(colours $((cw * 5)) $((cw * 5 + 1)) $((3 * ch)) $((4 * ch))) in
    *ff00ff*) ok "the pointer on an OSC 8 link's second row underlines its first" ;;
    *)        bad "the pointer on an OSC 8 link's second row underlines its first: no underline there" ;;
esac
