#!/bin/bash
# v0.3.74: kitty images went up with straight alpha, so a half-clear pixel
# was laid down at full strength and soft edges became hard blobs.
. "$LIB"
paint 1 "$ROWS" 0 0 255
img=$(for _ in {1..16}; do printf '\xff\x00\x00\x80'; done | base64 -w0)
printf '\e[H\e_Ga=T,i=1,f=32,s=4,v=4,c=40,r=10,q=2;%s\e\\' "$img"; settle
p=$(pix 100 60); r=$((16#${p:0:2})); b=$((16#${p:4:2}))
if [ $r -gt 110 ] && [ $r -lt 146 ] && [ $b -gt 110 ] && [ $b -lt 146 ]; then
    ok "half-clear red over blue is half of each"
else
    bad "half-clear red over blue is half of each: got $p"
fi
