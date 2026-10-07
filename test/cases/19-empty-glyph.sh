#!/bin/bash
# v0.3.87: glass died when it drew U+034F (COMBINING GRAPHEME JOINER). The
# character has a glyph with nothing in it, and the glyph engine gave such a
# glyph a junk size. From Symbola that was 9822 by 1024 pixels, and glass
# read far outside its bitmap. The character is written as octal bytes on
# purpose: the real thing in this file would kill an old glass that shows it.
. "$LIB"
printf 'a\315\217b\n' >/dev/tty
settle
is "glass still answers after drawing an empty glyph" "$(ask '\e[c' c)" 'ESC[?62;22c'
