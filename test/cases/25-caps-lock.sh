#!/bin/bash
# v0.3.92: with caps lock on, glass still typed small letters. It read
# Shift from a key's state and never Lock.
. "$LIB"
focus
# caps 2|0: caps lock on or off, the way ~/bin/toggle-capslock does it
caps() {
    python3 -c 'import ctypes, sys
X = ctypes.cdll.LoadLibrary("libX11.so.6")
X.XOpenDisplay.restype = ctypes.c_void_p
d = ctypes.c_void_p(X.XOpenDisplay(None))
X.XkbLockModifiers(d, 0x100, 2, int(sys.argv[1]))
X.XCloseDisplay(d)' "$1"
    settle
}
# keys K...: type them, print what glass sent
keys() {
    local r=
    xdotool key "$@"
    IFS= read -rs -t 2 -n $# r </dev/tty
    printf '%s' "$r"
}
caps 2
is "with caps lock on, letters are capitals and Shift makes them small" "$(keys a shift+a e 1)" 'AaE1'
caps 0
is "with caps lock off, letters are small again" "$(keys a e)" 'ae'
