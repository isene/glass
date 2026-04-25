# Future config keys (glass)

Pragmatic hardcodes in `glass.asm` that work fine today but could be
exposed in `~/.glassrc` later if anyone needs to tune them. Listed
roughly in order of "most likely to actually want this exposed".

## Codepoint substitution table

**Where:** `glass.asm`, function `ttf_upload_glyph`, around the
`.try_other_subs` / `.try_sub_23f5` / `.try_sub_23f4` chain.

**What it does:** When the embedded TTF engine reports a codepoint as
missing in the active font, glass tries one substitute codepoint that
is visually equivalent and known to exist in DejaVu Sans Mono:

| Missing | Substitute | Reason                                               |
|---------|------------|------------------------------------------------------|
| U+23BF ⎿ | U+2514 └ | DejaVu lacks tree-corner; CC uses ⎿                  |
| U+23BC ⎼ | U+2500 ─ | DejaVu lacks horizontal-7; CC uses ⎼                 |
| U+23F5 ⏵ | U+25B6 ▶ | DejaVu lacks medium-triangle; CC uses ⏵              |
| U+23F4 ⏴ | U+25C0 ◀ | symmetry with U+23F5                                 |

**Why config-worthy:** Different fonts have different gaps. A user with
a Nerd Font that already covers all these would still get the
substitution silently, which is harmless but wasteful. A user on a
font that lacks DIFFERENT codepoints would want to add their own
subs.

**Migration sketch:** A `~/.glassrc` syntax like
`subst_glyph = 0x23BF -> 0x2514`, parsed into a small `dq` table at
load time. The current `cmp/jne/jz` chain becomes a loop over the
table. Cost: ~1 cache line; negligible.

**Why not yet:** 4 substitutions, all driven by Claude Code emitting
specific glyphs that DejaVu lacks. Nobody else has hit this.

## Blank-class codepoint list

**Where:** `glass.asm`, `ttf_upload_glyph` `.have_size` block — chain
of `cmp rbx, X / je .blank_glyph` for SPACE (0x20), NBSP (0xA0), and
the standard Unicode space variants U+2007..U+200B, U+202F, U+205F,
U+3000.

**What it does:** Forces these codepoints to upload as a 0×0 glyph
(advance only, no mask) so they paint nothing — bypassing the X
server's default-glyph placeholder for any of these the active font
might lack.

**Why config-worthy:** This is a fixed Unicode list, but it's hardcoded
as a `cmp` chain. Doesn't need configuration, but if more space-class
codepoints turn out to need this treatment, a `dq` table is cleaner.

**Migration sketch:** Convert the chain to a loop over a static `dq`
list. Only worth doing if the list grows.

## Empty-glyph fallback bitmap

**Where:** `glass.asm`, `ttf_upload_glyph` `.empty_glyph` block.

**What it does:** When the engine returns missing AND no substitute
matches, uploads a 1×1 fully-transparent glyph (W=1, H=1, alpha=0).
This was W=H=0 originally; the X server's default-glyph behaviour
under at least one server build still painted the placeholder for
zero-area glyphs, so 1×1 transparent is the safe minimum.

**Why config-worthy:** Not really. The 1×1 transparent is a
universally-correct choice. Documented for archaeology only — if the
artifact returns, this is the first place to look.

## Default font size

**Where:** `glass.asm` line 460, `DEFAULT_FONT_SIZE equ 15`.

**What it does:** Initial font size when `~/.glassrc` doesn't specify
`font_size = N`.

**Why config-worthy:** Already overridable via `~/.glassrc`. The source
default is the fallback when no rc file exists.

**Migration sketch:** N/A — already config-driven.
