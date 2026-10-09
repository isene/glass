#!/bin/bash
# frame v0.1.40: a key held while the window was hidden stayed down for the
# program in it. tile hides a workspace before it moves the keyboard, and
# frame never told the hidden window. A game went on turning after the
# switch back. glass lets go of held keys when it is told (FocusOut).
. "$LIB"
focus
printf '\e[>11u'                          # every key as a code, with press and release
xdotool keydown a; sleep 0.2
xdotool windowunmap "$WIN"; sleep 0.3
keys=; while k=$(ask '' u); [ -n "$k" ]; do keys+="$k "; done
xdotool keyup a
xdotool windowmap "$WIN"
case $keys in
    *'ESC[97;1:3u'*) ok "a held key is let go when the window is hidden" ;;
    *) bad "a held key is let go when the window is hidden: wanted ESC[97;1:3u among '$keys'" ;;
esac
