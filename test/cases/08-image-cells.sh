#!/bin/bash
# v0.3.68: a picture sent with a=T ignored c and r, so a small game frame
# stayed small instead of filling its cells.
. "$LIB"
paint 1 "$ROWS" 0 0 0
img=$(for _ in 1 2 3 4; do printf '\x00\xff\x00'; done | base64 -w0)
printf '\e[H\e_Ga=T,i=1,f=24,s=2,v=2,c=40,r=10,q=2;%s\e\\' "$img"; settle
size
is "a 2x2 picture fills the 40x10 cells it was given" \
   "$(pix $((W / COLS * 20)) $((H / ROWS * 5)))" 00ff00
