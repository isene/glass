#!/bin/bash
# v0.3.77: OSC 52 copied 3 KB at most; a longer copy was cut short.
. "$LIB"
printf -v text '%*s' 12000 ''
printf '\e]52;c;%s\a' "$(printf '%s' "${text// /x}" | base64 -w0)"; settle
is "12000 bytes reach the clipboard" "$(xclip -o -selection clipboard | wc -c)" 12000
