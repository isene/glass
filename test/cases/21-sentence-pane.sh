#!/bin/bash
# v0.3.89: a sentence stays inside its pane. In a pane with a box line
# around it, three clicks took the blank cells out to the line, and the
# sentence stopped at the row's end: the line counted as text.
. "$LIB"
printf '\e[H\e[2J'
printf 'left.txt   \342\224\202 - Sign in with the password. Do not          \342\224\202\n'
printf 'other.txt  \342\224\202   pick "Sign in". The mail runs through it,  \342\224\202\n'
printf 'third.txt  \342\224\202   but the account has its own password.      \342\224\202\n'
printf '\n'
# Two long lines that glass wraps itself. The space between the words
# sits in the last col of the first, and in col 0 of the row below in
# the second.
printf -v x '%*s' $((COLS - 1)) ''; x=${x// /x}
printf '%s tail end. More.\n' "$x"
printf '%sx tail end. More.\n' "$x"
focus
ch=$((H / ROWS)); cw=$((W / COLS))
# clicks N COL ROW: N clicks on that cell (counted from 0). Prints what was
# picked, with the spaces at its end cut.
clicks() {
    local t
    xdotool mousemove --window "$WIN" $((cw * $2 + cw / 2)) $((ch * $3 + ch / 2)) click --repeat "$1" --delay 60 1
    settle
    t=$(timeout 2 xclip -o -selection primary)
    printf '%s' "${t%"${t##*[! ]}"}"
}
at() { pix $((cw * $1 + cw / 2)) $((ch * $2 + ch / 2)); }   # the colour of cell COL ROW
is "a sentence runs on to the next row of its pane" "$(clicks 3 36 1)" 'The mail runs through it, but the account has its own password.'
is "the blank cells behind the row's text are not marked" "$(at 57 1)" "$(at 57 3)"
is "nor are the cells of the pane to the left" "$(at 9 2)" "$(at 9 3)"
is "and it starts on the row above, behind the full stop there" "$(clicks 3 16 1)" 'Do not pick "Sign in".'
is "a wrapped line keeps the space in its last col" "$(clicks 3 5 4)" "$x tail end."
is "and the space in col 0 of the next row" "$(clicks 3 5 6)" "${x}x tail end."
