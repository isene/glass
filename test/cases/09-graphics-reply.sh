#!/bin/bash
# v0.3.67: glass never answered a kitty graphics command, so a program
# could not find out whether the terminal shows pictures.
. "$LIB"
is "a sent picture is answered with OK" \
   "$(ask '\e_Gi=31,a=t,f=24,s=1,v=1;AAAA\e\\' '\')" 'ESC_Gi=31;OKESC\'
