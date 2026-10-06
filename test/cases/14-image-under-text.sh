#!/bin/bash
# v0.3.73: a picture with z < 0 drew over the text instead of under it.
. "$LIB"
img=$(for _ in 1 2 3 4; do printf '\xff\x00\x00'; done | base64 -w0)
printf '\e[H\e[2J\e_Ga=T,i=1,f=24,s=2,v=2,c=20,r=3,z=-1,q=2;%s\e\\' "$img"
printf '\e[H\e[38;2;255;255;255mMMMMMMMM\e[0m'; settle
size; seen=$(colours 0 $((W / COLS * 4)) 0 $((H / ROWS)))
case $seen in *ff0000*) ok "the picture is there" ;; *) bad "the picture is there: no red found" ;; esac
case $seen in *ffffff*) ok "the letters sit on top of it" ;; *) bad "the letters sit on top of it: no white found" ;; esac
