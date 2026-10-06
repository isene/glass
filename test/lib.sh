# lib.sh: helpers for the cases. A case starts with:  . "$LIB"
exec 2>>"$RESULT.err"
read -r ROWS COLS < <(stty size </dev/tty)

ok()  { echo "ok $*" >> "$RESULT"; }
bad() { echo "FAIL $*" >> "$RESULT"; }
# is NAME GOT WANT: one verdict line
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1: wanted '$3', got '$2'"; fi; }

# ask QUERY END: send QUERY to the terminal and print its answer up to the
# byte END, with the escape byte written as ESC. Prints nothing when no
# answer came within a second.
ask() {
    local r=
    printf '%b' "$1" >/dev/tty
    IFS= read -rs -t 1 -d "$2" r </dev/tty && r+=$2
    printf '%s' "${r//$'\e'/ESC}"
}

# paint FIRST LAST R G B: rows FIRST..LAST (counted from 1) in one colour
paint() {
    local r line
    printf -v line '%*s' "$COLS" ''
    for ((r = $1; r <= $2; r++)); do
        printf '\e[%d;1H\e[48;2;%d;%d;%dm%s\e[0m' "$r" "$3" "$4" "$5" "$line"
    done >/dev/tty
}

settle() { sleep 0.5; }                   # let glass paint what it was sent
pix()    { xpix "$1" "$2"; }              # the colour at a point, as rrggbb
size()   { read -r W H WIN < <(xpix); }   # window size in pixels, and its id
focus()  { size; xdotool windowfocus "$WIN"; sleep 0.2; }

# colours X0 X1 Y0 Y1: every colour found in that box, one rrggbb per line
colours() {
    local pts=() x y
    for ((y = $3; y < $4; y++)); do for ((x = $1; x < $2; x++)); do pts+=("$x" "$y"); done; done
    xpix "${pts[@]}" | sort -u
}
