#!/bin/bash
# v0.3.86: a picture sent with a=T and no id number was stored and never
# shown. chafa sends its pictures that way.
. "$LIB"
paint 1 "$ROWS" 0 0 0
green=$(for _ in 1 2 3 4; do printf '\x00\xff\x00'; done | base64 -w0)
red=$(for _ in 1 2 3 4; do printf '\xff\x00\x00'; done | base64 -w0)
printf '\e[H\e_Ga=T,f=24,s=2,v=2,c=20,r=5,q=2;%s\e\\' "$green"
# The second one as chafa sends it: the header first, the pixels after.
printf '\e[10;1H\e_Ga=T,f=24,s=2,v=2,c=20,r=5,m=1,q=2\e\\\e_Gm=0;%s\e\\' "$red"; settle
size
ch=$((H / ROWS)); cw=$((W / COLS))
is "a picture with no id is shown"           "$(pix $((cw * 10)) $((ch * 2)))"  00ff00
is "a second one does not replace the first" "$(pix $((cw * 10)) $((ch * 11)))" ff0000
is "and no answer is sent for one" "$(ask "\e[20;1H\e_Ga=T,f=24,s=2,v=2;$green\e\\\\" '\')" ''
