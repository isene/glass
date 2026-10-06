#!/bin/bash
# v0.3.82: glass ignored focus reports (DECSET 1004). Claude Code then
# believed every window had focus and blinked in all of them.
. "$LIB"
focus; read -r _ _ _ ROOT < <(xpix)
printf '\e[?1004h'
is "focus lost is reported"   "$(xdotool windowfocus "$ROOT"; ask '' O)" 'ESC[O'
is "focus gained is reported" "$(xdotool windowfocus "$WIN"; ask '' I)"  'ESC[I'
xdotool windowfocus "$ROOT"; ask '' O >/dev/null
printf '\e[?1004l'
is "the mode going on without focus says so at once" "$(ask '\e[?1004h' O)" 'ESC[O'
