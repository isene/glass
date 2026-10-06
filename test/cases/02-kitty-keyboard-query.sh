#!/bin/bash
# v0.3.69: the kitty keyboard query CSI ? u got no answer, and pushed flags
# were not kept.
. "$LIB"
is "the flags start at 0"  "$(ask '\e[?u' u)" 'ESC[?0u'
printf '\e[>3u'
is "a push of 3 is kept"   "$(ask '\e[?u' u)" 'ESC[?3u'
printf '\e[<u'
is "a pop goes back to 0"  "$(ask '\e[?u' u)" 'ESC[?0u'
