#!/bin/bash
# v0.3.108: a click on an OSC 8 link opens its whole address. glass cut it
# at 511 bytes, and a mail's tracking link (1030 bytes from Spotify) led to
# a "Wrong Link" page. The case points https links at a stand-in opener in
# the scratch home, so no browser starts.
. "$LIB"
mkdir -p "$HOME/.config" "$HOME/.local/share/applications"
rec=$HOME/opened.txt; rm -f "$rec"
printf '#!/bin/sh\nprintf %%s "$1" > %s\n' "$rec" > "$HOME/rec"; chmod +x "$HOME/rec"
printf '[Desktop Entry]\nType=Application\nName=rec\nExec=%s %%u\nMimeType=x-scheme-handler/https;\n' "$HOME/rec" \
    > "$HOME/.local/share/applications/rec.desktop"
printf '[Default Applications]\nx-scheme-handler/https=rec.desktop\n' > "$HOME/.config/mimeapps.list"
url=https://example.org/$(printf 'a%.0s' {1..1000})END
printf '\e[H\e[2J  \e]8;;%s\e\\click here\e]8;;\e\\\n' "$url"
focus
ch=$((H / ROWS)); cw=$((W / COLS))
xdotool mousemove --window "$WIN" $((cw * 5)) $((ch / 2)); settle
xdotool click --window "$WIN" 1
for _ in {1..30}; do [ -s "$rec" ] && break; sleep 0.1; done
got=$(cat "$rec" 2>/dev/null)
is "a click opens the whole long address (${#url} bytes)" "${#got}" "${#url}"
