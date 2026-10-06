#!/bin/bash
# v0.3.72: only kitty keyboard flags 1 and 2 worked. Flag 8 (every key as
# an escape code) and flag 4 (the shifted key rides along) did nothing.
. "$LIB"
focus
printf '\e[>8u'
is "flag 8: Enter comes as an escape code" "$(xdotool key Return; ask '' u)" 'ESC[13u'
printf '\e[<u\e[>12u'
xdotool key shift+b
keys=; while k=$(ask '' u); [ -n "$k" ]; do keys+="$k "; done
case $keys in
    *'ESC[98:66;2u'*) ok "flags 4+8: Shift+b carries the shifted key" ;;
    *) bad "flags 4+8: Shift+b carries the shifted key: wanted ESC[98:66;2u among '$keys'" ;;
esac
