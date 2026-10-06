#!/bin/bash
# v0.3.70: glass dropped CSI c and CSI > c. A Rust TUI built on crossterm
# asks at start and waits for the answer with no timeout, so it hung.
. "$LIB"
is "CSI c answers as a VT220 with colour" "$(ask '\e[c' c)"  'ESC[?62;22c'
is "CSI > c answers"                      "$(ask '\e[>c' c)" 'ESC[>1;10;0c'
