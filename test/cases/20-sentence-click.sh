#!/bin/bash
# v0.3.88: three clicks pick the sentence under the pointer and four pick
# the row. Before, three picked the row and a fourth click started over.
. "$LIB"
printf '\e[H\e[2J'
printf '  Opening words here. The second sentence runs on over\n'
printf '  two rows of text. A third one.\n'
printf '\n'
printf -- '- An item with v0.3.87 and glass.asm in it. More.\n'
printf -- '- Another item\n'
printf '12. Det er p\303\245 tide. Neste.\n'
printf '\342\217\272 Behind a symbol. Tail.\n'
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
two='The second sentence runs on over two rows of text.'
is "three clicks pick a sentence over two rows, as one line" "$(clicks 3 30 0)" "$two"
is "clicked on its second row, the same sentence" "$(clicks 3 6 1)" "$two"
is "a dot inside a word ends nothing, and the list mark stays out" "$(clicks 3 8 3)" 'An item with v0.3.87 and glass.asm in it.'
is "a row with no full stop ends before the next list mark" "$(clicks 3 4 4)" 'Another item'
is "a letter outside ASCII ends nothing" "$(clicks 3 6 5)" 'Det er på tide.'
is "a symbol and a space open a row as a list mark does" "$(clicks 3 4 6)" 'Behind a symbol.'
is "four clicks pick the whole row" "$(clicks 4 8 3)" '- An item with v0.3.87 and glass.asm in it. More.'
for ((i = 0; i < ROWS; i++)); do echo filler; done
xdotool key shift+Prior; settle
is "and a sentence in the scrollback" "$(clicks 3 30 0)" "$two"
