#!/bin/bash
# v0.3.96: every redraw blended each picture over the screen again, even on
# rows that did not change. A half-clear pixel crept toward full strength
# with each redraw, and the server blended every pixel of the picture each
# time a clock ticked elsewhere on the screen.
. "$LIB"
paint 1 "$ROWS" 0 0 255
img=$(for _ in {1..16}; do printf '\xff\x00\x00\x80'; done | base64 -w0)
printf '\e[H\e_Ga=T,i=1,f=32,s=4,v=4,c=40,r=10,q=2;%s\e\\' "$img"; settle
for i in 1 2 3 4 5; do printf '\e[20;50Htick %d' $i; settle; done
p=$(pix 100 60); r=$((16#${p:0:2})); b=$((16#${p:4:2}))
if [ $r -gt 110 ] && [ $r -lt 146 ] && [ $b -gt 110 ] && [ $b -lt 146 ]; then
    ok "half-clear red stays half of each after five redraws below it"
else
    bad "half-clear red stays half of each after five redraws below it: got $p"
fi
