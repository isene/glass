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
# Two more pictures in one block, one right of the first and one below it.
# The area glass copies to the window then spans the first picture, and it
# must still show it blended once, not again over itself.
pic() {
    local shm=glass-test-$$-$1
    for _ in {1..16}; do printf '\xff\x00\x00\x80'; done > /dev/shm/$shm
    printf '\e_Ga=t,t=s,i=%d,f=32,s=4,v=4,q=2;%s\e\\' $1 "$(printf %s $shm | base64 -w0)"
    printf '\e[%d;%dH\e_Ga=p,i=%d,c=10,r=3,z=1,q=2,C=1\e\\' $2 $3 $1
}
printf '\e[?2026h%s%s\e[?2026l' "$(pic 2 1 50)" "$(pic 3 12 1)"; settle
p=$(pix 100 60); r=$((16#${p:0:2})); b=$((16#${p:4:2}))
if [ $r -gt 110 ] && [ $r -lt 146 ] && [ $b -gt 110 ] && [ $b -lt 146 ]; then
    ok "and after two more pictures are placed beside it"
else
    bad "and after two more pictures are placed beside it: got $p"
fi
