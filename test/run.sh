#!/bin/bash
# run.sh [CASE...]: run the cases in cases/, each in its own glass window on
# a scratch frame. It never touches the display you are sitting at.
#
#   GLASS=path   the glass to test (default: the one in this repo)
#   FRAME=path   the frame to show it on (default: ../frame/frame, else PATH)
#
# A case is a bash script that runs INSIDE glass, as its -e program. It
# talks to the terminal, reads pixels back with xpix, and writes "ok ..."
# or "FAIL ..." lines to $RESULT. lib.sh has the helpers.
#
# Needs gcc, libx11-dev, xdotool, xclip and ImageMagick (glass decodes a PNG
# with convert).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
GLASS=${GLASS:-$HERE/../glass}
FRAME=${FRAME:-$HERE/../../frame/frame}
[ -x "$FRAME" ] || FRAME=$(command -v frame) || { echo "no frame found: set FRAME=path"; exit 2; }
[ -x "$GLASS" ] || { echo "no glass at $GLASS: run make"; exit 2; }

T=$(mktemp -d); mkdir "$T/home" "$T/bin"
cp "$HERE/glassrc" "$T/home/.glassrc"
gcc -O1 -o "$T/bin/xpix" "$HERE/xpix.c" -lX11 || { echo "xpix did not build"; exit 2; }

D=23; while [ -e /tmp/.X11-unix/X$D ]; do D=$((D + 1)); done
"$FRAME" $D --fbtest --noinput >"$T/frame.log" 2>&1 &
FPID=$!
trap 'kill $FPID 2>/dev/null; rm -rf "$T" /tmp/.X11-unix/X$D' EXIT
for _ in {1..25}; do [ -S /tmp/.X11-unix/X$D ] && break; sleep 0.2; done

fail=0
for c in "$HERE"/cases/*.sh; do
    name=$(basename "$c" .sh)
    [ $# -gt 0 ] && [[ " $* " != *" $name "* ]] && continue
    res=$T/$name.res
    HOME=$T/home PATH=$T/bin:$PATH DISPLAY=:$D RESULT=$res LIB=$HERE/lib.sh \
        "$GLASS" -e "$c" >"$T/$name.log" 2>&1 &
    gp=$!
    for _ in {1..150}; do kill -0 $gp 2>/dev/null || break; sleep 0.1; done
    if kill -0 $gp 2>/dev/null; then
        kill $gp; echo "FAIL the case did not finish in 15 s" >> "$res"
    fi
    wait $gp 2>/dev/null
    [ -s "$res" ] || echo "FAIL no verdict: glass died or the case never ran" > "$res"
    while read -r verdict text; do
        [ "$verdict" = ok ] || { fail=1; cat "$res.err" 2>/dev/null; }
        printf '  %-5s %s: %s\n' "$verdict" "$name" "$text"
    done < "$res"
done
[ $fail = 0 ] && echo "glass tests: all good" || echo "glass tests: FAILED"
exit $fail
