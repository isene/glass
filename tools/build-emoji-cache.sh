#!/bin/bash
# Pre-render the bundled emoji cache for glass.
#
# Usage:  ./tools/build-emoji-cache.sh [WIDTH HEIGHT]
#
# Each emoji codepoint listed in tools/common-emoji.txt is rasterized
# at WIDTHxHEIGHT pixels (defaults to 12x13 — the cell size for the
# default font) using ImageMagick + Noto Color Emoji, and written to
# cache/<HEX>-WxH.rgba. glass loads these directly via XRender at
# runtime, skipping the per-emoji ~70ms convert fork on first use.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="$SCRIPT_DIR/common-emoji.txt"
OUT_DIR="$SCRIPT_DIR/../cache"

W="${1:-12}"
H="${2:-13}"
SIZE="${W}x${H}"
PT=$((H * 700))

mkdir -p "$OUT_DIR"

if ! command -v convert >/dev/null; then
    echo "error: ImageMagick 'convert' not found in PATH" >&2
    exit 1
fi

FONT_PATH="/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"
if [ ! -f "$FONT_PATH" ]; then
    echo "warn: $FONT_PATH not found; pango will fall back to fontconfig" >&2
fi

count=0
skip=0
total=$(grep -cv '^#\|^$' "$LIST")

while read -r CP; do
    case "$CP" in
        ''|\#*) continue ;;
    esac
    HEX=$(printf '%08X' "0x$CP")
    OUT="$OUT_DIR/$HEX-${SIZE}.rgba"
    if [ -f "$OUT" ]; then
        skip=$((skip + 1))
        continue
    fi
    EMOJI=$(printf "\\U$CP")
    convert -size "$SIZE" -background none \
        "pango:<span font_family='Noto Color Emoji' size='$PT'>$EMOJI</span>" \
        -depth 8 "rgba:$OUT" 2>/dev/null || {
        echo "warn: convert failed for U+$CP" >&2
        continue
    }
    count=$((count + 1))
    if [ $((count % 50)) -eq 0 ]; then
        echo "  ... $count rendered ($skip cached)"
    fi
done < "$LIST"

echo "Done: $count newly rendered, $skip already cached, total list $total."
echo "Output: $OUT_DIR (size ${SIZE})"
ls -la "$OUT_DIR" | head -3
du -sh "$OUT_DIR"
