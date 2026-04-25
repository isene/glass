; glass - Pure assembly terminal emulator
; Part of CHasm (CHange to ASM)
; x86_64 Linux, NASM syntax, no libc, pure syscalls
; Talks X11 wire protocol directly via Unix socket

; ══════════════════════════════════════════════════════════════════════
; Syscall numbers
; ══════════════════════════════════════════════════════════════════════
%define SYS_READ        0
%define SYS_WRITE       1
%define SYS_OPEN        2
%define SYS_CLOSE       3
%define SYS_POLL        7
%define SYS_MMAP        9
%define SYS_MUNMAP      11
%define SYS_IOCTL       16
%define SYS_DUP2        33
%define SYS_SOCKET      41
%define SYS_CONNECT     42
%define SYS_FORK        57
%define SYS_EXECVE      59
%define SYS_EXIT        60
%define SYS_WAIT4       61
%define SYS_KILL        62
%define SYS_SETSID      112
%define SYS_CLOCK_GETTIME 228
%define SYS_PIPE         22
%define SYS_MKDIR        83
%define SYS_CREAT        85

; ══════════════════════════════════════════════════════════════════════
; Constants
; ══════════════════════════════════════════════════════════════════════
%define AF_UNIX         1
%define SOCK_STREAM     1
%define O_RDWR          2
%define O_RDONLY         0
%define O_WRONLY         1
%define O_CREAT          0o100
%define O_TRUNC          0o1000
%define POLLIN          1
%define SIGWINCH        28

; PTY ioctls
%define TIOCSPTLCK      0x40045431
%define TIOCGPTN        0x80045430
%define TIOCSCTTY       0x540E
%define TIOCSWINSZ      0x5414

; X11 opcodes
%define X11_CREATE_WINDOW     1
%define X11_CHANGE_WINDOW_ATTRS 2
%define X11_MAP_WINDOW        8
%define X11_INTERN_ATOM       16
%define X11_CHANGE_PROPERTY   18
%define X11_OPEN_FONT         45
%define X11_CLOSE_FONT        46
%define X11_QUERY_FONT        47
%define X11_CREATE_GC         55
%define X11_CHANGE_GC         56
%define X11_CLEAR_AREA        61
%define X11_POLY_FILL_RECT    70
%define X11_IMAGE_TEXT8       76
%define X11_IMAGE_TEXT16      77
%define X11_GET_KEYBOARD_MAPPING 101
%define X11_SET_SELECTION_OWNER 22
%define X11_CONVERT_SELECTION 24
%define X11_SEND_EVENT        25
%define X11_CHANGE_WINDOW_ATTRS2 2
%define X11_GET_PROPERTY      20
%define X11_GET_GEOMETRY      14
%define X11_CREATE_COLORMAP   78
%define X11_GET_IMAGE         73
%define X11_GET_SELECTION_OWNER 23
%define X11_TRANSLATE_COORDINATES 40
%define X11_CREATE_PIXMAP     53
%define X11_FREE_PIXMAP       54
%define X11_PUT_IMAGE         72
%define X11_POLY_TEXT_16      75
%define X11_QUERY_EXTENSION   98
%define CW_BACK_PIXMAP        0x00000001

; XRender extension minor opcodes (sent with major = render_major_opcode)
%define RENDER_QUERY_VERSION         0
%define RENDER_QUERY_PICT_FORMATS    1
%define RENDER_CREATE_PICTURE        4
%define RENDER_FREE_PICTURE          7
%define RENDER_COMPOSITE             8
%define RENDER_CREATE_GLYPH_SET      17
%define RENDER_FREE_GLYPH_SET        19
%define RENDER_ADD_GLYPHS            20
%define RENDER_COMPOSITE_GLYPHS_32   25
%define RENDER_FILL_RECTANGLES       26
%define RENDER_SET_PICTURE_TRANSFORM 28
%define RENDER_OP_OVER               3
%define RENDER_OP_SRC                1

; Kitty graphics protocol
%define APC_BODY_MAX        16384            ; one APC body cap (glow chunks ~4K)
%define APC_PAYLOAD_MAX     16777216         ; 16MB accumulator for base64 chunks
%define IMG_SLOTS           32
%define IMG_SLOT_SIZE       32
%define PLACE_SLOTS         32
%define PLACE_SLOT_SIZE     16
%define MAX_IMG_DIM         8192             ; sanity cap on width/height
%define IMG_DECODE_MAX      67108864         ; 64MB max decoded RGBA
%define MMAP_PROT_RW        3
%define MMAP_FLAGS_PRIV     0x22             ; MAP_PRIVATE | MAP_ANONYMOUS

; X11 event types
%define EV_KEY_PRESS        2
%define EV_KEY_RELEASE      3
%define EV_EXPOSE           12
%define EV_CONFIGURE_NOTIFY 22
%define EV_CLIENT_MESSAGE   33
%define EV_BUTTON_PRESS     4
%define EV_BUTTON_RELEASE   5
%define EV_MOTION_NOTIFY    6
%define EV_FOCUS_IN         9
%define EV_FOCUS_OUT        10
%define EV_SELECTION_REQUEST 30
%define EV_SELECTION_NOTIFY  31

; X11 masks
%define KEY_PRESS_MASK      0x00000001
%define EXPOSURE_MASK       0x00008000
%define STRUCTURE_NOTIFY_MASK 0x00020000
%define FOCUS_CHANGE_MASK   0x00200000
; BUTTON_PRESS(0x4) | BUTTON_RELEASE(0x8) | BUTTON_MOTION(0x2000)
; | KEY_PRESS(0x1) | EXPOSURE(0x8000) | STRUCTURE(0x20000) | FOCUS(0x200000)
%define EVENT_MASK_ALL      0x0022A00D

; CreateWindow value mask bits
%define CW_BACK_PIXEL       0x00000002
%define CW_BORDER_PIXEL     0x00000008
%define CW_EVENT_MASK       0x00000800
%define CW_COLORMAP         0x00002000

; CreateGC value mask bits
%define GC_FOREGROUND       0x00000004
%define GC_BACKGROUND       0x00000008
%define GC_FONT             0x00004000

; Terminal defaults
%define DEFAULT_COLS    80
%define DEFAULT_ROWS    24
%define MAX_COLS        400
%define MAX_ROWS        128
%define CELL_SIZE       16
; Cell layout (16 bytes):
;   [0-1]   char (UCS-2 low 16 bits)
;   [2]     fg flags (bit 0 = use default fg from palette[7])
;   [3]     bg flags (bit 0 = use default bg from palette[0])
;   [4]     attrs (bold/underline/inverse bits)
;   [5]     osc8 link id (0 = none)
;   [6-7]   reserved (zero)
;   [8-11]  fg pixel (32-bit ARGB; ignored when fg-default flag set)
;   [12-15] bg pixel (32-bit ARGB; ignored when bg-default flag set)
;
; DEFAULT_CELL_LO: char=space, both default flags set, attrs=0, osc8=0.
; Kept inside 32-bit signed range so it fits a `mov qword [mem], imm32`
; without warnings (avoids reload via register at every clear site).
%define DEFAULT_CELL_LO 0x0000000001010020

; VT parser states
%define VT_NORMAL       0
%define VT_ESC          1
%define VT_CSI          2
%define VT_CSI_PARAM    3
%define VT_OSC          4
%define VT_CHARSET      5    ; consume one charset designator byte, then VT_NORMAL
%define VT_STRING       6    ; DCS/PM body: discard bytes until ST (ESC \) or BEL
%define VT_APC          7    ; APC body: capture into apc_body, dispatch on ST/BEL

; ══════════════════════════════════════════════════════════════════════
; Data section
; ══════════════════════════════════════════════════════════════════════
section .data

; X11 auth
auth_name:      db "MIT-MAGIC-COOKIE-1"
auth_name_len   equ 18

; X11 socket path template
x11_sock_pre:   db "/tmp/.X11-unix/X", 0

; Font name (Unicode BMP fixed font)
font_name:      db "-misc-fixed-medium-r-semicondensed--13-120-75-75-c-60-iso10646-1", 0
font_name_len   equ 64

; WM atom names
wm_protocols_str: db "WM_PROTOCOLS", 0
wm_protocols_len  equ 12
wm_delete_str:  db "WM_DELETE_WINDOW", 0
wm_delete_len   equ 16
tile_shell_pid_str: db "_TILE_SHELL_PID", 0
tile_shell_pid_len  equ 15

; XRender extension name (used by QueryExtension)
render_ext_str:   db "RENDER", 0
render_ext_len    equ 6

; Disk cache for rasterized emoji. Files live in
; $HOME/.cache/glass/emoji/<HEX_CODEPOINT>-<W>x<H>.rgba and contain
; raw RGBA bytes at the current cell size. Lookups skip the ~70ms
; fork+exec convert pipeline; first-time renders write to the cache
; so subsequent glass sessions are instant.
emoji_cache_dir_suffix:  db "/.cache/glass/emoji", 0
emoji_cache_glass:       db "/.cache/glass", 0
emoji_cache_dotcache:    db "/.cache", 0

; System-wide bundled cache installed by `make install`. Glass falls
; back to this when a glyph isn't in the user's per-session cache yet,
; so a fresh user gets instant rendering for the standard emoji set
; without paying the convert fork cost on first sight.
emoji_sys_cache_dir:     db "/usr/local/share/glass/emoji", 0

; convert(1) command for emoji rasterization. Each emoji render forks
; convert with these argv pointers patched per-codepoint (size_arg
; and pango_arg are filled in BSS before fork). Output is raw RGBA
; bytes on stdout (depth 8, 4 bytes per pixel).
convert_path:     db "/usr/bin/convert", 0
convert_arg_size: db "-size", 0
convert_arg_bg:   db "-background", 0
convert_arg_none: db "none", 0
convert_arg_depth:db "-depth", 0
convert_arg_8:    db "8", 0
convert_arg_rgba: db "RGBA:-", 0
; PNG → RGBA conversion for kitty graphics: `convert png:- rgba:-`
convert_arg_png_in: db "png:-", 0
convert_arg_rgba_lower: db "rgba:-", 0

; Advertised TERM for the child shell. Set to xterm-kitty so apps
; (glow, ueberzug, etc.) detect that glass supports kitty graphics.
; Change from xterm-256color happens once image display is wired up.
kitty_term_env: db "TERM=xterm-kitty", 0
; _GLASS_ID= identifies glass specifically so apps that want to test
; for glass (vs. real kitty) can branch. Not yet used by any known
; client, but cheap to advertise.
glass_id_env: db "_GLASS_ID=1", 0

; Selection atom names
clipboard_str:    db "CLIPBOARD", 0
clipboard_len     equ 9
utf8_string_str:  db "UTF8_STRING", 0
utf8_string_len   equ 11
targets_str:      db "TARGETS", 0
targets_len       equ 7
glass_sel_str:    db "GLASS_SEL", 0
glass_sel_len     equ 9
xrootpmap_str:    db "_XROOTPMAP_ID", 0
xrootpmap_len     equ 13
netwm_cm_str:     db "_NET_WM_CM_S0", 0
netwm_cm_len      equ 13

; Dead-keysym → printable Unicode codepoint table. Indexed by
; (keysym - 0xFE50). Values are UCS-2 codepoints (all fit in 16 bits
; — the spacing equivalents live in U+0060..U+037A). Zero means "no
; printable equivalent, drop the keystroke".
dead_to_ucs:
    dw 0x0060   ; FE50 dead_grave            → `
    dw 0x00B4   ; FE51 dead_acute            → ´
    dw 0x005E   ; FE52 dead_circumflex       → ^
    dw 0x007E   ; FE53 dead_tilde            → ~
    dw 0x00AF   ; FE54 dead_macron           → ¯
    dw 0x02D8   ; FE55 dead_breve            → ˘
    dw 0x02D9   ; FE56 dead_abovedot         → ˙
    dw 0x00A8   ; FE57 dead_diaeresis        → ¨
    dw 0x02DA   ; FE58 dead_abovering        → ˚
    dw 0x02DD   ; FE59 dead_doubleacute      → ˝
    dw 0x02C7   ; FE5A dead_caron            → ˇ
    dw 0x00B8   ; FE5B dead_cedilla          → ¸
    dw 0x02DB   ; FE5C dead_ogonek           → ˛
    dw 0x037A   ; FE5D dead_iota             → ͺ
    dw 0       ; FE5E dead_voiced_sound      (no spacing equivalent)
    dw 0       ; FE5F dead_semivoiced_sound  (no spacing equivalent)
    dw 0       ; FE60 dead_belowdot          (combining only)
    dw 0       ; FE61 dead_hook
    dw 0       ; FE62 dead_horn
    dw 0       ; FE63
    dw 0       ; FE64
    dw 0       ; FE65
    dw 0       ; FE66
    dw 0       ; FE67
    dw 0       ; FE68
    dw 0       ; FE69
    dw 0       ; FE6A
    dw 0       ; FE6B
    dw 0       ; FE6C
    dw 0       ; FE6D
    dw 0       ; FE6E
    dw 0       ; FE6F
    dw 0       ; FE70
    dw 0       ; FE71
    dw 0       ; FE72
    dw 0       ; FE73
    dw 0       ; FE74
    dw 0       ; FE75
    dw 0       ; FE76
    dw 0       ; FE77
    dw 0       ; FE78
    dw 0       ; FE79
    dw 0       ; FE7A
    dw 0       ; FE7B
    dw 0       ; FE7C
    dw 0       ; FE7D
    dw 0       ; FE7E
    dw 0       ; FE7F

; Dead-key composition table. Each entry is one dword:
;   bits  0..7  = dead-key offset (keysym - 0xFE50)
;   bits  8..15 = base ASCII keysym (e.g. 'a', 'O', ' ')
;   bits 16..31 = composed Unicode codepoint (UCS-2)
; Sentinel (0) terminates. Linear scan — fast enough at ~50 entries.
;
; Format helper macro: dead_off + base<<8 + composed<<16.
%define COMP(d,b,c)  (d) | ((b) << 8) | ((c) << 16)
compose_table:
    ; ─── dead_diaeresis (0x07): ¨ ───────────────────────────────
    dd COMP(0x07, 'a', 0x00E4)      ; ä
    dd COMP(0x07, 'A', 0x00C4)      ; Ä
    dd COMP(0x07, 'e', 0x00EB)      ; ë
    dd COMP(0x07, 'E', 0x00CB)      ; Ë
    dd COMP(0x07, 'i', 0x00EF)      ; ï
    dd COMP(0x07, 'I', 0x00CF)      ; Ï
    dd COMP(0x07, 'o', 0x00F6)      ; ö
    dd COMP(0x07, 'O', 0x00D6)      ; Ö
    dd COMP(0x07, 'u', 0x00FC)      ; ü
    dd COMP(0x07, 'U', 0x00DC)      ; Ü
    dd COMP(0x07, 'y', 0x00FF)      ; ÿ
    dd COMP(0x07, 'Y', 0x0178)      ; Ÿ
    ; ─── dead_acute (0x01): ´ ──────────────────────────────────
    dd COMP(0x01, 'a', 0x00E1)      ; á
    dd COMP(0x01, 'A', 0x00C1)      ; Á
    dd COMP(0x01, 'e', 0x00E9)      ; é
    dd COMP(0x01, 'E', 0x00C9)      ; É
    dd COMP(0x01, 'i', 0x00ED)      ; í
    dd COMP(0x01, 'I', 0x00CD)      ; Í
    dd COMP(0x01, 'o', 0x00F3)      ; ó
    dd COMP(0x01, 'O', 0x00D3)      ; Ó
    dd COMP(0x01, 'u', 0x00FA)      ; ú
    dd COMP(0x01, 'U', 0x00DA)      ; Ú
    dd COMP(0x01, 'y', 0x00FD)      ; ý
    dd COMP(0x01, 'Y', 0x00DD)      ; Ý
    dd COMP(0x01, 'c', 0x0107)      ; ć
    dd COMP(0x01, 'C', 0x0106)      ; Ć
    dd COMP(0x01, 'n', 0x0144)      ; ń
    dd COMP(0x01, 'N', 0x0143)      ; Ń
    dd COMP(0x01, 's', 0x015B)      ; ś
    dd COMP(0x01, 'S', 0x015A)      ; Ś
    dd COMP(0x01, 'z', 0x017A)      ; ź
    dd COMP(0x01, 'Z', 0x0179)      ; Ź
    ; ─── dead_grave (0x00): ` ──────────────────────────────────
    dd COMP(0x00, 'a', 0x00E0)      ; à
    dd COMP(0x00, 'A', 0x00C0)      ; À
    dd COMP(0x00, 'e', 0x00E8)      ; è
    dd COMP(0x00, 'E', 0x00C8)      ; È
    dd COMP(0x00, 'i', 0x00EC)      ; ì
    dd COMP(0x00, 'I', 0x00CC)      ; Ì
    dd COMP(0x00, 'o', 0x00F2)      ; ò
    dd COMP(0x00, 'O', 0x00D2)      ; Ò
    dd COMP(0x00, 'u', 0x00F9)      ; ù
    dd COMP(0x00, 'U', 0x00D9)      ; Ù
    ; ─── dead_circumflex (0x02): ^ ─────────────────────────────
    dd COMP(0x02, 'a', 0x00E2)      ; â
    dd COMP(0x02, 'A', 0x00C2)      ; Â
    dd COMP(0x02, 'e', 0x00EA)      ; ê
    dd COMP(0x02, 'E', 0x00CA)      ; Ê
    dd COMP(0x02, 'i', 0x00EE)      ; î
    dd COMP(0x02, 'I', 0x00CE)      ; Î
    dd COMP(0x02, 'o', 0x00F4)      ; ô
    dd COMP(0x02, 'O', 0x00D4)      ; Ô
    dd COMP(0x02, 'u', 0x00FB)      ; û
    dd COMP(0x02, 'U', 0x00DB)      ; Û
    ; ─── dead_tilde (0x03): ~ ──────────────────────────────────
    dd COMP(0x03, 'a', 0x00E3)      ; ã
    dd COMP(0x03, 'A', 0x00C3)      ; Ã
    dd COMP(0x03, 'n', 0x00F1)      ; ñ
    dd COMP(0x03, 'N', 0x00D1)      ; Ñ
    dd COMP(0x03, 'o', 0x00F5)      ; õ
    dd COMP(0x03, 'O', 0x00D5)      ; Õ
    ; ─── dead_caron (0x0A): ˇ ──────────────────────────────────
    dd COMP(0x0A, 'c', 0x010D)      ; č
    dd COMP(0x0A, 'C', 0x010C)      ; Č
    dd COMP(0x0A, 's', 0x0161)      ; š
    dd COMP(0x0A, 'S', 0x0160)      ; Š
    dd COMP(0x0A, 'z', 0x017E)      ; ž
    dd COMP(0x0A, 'Z', 0x017D)      ; Ž
    ; ─── dead_doubleacute (0x09): ˝ ────────────────────────────
    dd COMP(0x09, 'o', 0x0151)      ; ő
    dd COMP(0x09, 'O', 0x0150)      ; Ő
    dd COMP(0x09, 'u', 0x0171)      ; ű
    dd COMP(0x09, 'U', 0x0170)      ; Ű
    ; ─── dead_cedilla (0x0B): ¸ ────────────────────────────────
    dd COMP(0x0B, 'c', 0x00E7)      ; ç
    dd COMP(0x0B, 'C', 0x00C7)      ; Ç
    dd 0                              ; sentinel

; Window title
win_title:      db "glass", 0
win_title_len   equ 5

; WM_CLASS
wm_class:       db "glass", 0, "Glass", 0
wm_class_len    equ 12

; Bracketed paste sequences
bracket_paste_start: db 27, "[200~"
bracket_paste_start_len equ 6
bracket_paste_end:   db 27, "[201~"
bracket_paste_end_len equ 6

; Font size lookup table: size, dpi_size, width, name string
; Format: each entry = font name string (null-terminated)
font_10: db "-misc-fixed-medium-r-normal--10-100-75-75-c-60-iso10646-1", 0
font_10_len equ $ - font_10 - 1
font_13: db "-misc-fixed-medium-r-semicondensed--13-120-75-75-c-60-iso10646-1", 0
font_13_len equ $ - font_13 - 1
font_15: db "-misc-fixed-medium-r-normal--15-140-75-75-c-90-iso10646-1", 0
font_15_len equ $ - font_15 - 1
font_18: db "-misc-fixed-medium-r-normal--18-120-100-100-c-90-iso10646-1", 0
font_18_len equ $ - font_18 - 1
font_20: db "-misc-fixed-medium-r-normal--20-200-75-75-c-100-iso10646-1", 0
font_20_len equ $ - font_20 - 1

; Larger Terminus presets — much more legible than misc-fixed at the
; same point size. Available wherever the `xfonts-terminus` package
; is installed (Debian/Ubuntu, Arch, Fedora).
font_22: db "-xos4-terminus-medium-r-normal--22-220-72-72-c-110-iso10646-1", 0
font_22_len equ $ - font_22 - 1
font_24: db "-xos4-terminus-medium-r-normal--24-240-72-72-c-120-iso10646-1", 0
font_24_len equ $ - font_24 - 1
font_28: db "-xos4-terminus-medium-r-normal--28-280-72-72-c-140-iso10646-1", 0
font_28_len equ $ - font_28 - 1
font_32: db "-xos4-terminus-medium-r-normal--32-320-72-72-c-160-iso10646-1", 0
font_32_len equ $ - font_32 - 1

; Bold companions. Same metrics (cell width / height) as the medium
; XLFDs above so the grid stays aligned. font_10 and font_20 have no
; bold variant at the same metrics; SGR 1 falls back to medium for
; those sizes.
font_13_bold: db "-misc-fixed-bold-r-semicondensed--13-120-75-75-c-60-iso10646-1", 0
font_13_bold_len equ $ - font_13_bold - 1
font_15_bold: db "-misc-fixed-bold-r-normal--15-140-75-75-c-90-iso10646-1", 0
font_15_bold_len equ $ - font_15_bold - 1
font_18_bold: db "-misc-fixed-bold-r-normal--18-120-100-100-c-90-iso10646-1", 0
font_18_bold_len equ $ - font_18_bold - 1
font_22_bold: db "-xos4-terminus-bold-r-normal--22-220-72-72-c-110-iso10646-1", 0
font_22_bold_len equ $ - font_22_bold - 1
font_24_bold: db "-xos4-terminus-bold-r-normal--24-240-72-72-c-120-iso10646-1", 0
font_24_bold_len equ $ - font_24_bold - 1
font_28_bold: db "-xos4-terminus-bold-r-normal--28-280-72-72-c-140-iso10646-1", 0
font_28_bold_len equ $ - font_28_bold - 1
font_32_bold: db "-xos4-terminus-bold-r-normal--32-320-72-72-c-160-iso10646-1", 0
font_32_bold_len equ $ - font_32_bold - 1

; Ordered preset table for Alt+plus / Alt+minus stepping.
font_size_presets: dq 10, 13, 15, 18, 20, 22, 24, 28, 32
FONT_SIZE_PRESET_COUNT equ 9
DEFAULT_FONT_SIZE equ 13         ; fallback when no font_size in .glassrc

; Fallback font: covers the entire Unicode BMP (16x16 PCF from
; xfonts-unifont). Used per-cell when the primary font lacks the
; codepoint, so CC's emoji-ish symbols / CJK / math glyphs render as
; actual characters instead of the X server's substitute glyph.
fallback_font_xlfd: db "-gnu-unifont-medium-r-normal-sans-16-160-75-75-c-80-iso10646-1", 0
fallback_font_xlfd_len equ $ - fallback_font_xlfd - 1

; _NET_WM_WINDOW_OPACITY for Alt+t.
opacity_atom_str: db "_NET_WM_WINDOW_OPACITY"
opacity_atom_len equ $ - opacity_atom_str

; PTY paths
ptmx_path:      db "/dev/ptmx", 0
pts_prefix:     db "/dev/pts/", 0

; Shell to launch
shell_name:     db "bare", 0
shell_flag:     db "-l", 0
term_env:       db "TERM=xterm-kitty", 0
colorterm_env:  db "COLORTERM=truecolor", 0
hkp_dbg_path:   db "/tmp/glass_keys.log", 0
hkp_paste_marker: db "*** PASTE HANDLER REACHED ***", 10
hkp_paste_marker_len equ $ - hkp_paste_marker

; Error messages
err_x11:        db "glass: cannot connect to X11", 10
err_x11_len     equ $ - err_x11
err_x11_auth:   db "glass: X11 auth failed", 10
err_x11_auth_len equ $ - err_x11_auth
err_pty:        db "glass: cannot open PTY", 10
err_pty_len     equ $ - err_pty
err_fork:       db "glass: fork failed", 10
err_fork_len    equ $ - err_fork

; URL opener
xdg_open:       db "/usr/bin/xdg-open", 0

; Config file suffix
glassrc_suffix: db "/.glassrc", 0

; Standard 16-color palette (0x00RRGGBB). Default is kitty's palette —
; modern terminal apps are tuned against these values, so the diff
; backgrounds, syntax highlighting, etc. land where the upstream
; designer intended. Override with `palette = NAME` or
; `colorN = #RRGGBB` in ~/.glassrc.
std_colors:
theme_kitty:
    dd 0x00000000  ; 0  black
    dd 0x00CC0403  ; 1  red
    dd 0x0019CB00  ; 2  green
    dd 0x00CECB00  ; 3  yellow
    dd 0x000D73CC  ; 4  blue
    dd 0x00CB1ED1  ; 5  magenta
    dd 0x000DCDCD  ; 6  cyan
    dd 0x00DDDDDD  ; 7  white
    dd 0x00767676  ; 8  bright black
    dd 0x00F2201F  ; 9  bright red
    dd 0x0023FD00  ; 10 bright green
    dd 0x00FFFD00  ; 11 bright yellow
    dd 0x001A8FFF  ; 12 bright blue
    dd 0x00FD28FF  ; 13 bright magenta
    dd 0x0014FFFF  ; 14 bright cyan
    dd 0x00FFFFFF  ; 15 bright white

; Bundled named palettes — selected via `palette = NAME` in ~/.glassrc.
; Each block is 16 dwords (slots 0..15). Slot 0 is bg-default, slot 7
; is fg-default; explicit `bg = ...` / `fg = ...` lines re-override after
; the theme is applied so the user's preferred bg never gets clobbered.
theme_vga:                                          ; the historical default
    dd 0x00000000, 0x00AA0000, 0x0000AA00, 0x00AA5500
    dd 0x000000AA, 0x00AA00AA, 0x0000AAAA, 0x00AAAAAA
    dd 0x00555555, 0x00FF5555, 0x0055FF55, 0x00FFFF55
    dd 0x005555FF, 0x00FF55FF, 0x0055FFFF, 0x00FFFFFF

theme_solarized_dark:
    dd 0x00073642, 0x00DC322F, 0x00859900, 0x00B58900
    dd 0x00268BD2, 0x00D33682, 0x002AA198, 0x00EEE8D5
    dd 0x00002B36, 0x00CB4B16, 0x00586E75, 0x00657B83
    dd 0x00839496, 0x006C71C4, 0x0093A1A1, 0x00FDF6E3

theme_dracula:
    dd 0x0021222C, 0x00FF5555, 0x0050FA7B, 0x00F1FA8C
    dd 0x00BD93F9, 0x00FF79C6, 0x008BE9FD, 0x00F8F8F2
    dd 0x006272A4, 0x00FF6E6E, 0x0069FF94, 0x00FFFFA5
    dd 0x00D6ACFF, 0x00FF92DF, 0x00A4FFFF, 0x00FFFFFF

theme_gruvbox_dark:
    dd 0x00282828, 0x00CC241D, 0x0098971A, 0x00D79921
    dd 0x00458588, 0x00B16286, 0x00689D6A, 0x00A89984
    dd 0x00928374, 0x00FB4934, 0x00B8BB26, 0x00FABD2F
    dd 0x0083A598, 0x00D3869B, 0x008EC07C, 0x00EBDBB2

theme_nord:
    dd 0x003B4252, 0x00BF616A, 0x00A3BE8C, 0x00EBCB8B
    dd 0x0081A1C1, 0x00B48EAD, 0x0088C0D0, 0x00E5E9F0
    dd 0x004C566A, 0x00BF616A, 0x00A3BE8C, 0x00EBCB8B
    dd 0x0081A1C1, 0x00B48EAD, 0x008FBCBB, 0x00ECEFF4

theme_tokyonight:
    dd 0x0015161E, 0x00F7768E, 0x009ECE6A, 0x00E0AF68
    dd 0x007AA2F7, 0x00BB9AF7, 0x007DCFFF, 0x00A9B1D6
    dd 0x00414868, 0x00F7768E, 0x009ECE6A, 0x00E0AF68
    dd 0x007AA2F7, 0x00BB9AF7, 0x007DCFFF, 0x00C0CAF5

theme_monokai:
    dd 0x00272822, 0x00F92672, 0x00A6E22E, 0x00F4BF75
    dd 0x0066D9EF, 0x00AE81FF, 0x00A1EFE4, 0x00F8F8F2
    dd 0x0075715E, 0x00F92672, 0x00A6E22E, 0x00F4BF75
    dd 0x0066D9EF, 0x00AE81FF, 0x00A1EFE4, 0x00F9F8F5

; ══════════════════════════════════════════════════════════════════════
; BSS section
; ══════════════════════════════════════════════════════════════════════
section .bss

; CLI exec override: when started with `glass -e CMD ARGS...` (or
; `glass -- CMD ARGS...`), pty_fork's child execve()s these argv
; pointers instead of the default bare/sh chain. exec_argv[0] is
; the command, rest are its args, NULL-terminated. exec_argv[0]==0
; means no -e was passed; use the default shell.
exec_argv:           resq 32

; Dead-key composition state. Holds the dead-key offset (0..0x2f,
; relative to 0xFE50) of the most-recent dead-keysym press; 0xFF means
; "no dead key pending". When the next keypress arrives we look up
; (pending_dead, key) in compose_table; on a hit we emit the composed
; codepoint, on a miss we emit the dead key's spacing equivalent and
; then process the new key normally.
pending_dead:        resb 1

; X11 connection
x11_fd:             resq 1
x11_seq:            resd 1
x11_rid_base:       resd 1
x11_rid_mask:       resd 1
x11_rid_next:       resd 1
x11_root_window:    resd 1
x11_root_visual:    resd 1
x11_screen_width:   resw 1
x11_screen_height:  resw 1
x11_root_depth:     resb 1
x11_white_pixel:    resd 1
x11_black_pixel:    resd 1
x11_min_keycode:    resb 1
x11_max_keycode:    resb 1
x11_argb_visual:    resd 1          ; 32-bit TrueColor visual ID (0 if none)
x11_argb_colormap:  resd 1          ; colormap for ARGB visual (0 if none)
xrootpmap_atom:     resd 1          ; _XROOTPMAP_ID
netwm_cm_atom:      resd 1          ; _NET_WM_CM_S0 (compositor selection)
pseudo_bg_pixel:    resd 1          ; cached blended pseudo-bg color
pseudo_bg_set:      resb 1          ; 1 if pseudo-transparency active
pseudo_setup_done:  resb 1          ; one-shot guard for setup call
compositor_active:  resb 1          ; 1 if a compositor owns _NET_WM_CM_S0
bg_pixmap_id:       resd 1          ; server-side wallpaper-blended pixmap
bg_pixmap_w:        resd 1          ; width the pixmap was built for
bg_pixmap_h:        resd 1          ; height the pixmap was built for
pseudo_full:        resb 1          ; 1 = per-pixel pseudo-transparency active
pseudo_root_pmap:   resd 1
pseudo_root_x:      resd 1
pseudo_root_y:      resd 1
pseudo_strip_h:     resd 1
pseudo_strip_pixels:resd 1
pseudo_data_bytes:  resd 1
pseudo_pi_words:    resd 1
pseudo_wp_w:        resd 1
pseudo_bg_w:        resd 1
pseudo_total_bytes: resd 1

; Our resources
win_id:             resd 1
gc_id:              resd 1
gc_bg_id:           resd 1
font_id:            resd 1
font_id_bold:       resd 1          ; bold variant; equals font_id when none
fallback_font_id:   resd 1          ; Unifont, 0 = not loaded
fallback_gc_id:     resd 1          ; GC bound to the fallback font
fallback_char_w:    resw 1          ; max char width of fallback font
fallback_ascent:    resw 1          ; baseline of fallback font
; Glyph-coverage bitmap of the PRIMARY font: 1 bit per BMP codepoint
; (65536 / 8 = 8192 bytes). 1 = primary font has a glyph for this
; codepoint; 0 = fall back to fallback_font_id. Built from QueryFont
; reply at startup (see build_primary_glyph_map). All-zero by default,
; so a missing fallback font means everything tries primary (existing
; behaviour) — graceful degradation.
glyph_present:      resb 8192
gc_current_font:    resd 1          ; tracks which font is loaded in gc_id

; Kitty graphics protocol state
apc_body:           resb APC_BODY_MAX
apc_body_len:       resq 1
apc_payload:        resb APC_PAYLOAD_MAX  ; accumulated base64 across chunks
apc_payload_len:    resq 1
apc_pending_id:     resd 1          ; image id from first chunk's a=t
apc_pending_fmt:    resd 1          ; 100=PNG, 32=RGBA, 24=RGB
apc_pending_w:      resd 1          ; for raw RGBA
apc_pending_h:      resd 1
apc_pending_q:      resb 1          ; quiet level
apc_pending_active: resb 1          ; 1 = mid-transmission (m=1 seen)
apc_pending_place:  resb 1          ; 1 = a=T, place after decoding
img_table:          resb IMG_SLOTS * IMG_SLOT_SIZE
place_table:        resb PLACE_SLOTS * PLACE_SLOT_SIZE
place_count:        resq 1
img_decode_buf:     resq 1          ; mmap'd RGBA scratch (decoded PNG)
img_decode_len:     resq 1          ; allocated bytes
png_argv:           resq 8          ; argv[] for the convert child
; Pipe fds for the convert pipeline. Kept in BSS rather than scratch
; registers because syscall clobbers r11 every call, and there aren't
; enough callee-saved regs to spare without juggling.
png_in_read:        resd 1          ; child stdin source (parent: closed)
png_in_write:       resd 1          ; parent writes PNG bytes here
png_out_read:       resd 1          ; parent reads RGBA bytes here
png_out_write:      resd 1          ; child stdout target (parent: closed)
run_bold:           resb 1          ; current run's bold bit (renderer)
run_underline:      resb 1          ; current run's underline bit (renderer)
wm_protocols_atom:  resd 1

; XRender extension state. render_major is 0 if RENDER is unavailable
; (or QueryExtension hasn't run yet) — emoji rendering is gated on it
; being non-zero. window_picture wraps the glass window; emoji_pictures
; hold the cached ARGB rasters produced by `convert`.
render_major:           resd 1     ; major opcode, 0 = unavailable
render_format_argb32:   resd 1     ; PictFormat ID for ARGB32 source
render_format_window:   resd 1     ; PictFormat ID matching our visual
render_format_a8:       resd 1     ; PictFormat ID for 8-bit alpha (TTF glyphs)

; ---- TTF rendering (XRender CompositeGlyphs32) ----
ttf_glyphset:           resd 1     ; XID of GlyphSet for this font
ttf_pen_pixmap:         resd 1     ; 1×1 ARGB32 pixmap (foreground source)
ttf_pen_picture:        resd 1     ; Picture wrapping ttf_pen_pixmap (Repeat=true)
ttf_pen_color:          resd 1     ; current pen ARGB (cached so we skip redundant fills)
render_window_picture:  resd 1     ; Picture wrapping the glass window
render_temp_gc:         resd 1     ; GC used to PutImage onto pixmaps

%define MAX_EMOJI 1024
%define EMOJI_RASTER_MAX (64 * 64 * 4)   ; allow up to 64x64 ARGB
emoji_codepoints:       resd MAX_EMOJI   ; 32-bit codepoints we've seen
emoji_pictures:         resd MAX_EMOJI   ; XID of XRender Picture (0 = not yet rendered)
emoji_pixmaps:          resd MAX_EMOJI   ; XID of backing Pixmap
emoji_count:            resq 1
cur_emoji_index:        resw 1     ; set by UTF-8 decoder before grid_put_char
; Buffers for fork+exec convert (rebuilt per emoji)
emoji_size_arg:         resb 16          ; "WxH\0"
emoji_pango_arg:        resb 256         ; "pango:<span ...>UTF8</span>\0"
emoji_argv:             resq 16          ; argv pointers passed to execve
emoji_raster_buf:       resb EMOJI_RASTER_MAX
emoji_cache_path:       resb 256         ; full path to disk cache file (user)
emoji_sys_cache_path:   resb 256         ; full path to system bundled cache
emoji_cache_dir:        resb 256         ; full path to cache directory
emoji_cache_dirs_made:  resb 1           ; 1 after we've created the dirs
render_gc_ready:        resb 1           ; 1 once render_temp_gc is created
wm_delete_atom:     resd 1
tile_shell_pid_atom: resd 1

; Font metrics
font_ascent:        resw 1
font_descent:       resw 1
char_width:         resw 1
char_height:        resw 1

; Keyboard (proper X11 keysym mapping)
keysym_map:         resd 2048       ; 256 keycodes × 8 keysyms each
keysyms_per_kc:     resd 1
hkp_unshifted_ksym: resd 1          ; saved unshifted keysym for special checks
hkp_dbg_buf:        resb 64         ; debug buffer for keypress log

; Scrollback
scroll_buf:         resb MAX_COLS * 1000 * CELL_SIZE  ; 1000 lines
scroll_lines:       resq 1          ; number of lines stored
scroll_write_pos:   resq 1          ; circular write position
scroll_offset:      resq 1          ; current view offset (0 = live)

; Selection
sel_active:         resq 1          ; 1 = selection in progress
sel_start_row:      resq 1
sel_start_col:      resq 1
sel_end_row:        resq 1
sel_end_col:        resq 1
sel_buf:            resb 16384      ; selection text buffer
sel_len:            resq 1
sel_button_held:    resq 1          ; 1 = mouse button is held

; Multi-click detection (double/triple click for word/line selection)
last_click_time:    resq 1          ; CLOCK_MONOTONIC ms of last button press
last_click_row:     resq 1
last_click_col:     resq 1
click_count:        resq 1          ; 1=single, 2=double, 3=triple
click_ts_buf:       resq 2          ; scratch for clock_gettime (sec, nsec)
sel_mode:           resq 1          ; 0=char, 1=word, 2=line (locks drag/release)

; UTF-8 decoder state
utf8_char:          resd 1
utf8_remaining:     resd 1

; URL detection
url_list:           resb 768        ; 32 URLs, each 24 bytes
url_count:          resq 1
url_strings:        resb 8192       ; extracted URL text
url_str_pos:        resq 1

; Config (.glassrc)
cfg_bg_pixel:       resd 1
cfg_fg_pixel:       resd 1
cfg_cursor_pixel:   resd 1
cfg_bg_set:         resb 1
cfg_fg_set:         resb 1
cfg_cursor_set:     resb 1
cfg_opacity:        resb 1          ; 0..255, 255 = opaque (default)
cfg_opacity_set:    resb 1
cfg_font_bold:      resb 1          ; 1 = use bold variant as the default font
cfg_osc8_underline: resb 1          ; 1 = underline OSC 8 hyperlink spans, 0 = don't
                                    ; (some apps — notably Claude Code — open
                                    ; OSC 8 spans that never close cleanly,
                                    ; making large parts of the screen appear
                                    ; underlined; this lets the user opt out)

; Runtime-toggleable state (Alt+plus/minus/_, Alt+b, Alt+t)
bg_cycle_pixels:    resd 16         ; up to 16 cycle colors
bg_cycle_count:     resq 1          ; number of colors parsed from .glassrc
bg_cycle_idx:       resq 1          ; current index in cycle (0 = first entry)
opacity_cycle_vals: resb 16         ; 0..100 percent values from .glassrc
opacity_cycle_count: resq 1
opacity_cycle_idx:  resq 1
saved_bg_pixel:     resd 1          ; configured cfg_bg before any cycling
saved_bg_set:      resb 1          ; 1 if saved_bg_pixel is valid
opacity_toggle:     resb 1          ; 0 = opaque (or untouched), 1 = ~50%
opacity_atom:       resd 1          ; _NET_WM_WINDOW_OPACITY atom id
opacity_atom_set:   resb 1          ; 1 once interned
last_opacity_pct:   resb 1          ; last applied percent (0..100)
last_opacity_init:  resb 1          ; 1 once last_opacity_pct holds a value
opacity_prop_set:   resb 1          ; 1 if _NET_WM_WINDOW_OPACITY ever set
original_font_size: resq 1          ; cfg_font_size at startup (for reset)

; Configurable keybinding table. Five slots, one per Alt-action.
; mod byte holds the required Shift|Ctrl|Alt mask (bits 0,2,3).
; A mod value of 0 means the binding is disabled.
KB_FONT_INC      equ 0
KB_FONT_DEC      equ 1
KB_FONT_RESET    equ 2
KB_BG_CYCLE      equ 3
KB_OPACITY       equ 4
KB_COUNT         equ 5
keybind_mods:    resb KB_COUNT
keybind_keysyms: resd KB_COUNT
cfg_blink_ms:       resq 1          ; cursor blink interval in ms (0 = off)
cursor_blink_until: resq 1          ; CLOCK_MONOTONIC ms when next toggle is due
cur_osc8_id:        resb 1          ; current OSC 8 link id (0 = none)
row_wrapped:        resb MAX_ROWS    ; 1 = row N's last char wrapped to N+1
osc8_uri_offsets:   resd 256        ; offset in osc8_uris per link id
osc8_uris:          resb 4096       ; null-terminated URIs from OSC 8
osc8_uris_pos:      resq 1          ; next free byte in osc8_uris
osc8_count:         resq 1          ; number of distinct URIs registered
cfg_buf:            resb 4096

; Selection atoms
clipboard_atom:     resd 1
utf8_string_atom:   resd 1
targets_atom:       resd 1
glass_sel_atom:     resd 1
primary_atom:       resd 1          ; XA_PRIMARY = 1 (built-in)

; PTY
pty_master:         resq 1
pty_slave_path:     resb 32
child_pid:          resq 1

; Terminal grid (char, fg, bg, attrs per cell)
grid:               resb MAX_COLS * MAX_ROWS * CELL_SIZE
grid_cols:          resq 1
grid_rows:          resq 1
prev_grid_cols:     resq 1
prev_grid_rows:     resq 1

; Cursor
cursor_row:         resq 1
cursor_col:         resq 1
cursor_saved_row:   resq 1
cursor_saved_col:   resq 1
; Deferred autowrap: when a printable char is written at the last column
; we keep the cursor there and set pending_wrap=1 instead of immediately
; advancing to the next row. The wrap is performed when the NEXT
; printable char arrives. CR/LF/BS/cursor-positioning all clear the
; flag without consuming the queued advance — this matches xterm and
; prevents the classic "blank row between rows" bug when programs
; pad to grid_cols and follow with [K\r\n.
pending_wrap:       resb 1

; VT parser
vt_state:           resq 1
vt_params:          resd 16
vt_param_count:     resq 1
vt_private:         resb 1

; Current attributes
; cur_fg_pixel/cur_bg_pixel hold the resolved 32-bit pixel for any
; explicitly-set color (indexed or truecolor). When the default
; flag is set the pixel is ignored and palette[7]/palette[0] is
; used at render time, so changes to those palette slots after
; cells are written are still honored.
cur_fg_pixel:       resd 1
cur_bg_pixel:       resd 1
cur_fg_default:     resb 1     ; 1 = use palette[7] at render time
cur_bg_default:     resb 1     ; 1 = use palette[0] at render time
cur_attrs:          resb 1
default_fg:         resb 1
default_bg:         resb 1

; Window
win_width:          resq 1
win_height:         resq 1

; I/O buffers
x11_buf:            resb 65536
x11_write_buf:      resb 16384
x11_write_pos:      resq 1
pty_read_buf:       resb 4096
xauth_buf:          resb 4096
xauth_data:         resb 16
xauth_len:          resq 1
conn_setup_buf:     resb 16384
sockaddr_buf:       resb 112

; Poll
poll_fds:           resb 16

; Environment
envp:               resq 1
child_envp:         resq 512        ; modified env with TERM set
display_num:        resq 1

; 256-color palette
palette:            resd 256

; Alt screen buffer
alt_grid:           resb MAX_COLS * MAX_ROWS * CELL_SIZE
alt_cursor_row:     resq 1
alt_cursor_col:     resq 1
alt_screen_active:  resq 1          ; 0 = main, 1 = alt

; DECSET mode flags
cursor_visible:     resq 1          ; 1 = visible (default)
autowrap:           resq 1          ; 1 = autowrap on (default)
mouse_tracking:     resq 1          ; 0=off, 1=normal, 2=button, 3=any
mouse_sgr:          resq 1          ; 1 = SGR mouse encoding
bracketed_paste:    resq 1          ; 1 = bracketed paste mode
cursor_style:       resq 1          ; 0=block, 1=underline, 2=bar
scroll_top:         resq 1          ; scroll region top (0-based, default 0)
scroll_bottom:      resq 1          ; scroll region bottom (0-based, default grid_rows-1)
bell_flash_until:   resq 1          ; CLOCK_REALTIME nanoseconds
cursor_blink_state: resq 1          ; 0 = invisible, 1 = visible
last_blink_time:    resq 1          ; nanoseconds of last toggle
dirty_rows:         resb 256        ; per-row dirty flags (1 = needs redraw)
all_dirty:          resq 1          ; 1 = full redraw needed
child_forked:       resq 1          ; 1 if child has been forked

; OSC title
osc_buf:            resb 256
osc_pos:            resq 1
osc_num:            resq 1          ; OSC number (0, 2, etc.)
osc_collecting:     resq 1          ; 1 = collecting title text
osc_in_num:         resq 1          ; 1 = still parsing OSC number

; Font configuration
cfg_font_size:      resq 1          ; 0 = default, else pixel size

; ---- TTF font (glyph engine) ----
cfg_font_path:      resb 512        ; null-terminated path to TTF file (empty = use X core font)
cfg_font_path_set:  resq 1          ; 1 if cfg_font_path is populated
cfg_ttf_weight:     resq 1          ; variation weight (0 = font's fvar default)
ttf_active:         resq 1          ; 1 once glyph_load_font succeeds
dyn_font_name:      resb 128
dyn_font_name_len:  resq 1
dyn_bold_font_name: resb 128
dyn_bold_font_name_len: resq 1

; Mouse escape sequence buffer
mouse_seq_buf:      resb 32

; Misc
; Sized for the worst-case TTF AddGlyphs payload: 28-byte header + a
; stride-padded W×H alpha bitmap. The rasterizer caps single glyphs at
; MAX_OUT_DIM=512 in the glyph engine, so the absolute upper bound is
; 28 + 512*512 ≈ 256 KB. Anything smaller and a tall Nerd Font glyph at
; preset font_size 28/32 (ascender + descender stack) overflowed and
; corrupted neighbouring BSS — manifesting as a SEGV ~half a second
; into the next render. BSS is lazy-allocated by the kernel, so the
; reservation is free until actually touched.
tmp_buf:            resb 262176
num_buf:            resb 32
key_out_buf:        resb 32
rs_row_base:        resq 1          ; pointer to current row's cell data

; ══════════════════════════════════════════════════════════════════════
; Text section
; ══════════════════════════════════════════════════════════════════════
section .text
global _start

; Emit a single UCS-2 codepoint (eax) as UTF-8 to the pty master.
; Used by the dead-key composition fallback when no match is found —
; the dead char is written first, then the caller continues processing
; the new key. Preserves no caller registers; caller saves what it needs.
emit_ucs_inline:
    push rax                              ; preserve codepoint for callers that need it
    cmp eax, 0x80
    jb .eui_1b
    ; 2-byte UTF-8
    mov ecx, eax
    shr ecx, 6
    or ecx, 0xC0
    mov [key_out_buf], cl
    and eax, 0x3F
    or eax, 0x80
    mov [key_out_buf+1], al
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [key_out_buf]
    mov rdx, 2
    syscall
    pop rax
    ret
.eui_1b:
    mov [key_out_buf], al
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [key_out_buf]
    mov rdx, 1
    syscall
    pop rax
    ret

_start:
    ; Save envp
    mov rdi, [rsp]          ; argc
    lea rsi, [rsp + 8]      ; argv
    lea rax, [rdi + 1]
    lea rcx, [rsi + rax*8]
    mov [envp], rcx

    ; Parse argv for `-e CMD [ARGS...]` or `-- CMD [ARGS...]`. Anything
    ; after the marker becomes exec_argv (capped at 31 args + NULL).
    ; Argv before the marker is silently ignored — we don't have any
    ; other CLI flags yet.
    mov r8, rdi             ; argc
    mov r9, rsi             ; argv
    xor r10, r10            ; iterator
.es_arg_loop:
    inc r10                 ; skip argv[0]
    cmp r10, r8
    jge .es_arg_done
    mov rax, [r9 + r10*8]
    test rax, rax
    jz .es_arg_done
    cmp word [rax], 0x652d  ; "-e" little-endian (0x65 0x2d wrong way → "-e" is bytes 0x2d 0x65)
    je .es_check_e
    cmp dword [rax], 0x002d2d ; "--\0" → length 2
    jne .es_arg_loop
    jmp .es_collect
.es_check_e:
    cmp byte [rax+2], 0
    jne .es_arg_loop
.es_collect:
    inc r10                 ; advance past the marker
    xor r11, r11            ; dest index
.es_collect_loop:
    cmp r10, r8
    jge .es_collect_done
    cmp r11, 31
    jge .es_collect_done
    mov rax, [r9 + r10*8]
    test rax, rax
    jz .es_collect_done
    mov [exec_argv + r11*8], rax
    inc r10
    inc r11
    jmp .es_collect_loop
.es_collect_done:
    mov qword [exec_argv + r11*8], 0
.es_arg_done:

    ; No dead key pending at startup.
    mov byte [pending_dead], 0xFF

    ; Initialize palette
    call init_palette

    ; Set defaults
    mov byte [default_fg], 7     ; white
    mov byte [default_bg], 0     ; black
    mov byte [cur_fg_default], 1
    mov byte [cur_bg_default], 1
    mov dword [cur_fg_pixel], 0
    mov dword [cur_bg_pixel], 0
    mov qword [grid_cols], DEFAULT_COLS
    mov qword [grid_rows], DEFAULT_ROWS
    mov qword [cursor_visible], 1
    mov qword [cursor_blink_state], 1
    mov qword [autowrap], 1
    mov qword [alt_screen_active], 0
    mov qword [mouse_tracking], 0
    mov qword [mouse_sgr], 0
    mov qword [scroll_top], 0
    mov qword [scroll_bottom], 0      ; 0 = use grid_rows-1
    mov qword [bracketed_paste], 0
    mov byte [cfg_osc8_underline], 1   ; standard terminal default; ~/.glassrc can disable
    mov qword [cursor_style], 0
    mov qword [cfg_font_size], 0

    ; Initialize grid with spaces
    call grid_clear

    ; Parse DISPLAY number
    call parse_display

    ; Seed default Alt+key bindings before parsing the user's config so
    ; load_config can override individual entries via key.NAME = ...
    call init_keybindings

    ; Load config from ~/.glassrc (before X11 connect)
    call load_config
    ; Snapshot the configured font_size so Alt+_ (font reset) can
    ; return to it later regardless of how often the user hit Alt+plus.
    mov rax, [cfg_font_size]
    mov [original_font_size], rax

    ; If font_path is configured, load the TTF via the embedded glyph
    ; engine. On failure we silently fall back to X core fonts so a
    ; bad path never bricks glass.
    cmp qword [cfg_font_path_set], 0
    je .ttf_skip
    lea rdi, [cfg_font_path]
    call glyph_load_font
    test rax, rax
    jnz .ttf_failed
    mov rdi, [cfg_ttf_weight]
    call glyph_set_weight
    mov qword [ttf_active], 1
    jmp .ttf_skip
.ttf_failed:
    mov qword [ttf_active], 0
.ttf_skip:

    ; Read Xauthority
    call read_xauthority

    ; Connect to X11
    call x11_connect
    test rax, rax
    jnz .die_x11

    ; Parse X11 setup reply
    call x11_parse_setup

    ; Get keyboard mapping from server
    call x11_get_keymap

    ; If the user asked for opacity, find out whether a compositor owns
    ; _NET_WM_CM_S0; this decides whether CreateWindow uses the ARGB32
    ; visual (real per-pixel transparency) or stays opaque so that
    ; setup_pseudo_transparency can take over. Skipped entirely when
    ; opacity is not configured, so opaque-only configs pay no
    ; X11 round-trip cost.
    cmp byte [cfg_opacity_set], 1
    jne .start_no_compositor_check
    call check_compositor
.start_no_compositor_check:

    ; Build dynamic font name if font_size configured
    call setup_font_name

    ; Open font
    call x11_open_font

    ; Query font metrics
    call x11_query_font

    ; If a TTF was loaded, override the X core font's char_width /
    ; char_height / font_ascent with the TTF's own metrics so the cell
    ; geometry matches the rasterised glyphs (no descender clipping).
    call ttf_compute_metrics

    ; (Fallback font init disabled until rewritten — earlier version
    ; left undrained QueryFont reply bytes in the X socket which
    ; corrupted the InternAtom replies in x11_set_wm_hints, breaking
    ; WM_PROTOCOLS / WM_DELETE_WINDOW so glass couldn't be closed via
    ; the WM. Keeping the build_primary_glyph_map / init_fallback_font
    ; bodies in place but unreferenced.)

    ; Create window
    call x11_create_window

    ; Create GC
    call x11_create_gc

    ; Set WM hints (before map to avoid event/reply mixing)
    call x11_set_wm_hints

    ; Intern selection atoms
    call x11_intern_sel_atoms

    ; Probe for the RENDER extension and set up Picture for our window.
    ; Required for color emoji rendering. Silently skipped if not present.
    call x11_setup_render

    ; If TTF font loaded, set up the XRender GlyphSet + pen Picture for
    ; CompositeGlyphs32 text rendering.
    call ttf_xrender_init

    ; Map window
    call x11_map_window

    ; Flush all pending X11 requests
    call x11_flush

    ; Open PTY (but don't fork yet - wait for first ConfigureNotify)
    call pty_open
    test rax, rax
    jnz .die_pty

    ; Enter event loop
    jmp event_loop

.die_x11:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [err_x11]
    mov rdx, err_x11_len
    syscall
    jmp .die

.die_pty:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [err_pty]
    mov rdx, err_pty_len
    syscall
    jmp .die

.die_fork:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [err_fork]
    mov rdx, err_fork_len
    syscall

.die:
    mov rdi, 1
    mov rax, SYS_EXIT
    syscall

; ══════════════════════════════════════════════════════════════════════
; X11 connection
; ══════════════════════════════════════════════════════════════════════

; Parse $DISPLAY to get display number
parse_display:
    push rbx
    mov rdi, [envp]
    ; Search for DISPLAY=
.pd_loop:
    mov rax, [rdi]
    test rax, rax
    jz .pd_default
    ; Check for "DISPLAY="
    cmp dword [rax], 'DISP'
    jne .pd_next
    cmp dword [rax+4], 'LAY='
    jne .pd_next
    ; Found it. Parse ":N"
    add rax, 8
    cmp byte [rax], ':'
    jne .pd_default
    inc rax
    ; Parse number
    xor ebx, ebx
    mov rcx, 10
.pd_num:
    movzx edx, byte [rax]
    cmp dl, '0'
    jb .pd_num_done
    cmp dl, '9'
    ja .pd_num_done
    sub dl, '0'
    imul ebx, 10
    add ebx, edx
    inc rax
    jmp .pd_num
.pd_num_done:
    mov [display_num], rbx
    pop rbx
    ret
.pd_next:
    add rdi, 8
    jmp .pd_loop
.pd_default:
    mov qword [display_num], 0
    pop rbx
    ret

; Read Xauthority file
read_xauthority:
    push rbx
    push r12

    ; Find XAUTHORITY env var
    mov rdi, [envp]
.rxa_loop:
    mov rax, [rdi]
    test rax, rax
    jz .rxa_try_home
    cmp dword [rax], 'XAUT'
    jne .rxa_next
    cmp dword [rax+4], 'HORI'
    jne .rxa_next
    cmp word [rax+8], 'TY'
    jne .rxa_next
    cmp byte [rax+10], '='
    jne .rxa_next
    ; Found XAUTHORITY=path
    lea rsi, [rax + 11]
    jmp .rxa_open
.rxa_next:
    add rdi, 8
    jmp .rxa_loop

.rxa_try_home:
    ; Use $HOME/.Xauthority
    mov rdi, [envp]
.rxa_home_loop:
    mov rax, [rdi]
    test rax, rax
    jz .rxa_done
    cmp dword [rax], 'HOME'
    jne .rxa_home_next
    cmp byte [rax+4], '='
    jne .rxa_home_next
    lea rsi, [rax + 5]
    ; Build path in tmp_buf
    lea rdi, [tmp_buf]
.rxa_cp_home:
    mov al, [rsi]
    test al, al
    jz .rxa_append
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .rxa_cp_home
.rxa_append:
    mov dword [rdi], '/.Xa'
    mov dword [rdi+4], 'utho'
    mov dword [rdi+8], 'rity'
    mov byte [rdi+12], 0
    lea rsi, [tmp_buf]
    jmp .rxa_open
.rxa_home_next:
    add rdi, 8
    jmp .rxa_home_loop

.rxa_open:
    ; Open and read the file
    mov rax, SYS_OPEN
    mov rdi, rsi
    xor esi, esi         ; O_RDONLY
    xor edx, edx
    syscall
    test rax, rax
    js .rxa_done
    mov rbx, rax         ; fd

    mov rax, SYS_READ
    mov rdi, rbx
    lea rsi, [xauth_buf]
    mov rdx, 4096
    syscall
    mov r12, rax          ; bytes read

    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall

    ; Parse Xauthority entries (big-endian format)
    ; Format: family(2) + addr_len(2) + addr + num_len(2) + num + name_len(2) + name + data_len(2) + data
    lea rsi, [xauth_buf]
    lea rdi, [xauth_buf]
    add rdi, r12          ; end pointer
.rxa_parse:
    cmp rsi, rdi
    jge .rxa_done
    ; family (2 bytes big-endian, skip)
    add rsi, 2
    ; address length (2 bytes big-endian)
    movzx eax, byte [rsi]
    shl eax, 8
    movzx ecx, byte [rsi+1]
    or eax, ecx
    add rsi, 2
    add rsi, rax          ; skip address
    ; number length
    movzx eax, byte [rsi]
    shl eax, 8
    movzx ecx, byte [rsi+1]
    or eax, ecx
    add rsi, 2
    add rsi, rax          ; skip number
    ; name length
    movzx eax, byte [rsi]
    shl eax, 8
    movzx ecx, byte [rsi+1]
    or eax, ecx
    add rsi, 2
    mov rbx, rax          ; name_len
    add rsi, rbx          ; skip name
    ; data length
    movzx eax, byte [rsi]
    shl eax, 8
    movzx ecx, byte [rsi+1]
    or eax, ecx
    add rsi, 2
    ; Copy data (the cookie)
    cmp eax, 16
    jne .rxa_skip_data
    ; This is our cookie
    lea rdi, [xauth_data]
    mov ecx, 16
.rxa_cp_cookie:
    mov bl, [rsi]
    mov [rdi], bl
    inc rsi
    inc rdi
    dec ecx
    jnz .rxa_cp_cookie
    mov qword [xauth_len], 16
    jmp .rxa_done
.rxa_skip_data:
    add rsi, rax
    jmp .rxa_parse

.rxa_done:
    pop r12
    pop rbx
    ret

; Connect to X11 server
; Returns: rax = 0 on success, -1 on failure
x11_connect:
    push rbx
    push r12

    ; Create socket
    mov rax, SYS_SOCKET
    mov rdi, AF_UNIX
    mov rsi, SOCK_STREAM
    xor edx, edx
    syscall
    test rax, rax
    js .xc_fail
    mov [x11_fd], rax
    mov rbx, rax

    ; Build sockaddr_un
    lea rdi, [sockaddr_buf]
    mov word [rdi], AF_UNIX    ; sa_family
    add rdi, 2
    ; Copy "/tmp/.X11-unix/X"
    lea rsi, [x11_sock_pre]
.xc_cp_path:
    mov al, [rsi]
    test al, al
    jz .xc_cp_num
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .xc_cp_path
.xc_cp_num:
    ; Append display number
    mov rax, [display_num]
    push rdi
    call itoa
    pop rdi
    add rdi, rax
    mov byte [rdi], 0

    ; Connect
    mov rax, SYS_CONNECT
    mov rdi, rbx
    lea rsi, [sockaddr_buf]
    mov rdx, 110             ; sizeof(sockaddr_un)
    syscall
    test rax, rax
    js .xc_fail

    ; Send connection setup
    ; Byte order: 'B' big-endian or 'l' little-endian
    lea rdi, [tmp_buf]
    mov byte [rdi], 0x6C     ; little-endian
    mov byte [rdi+1], 0      ; unused
    mov word [rdi+2], 11     ; protocol major
    mov word [rdi+4], 0      ; protocol minor
    ; Auth name length
    mov word [rdi+6], auth_name_len
    ; Auth data length
    movzx eax, word [xauth_len]
    mov word [rdi+8], ax
    mov word [rdi+10], 0     ; unused
    ; Auth name (padded to 4)
    lea rsi, [auth_name]
    lea rdi, [tmp_buf + 12]
    mov ecx, auth_name_len
.xc_cp_auth_name:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec ecx
    jnz .xc_cp_auth_name
    ; Pad auth name to 4-byte boundary
    mov ecx, auth_name_len
    and ecx, 3
    jz .xc_auth_data
    mov edx, 4
    sub edx, ecx
.xc_pad_name:
    mov byte [rdi], 0
    inc rdi
    dec edx
    jnz .xc_pad_name
.xc_auth_data:
    ; Auth data (16 bytes, already 4-aligned)
    lea rsi, [xauth_data]
    mov ecx, 16
.xc_cp_auth_data:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec ecx
    jnz .xc_cp_auth_data

    ; Calculate total length
    mov rdx, rdi
    lea rsi, [tmp_buf]
    sub rdx, rsi

    ; Send
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall

    ; Read full setup reply (may need multiple reads)
    xor r12, r12              ; total bytes read
.xc_read_loop:
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [conn_setup_buf]
    add rsi, r12
    mov rdx, 16384
    sub rdx, r12
    jle .xc_read_done         ; buffer full
    syscall
    test rax, rax
    jle .xc_fail
    add r12, rax
    ; Need at least 8 bytes to check reply size
    cmp r12, 8
    jl .xc_read_loop
    ; Check total reply size: 8 + additional_data*4
    movzx eax, word [conn_setup_buf + 6]
    shl eax, 2
    add eax, 8
    cmp r12d, eax
    jl .xc_read_loop          ; need more data
.xc_read_done:

    ; Check success (first byte = 1)
    cmp byte [conn_setup_buf], 1
    jne .xc_fail

    xor eax, eax
    pop r12
    pop rbx
    ret

.xc_fail:
    mov rax, -1
    pop r12
    pop rbx
    ret

; Parse X11 connection setup reply
x11_parse_setup:
    push rbx
    push r12
    lea rsi, [conn_setup_buf]

    ; Skip first 8 bytes (status, pad, major, minor, additional_data_len)
    ; resource-id-base at offset 4 (CARD32)... wait, the reply format:
    ; Byte 0: success (1)
    ; Byte 1: unused
    ; Bytes 2-3: protocol-major-version
    ; Bytes 4-5: protocol-minor-version
    ; Bytes 6-7: additional data length (in 4-byte units)
    ; Bytes 8-11: release-number
    ; Bytes 12-15: resource-id-base
    ; Bytes 16-19: resource-id-mask
    ; Bytes 20-23: motion-buffer-size
    ; Bytes 24-25: vendor-length
    ; Bytes 26-27: maximum-request-length
    ; Byte 28: number of screens
    ; Byte 29: number of formats
    ; Byte 30: image-byte-order
    ; Byte 31: bitmap-bit-order
    ; Byte 32: bitmap-scanline-unit
    ; Byte 33: bitmap-scanline-pad
    ; Byte 34: min-keycode
    ; Byte 35: max-keycode
    ; Bytes 36-39: unused

    mov eax, [rsi + 12]
    mov [x11_rid_base], eax
    mov eax, [rsi + 16]
    mov [x11_rid_mask], eax
    mov dword [x11_rid_next], 1

    movzx eax, byte [rsi + 34]
    mov [x11_min_keycode], al
    movzx eax, byte [rsi + 35]
    mov [x11_max_keycode], al

    ; Vendor length (at offset 24)
    movzx eax, word [rsi + 24]
    mov rbx, rax
    ; Pad to 4
    add rbx, 3
    and rbx, ~3

    ; Number of formats (at offset 29)
    movzx ecx, byte [rsi + 29]
    imul ecx, 8              ; 8 bytes per format

    ; Skip to SCREEN: offset 40 + vendor_padded + formats
    lea r12, [rsi + 40]
    add r12, rbx             ; skip vendor
    add r12, rcx             ; skip formats

    ; Parse first SCREEN structure
    ; Bytes 0-3: root window
    ; Bytes 4-7: default colormap
    ; Bytes 8-11: white-pixel
    ; Bytes 12-15: black-pixel
    ; Bytes 16-19: current-input-masks
    ; Bytes 20-21: width-in-pixels
    ; Bytes 22-23: height-in-pixels
    ; Bytes 24-25: width-in-mm
    ; Bytes 26-27: height-in-mm
    ; Bytes 28-29: min-installed-maps
    ; Bytes 30-31: max-installed-maps
    ; Bytes 32-35: root-visual
    ; Byte 36: backing-stores
    ; Byte 37: save-unders
    ; Byte 38: root-depth
    ; Byte 39: number of depths

    mov eax, [r12]
    mov [x11_root_window], eax
    mov eax, [r12 + 8]
    mov [x11_white_pixel], eax
    mov eax, [r12 + 12]
    mov [x11_black_pixel], eax
    movzx eax, word [r12 + 20]
    mov [x11_screen_width], ax
    movzx eax, word [r12 + 22]
    mov [x11_screen_height], ax
    mov eax, [r12 + 32]
    mov [x11_root_visual], eax
    movzx eax, byte [r12 + 38]
    mov [x11_root_depth], al

    ; Walk DEPTH structures looking for depth=32 TrueColor visual.
    ; SCREEN header is 40 bytes, then number-of-depths DEPTH structs.
    ; DEPTH = 8-byte header + N * 24-byte VISUALTYPE.
    ; VISUALTYPE byte 4 = class (4 = TrueColor); bytes 0-3 = visual-id.
    movzx ecx, byte [r12 + 39]            ; number of depths
    lea rbx, [r12 + 40]                   ; rbx = current DEPTH
.xps_depth_loop:
    test ecx, ecx
    jz .xps_done
    movzx eax, byte [rbx]                 ; depth
    movzx edx, word [rbx + 2]             ; number of visuals
    lea r12, [rbx + 8]                    ; r12 = first VISUALTYPE
    cmp eax, 32
    jne .xps_advance_depth
.xps_visual_loop:
    test edx, edx
    jz .xps_advance_depth
    movzx eax, byte [r12 + 4]
    cmp eax, 4                            ; TrueColor
    jne .xps_next_visual
    mov eax, [r12]
    mov [x11_argb_visual], eax
    jmp .xps_done
.xps_next_visual:
    add r12, 24
    dec edx
    jmp .xps_visual_loop
.xps_advance_depth:
    ; r12 = first visual; advance past remaining visuals to next DEPTH
    mov rax, rdx
    imul rax, 24
    add r12, rax
    mov rbx, r12
    dec ecx
    jmp .xps_depth_loop
.xps_done:

    pop r12
    pop rbx
    ret

; Get keyboard mapping from X11 server
x11_get_keymap:
    push rbx
    push r12
    push r13

    ; Calculate count = max_keycode - min_keycode + 1
    movzx eax, byte [x11_min_keycode]
    mov r12d, eax                     ; save min_keycode
    movzx ecx, byte [x11_max_keycode]
    sub ecx, eax
    inc ecx
    mov r13d, ecx                     ; count

    ; Build GetKeyboardMapping request
    ; opcode=101, pad=0, length=2, first_keycode, count, pad(2)
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_GET_KEYBOARD_MAPPING
    mov byte [rdi+1], 0
    mov word [rdi+2], 2              ; request length = 2 words
    mov [rdi+4], r12b                ; first_keycode
    mov [rdi+5], r13b                ; count
    mov word [rdi+6], 0              ; pad

    lea rsi, [tmp_buf]
    mov rdx, 8
    call x11_buffer
    inc dword [x11_seq]

    ; Flush and read reply
    call x11_flush

    ; Read reply header (32 bytes minimum)
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 32
    syscall
    cmp rax, 32
    jl .xgk_done

    ; Reply byte 1 = keysyms_per_keycode
    movzx eax, byte [x11_buf + 1]
    mov [keysyms_per_kc], eax
    mov ebx, eax                     ; keysyms_per_kc

    ; Reply bytes 4-7 = reply length in 4-byte units (number of keysyms)
    mov eax, [x11_buf + 4]
    shl eax, 2                       ; total data bytes
    mov r13d, eax                    ; total bytes to read

    ; Read keysym data in chunks
    xor r12d, r12d                   ; bytes read so far
.xgk_read_loop:
    cmp r12d, r13d
    jge .xgk_parse
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    add rsi, r12
    mov edx, r13d
    sub edx, r12d
    cmp edx, 65536
    jle .xgk_read_ok
    mov edx, 65536
.xgk_read_ok:
    syscall
    test eax, eax
    jle .xgk_done
    add r12d, eax
    jmp .xgk_read_loop

.xgk_parse:
    ; Parse keysym data into keysym_map
    ; Data is: for each keycode, keysyms_per_kc CARD32 keysyms
    ; Store indexed by keycode (not keycode - min_keycode)
    movzx eax, byte [x11_min_keycode]
    mov ecx, eax                     ; current keycode
    xor edx, edx                     ; source offset in x11_buf
    mov ebx, [keysyms_per_kc]
.xgk_store_loop:
    cmp edx, r12d
    jge .xgk_done
    ; For this keycode, copy up to 8 keysyms
    xor esi, esi                     ; keysym index
.xgk_sym_loop:
    cmp esi, ebx
    jge .xgk_next_kc
    cmp esi, 8
    jge .xgk_skip_sym
    cmp edx, r12d
    jge .xgk_done
    ; Store: keysym_map[keycode * 8 + sym_index]
    mov eax, ecx
    shl eax, 3                       ; keycode * 8
    add eax, esi
    mov r8d, [x11_buf + rdx]
    mov [keysym_map + rax*4], r8d
    add edx, 4
    inc esi
    jmp .xgk_sym_loop
.xgk_skip_sym:
    add edx, 4
    inc esi
    jmp .xgk_sym_loop
.xgk_next_kc:
    inc ecx
    jmp .xgk_store_loop

.xgk_done:
    pop r13
    pop r12
    pop rbx
    ret

; Allocate X11 resource ID
alloc_xid:
    mov eax, [x11_rid_next]
    inc dword [x11_rid_next]
    and eax, [x11_rid_mask]
    or eax, [x11_rid_base]
    ret

; ══════════════════════════════════════════════════════════════════════
; X11 requests
; ══════════════════════════════════════════════════════════════════════

; Flush X11 write buffer
x11_flush:
    mov rdx, [x11_write_pos]
    test rdx, rdx
    jz .xf_done
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    lea rsi, [x11_write_buf]
    syscall
    mov qword [x11_write_pos], 0
.xf_done:
    ret

; Append data to X11 write buffer
; rsi = data, rdx = length
x11_buffer:
    push rbx
    mov rbx, [x11_write_pos]
    lea rdi, [x11_write_buf + rbx]
    xor ecx, ecx
.xb_loop:
    cmp rcx, rdx
    jge .xb_done
    movzx eax, byte [rsi + rcx]
    mov [rdi + rcx], al
    inc rcx
    jmp .xb_loop
.xb_done:
    add rbx, rdx
    mov [x11_write_pos], rbx
    ; Auto-flush if buffer is getting full
    cmp rbx, 14000
    jl .xb_no_flush
    call x11_flush
.xb_no_flush:
    pop rbx
    ret

; Send and receive (synchronous request)
; x11_drain_until_reply: read from x11_fd into x11_buf until a reply
; (type 1) lands. Events (type 2..127) that arrive in the meantime are
; discarded — fine while we're inside a one-shot setup, missed events
; are recovered by the next render and the next event-loop poll.
; Returns rax = 0 on success, -1 on read failure or X11 error reply.
x11_drain_until_reply:
    push r12
    push r13
.xdr_read_hdr:
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 32
    syscall
    cmp rax, 32
    jl .xdr_fail
    movzx eax, byte [x11_buf]
    test al, al
    jz .xdr_fail                  ; X11 error
    cmp al, 1
    jne .xdr_read_hdr             ; event, drop and retry
    ; Reply: drain any extra bytes (reply length in 4-byte units at +4)
    mov eax, [x11_buf + 4]
    shl eax, 2
    test eax, eax
    jz .xdr_done
    mov r12, rax                  ; remaining bytes
    mov r13, 32                   ; current write offset
.xdr_extra:
    test r12, r12
    jz .xdr_done
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    add rsi, r13
    mov rdx, r12
    cmp rdx, 32768
    jle .xdr_extra_ok
    mov rdx, 32768
.xdr_extra_ok:
    syscall
    test rax, rax
    jle .xdr_fail
    sub r12, rax
    add r13, rax
    jmp .xdr_extra
.xdr_done:
    xor eax, eax
    pop r13
    pop r12
    ret
.xdr_fail:
    mov rax, -1
    pop r13
    pop r12
    ret

x11_send_recv:
    push rbx
    push r12
    push r13
    push r14
    call x11_flush
    ; Read first chunk
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 65536
    syscall
    test rax, rax
    jle .xsr_done
    mov r12, rax              ; bytes read so far in x11_buf
    ; If reply (type 1), drain any remaining data
    cmp byte [x11_buf], 1
    jne .xsr_done
    cmp r12, 8
    jl .xsr_done
    mov eax, [x11_buf + 4]   ; reply length in 4-byte units
    shl eax, 2
    add eax, 32
    mov r13d, eax             ; total reply size
    cmp r12, r13              ; have all data?
    jge .xsr_done
    ; Drain rest of reply into the END of x11_buf (cyclic), discarding
    mov r14, r13
    sub r14, r12              ; bytes still to drain
.xsr_drain:
    test r14, r14
    jz .xsr_done
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf + 60000]   ; scratch area (overwrites ok)
    mov rdx, 4096
    cmp rdx, r14
    jle .xsr_drain_ok
    mov rdx, r14
.xsr_drain_ok:
    syscall
    test rax, rax
    jle .xsr_done
    sub r14, rax
    jmp .xsr_drain
.xsr_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Open font
x11_open_font:
    push rbx
    push r12
    push r13
    call alloc_xid
    mov [font_id], eax

    ; Determine which font name and length to use
    mov rax, [dyn_font_name_len]
    test rax, rax
    jz .xof_use_default
    ; Use dynamic font name
    lea r12, [dyn_font_name]
    mov r13, rax
    jmp .xof_build
.xof_use_default:
    lea r12, [font_name]
    mov r13, font_name_len
.xof_build:
    ; Build OpenFont request
    ; opcode=45, pad, length, fid, name_len, pad, name...
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_OPEN_FONT
    mov byte [rdi+1], 0
    ; length = (3 + pad4(name_len)/4) words
    mov ecx, r13d
    add ecx, 3
    and ecx, ~3
    shr ecx, 2
    add ecx, 3
    mov word [rdi+2], cx
    mov eax, [font_id]
    mov [rdi+4], eax
    mov word [rdi+8], r13w
    mov word [rdi+10], 0
    ; Copy font name
    lea rbx, [rdi + 12]
    xor ecx, ecx
.xof_cp:
    cmp ecx, r13d
    jge .xof_pad
    movzx eax, byte [r12 + rcx]
    mov [rbx + rcx], al
    inc ecx
    jmp .xof_cp
.xof_pad:
    ; Pad to 4
    mov eax, r13d
    add eax, 3
    and eax, ~3
    add eax, 12
    ; Send
    mov rdx, rax
    lea rsi, [tmp_buf]
    call x11_buffer
    inc dword [x11_seq]

    ; Bold companion: only when setup_font_name set dyn_bold_font_name
    mov rax, [dyn_bold_font_name_len]
    test rax, rax
    jz .xof_no_bold
    call alloc_xid
    mov [font_id_bold], eax
    lea r12, [dyn_bold_font_name]
    mov r13, [dyn_bold_font_name_len]
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_OPEN_FONT
    mov byte [rdi+1], 0
    mov ecx, r13d
    add ecx, 3
    and ecx, ~3
    shr ecx, 2
    add ecx, 3
    mov word [rdi+2], cx
    mov eax, [font_id_bold]
    mov [rdi+4], eax
    mov word [rdi+8], r13w
    mov word [rdi+10], 0
    lea rbx, [rdi + 12]
    xor ecx, ecx
.xof_bcp:
    cmp ecx, r13d
    jge .xof_bpad
    movzx eax, byte [r12 + rcx]
    mov [rbx + rcx], al
    inc ecx
    jmp .xof_bcp
.xof_bpad:
    mov eax, r13d
    add eax, 3
    and eax, ~3
    add eax, 12
    mov rdx, rax
    lea rsi, [tmp_buf]
    call x11_buffer
    inc dword [x11_seq]
    jmp .xof_done
.xof_no_bold:
    ; No matching bold variant: alias bold to medium so renderer's
    ; ChangeGC font path is a no-op for bold cells at this size.
    mov eax, [font_id]
    mov [font_id_bold], eax
.xof_done:
    pop r13
    pop r12
    pop rbx
    ret

; Query font metrics
x11_query_font:
    push rbx

    ; Build QueryFont request
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_QUERY_FONT
    mov byte [rdi+1], 0
    mov word [rdi+2], 2      ; length = 2 words
    mov eax, [font_id]
    mov [rdi+4], eax

    lea rsi, [tmp_buf]
    mov rdx, 8
    call x11_buffer
    inc dword [x11_seq]

    ; Flush and read reply
    call x11_send_recv

    ; Parse reply
    ; Reply format: standard 32 bytes header + font info
    ; offset 8: min-bounds CHARINFO (12 bytes)
    ; offset 24: max-bounds CHARINFO (12 bytes)
    ;   CHARINFO: left-sb(2), right-sb(2), width(2), ascent(2), descent(2), attrs(2)
    ; offset 40: min-char-or-byte2 (2)
    ; offset 42: max-char-or-byte2 (2)
    ; offset 46: font-ascent (2, signed)
    ; offset 48: font-descent (2, signed)
    lea rsi, [x11_buf]

    ; max-bounds character-width at offset 24+4 = 28
    movzx eax, word [rsi + 28]
    mov [char_width], ax

    ; font-ascent at offset 52
    movzx eax, word [rsi + 52]
    mov [font_ascent], ax

    ; font-descent at offset 54
    movzx eax, word [rsi + 54]
    mov [font_descent], ax

    ; char_height = ascent + descent
    movzx eax, word [font_ascent]
    movzx ecx, word [font_descent]
    add eax, ecx
    mov [char_height], ax

    pop rbx
    ret

; ──────────────────────────────────────────────────────────────────────
; Fallback font (Unifont) — covers everything the primary font lacks.
;
; build_primary_glyph_map sends QueryFont for the primary font and
; streams the per-character info, setting one bit per BMP codepoint
; in glyph_present. The render path tests this bit per cell and routes
; the cell through the fallback GC when missing.
;
; init_fallback_font opens the Unifont XLFD, queries its metrics, and
; allocates a dedicated GC bound to it. Fails silently (leaves
; fallback_font_id = 0) if Unifont isn't installed; the renderer then
; degrades to the X server's default-glyph behaviour as before.
; ──────────────────────────────────────────────────────────────────────

; Build glyph_present from primary font's QueryFont reply. Reads the
; reply in chunks via SYS_READ so we don't need to buffer arbitrarily-
; large CHARINFO arrays (Unifont's reply is ~800KB, won't fit in
; x11_buf). Stream-parses each CHARINFO and marks its codepoint bit
; when any metric is non-zero (X11 spec: "all-zero = nonexistent").
build_primary_glyph_map:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Send QueryFont for primary font.
    call x11_flush
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_QUERY_FONT
    mov byte [rdi+1], 0
    mov word [rdi+2], 2
    mov eax, [font_id]
    mov [rdi+4], eax
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    lea rsi, [tmp_buf]
    mov rdx, 8
    syscall
    inc dword [x11_seq]

    ; Read 32-byte reply header.
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 32
    syscall
    cmp rax, 32
    jl .bpgm_done
    ; Bail if not a reply.
    cmp byte [x11_buf], 1
    jne .bpgm_done

    ; Read the next 28 bytes (header bytes 32..59) so we have through
    ; the CHARINFO count at offset 56 in the WHOLE reply (which is
    ; offset 24 from the start of this chunk if we re-anchor — easier
    ; to just keep the header at x11_buf and read these next bytes
    ; into x11_buf+32).
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf + 32]
    mov rdx, 28
    syscall
    cmp rax, 28
    jl .bpgm_done

    ; Pull out what we need:
    ;   offset 40: min-char-or-byte2 (CARD16) → r12d (later)
    ;   offset 42: max-char-or-byte2 (CARD16) → r13d (later)
    ;   offset 46: number of FONTPROPs (n, CARD16)
    ;   offset 49: min-byte1 (CARD8)
    ;   offset 50: max-byte1 (CARD8)
    ;   offset 56: number of CHARINFOs (m, CARD32)
    movzx r12d, word [x11_buf + 40]    ; min-char-or-byte2
    movzx r13d, word [x11_buf + 42]    ; max-char-or-byte2
    movzx r14d, word [x11_buf + 46]    ; n
    movzx r15d, byte [x11_buf + 49]    ; min-byte1
    ; (max-byte1 unused for index→codepoint mapping; m drives loop)

    ; Skip 8*n bytes of FONTPROPs by reading & discarding.
    shl r14, 3                          ; n * 8
.bpgm_skip_props:
    test r14, r14
    jz .bpgm_props_done
    mov rax, r14
    cmp rax, 65536
    jbe .bpgm_props_chunk_ok
    mov rax, 65536
.bpgm_props_chunk_ok:
    mov rdx, rax
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    syscall
    test rax, rax
    jle .bpgm_done
    sub r14, rax
    jmp .bpgm_skip_props
.bpgm_props_done:

    ; Number of CHARINFOs (m, CARD32). mov of a 32-bit operand into a
    ; 32-bit register zero-extends into the 64-bit register, so this
    ; safely caps any garbage in the upper bits.
    mov ebx, [x11_buf + 56]             ; m
    test rbx, rbx
    jz .bpgm_done                       ; no chars

    ; chars per row = max-char-or-byte2 - min-char-or-byte2 + 1
    mov rcx, r13
    sub rcx, r12
    inc rcx                             ; rcx = chars-per-row (byte2 stride)
    test rcx, rcx
    jz .bpgm_done

    ; Stream-read CHARINFOs in 1200-byte chunks (= 100 entries each).
    xor r14, r14                        ; iterator i = 0..m-1
.bpgm_ci_loop:
    cmp r14, rbx
    jge .bpgm_done
    ; Read up to 1200 bytes at a time.
    mov rax, rbx
    sub rax, r14
    mov rdx, 100
    cmp rax, rdx
    jge .bpgm_have_chunk
    mov rdx, rax                        ; less than 100 left
.bpgm_have_chunk:
    mov r8, rdx                         ; r8 = chunk count
    imul rdx, 12                        ; bytes
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    syscall
    test rax, rax
    jle .bpgm_done
    ; Walk r8 entries.
    xor r9, r9                          ; entry index in chunk
.bpgm_ci_walk:
    cmp r9, r8
    jge .bpgm_chunk_done
    ; ptr = x11_buf + r9 * 12
    mov rax, r9
    imul rax, 12
    lea rdi, [x11_buf + rax]
    ; Test if any of left-sb, right-sb, width, ascent, descent, attrs
    ; is non-zero. They're 6 consecutive CARD16s = 12 bytes.
    mov rax, [rdi]                      ; bytes 0..7
    or rax, [rdi + 4]                   ; OR in bytes 4..11 (overlap doesn't matter)
    test rax, rax
    jz .bpgm_ci_zero                    ; absent → leave bit clear
    ; Compute codepoint from i = r14+r9.
    mov rax, r14
    add rax, r9
    xor edx, edx
    div rcx                             ; rax = byte1 offset, rdx = byte2 offset
    add rax, r15                        ; + min-byte1
    add rdx, r12                        ; + min-char-or-byte2
    ; codepoint = (byte1 << 8) | byte2
    shl rax, 8
    or rax, rdx
    cmp rax, 0xFFFF
    ja .bpgm_ci_zero                    ; non-BMP, ignore
    ; Set bit: glyph_present[cp >> 3] |= 1 << (cp & 7)
    mov rsi, rax
    shr rsi, 3
    mov dl, al
    and dl, 7
    mov bh, 1
    shl bh, cl                          ; can't, cl already used. Redo.
    ; Recompute shift in cl explicitly.
    mov cl, dl
    mov dl, 1
    shl dl, cl
    or [glyph_present + rsi], dl
    ; Restore rcx for the divide loop's next round.
    mov rcx, r13
    sub rcx, r12
    inc rcx
.bpgm_ci_zero:
    inc r9
    jmp .bpgm_ci_walk
.bpgm_chunk_done:
    add r14, r8
    jmp .bpgm_ci_loop
.bpgm_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Open the Unifont XLFD as the fallback font, query its char_width
; and ascent (used for centering the fallback glyph in the primary
; cell), and allocate a dedicated GC. Failure leaves fallback_font_id
; = 0; the renderer then skips the fallback path entirely.
init_fallback_font:
    push rbx
    push r12
    push r13

    ; OpenFont
    call alloc_xid
    mov [fallback_font_id], eax
    mov r12d, eax                       ; r12 = fallback fid

    lea rdi, [tmp_buf]
    mov byte [rdi], X11_OPEN_FONT
    mov byte [rdi+1], 0
    ; length = 3 + (name_len + 3)/4 words
    mov ecx, fallback_font_xlfd_len
    add ecx, 3
    and ecx, ~3
    shr ecx, 2
    add ecx, 3
    mov word [rdi+2], cx
    mov [rdi+4], r12d
    mov word [rdi+8], fallback_font_xlfd_len
    mov word [rdi+10], 0
    ; Copy name
    lea rbx, [rdi + 12]
    xor ecx, ecx
.iff_cp:
    cmp ecx, fallback_font_xlfd_len
    jge .iff_pad
    movzx eax, byte [fallback_font_xlfd + rcx]
    mov [rbx + rcx], al
    inc ecx
    jmp .iff_cp
.iff_pad:
    mov eax, fallback_font_xlfd_len
    add eax, 3
    and eax, ~3
    add eax, 12
    mov rdx, rax
    lea rsi, [tmp_buf]
    call x11_buffer
    inc dword [x11_seq]

    ; QueryFont — extract metrics. If this fails (no glyphs / font not
    ; available), the X server returns an error which we'd see as a
    ; non-reply byte; treat as "no fallback".
    call x11_flush
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_QUERY_FONT
    mov byte [rdi+1], 0
    mov word [rdi+2], 2
    mov [rdi+4], r12d
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    lea rsi, [tmp_buf]
    mov rdx, 8
    syscall
    inc dword [x11_seq]

    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 60
    syscall
    cmp rax, 60
    jl .iff_no_font
    cmp byte [x11_buf], 1
    jne .iff_no_font

    ; Drain the rest of the QueryFont reply (we don't need its
    ; per-char info, just the metrics already captured).
    mov eax, [x11_buf + 4]
    shl eax, 2
    add eax, 32
    sub eax, 60                         ; bytes still to drain
    mov r13d, eax
.iff_drain:
    test r13d, r13d
    jle .iff_drained
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 65536
    cmp r13, rdx
    jbe .iff_drain_chunk_ok
    mov rdx, 65536
    jmp .iff_drain_do
.iff_drain_chunk_ok:
    mov rdx, r13
.iff_drain_do:
    syscall
    test rax, rax
    jle .iff_drained
    sub r13d, eax
    jmp .iff_drain
.iff_drained:

    ; max-bounds character-width at offset 24+4 = 28
    movzx eax, word [x11_buf + 28]
    mov [fallback_char_w], ax
    ; font-ascent at offset 52
    movzx eax, word [x11_buf + 52]
    mov [fallback_ascent], ax

    ; CreateGC bound to the fallback font.
    call alloc_xid
    mov [fallback_gc_id], eax
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CREATE_GC
    mov byte [rdi+1], 0
    mov word [rdi+2], 6                 ; 4 base + 2 value words
    mov eax, [fallback_gc_id]
    mov [rdi+4], eax
    mov eax, [win_id]
    mov [rdi+8], eax
    ; value-mask: GCFont (bit 14 = 0x4000) | GCForeground (bit 2 = 0x4)
    ; — set foreground later per-draw via ChangeGC.
    mov dword [rdi+12], 0x4004
    mov dword [rdi+16], 0xFFFFFFFF      ; foreground placeholder (set per-draw)
    mov [rdi+20], r12d                  ; font
    mov rdx, 24
    lea rsi, [tmp_buf]
    call x11_buffer
    inc dword [x11_seq]
    pop r13
    pop r12
    pop rbx
    ret
.iff_no_font:
    ; Failure: zero out the fallback so the renderer skips it.
    mov dword [fallback_font_id], 0
    pop r13
    pop r12
    pop rbx
    ret

; Create window
x11_create_window:
    push rbx

    call alloc_xid
    mov [win_id], eax

    ; Calculate window size: use full screen (WM may shrink it)
    movzx eax, word [x11_screen_width]
    test eax, eax
    jnz .xcw_have_w
    movzx eax, word [char_width]
    imul eax, DEFAULT_COLS
.xcw_have_w:
    mov [win_width], rax
    ; Compute initial grid_cols = win_width / char_width
    movzx ecx, word [char_width]
    test ecx, ecx
    jz .xcw_skip_cols
    xor edx, edx
    div rcx
    cmp rax, MAX_COLS
    jle .xcw_cols_ok
    mov rax, MAX_COLS
.xcw_cols_ok:
    mov [grid_cols], rax
.xcw_skip_cols:

    movzx eax, word [x11_screen_height]
    test eax, eax
    jnz .xcw_have_h
    movzx eax, word [char_height]
    imul eax, DEFAULT_ROWS
.xcw_have_h:
    mov [win_height], rax
    ; Compute initial grid_rows = win_height / char_height
    movzx ecx, word [char_height]
    test ecx, ecx
    jz .xcw_skip_rows
    xor edx, edx
    div rcx
    cmp rax, MAX_ROWS
    jle .xcw_rows_ok
    mov rax, MAX_ROWS
.xcw_rows_ok:
    mov [grid_rows], rax
.xcw_skip_rows:

    ; Decide whether to use the ARGB32 visual for transparency.
    ; Conditions: opacity configured, opacity < 255, ARGB visual found,
    ; AND a compositor is running (else alpha bits are stored but
    ; ignored on display, so we'd just look opaque). Without a
    ; compositor we leave the visual alone and let
    ; setup_pseudo_transparency tint palette[0] from the wallpaper.
    ; The "transparent path taken" flag lives in [x11_argb_colormap]
    ; (0 = simple path, nonzero = ARGB) so it survives across syscalls
    ; in x11_create_colormap.
    cmp byte [cfg_opacity_set], 1
    jne .xcw_pick_visual
    movzx eax, byte [cfg_opacity]
    cmp eax, 255
    jae .xcw_pick_visual
    cmp dword [x11_argb_visual], 0
    je .xcw_pick_visual
    cmp byte [compositor_active], 1
    jne .xcw_pick_visual
    call x11_create_colormap
    call palette_apply_alpha
.xcw_pick_visual:

    ; Build CreateWindow request
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CREATE_WINDOW     ; opcode
    cmp dword [x11_argb_colormap], 0
    je .xcw_depth_root
    mov byte [rdi+1], 32                  ; depth
    mov word [rdi+2], 12                  ; length (8 + 4 values = 12 words)
    mov eax, [x11_argb_visual]
    jmp .xcw_visual_set
.xcw_depth_root:
    mov al, [x11_root_depth]
    mov byte [rdi+1], al
    mov word [rdi+2], 10                  ; length (8 + 2 values = 10 words)
    mov eax, [x11_root_visual]
.xcw_visual_set:
    mov [rdi+24], eax                     ; visual

    mov eax, [win_id]
    mov [rdi+4], eax                      ; wid
    mov eax, [x11_root_window]
    mov [rdi+8], eax                      ; parent
    mov word [rdi+12], 0                  ; x
    mov word [rdi+14], 0                  ; y
    mov eax, [win_width]
    mov word [rdi+16], ax                 ; width
    mov eax, [win_height]
    mov word [rdi+18], ax                 ; height
    mov word [rdi+20], 0                  ; border-width
    mov word [rdi+22], 1                  ; class = InputOutput

    ; Compute background pixel (with alpha if transparent)
    cmp byte [cfg_bg_set], 1
    jne .xcw_default_bg
    mov eax, [cfg_bg_pixel]
    jmp .xcw_set_bg
.xcw_default_bg:
    mov eax, [x11_black_pixel]
.xcw_set_bg:
    cmp dword [x11_argb_colormap], 0
    je .xcw_no_alpha
    and eax, 0x00FFFFFF
    movzx ecx, byte [cfg_opacity]
    shl ecx, 24
    or eax, ecx
.xcw_no_alpha:
    mov r10d, eax                         ; r10 = bg pixel (ARGB or RGB)

    ; Value mask + values (ascending CW bit order)
    cmp dword [x11_argb_colormap], 0
    je .xcw_mask_simple
    mov dword [rdi+28], CW_BACK_PIXEL | CW_BORDER_PIXEL | CW_EVENT_MASK | CW_COLORMAP
    mov [rdi+32], r10d                    ; back-pixel
    mov [rdi+36], r10d                    ; border-pixel (any valid pixel)
    mov dword [rdi+40], EVENT_MASK_ALL    ; event-mask
    mov eax, [x11_argb_colormap]
    mov [rdi+44], eax                     ; colormap
    mov rdx, 48
    jmp .xcw_send
.xcw_mask_simple:
    mov dword [rdi+28], CW_BACK_PIXEL | CW_EVENT_MASK
    mov [rdi+32], r10d                    ; back-pixel
    mov dword [rdi+36], EVENT_MASK_ALL    ; event-mask
    mov rdx, 40
.xcw_send:
    lea rsi, [tmp_buf]
    call x11_buffer
    inc dword [x11_seq]

    pop rbx
    ret

; CreateColormap (opcode 78) for the ARGB visual.
; Stores colormap id in x11_argb_colormap.
x11_create_colormap:
    push rbx
    call alloc_xid
    mov [x11_argb_colormap], eax
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CREATE_COLORMAP
    mov byte [rdi+1], 0                   ; alloc = None
    mov word [rdi+2], 4                   ; length = 4 words
    mov eax, [x11_argb_colormap]
    mov [rdi+4], eax                      ; mid
    mov eax, [x11_root_window]
    mov [rdi+8], eax                      ; window (any with same root)
    mov eax, [x11_argb_visual]
    mov [rdi+12], eax                     ; visual
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]
    pop rbx
    ret

; Create graphics context
x11_create_gc:
    push rbx

    ; GC for text
    call alloc_xid
    mov [gc_id], eax

    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CREATE_GC
    mov byte [rdi+1], 0
    mov word [rdi+2], 7      ; length = 4 + 3 values
    mov eax, [gc_id]
    mov [rdi+4], eax         ; cid
    mov eax, [win_id]
    mov [rdi+8], eax         ; drawable
    mov dword [rdi+12], GC_FOREGROUND | GC_BACKGROUND | GC_FONT
    ; GC foreground: use cfg_fg_pixel or white
    cmp byte [cfg_fg_set], 1
    jne .xgc_def_fg
    mov eax, [cfg_fg_pixel]
    jmp .xgc_set_fg
.xgc_def_fg:
    mov eax, [x11_white_pixel]
.xgc_set_fg:
    mov [rdi+16], eax        ; foreground
    ; GC background: use cfg_bg_pixel or black
    cmp byte [cfg_bg_set], 1
    jne .xgc_def_bg
    mov eax, [cfg_bg_pixel]
    jmp .xgc_set_bg
.xgc_def_bg:
    mov eax, [x11_black_pixel]
.xgc_set_bg:
    mov [rdi+20], eax        ; background
    mov eax, [font_id]
    mov [rdi+24], eax        ; font
    mov [gc_current_font], eax

    lea rsi, [tmp_buf]
    mov rdx, 28
    call x11_buffer
    inc dword [x11_seq]

    ; GC for background fills
    call alloc_xid
    mov [gc_bg_id], eax

    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CREATE_GC
    mov byte [rdi+1], 0
    mov word [rdi+2], 5      ; length = 4 + 1 value
    mov eax, [gc_bg_id]
    mov [rdi+4], eax
    mov eax, [win_id]
    mov [rdi+8], eax
    mov dword [rdi+12], GC_FOREGROUND
    ; bg fill GC: use cfg_bg_pixel or black
    cmp byte [cfg_bg_set], 1
    jne .xgcbg_def
    mov eax, [cfg_bg_pixel]
    jmp .xgcbg_set
.xgcbg_def:
    mov eax, [x11_black_pixel]
.xgcbg_set:
    mov [rdi+16], eax

    lea rsi, [tmp_buf]
    mov rdx, 20
    call x11_buffer
    inc dword [x11_seq]

    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; XRender extension setup. Probes for RENDER, then queries PictFormats
; to find the ARGB32 format we need for emoji source pictures and the
; format matching our window's visual. On success creates a Picture
; wrapping our window so emoji can be composited onto it. All emoji
; rendering is silently disabled if RENDER is unavailable.
; ══════════════════════════════════════════════════════════════════════
x11_setup_render:
    push rbx
    push r12
    push r13
    push r14

    ; QueryExtension "RENDER"
    call x11_flush
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_QUERY_EXTENSION
    mov byte [rdi+1], 0
    mov word [rdi+2], 2 + (render_ext_len + 3) / 4
    mov word [rdi+4], render_ext_len
    mov word [rdi+6], 0
    lea rsi, [render_ext_str]
    lea rbx, [tmp_buf + 8]
    xor ecx, ecx
.xsr_cp_name:
    cmp ecx, render_ext_len
    jge .xsr_send_qe
    movzx eax, byte [rsi + rcx]
    mov [rbx + rcx], al
    inc ecx
    jmp .xsr_cp_name
.xsr_send_qe:
    mov eax, render_ext_len
    add eax, 3
    and eax, ~3
    add eax, 8
    mov rdx, rax
    lea rsi, [tmp_buf]
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    inc dword [x11_seq]
    call x11_drain_until_reply
    ; Reply layout: byte 8 = present, byte 9 = major opcode
    cmp byte [x11_buf + 8], 1
    jne .xsr_unavailable
    movzx eax, byte [x11_buf + 9]
    mov [render_major], eax

    ; RenderQueryPictFormats (variable-size reply with all formats)
    lea rdi, [tmp_buf]
    mov al, [render_major]
    mov [rdi], al
    mov byte [rdi+1], RENDER_QUERY_PICT_FORMATS
    mov word [rdi+2], 1
    mov rdx, 4
    lea rsi, [tmp_buf]
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    inc dword [x11_seq]
    call x11_drain_until_reply
    ; Reply: bytes 8-11 = num formats, then 28 bytes per format starting
    ; at offset 32. Each format: id(4), type(1), depth(1), pad(2),
    ; r_shift(2), r_mask(2), g_shift(2), g_mask(2), b_shift(2), b_mask(2),
    ; a_shift(2), a_mask(2), colormap(4).
    mov ecx, [x11_buf + 8]              ; num formats
    test ecx, ecx
    jz .xsr_unavailable
    lea rbx, [x11_buf + 32]             ; first format
.xsr_fmt_loop:
    test ecx, ecx
    jz .xsr_fmt_done
    ; type must be Direct (1)
    cmp byte [rbx + 4], 1
    jne .xsr_fmt_next
    ; PICTFORMINFO offsets (per RENDER spec):
    ;   +5 depth, +8 r_shift, +10 r_mask, +12 g_shift, +14 g_mask,
    ;   +16 b_shift, +18 b_mask, +20 a_shift, +22 a_mask
    movzx eax, byte [rbx + 5]           ; depth
    movzx edx, word [rbx + 8]           ; r_shift
    movzx esi, word [rbx + 12]          ; g_shift
    movzx edi, word [rbx + 16]          ; b_shift
    movzx r8d, word [rbx + 20]          ; a_shift
    movzx r9d, word [rbx + 22]          ; a_mask
    ; ARGB32: depth=32, r_shift=16, g_shift=8, b_shift=0, a_shift=24, a_mask=0xFF
    cmp eax, 32
    jne .xsr_check_a8
    cmp edx, 16
    jne .xsr_check_a8
    cmp esi, 8
    jne .xsr_check_a8
    test edi, edi
    jnz .xsr_check_a8
    cmp r8d, 24
    jne .xsr_check_a8
    cmp r9d, 0xFF
    jne .xsr_check_a8
    cmp dword [render_format_argb32], 0
    jne .xsr_check_a8                   ; already found
    mov eax, [rbx]
    mov [render_format_argb32], eax
    jmp .xsr_check_a8
.xsr_check_a8:
    ; Alpha8: depth=8, RGB shifts=0/0/0, a_shift=0, a_mask=0xFF
    movzx eax, byte [rbx + 5]
    cmp eax, 8
    jne .xsr_check_window
    test edx, edx                       ; r_shift = 0
    jnz .xsr_check_window
    test esi, esi                       ; g_shift = 0
    jnz .xsr_check_window
    test edi, edi                       ; b_shift = 0
    jnz .xsr_check_window
    test r8d, r8d                       ; a_shift = 0
    jnz .xsr_check_window
    cmp r9d, 0xFF                       ; a_mask = 0xFF
    jne .xsr_check_window
    cmp dword [render_format_a8], 0
    jne .xsr_check_window
    mov eax, [rbx]
    mov [render_format_a8], eax
    jmp .xsr_check_window
.xsr_check_window:
    ; Window format: matches our window's depth (24 normally, 32 in
    ; ARGB transparency mode). RGB ordering R=16/G=8/B=0.
    movzx r12d, byte [rbx + 5]          ; depth
    movzx r13d, word [rbx + 8]          ; r_shift
    movzx r14d, word [rbx + 12]         ; g_shift
    movzx eax, word [rbx + 16]          ; b_shift
    cmp r13d, 16
    jne .xsr_fmt_next
    cmp r14d, 8
    jne .xsr_fmt_next
    test eax, eax
    jnz .xsr_fmt_next
    ; Take a depth-24 format if we don't have a window format yet, or
    ; upgrade to depth-32 if ARGB visual is in use.
    cmp dword [x11_argb_colormap], 0
    je .xsr_want_24
    cmp r12d, 32
    jne .xsr_fmt_next
    jmp .xsr_take_window
.xsr_want_24:
    cmp r12d, 24
    jne .xsr_fmt_next
.xsr_take_window:
    cmp dword [render_format_window], 0
    jne .xsr_fmt_next
    mov eax, [rbx]
    mov [render_format_window], eax
.xsr_fmt_next:
    add rbx, 28
    dec ecx
    jmp .xsr_fmt_loop
.xsr_fmt_done:
    ; Need both formats to proceed
    cmp dword [render_format_argb32], 0
    je .xsr_unavailable
    cmp dword [render_format_window], 0
    je .xsr_unavailable

    ; CreatePicture wrapping our window so we can composite onto it.
    ; Request: opcode=major, minor=4, length=5, picture-id, drawable,
    ; format, value-mask=0.
    call alloc_xid
    mov [render_window_picture], eax
    lea rdi, [tmp_buf]
    mov al, [render_major]
    mov [rdi], al
    mov byte [rdi+1], RENDER_CREATE_PICTURE
    mov word [rdi+2], 5
    mov eax, [render_window_picture]
    mov [rdi+4], eax
    mov eax, [win_id]
    mov [rdi+8], eax
    mov eax, [render_format_window]
    mov [rdi+12], eax
    mov dword [rdi+16], 0               ; value-mask
    lea rsi, [tmp_buf]
    mov rdx, 20
    call x11_buffer
    inc dword [x11_seq]

    ; render_temp_gc is created lazily on the first emoji render so its
    ; depth matches the depth-32 emoji pixmap (a depth-24 GC can't
    ; PutImage onto a depth-32 drawable).
    call x11_flush

    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.xsr_unavailable:
    mov dword [render_major], 0
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; find_or_alloc_emoji: edi = 32-bit codepoint. Returns rax = emoji
; index (>= 0), or -1 if the cache is full. Linear search — N is
; small (max 1024) and emoji are sticky (same set on each refresh).
; ══════════════════════════════════════════════════════════════════════
find_or_alloc_emoji:
    push rbx
    push r12
    mov r12, [emoji_count]
    xor rbx, rbx
.foe_search:
    cmp rbx, r12
    jge .foe_alloc
    cmp [emoji_codepoints + rbx*4], edi
    je .foe_found
    inc rbx
    jmp .foe_search
.foe_found:
    mov rax, rbx
    pop r12
    pop rbx
    ret
.foe_alloc:
    cmp r12, MAX_EMOJI
    jge .foe_full
    mov [emoji_codepoints + r12*4], edi
    mov dword [emoji_pictures + r12*4], 0
    mov dword [emoji_pixmaps + r12*4], 0
    mov rax, r12
    inc r12
    mov [emoji_count], r12
    pop r12
    pop rbx
    ret
.foe_full:
    mov rax, -1
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; itoa_decimal: rdi = unsigned value, rsi = output buffer.
; Writes decimal digits (no terminator). Returns rax = number of bytes
; written. Used for assembling the convert size argument.
; ══════════════════════════════════════════════════════════════════════
itoa_decimal:
    push rbx
    push r12
    push r13
    mov r12, rsi             ; output start
    mov rax, rdi
    mov ecx, 10
    sub rsp, 24
    mov r13, rsp             ; scratch (digits in reverse)
    xor ebx, ebx
.itd_loop:
    xor edx, edx
    div rcx
    add dl, '0'
    mov [r13 + rbx], dl
    inc ebx
    test rax, rax
    jnz .itd_loop
    ; Copy reversed
    xor ecx, ecx
.itd_copy:
    cmp ecx, ebx
    jge .itd_done
    mov edx, ebx
    sub edx, ecx
    dec edx
    mov al, [r13 + rdx]
    mov [r12 + rcx], al
    inc ecx
    jmp .itd_copy
.itd_done:
    add rsp, 24
    mov rax, rcx
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; encode_utf8: edi = codepoint, rsi = output buffer. Writes 1-4 bytes.
; Returns rax = bytes written.
; ══════════════════════════════════════════════════════════════════════
encode_utf8:
    cmp edi, 0x80
    jb .eu_1
    cmp edi, 0x800
    jb .eu_2
    cmp edi, 0x10000
    jb .eu_3
.eu_4:
    mov eax, edi
    shr eax, 18
    or al, 0xF0
    mov [rsi], al
    mov eax, edi
    shr eax, 12
    and eax, 0x3F
    or al, 0x80
    mov [rsi+1], al
    mov eax, edi
    shr eax, 6
    and eax, 0x3F
    or al, 0x80
    mov [rsi+2], al
    mov eax, edi
    and eax, 0x3F
    or al, 0x80
    mov [rsi+3], al
    mov eax, 4
    ret
.eu_3:
    mov eax, edi
    shr eax, 12
    or al, 0xE0
    mov [rsi], al
    mov eax, edi
    shr eax, 6
    and eax, 0x3F
    or al, 0x80
    mov [rsi+1], al
    mov eax, edi
    and eax, 0x3F
    or al, 0x80
    mov [rsi+2], al
    mov eax, 3
    ret
.eu_2:
    mov eax, edi
    shr eax, 6
    or al, 0xC0
    mov [rsi], al
    mov eax, edi
    and eax, 0x3F
    or al, 0x80
    mov [rsi+1], al
    mov eax, 2
    ret
.eu_1:
    mov al, dil
    mov [rsi], al
    mov eax, 1
    ret

; ══════════════════════════════════════════════════════════════════════
; Emoji disk cache helpers. The first emoji render touches mkdir to
; build $HOME/.cache/glass/emoji once; thereafter every glyph is
; loaded from disk in a single read syscall instead of forking convert.
; Cache key encodes both the codepoint and the cell-pixel dimensions
; so a font/size change produces a separate cache file.
; ══════════════════════════════════════════════════════════════════════

; find_home: returns HOME string in rax (NULL if not found).
emoji_find_home:
    mov rdi, [envp]
.efh_loop:
    mov rax, [rdi]
    test rax, rax
    jz .efh_none
    cmp dword [rax], 'HOME'
    jne .efh_next
    cmp byte [rax + 4], '='
    jne .efh_next
    lea rax, [rax + 5]
    ret
.efh_next:
    add rdi, 8
    jmp .efh_loop
.efh_none:
    xor eax, eax
    ret

; emoji_strcpy_advance: rdi=dst, rsi=src. Copies through (excluding)
; the NUL. Returns rdi past last byte written.
emoji_strcpy_advance:
    push rax
.esa_loop:
    mov al, [rsi]
    test al, al
    jz .esa_done
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .esa_loop
.esa_done:
    pop rax
    ret

; emoji_hex8: rdi = 32-bit value, rsi = output buffer. Writes 8
; uppercase hex digits, returns rax = 8.
emoji_hex8:
    push rbx
    mov ebx, 7
.eh8_loop:
    mov ecx, ebx
    shl ecx, 2
    mov eax, edi
    shr eax, cl
    and eax, 0xF
    cmp al, 10
    jb .eh8_digit
    add al, 'A' - 10
    jmp .eh8_put
.eh8_digit:
    add al, '0'
.eh8_put:
    mov edx, 7
    sub edx, ebx
    mov [rsi + rdx], al
    test ebx, ebx
    jz .eh8_done
    dec ebx
    jmp .eh8_loop
.eh8_done:
    mov eax, 8
    pop rbx
    ret

; emoji_build_cache_path: edi = codepoint, esi = width, edx = height.
; Writes to emoji_cache_path. Also fills emoji_cache_dir with the
; parent directory so ensure_cache_dir can mkdir it. Returns rax = 1
; on success, 0 if HOME isn't set.
emoji_build_cache_path:
    push rbx
    push r12
    push r13
    push r14
    mov r12d, edi               ; codepoint
    mov r13d, esi               ; width
    mov r14d, edx               ; height
    call emoji_find_home
    test rax, rax
    jz .ebcp_fail
    mov rsi, rax
    lea rdi, [emoji_cache_dir]
    call emoji_strcpy_advance
    lea rsi, [emoji_cache_dir_suffix]
    call emoji_strcpy_advance
    mov byte [rdi], 0
    ; Now build the file path: dir + "/" + hex(codepoint) + "-WxH.rgba"
    lea rdi, [emoji_cache_path]
    lea rsi, [emoji_cache_dir]
    call emoji_strcpy_advance
    mov byte [rdi], '/'
    inc rdi
    mov rsi, rdi                 ; itoa/hex helpers want rsi=dst
    mov edi, r12d
    call emoji_hex8
    add rsi, rax
    mov byte [rsi], '-'
    inc rsi
    mov edi, r13d                ; width
    call itoa_decimal
    add rsi, rax
    mov byte [rsi], 'x'
    inc rsi
    mov edi, r14d                ; height
    call itoa_decimal
    add rsi, rax
    mov rdi, rsi
    lea rsi, [.ebcp_ext]
    call emoji_strcpy_advance
    mov byte [rdi], 0

    ; Also build the system-bundled cache path for fallback lookup.
    ; Format: /usr/local/share/glass/emoji/<HEX>-WxH.rgba
    lea rdi, [emoji_sys_cache_path]
    lea rsi, [emoji_sys_cache_dir]
    call emoji_strcpy_advance
    mov byte [rdi], '/'
    inc rdi
    mov rsi, rdi
    mov edi, r12d
    call emoji_hex8
    add rsi, rax
    mov byte [rsi], '-'
    inc rsi
    mov edi, r13d
    call itoa_decimal
    add rsi, rax
    mov byte [rsi], 'x'
    inc rsi
    mov edi, r14d
    call itoa_decimal
    add rsi, rax
    mov rdi, rsi
    lea rsi, [.ebcp_ext]
    call emoji_strcpy_advance
    mov byte [rdi], 0

    mov eax, 1
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.ebcp_fail:
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.ebcp_ext: db ".rgba", 0

; emoji_ensure_cache_dir: mkdir's $HOME/.cache, /.cache/glass and
; /.cache/glass/emoji. Idempotent; ignores EEXIST. Caller has filled
; emoji_cache_dir as a side-effect of build_cache_path.
emoji_ensure_cache_dir:
    cmp byte [emoji_cache_dirs_made], 1
    je .eecd_done
    push rbx
    push r12
    ; Build $HOME/.cache then $HOME/.cache/glass then full dir.
    call emoji_find_home
    test rax, rax
    jz .eecd_pop
    mov rsi, rax
    lea rdi, [tmp_buf]
    call emoji_strcpy_advance
    push rdi                     ; save cursor at end of HOME
    lea rsi, [emoji_cache_dotcache]
    call emoji_strcpy_advance
    mov byte [rdi], 0
    mov rax, SYS_MKDIR
    lea rdi, [tmp_buf]
    mov esi, 0o755
    syscall                       ; ignore EEXIST
    pop rdi
    push rdi
    lea rsi, [emoji_cache_glass]
    call emoji_strcpy_advance
    mov byte [rdi], 0
    mov rax, SYS_MKDIR
    lea rdi, [tmp_buf]
    mov esi, 0o755
    syscall
    pop rdi
    lea rsi, [emoji_cache_dir_suffix]
    call emoji_strcpy_advance
    mov byte [rdi], 0
    mov rax, SYS_MKDIR
    lea rdi, [tmp_buf]
    mov esi, 0o755
    syscall
    mov byte [emoji_cache_dirs_made], 1
.eecd_pop:
    pop r12
    pop rbx
.eecd_done:
    ret

; emoji_try_load_cache: rdi = path, rsi = expected size in bytes.
; Reads the file into emoji_raster_buf if it exists. Returns rax =
; bytes read on success, 0 on miss.
emoji_try_load_cache:
    push rbx
    push r12
    mov r12, rsi                 ; expected size
    mov rax, SYS_OPEN
    ; rdi already = path
    xor esi, esi                 ; O_RDONLY
    xor edx, edx
    syscall
    test rax, rax
    js .etlc_miss
    mov ebx, eax
    mov rax, SYS_READ
    mov edi, ebx
    lea rsi, [emoji_raster_buf]
    mov rdx, r12
    syscall
    mov r12, rax                 ; bytes actually read
    mov rax, SYS_CLOSE
    mov edi, ebx
    syscall
    mov rax, r12
    pop r12
    pop rbx
    ret
.etlc_miss:
    xor eax, eax
    pop r12
    pop rbx
    ret

; emoji_save_cache: rdi = byte count from emoji_raster_buf to write
; to emoji_cache_path. Best-effort.
emoji_save_cache:
    push rbx
    push r12
    mov r12, rdi
    call emoji_ensure_cache_dir
    mov rax, SYS_OPEN
    lea rdi, [emoji_cache_path]
    mov esi, O_WRONLY | O_CREAT | O_TRUNC
    mov edx, 0o644
    syscall
    test rax, rax
    js .esc_done
    mov ebx, eax
    mov rax, SYS_WRITE
    mov edi, ebx
    lea rsi, [emoji_raster_buf]
    mov rdx, r12
    syscall
    mov rax, SYS_CLOSE
    mov edi, ebx
    syscall
.esc_done:
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; render_emoji_glyph: rdi = emoji index. Forks `convert` to rasterize
; the emoji codepoint at cell size into RGBA, then uploads it as a
; depth-32 Pixmap and wraps it in an XRender Picture. Stores the IDs
; in emoji_pixmaps[index] / emoji_pictures[index]. No-op if the
; picture is already cached.
;
; r12 = index, r13 = pixmap width, r14 = pixmap height throughout.
; ══════════════════════════════════════════════════════════════════════
render_emoji_glyph:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi             ; index
    mov eax, [emoji_pictures + r12*4]
    test eax, eax
    jnz .reg_done

    ; Pixmap dimensions: 2-cells wide (emoji at cell width are illegible)
    movzx r13d, word [char_width]
    add r13d, r13d
    movzx r14d, word [char_height]

    ; Try the on-disk caches first (user, then bundled system). A hit
    ; skips the ~70ms convert fork entirely and proceeds straight to
    ; PutImage with the cached RGBA.
    mov edi, [emoji_codepoints + r12*4]
    mov esi, r13d
    mov edx, r14d
    call emoji_build_cache_path
    test eax, eax
    jz .reg_no_cache
    mov ebx, r13d
    imul ebx, r14d
    shl ebx, 2                            ; expected size = W*H*4
    ; Try user cache
    lea rdi, [emoji_cache_path]
    mov esi, ebx
    call emoji_try_load_cache
    cmp rax, rbx
    je .reg_have_raster
    ; Try system bundled cache
    lea rdi, [emoji_sys_cache_path]
    mov esi, ebx
    call emoji_try_load_cache
    cmp rax, rbx
    je .reg_have_raster

.reg_no_cache:
    ; Build "WxH\0" into emoji_size_arg
    mov edi, r13d
    lea rsi, [emoji_size_arg]
    call itoa_decimal
    mov ebx, eax
    mov byte [emoji_size_arg + rbx], 'x'
    inc ebx
    mov edi, r14d
    lea rsi, [emoji_size_arg + rbx]
    call itoa_decimal
    add ebx, eax
    mov byte [emoji_size_arg + rbx], 0

    ; Build the pango: argument incrementally so we never need strlen.
    ; rdi tracks the write cursor; r15 saved across calls below.
    lea rdi, [emoji_pango_arg]
    lea rsi, [.reg_pango_prefix]
    call .reg_strcpy_advance     ; rdi = end after copy
    ; pointsize = char_height * 700 (Pango units of 1/1024 pt, fits cell)
    mov eax, r14d
    imul eax, 700
    mov r15, rdi                  ; save dest
    mov rsi, rdi
    mov edi, eax
    call itoa_decimal
    mov rdi, r15
    add rdi, rax
    lea rsi, [.reg_pango_mid]
    call .reg_strcpy_advance
    ; UTF-8 bytes for the emoji codepoint. encode_utf8 takes edi as
    ; the codepoint and rsi as the destination, returns bytes-written
    ; in rax. Save the cursor in rsi first so we can advance after.
    mov rsi, rdi                  ; rsi = current write cursor
    mov edi, [emoji_codepoints + r12*4]
    call encode_utf8
    add rsi, rax
    mov rdi, rsi                  ; rdi = cursor after the UTF-8 bytes
    lea rsi, [.reg_pango_suffix]
    call .reg_strcpy_advance
    mov byte [rdi], 0

    ; Build argv array
    lea rax, [convert_path]
    mov [emoji_argv + 0*8], rax
    lea rax, [convert_arg_size]
    mov [emoji_argv + 1*8], rax
    lea rax, [emoji_size_arg]
    mov [emoji_argv + 2*8], rax
    lea rax, [convert_arg_bg]
    mov [emoji_argv + 3*8], rax
    lea rax, [convert_arg_none]
    mov [emoji_argv + 4*8], rax
    lea rax, [emoji_pango_arg]
    mov [emoji_argv + 5*8], rax
    lea rax, [convert_arg_depth]
    mov [emoji_argv + 6*8], rax
    lea rax, [convert_arg_8]
    mov [emoji_argv + 7*8], rax
    lea rax, [convert_arg_rgba]
    mov [emoji_argv + 8*8], rax
    mov qword [emoji_argv + 9*8], 0

    ; Create pipe (read end goes to parent, write end to child stdout)
    sub rsp, 16
    mov rax, SYS_PIPE
    mov rdi, rsp
    syscall
    test rax, rax
    js .reg_pipe_fail
    mov ebx, [rsp]              ; read fd
    mov r15d, [rsp + 4]          ; write fd
    add rsp, 16

    ; Fork
    mov rax, SYS_FORK
    syscall
    test rax, rax
    js .reg_fork_fail
    jnz .reg_parent

    ; Child: dup2(write_fd, 1), close pipe ends, exec convert
    mov rax, SYS_DUP2
    mov edi, r15d
    mov esi, 1
    syscall
    mov rax, SYS_CLOSE
    mov edi, ebx
    syscall
    mov rax, SYS_CLOSE
    mov edi, r15d
    syscall
    mov rax, SYS_EXECVE
    lea rdi, [convert_path]
    lea rsi, [emoji_argv]
    mov rdx, [envp]
    syscall
    ; If exec fails, exit with error
    mov rax, SYS_EXIT
    mov rdi, 127
    syscall

.reg_parent:
    ; rax = child pid; ebx = read fd, r15d = write fd.
    ; Close write end so the pipe sees EOF after the child finishes.
    push rax                       ; save child pid
    mov rax, SYS_CLOSE
    mov edi, r15d
    syscall
    pop r15                        ; r15 = child pid

    ; Pre-compute expected raster size = (char_width*2) * char_height * 4
    movzx eax, word [char_width]
    add eax, eax
    movzx edx, word [char_height]
    imul eax, edx
    shl eax, 2
    mov r13, rax                   ; total bytes expected
    xor r14, r14                   ; bytes received so far
.reg_read_loop:
    cmp r14, r13
    jge .reg_read_done
    cmp r14, EMOJI_RASTER_MAX
    jge .reg_read_done
    mov rax, SYS_READ
    mov edi, ebx
    lea rsi, [emoji_raster_buf + r14]
    mov rdx, r13
    sub rdx, r14
    syscall
    test rax, rax
    jle .reg_read_done
    add r14, rax
    jmp .reg_read_loop
.reg_read_done:
    mov rax, SYS_CLOSE
    mov edi, ebx
    syscall

    ; Wait for child to avoid zombies. r14 holds bytes received and
    ; must survive the syscall.
    push r14
    sub rsp, 8
    mov rax, SYS_WAIT4
    mov rdi, r15
    mov rsi, rsp
    xor edx, edx
    xor r10, r10
    syscall
    add rsp, 8
    pop r14

    ; If we got no data, bail (child failed)
    test r14, r14
    jz .reg_done

    ; Persist this glyph so the next glass session is instant.
    mov rdi, r14
    call emoji_save_cache

.reg_have_raster:
    ; Recompute pixmap dimensions (clobbered by reads above)
    movzx r13d, word [char_width]
    add r13d, r13d
    movzx r14d, word [char_height]

    ; CreatePixmap depth=32, w=r13, h=r14
    call alloc_xid
    mov [emoji_pixmaps + r12*4], eax
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CREATE_PIXMAP
    mov byte [rdi+1], 32        ; depth
    mov word [rdi+2], 4
    mov [rdi+4], eax            ; pid
    mov eax, [win_id]
    mov [rdi+8], eax            ; drawable (visual relationship)
    mov word [rdi+12], r13w     ; width
    mov word [rdi+14], r14w     ; height
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]

    ; Create render_temp_gc lazily on first emoji
    cmp byte [render_gc_ready], 1
    je .reg_gc_done
    call alloc_xid
    mov [render_temp_gc], eax
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CREATE_GC
    mov byte [rdi+1], 0
    mov word [rdi+2], 4
    mov eax, [render_temp_gc]
    mov [rdi+4], eax
    mov eax, [emoji_pixmaps + r12*4]
    mov [rdi+8], eax            ; depth-32 drawable
    mov dword [rdi+12], 0
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]
    mov byte [render_gc_ready], 1
.reg_gc_done:

    ; PutImage: opcode=72, format=ZPixmap=2, length=(24+data+3)/4,
    ; drawable, gc, w(2), h(2), dst-x(2), dst-y(2), left-pad, depth, pad(2)
    ; data follows.
    call x11_flush
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_PUT_IMAGE
    mov byte [rdi+1], 2          ; ZPixmap
    mov eax, r14d                ; bytes
    mov ecx, r13d
    imul ecx, eax
    shl ecx, 2                   ; w*h*4 bytes
    add ecx, 24 + 3
    shr ecx, 2
    mov word [rdi+2], cx
    mov eax, [emoji_pixmaps + r12*4]
    mov [rdi+4], eax
    mov eax, [render_temp_gc]
    mov [rdi+8], eax
    mov word [rdi+12], r13w
    mov word [rdi+14], r14w
    mov word [rdi+16], 0
    mov word [rdi+18], 0
    mov byte [rdi+20], 0
    mov byte [rdi+21], 32
    mov word [rdi+22], 0
    ; Send header directly, then RGBA body
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    lea rsi, [tmp_buf]
    mov rdx, 24
    syscall
    ; Send RGBA payload
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    lea rsi, [emoji_raster_buf]
    mov edx, r13d
    imul edx, r14d
    shl edx, 2
    syscall
    ; Pad to 4-byte boundary
    mov ecx, r13d
    imul ecx, r14d
    shl ecx, 2
    test ecx, 3
    jz .reg_no_pad
    mov edx, 4
    sub edx, ecx
    and edx, 3
    sub rsp, 8
    mov qword [rsp], 0
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    mov rsi, rsp
    syscall
    add rsp, 8
.reg_no_pad:
    inc dword [x11_seq]

    ; Create XRender Picture wrapping the pixmap
    call alloc_xid
    mov [emoji_pictures + r12*4], eax
    lea rdi, [tmp_buf]
    mov al, [render_major]
    mov [rdi], al
    mov byte [rdi+1], RENDER_CREATE_PICTURE
    mov word [rdi+2], 5
    mov eax, [emoji_pictures + r12*4]
    mov [rdi+4], eax
    mov eax, [emoji_pixmaps + r12*4]
    mov [rdi+8], eax
    mov eax, [render_format_argb32]
    mov [rdi+12], eax
    mov dword [rdi+16], 0
    lea rsi, [tmp_buf]
    mov rdx, 20
    call x11_buffer
    inc dword [x11_seq]
    call x11_flush

.reg_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.reg_pipe_fail:
    add rsp, 16
    jmp .reg_done
.reg_fork_fail:
    mov rax, SYS_CLOSE
    mov edi, ebx
    syscall
    mov rax, SYS_CLOSE
    mov edi, r15d
    syscall
    jmp .reg_done

.reg_pango_prefix: db "pango:<span font_family='Noto Color Emoji' size='", 0
.reg_pango_mid:    db "'>", 0
.reg_pango_suffix: db "</span>", 0

; rdi = dst, rsi = src (NUL-terminated). Copies bytes (not the NUL),
; returns with rdi pointing past the last copied byte.
.reg_strcpy_advance:
    push rax
.regs_loop:
    mov al, [rsi]
    test al, al
    jz .regs_done
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .regs_loop
.regs_done:
    pop rax
    ret

; Map window
x11_map_window:
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_MAP_WINDOW
    mov byte [rdi+1], 0
    mov word [rdi+2], 2
    mov eax, [win_id]
    mov [rdi+4], eax

    lea rsi, [tmp_buf]
    mov rdx, 8
    call x11_buffer
    inc dword [x11_seq]
    ret

; Query actual window geometry (size after WM may have resized/maximized)
; Updates win_width, win_height, grid_cols, grid_rows
x11_get_geometry:
    push rbx
    ; Build GetGeometry request: opcode=14, length=2, drawable
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_GET_GEOMETRY
    mov byte [rdi+1], 0
    mov word [rdi+2], 2
    mov eax, [win_id]
    mov [rdi+4], eax

    lea rsi, [tmp_buf]
    mov rdx, 8
    call x11_buffer
    inc dword [x11_seq]
    call x11_flush

    ; Read reply (32 bytes)
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 32
    syscall
    cmp rax, 32
    jl .xgg_done
    ; Verify it's a reply (byte 0 = 1)
    cmp byte [x11_buf], 1
    jne .xgg_done

    ; Reply: byte 8-11 = root, 12-13 = x, 14-15 = y,
    ;        16-17 = width, 18-19 = height, 20-21 = border, 22 = depth
    movzx eax, word [x11_buf + 16]
    test eax, eax
    jz .xgg_done
    mov [win_width], rax
    movzx eax, word [x11_buf + 18]
    test eax, eax
    jz .xgg_done
    mov [win_height], rax
    ; Compute grid_cols = win_width / char_width
    movzx ecx, word [char_width]
    test ecx, ecx
    jz .xgg_done
    mov rax, [win_width]
    xor edx, edx
    div rcx
    cmp rax, MAX_COLS
    jle .xgg_cols_ok
    mov rax, MAX_COLS
.xgg_cols_ok:
    test rax, rax
    jz .xgg_done
    mov [grid_cols], rax
    mov [prev_grid_cols], rax
    ; Compute grid_rows = win_height / char_height
    movzx ecx, word [char_height]
    test ecx, ecx
    jz .xgg_done
    mov rax, [win_height]
    xor edx, edx
    div rcx
    cmp rax, MAX_ROWS
    jle .xgg_rows_ok
    mov rax, MAX_ROWS
.xgg_rows_ok:
    test rax, rax
    jz .xgg_done
    mov [grid_rows], rax
    mov [prev_grid_rows], rax
.xgg_done:
    pop rbx
    ret

; Set WM hints (title, delete window protocol)
x11_set_wm_hints:
    push rbx
    push r12

    ; InternAtom WM_PROTOCOLS
    call x11_flush
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_INTERN_ATOM
    mov byte [rdi+1], 0      ; only-if-exists = false
    mov word [rdi+2], 2 + (wm_protocols_len + 3) / 4
    mov word [rdi+4], wm_protocols_len
    mov word [rdi+6], 0
    lea rsi, [wm_protocols_str]
    lea rbx, [tmp_buf + 8]
    xor ecx, ecx
.xwm_cp1:
    cmp ecx, wm_protocols_len
    jge .xwm_pad1
    movzx eax, byte [rsi + rcx]
    mov [rbx + rcx], al
    inc ecx
    jmp .xwm_cp1
.xwm_pad1:
    ; Pad
    mov eax, wm_protocols_len
    add eax, 3
    and eax, ~3
    add eax, 8
    mov rdx, rax
    lea rsi, [tmp_buf]
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    inc dword [x11_seq]
    ; Read reply
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 32
    syscall
    mov eax, [x11_buf + 8]   ; atom at offset 8
    mov [wm_protocols_atom], eax

    ; InternAtom WM_DELETE_WINDOW
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_INTERN_ATOM
    mov byte [rdi+1], 0
    mov word [rdi+2], 2 + (wm_delete_len + 3) / 4
    mov word [rdi+4], wm_delete_len
    mov word [rdi+6], 0
    lea rsi, [wm_delete_str]
    lea rbx, [tmp_buf + 8]
    xor ecx, ecx
.xwm_cp2:
    cmp ecx, wm_delete_len
    jge .xwm_pad2
    movzx eax, byte [rsi + rcx]
    mov [rbx + rcx], al
    inc ecx
    jmp .xwm_cp2
.xwm_pad2:
    mov eax, wm_delete_len
    add eax, 3
    and eax, ~3
    add eax, 8
    mov rdx, rax
    lea rsi, [tmp_buf]
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    inc dword [x11_seq]
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 32
    syscall
    mov eax, [x11_buf + 8]
    mov [wm_delete_atom], eax

    ; InternAtom _TILE_SHELL_PID — used by tile to learn each glass's
    ; bare child PID for "spawn-here" (cwd-of-focused) workflows.
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_INTERN_ATOM
    mov byte [rdi+1], 0
    mov word [rdi+2], 2 + (tile_shell_pid_len + 3) / 4
    mov word [rdi+4], tile_shell_pid_len
    mov word [rdi+6], 0
    lea rsi, [tile_shell_pid_str]
    lea rbx, [tmp_buf + 8]
    xor ecx, ecx
.xwm_cp_tsp:
    cmp ecx, tile_shell_pid_len
    jge .xwm_pad_tsp
    movzx eax, byte [rsi + rcx]
    mov [rbx + rcx], al
    inc ecx
    jmp .xwm_cp_tsp
.xwm_pad_tsp:
    mov eax, tile_shell_pid_len
    add eax, 3
    and eax, ~3
    add eax, 8
    mov rdx, rax
    lea rsi, [tmp_buf]
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    inc dword [x11_seq]
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 32
    syscall
    mov eax, [x11_buf + 8]
    mov [tile_shell_pid_atom], eax

    ; ChangeProperty: WM_PROTOCOLS = [WM_DELETE_WINDOW]
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_PROPERTY
    mov byte [rdi+1], 0      ; mode = Replace
    mov word [rdi+2], 7      ; length
    mov eax, [win_id]
    mov [rdi+4], eax         ; window
    mov eax, [wm_protocols_atom]
    mov [rdi+8], eax         ; property
    mov dword [rdi+12], 4    ; type = ATOM
    mov byte [rdi+16], 32    ; format
    mov byte [rdi+17], 0
    mov word [rdi+18], 0
    mov dword [rdi+20], 1    ; data length (1 atom)
    mov eax, [wm_delete_atom]
    mov [rdi+24], eax

    lea rsi, [tmp_buf]
    mov rdx, 28
    call x11_buffer
    inc dword [x11_seq]

    ; ChangeProperty: WM_NAME = "glass"
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_PROPERTY
    mov byte [rdi+1], 0
    mov word [rdi+2], 6 + (win_title_len + 3) / 4
    mov eax, [win_id]
    mov [rdi+4], eax
    mov dword [rdi+8], 39    ; WM_NAME atom
    mov dword [rdi+12], 31   ; STRING type
    mov byte [rdi+16], 8     ; format
    mov byte [rdi+17], 0
    mov word [rdi+18], 0
    mov dword [rdi+20], win_title_len
    lea rsi, [win_title]
    lea rbx, [tmp_buf + 24]
    xor ecx, ecx
.xwm_cp_title:
    cmp ecx, win_title_len
    jge .xwm_send_title
    movzx eax, byte [rsi + rcx]
    mov [rbx + rcx], al
    inc ecx
    jmp .xwm_cp_title
.xwm_send_title:
    mov eax, win_title_len
    add eax, 3
    and eax, ~3
    add eax, 24
    mov rdx, rax
    lea rsi, [tmp_buf]
    call x11_buffer
    inc dword [x11_seq]

    pop r12
    pop rbx
    ret

; Intern selection atoms (CLIPBOARD, UTF8_STRING, TARGETS, GLASS_SEL)
x11_intern_sel_atoms:
    push rbx
    push r12

    ; Set PRIMARY atom (built-in, always 1)
    mov dword [primary_atom], 1

    ; Intern CLIPBOARD
    call x11_flush
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_INTERN_ATOM
    mov byte [rdi+1], 0
    mov word [rdi+2], 2 + (clipboard_len + 3) / 4
    mov word [rdi+4], clipboard_len
    mov word [rdi+6], 0
    lea rsi, [clipboard_str]
    lea rbx, [tmp_buf + 8]
    xor ecx, ecx
.xia_cp1:
    cmp ecx, clipboard_len
    jge .xia_send1
    movzx eax, byte [rsi + rcx]
    mov [rbx + rcx], al
    inc ecx
    jmp .xia_cp1
.xia_send1:
    mov eax, clipboard_len
    add eax, 3
    and eax, ~3
    add eax, 8
    mov rdx, rax
    lea rsi, [tmp_buf]
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    inc dword [x11_seq]
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 32
    syscall
    mov eax, [x11_buf + 8]
    mov [clipboard_atom], eax

    ; Intern UTF8_STRING
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_INTERN_ATOM
    mov byte [rdi+1], 0
    mov word [rdi+2], 2 + (utf8_string_len + 3) / 4
    mov word [rdi+4], utf8_string_len
    mov word [rdi+6], 0
    lea rsi, [utf8_string_str]
    lea rbx, [tmp_buf + 8]
    xor ecx, ecx
.xia_cp2:
    cmp ecx, utf8_string_len
    jge .xia_send2
    movzx eax, byte [rsi + rcx]
    mov [rbx + rcx], al
    inc ecx
    jmp .xia_cp2
.xia_send2:
    mov eax, utf8_string_len
    add eax, 3
    and eax, ~3
    add eax, 8
    mov rdx, rax
    lea rsi, [tmp_buf]
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    inc dword [x11_seq]
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 32
    syscall
    mov eax, [x11_buf + 8]
    mov [utf8_string_atom], eax

    ; Intern TARGETS
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_INTERN_ATOM
    mov byte [rdi+1], 0
    mov word [rdi+2], 2 + (targets_len + 3) / 4
    mov word [rdi+4], targets_len
    mov word [rdi+6], 0
    lea rsi, [targets_str]
    lea rbx, [tmp_buf + 8]
    xor ecx, ecx
.xia_cp3:
    cmp ecx, targets_len
    jge .xia_send3
    movzx eax, byte [rsi + rcx]
    mov [rbx + rcx], al
    inc ecx
    jmp .xia_cp3
.xia_send3:
    mov eax, targets_len
    add eax, 3
    and eax, ~3
    add eax, 8
    mov rdx, rax
    lea rsi, [tmp_buf]
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    inc dword [x11_seq]
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 32
    syscall
    mov eax, [x11_buf + 8]
    mov [targets_atom], eax

    ; Intern GLASS_SEL
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_INTERN_ATOM
    mov byte [rdi+1], 0
    mov word [rdi+2], 2 + (glass_sel_len + 3) / 4
    mov word [rdi+4], glass_sel_len
    mov word [rdi+6], 0
    lea rsi, [glass_sel_str]
    lea rbx, [tmp_buf + 8]
    xor ecx, ecx
.xia_cp4:
    cmp ecx, glass_sel_len
    jge .xia_send4
    movzx eax, byte [rsi + rcx]
    mov [rbx + rcx], al
    inc ecx
    jmp .xia_cp4
.xia_send4:
    mov eax, glass_sel_len
    add eax, 3
    and eax, ~3
    add eax, 8
    mov rdx, rax
    lea rsi, [tmp_buf]
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    inc dword [x11_seq]
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 32
    syscall
    mov eax, [x11_buf + 8]
    mov [glass_sel_atom], eax

    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; PTY management
; ══════════════════════════════════════════════════════════════════════

pty_open:
    push rbx

    ; Open /dev/ptmx
    mov rax, SYS_OPEN
    lea rdi, [ptmx_path]
    mov rsi, O_RDWR
    xor edx, edx
    syscall
    test rax, rax
    js .pto_fail
    mov [pty_master], rax
    mov rbx, rax

    ; Unlock slave
    sub rsp, 8
    mov qword [rsp], 0
    mov rax, SYS_IOCTL
    mov rdi, rbx
    mov rsi, TIOCSPTLCK
    mov rdx, rsp
    syscall
    add rsp, 8

    ; Get slave number
    sub rsp, 8
    mov rax, SYS_IOCTL
    mov rdi, rbx
    mov rsi, TIOCGPTN
    mov rdx, rsp
    syscall
    mov rax, [rsp]
    add rsp, 8

    ; Build "/dev/pts/N"
    lea rdi, [pty_slave_path]
    lea rsi, [pts_prefix]
.pto_cp:
    mov cl, [rsi]
    mov [rdi], cl
    test cl, cl
    jz .pto_num
    inc rsi
    inc rdi
    jmp .pto_cp
.pto_num:
    push rdi
    call itoa
    pop rdi

    xor eax, eax
    pop rbx
    ret
.pto_fail:
    mov rax, -1
    pop rbx
    ret

; Publish the bare child's PID on win_id as the _TILE_SHELL_PID
; CARDINAL property. tile reads this on Mod4+Shift+Return so it can
; resolve /proc/PID/cwd and spawn a sibling glass starting in the same
; directory. No-op (writes garbage) is harmless if tile isn't running;
; the property just sits on the window.
publish_shell_pid:
    cmp dword [tile_shell_pid_atom], 0
    je .psp_done
    cmp dword [win_id], 0
    je .psp_done
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_PROPERTY
    mov byte [rdi+1], 0                ; mode = Replace
    mov word [rdi+2], 7                ; length in 4-byte words
    mov eax, [win_id]
    mov [rdi+4], eax                   ; window
    mov eax, [tile_shell_pid_atom]
    mov [rdi+8], eax                   ; property
    mov dword [rdi+12], 6              ; type = CARDINAL
    mov byte [rdi+16], 32              ; format
    mov byte [rdi+17], 0
    mov word [rdi+18], 0
    mov dword [rdi+20], 1              ; data length (1 CARD32)
    mov rax, [child_pid]
    mov [rdi+24], eax                  ; PID (low 32 bits is plenty for Linux)
    lea rsi, [tmp_buf]
    mov rdx, 28
    call x11_buffer
    inc dword [x11_seq]
    call x11_flush
.psp_done:
    ret

pty_fork:
    push rbx
    push r12

    mov rax, SYS_FORK
    syscall
    test rax, rax
    jz .ptf_child
    js .ptf_fail

    ; Parent
    mov [child_pid], rax
    call publish_shell_pid
    xor eax, eax
    pop r12
    pop rbx
    ret

.ptf_child:
    ; Close master
    mov rax, SYS_CLOSE
    mov rdi, [pty_master]
    syscall

    ; New session
    mov rax, SYS_SETSID
    syscall

    ; Open slave
    mov rax, SYS_OPEN
    lea rdi, [pty_slave_path]
    mov rsi, O_RDWR
    xor edx, edx
    syscall
    test rax, rax
    js .ptf_child_exit
    mov rbx, rax

    ; Set controlling terminal
    mov rax, SYS_IOCTL
    mov rdi, rbx
    mov rsi, TIOCSCTTY
    xor edx, edx
    syscall

    ; Set window size from current grid dimensions (set by x11_get_geometry).
    ; Fill ws_xpixel/ws_ypixel so kitty-graphics clients (pointer, etc.)
    ; can size images to the actual pane in pixels.
    sub rsp, 8
    movzx eax, word [grid_rows]
    mov word [rsp], ax
    movzx eax, word [grid_cols]
    mov word [rsp+2], ax
    movzx eax, word [grid_cols]
    movzx ecx, word [char_width]
    imul eax, ecx
    mov word [rsp+4], ax
    movzx eax, word [grid_rows]
    movzx ecx, word [char_height]
    imul eax, ecx
    mov word [rsp+6], ax
    mov rax, SYS_IOCTL
    mov rdi, rbx
    mov rsi, TIOCSWINSZ
    mov rdx, rsp
    syscall
    add rsp, 8

    ; Dup slave to stdin/stdout/stderr
    mov rax, SYS_DUP2
    mov rdi, rbx
    xor esi, esi
    syscall
    mov rax, SYS_DUP2
    mov rdi, rbx
    mov esi, 1
    syscall
    mov rax, SYS_DUP2
    mov rdi, rbx
    mov esi, 2
    syscall

    ; Close original slave fd
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall

    ; Close X11 fd
    mov rax, SYS_CLOSE
    mov rdi, [x11_fd]
    syscall

    ; Build child env: copy parent envp into child_envp, replacing
    ; TERM with our own value and dropping any inherited variables
    ; that identify a different terminal emulator. If glass was launched
    ; from kitty, KITTY_WINDOW_ID etc. would otherwise pass through and
    ; mislead detect-protocol code (e.g. glow) into sending kitty
    ; graphics commands to glass that we can't handle yet.
    mov rsi, [envp]
    lea rdi, [child_envp]
    xor ecx, ecx                     ; dest index
    xor r8d, r8d                     ; found TERM flag
.ptf_env_copy:
    mov rax, [rsi]
    test rax, rax
    jz .ptf_env_add_term
    ; Drop KITTY_*  (KITTY_WINDOW_ID, KITTY_PID, KITTY_LISTEN_ON, ...)
    cmp dword [rax], 'KITT'
    jne .ptf_chk_terminfo
    cmp byte [rax+4], 'Y'
    jne .ptf_chk_terminfo
    cmp byte [rax+5], '_'
    je .ptf_env_skip
.ptf_chk_terminfo:
    ; Drop TERMINFO (parent's terminfo dir is kitty's; child should
    ; fall back to system terminfo for the TERM we advertise).
    cmp dword [rax], 'TERM'
    jne .ptf_chk_colorterm
    cmp dword [rax+4], 'INFO'
    jne .ptf_chk_term
    cmp byte [rax+8], '='
    je .ptf_env_skip
.ptf_chk_term:
    ; Replace TERM= with our own value.
    cmp byte [rax+4], '='
    jne .ptf_env_keep
    lea rax, [term_env]
    mov r8d, 1
    jmp .ptf_env_keep
.ptf_chk_colorterm:
    ; Drop any inherited COLORTERM= — we set our own (truecolor) below
    ; so apps like claude-code emit 24-bit RGB instead of falling back
    ; to 256-color cube approximations that read brighter/harsher than
    ; the kitty-default look. NASM word literal 'M=' = 0x3D4D, which
    ; matches the LE byte order of "M=" in memory at offsets 8..9.
    cmp dword [rax], 'COLO'
    jne .ptf_env_keep
    cmp dword [rax+4], 'RTER'
    jne .ptf_env_keep
    cmp word [rax+8], 'M='
    je .ptf_env_skip
.ptf_env_keep:
    mov [rdi + rcx*8], rax
    inc ecx
.ptf_env_skip:
    add rsi, 8
    jmp .ptf_env_copy
.ptf_env_add_term:
    test r8d, r8d
    jnz .ptf_env_after_term
    ; TERM wasn't in env, add it
    lea rax, [term_env]
    mov [rdi + rcx*8], rax
    inc ecx
.ptf_env_after_term:
    ; Always inject our COLORTERM=truecolor (we dropped any inherited
    ; value above, so we can append unconditionally).
    lea rax, [colorterm_env]
    mov [rdi + rcx*8], rax
    inc ecx
.ptf_env_done:
    mov qword [rdi + rcx*8], 0  ; null terminate

    ; If -e CMD ARGS… was passed on the command line, exec that
    ; instead of the default shell. Useful for `glass -e mutt`,
    ; `glass -- ssh user@host …`, etc. Falls through to the bare/sh
    ; chain on exec failure (PATH miss, etc.) so the user still gets
    ; a usable shell rather than a vanished window.
    mov rax, [exec_argv]
    test rax, rax
    jz .ptf_default_shell
    mov rdi, rax
    lea rsi, [exec_argv]
    lea rdx, [child_envp]
    mov rax, SYS_EXECVE
    syscall

.ptf_default_shell:
    ; Find shell in PATH
    sub rsp, 32
    lea rax, [.ptf_shell1]
    mov [rsp], rax
    lea rax, [shell_flag]
    mov [rsp+8], rax
    mov qword [rsp+16], 0
    mov rdi, [rsp]
    mov rsi, rsp
    lea rdx, [child_envp]
    mov rax, SYS_EXECVE
    syscall
    ; Try fallback
    lea rax, [.ptf_shell2]
    mov [rsp], rax
    mov rdi, [rsp]
    mov rsi, rsp
    lea rdx, [child_envp]
    mov rax, SYS_EXECVE
    syscall
    ; Last resort: /bin/sh
    lea rax, [.ptf_shell3]
    mov [rsp], rax
    mov qword [rsp+8], 0
    mov rdi, [rsp]
    mov rsi, rsp
    lea rdx, [child_envp]
    mov rax, SYS_EXECVE
    syscall

.ptf_child_exit:
    mov rdi, 1
    mov rax, SYS_EXIT
    syscall

.ptf_shell1: db "/home/geir/bin/bare", 0
.ptf_shell2: db "/usr/local/bin/bare", 0
.ptf_shell3: db "/bin/sh", 0

.ptf_fail:
    mov rax, -1
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Event loop
; ══════════════════════════════════════════════════════════════════════

event_loop:
    ; Set up poll fds
    ; struct pollfd { int fd; short events; short revents; }
    mov eax, [x11_fd]
    mov [poll_fds], eax           ; fd
    mov word [poll_fds + 4], POLLIN ; events
    mov word [poll_fds + 6], 0    ; revents

    mov rax, [pty_master]
    mov [poll_fds + 8], eax       ; fd
    mov word [poll_fds + 12], POLLIN
    mov word [poll_fds + 14], 0

.ev_loop:
    ; Poll: short timeout if child not yet forked (fallback), else use the
    ; cursor-blink interval if set, else infinite.
    cmp qword [child_forked], 0
    jne .ev_poll_normal
    mov edx, 200              ; 200ms timeout to fork fallback
    jmp .ev_do_poll
.ev_poll_normal:
    cmp qword [cfg_blink_ms], 0
    je .ev_poll_infinite
    cmp qword [cursor_visible], 0
    je .ev_poll_infinite
    ; Compute remaining ms until next blink toggle
    call click_now_ms
    mov rcx, [cursor_blink_until]
    sub rcx, rax
    test rcx, rcx
    jg .ev_blink_timeout_ok
    mov rcx, 1                ; due now-ish, fire next iteration
.ev_blink_timeout_ok:
    cmp rcx, [cfg_blink_ms]
    jle .ev_blink_timeout_set
    mov rcx, [cfg_blink_ms]
.ev_blink_timeout_set:
    mov rdx, rcx
    jmp .ev_do_poll
.ev_poll_infinite:
    mov rdx, -1
.ev_do_poll:
    mov rax, SYS_POLL
    lea rdi, [poll_fds]
    mov rsi, 2                ; nfds
    syscall
    test rax, rax
    jg .ev_check_blink
    ; Timeout or error
    cmp qword [child_forked], 0
    jne .ev_check_blink
    ; Fork now with current dimensions
    mov qword [child_forked], 1
    push rbx
    call pty_fork
    pop rbx
    jmp .ev_loop
.ev_check_blink:
    ; Even if a real fd event woke us, see if the blink timer expired so
    ; the cursor doesn't drift visually.
    cmp qword [cfg_blink_ms], 0
    je .ev_check_x11
    cmp qword [cursor_visible], 0
    je .ev_check_x11
    push rax
    call click_now_ms
    mov rcx, rax
    pop rax
    cmp rcx, [cursor_blink_until]
    jl .ev_check_x11
    ; Toggle state and rearm
    xor qword [cursor_blink_state], 1
    add rcx, [cfg_blink_ms]
    mov [cursor_blink_until], rcx
    push rax
    call render_screen
    call x11_flush
    pop rax
.ev_check_x11:

    ; Check X11 events. POLLHUP/POLLERR on the X11 socket means the
    ; X server has gone away; without the explicit exit below, poll
    ; would keep returning immediately with those bits set and we'd
    ; spin at 100% CPU forever (this happened repeatedly when xephyr
    ; was killed during tile/glass development — and at 8 stale glass
    ; instances the laptop's battery drained noticeably faster).
    movzx eax, word [poll_fds + 6]
    test eax, 0x18                ; POLLERR(8) | POLLHUP(16)
    jnz .ev_x11_dead
    test eax, POLLIN
    jz .ev_check_pty
    call handle_x11_events
    mov word [poll_fds + 6], 0

.ev_check_pty:
    ; Check PTY output (POLLIN | POLLHUP | POLLERR)
    movzx eax, word [poll_fds + 14]
    test eax, 0x19           ; POLLIN(1) | POLLERR(8) | POLLHUP(16)
    jz .ev_loop
    ; If POLLHUP/POLLERR without POLLIN, child died
    test eax, POLLIN
    jz .ev_child_died
    mov word [poll_fds + 14], 0

    ; Read PTY output
    mov rax, SYS_READ
    mov rdi, [pty_master]
    lea rsi, [pty_read_buf]
    mov rdx, 4096
    syscall
    test rax, rax
    jle .ev_child_died

    ; Snap to live view on new PTY output
    mov qword [scroll_offset], 0

    ; Process VT sequences
    mov rcx, rax
    lea rsi, [pty_read_buf]
    call vt_process

    ; Render screen
    call render_screen
    call scan_urls
    call x11_flush

    jmp .ev_loop

.ev_child_died:
    ; Child process exited
    mov rdi, 0
    mov rax, SYS_EXIT
    syscall

.ev_x11_dead:
    ; X server connection lost (e.g. tile/Xephyr was killed under us).
    ; Exit cleanly rather than spin on a dead socket.
    mov rdi, 0
    mov rax, SYS_EXIT
    syscall

; Handle X11 events
handle_x11_events:
    push rbx
    push r12

    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 8192
    syscall
    test rax, rax
    jle .hxe_done
    mov r12, rax             ; bytes read

    xor rbx, rbx             ; offset
.hxe_loop:
    cmp rbx, r12
    jge .hxe_done

    ; Event type (first byte, strip send_event flag)
    movzx eax, byte [x11_buf + rbx]
    and eax, 0x7F

    cmp al, 0                ; error
    je .hxe_x11_error

    cmp al, EV_KEY_PRESS
    je .hxe_key_press
    cmp al, EV_BUTTON_PRESS
    je .hxe_button_press
    cmp al, EV_BUTTON_RELEASE
    je .hxe_button_release
    cmp al, EV_MOTION_NOTIFY
    je .hxe_motion
    cmp al, EV_EXPOSE
    je .hxe_expose
    cmp al, EV_CONFIGURE_NOTIFY
    je .hxe_configure
    cmp al, EV_CLIENT_MESSAGE
    je .hxe_client_msg
    cmp al, EV_SELECTION_REQUEST
    je .hxe_sel_request
    cmp al, EV_SELECTION_NOTIFY
    je .hxe_sel_notify

.hxe_x11_error:
    ; X11 error event (32 bytes):
    ;   1: code, 2..3: seq, 4..7: bad rid, 8..9: minor, 10: major
    ; Dump to stderr so silent server-side rejection of TTF / XRender
    ; requests is at least visible. Keep one line; format:
    ;   "glass: x11 err code=N seq=N major=N minor=N rid=0xN\n"
    push rbx
    push r12
    movzx r12d, byte [x11_buf + rbx + 1]            ; code
    push r12
    movzx r12d, word [x11_buf + rbx + 2]            ; seq
    push r12
    movzx r12d, byte [x11_buf + rbx + 10]           ; major
    push r12
    movzx r12d, word [x11_buf + rbx + 8]            ; minor
    push r12
    mov   r12d, [x11_buf + rbx + 4]                 ; rid
    push r12
    lea rdi, [tmp_buf]
    lea rsi, [.hxe_err_pre]
    mov ecx, .hxe_err_pre_len
    call .hxe_err_copy
    pop rax                                          ; rid (last pushed)
    call .hxe_err_hex32
    mov byte [rdi], ' '
    inc rdi
    lea rsi, [.hxe_err_minor]
    mov ecx, .hxe_err_minor_len
    call .hxe_err_copy
    pop rax                                          ; minor
    call .hxe_err_dec
    mov byte [rdi], ' '
    inc rdi
    lea rsi, [.hxe_err_major]
    mov ecx, .hxe_err_major_len
    call .hxe_err_copy
    pop rax                                          ; major
    call .hxe_err_dec
    mov byte [rdi], ' '
    inc rdi
    lea rsi, [.hxe_err_seq]
    mov ecx, .hxe_err_seq_len
    call .hxe_err_copy
    pop rax                                          ; seq
    call .hxe_err_dec
    mov byte [rdi], ' '
    inc rdi
    lea rsi, [.hxe_err_code]
    mov ecx, .hxe_err_code_len
    call .hxe_err_copy
    pop rax                                          ; code
    call .hxe_err_dec
    mov byte [rdi], 10
    inc rdi
    lea rsi, [tmp_buf]
    mov rdx, rdi
    sub rdx, rsi
    mov rax, SYS_WRITE
    mov rdi, 2
    syscall
    pop r12
    pop rbx
    add rbx, 32
    jmp .hxe_loop

; Helpers used only by .hxe_x11_error. rdi = dst (advanced),
; .hxe_err_copy: rsi=src ecx=len  → copy and advance rdi.
; .hxe_err_dec : rax=value (u32) → write decimal, advance rdi.
; .hxe_err_hex32: rax=value (u32) → write "0xHHHHHHHH", advance rdi.
.hxe_err_copy:
    test ecx, ecx
    jz .hxe_err_copy_done
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec ecx
    jmp .hxe_err_copy
.hxe_err_copy_done:
    ret
.hxe_err_dec:
    push rbx
    push rcx
    push rdx
    mov ecx, 0                                       ; digit count
    test eax, eax
    jnz .hxe_err_dec_loop
    mov byte [rdi], '0'
    inc rdi
    jmp .hxe_err_dec_done
.hxe_err_dec_loop:
    test eax, eax
    jz .hxe_err_dec_emit
    xor edx, edx
    mov ebx, 10
    div ebx
    add dl, '0'
    push rdx
    inc ecx
    jmp .hxe_err_dec_loop
.hxe_err_dec_emit:
    test ecx, ecx
    jz .hxe_err_dec_done
    pop rdx
    mov [rdi], dl
    inc rdi
    dec ecx
    jmp .hxe_err_dec_emit
.hxe_err_dec_done:
    pop rdx
    pop rcx
    pop rbx
    ret
.hxe_err_hex32:
    mov byte [rdi], '0'
    mov byte [rdi+1], 'x'
    add rdi, 2
    mov ecx, 8
.hxe_err_hex_loop:
    test ecx, ecx
    jz .hxe_err_hex_done
    rol eax, 4
    mov edx, eax
    and edx, 0xF
    cmp dl, 10
    jl .hxe_err_hex_dig
    add dl, 'a' - 10 - '0'
.hxe_err_hex_dig:
    add dl, '0'
    mov [rdi], dl
    inc rdi
    dec ecx
    jmp .hxe_err_hex_loop
.hxe_err_hex_done:
    ret
.hxe_err_pre:    db "glass: x11 err rid="
.hxe_err_pre_len equ $ - .hxe_err_pre
.hxe_err_minor:  db "minor="
.hxe_err_minor_len equ $ - .hxe_err_minor
.hxe_err_major:  db "major="
.hxe_err_major_len equ $ - .hxe_err_major
.hxe_err_seq:    db "seq="
.hxe_err_seq_len equ $ - .hxe_err_seq
.hxe_err_code:   db "code="
.hxe_err_code_len equ $ - .hxe_err_code

.hxe_skip:
    ; If type is 1 (Reply), advance by 32 + reply_length*4 bytes
    cmp al, 1
    jne .hxe_skip_event
    ; Reply: bytes 4-7 = additional length in 4-byte units
    mov eax, [x11_buf + rbx + 4]
    shl eax, 2
    add eax, 32
    add rbx, rax
    jmp .hxe_loop
.hxe_skip_event:
    add rbx, 32              ; each event is 32 bytes
    jmp .hxe_loop

.hxe_key_press:
    ; keycode at offset 1, state at offset 28
    movzx eax, byte [x11_buf + rbx + 1]
    movzx ecx, word [x11_buf + rbx + 28]
    push rbx
    push r12
    call handle_keypress
    pop r12
    pop rbx
    add rbx, 32
    jmp .hxe_loop

.hxe_expose:
    push rbx
    push r12
    call render_screen
    call x11_flush
    pop r12
    pop rbx
    add rbx, 32
    jmp .hxe_loop

.hxe_configure:
    ; width at offset 20, height at offset 22
    push rbx
    push r12
    movzx eax, word [x11_buf + rbx + 20]
    mov [win_width], rax
    movzx eax, word [x11_buf + rbx + 22]
    mov [win_height], rax
    ; Recalculate grid size
    mov rax, [win_width]
    movzx ecx, word [char_width]
    test ecx, ecx
    jz .hxe_cfg_done
    xor edx, edx
    div rcx
    cmp rax, MAX_COLS
    jle .hxe_cfg_cols_ok
    mov rax, MAX_COLS
.hxe_cfg_cols_ok:
    mov [grid_cols], rax
    mov rax, [win_height]
    movzx ecx, word [char_height]
    test ecx, ecx
    jz .hxe_cfg_done
    xor edx, edx
    div rcx
    cmp rax, MAX_ROWS
    jle .hxe_cfg_rows_ok
    mov rax, MAX_ROWS
.hxe_cfg_rows_ok:
    mov [grid_rows], rax
    ; Only resize PTY if dimensions actually changed
    mov rax, [grid_cols]
    cmp rax, [prev_grid_cols]
    jne .hxe_cfg_resize
    mov rax, [grid_rows]
    cmp rax, [prev_grid_rows]
    je .hxe_cfg_done
.hxe_cfg_resize:
    mov rax, [grid_cols]
    mov [prev_grid_cols], rax
    mov rax, [grid_rows]
    mov [prev_grid_rows], rax
    ; Resize PTY. Fill ws_xpixel/ws_ypixel so kitty-graphics clients
    ; (pointer, etc.) can size images to the actual pane in pixels.
    sub rsp, 8
    movzx eax, word [grid_rows]
    mov word [rsp], ax        ; ws_row
    movzx eax, word [grid_cols]
    mov word [rsp+2], ax      ; ws_col
    movzx eax, word [grid_cols]
    movzx ecx, word [char_width]
    imul eax, ecx
    mov word [rsp+4], ax      ; ws_xpixel
    movzx eax, word [grid_rows]
    movzx ecx, word [char_height]
    imul eax, ecx
    mov word [rsp+6], ax      ; ws_ypixel
    mov rax, SYS_IOCTL
    mov rdi, [pty_master]
    mov rsi, TIOCSWINSZ
    mov rdx, rsp
    syscall
    add rsp, 8
    ; If child not yet forked, fork it now (with correct dimensions)
    cmp qword [child_forked], 0
    jne .hxe_cfg_send_winch
    mov qword [child_forked], 1
    push rbx
    push r12
    call pty_fork
    pop r12
    pop rbx
    jmp .hxe_cfg_done
.hxe_cfg_send_winch:
    ; Send SIGWINCH to child process group
    mov rax, SYS_KILL
    mov rdi, [child_pid]
    neg rdi                   ; negative pid = process group
    mov rsi, SIGWINCH
    syscall
.hxe_cfg_done:
    ; ConfigureNotify: (re)sample the wallpaper for pseudo-transparency.
    ; Tile may MOVE us when cycling layouts (without changing our size),
    ; so resampling on every CN is required — otherwise the bg pixmap
    ; still holds the slice from the previous root position and the
    ; transparency looks broken until the user toggles opacity.
    cmp byte [cfg_opacity_set], 1
    jne .hxe_cfg_no_pseudo
    cmp byte [compositor_active], 1
    je .hxe_cfg_no_pseudo
    ; First time only: mark setup done so the rest of the codebase
    ; (palette tinting, etc.) knows the pseudo path is in play. After
    ; that, every CN unconditionally re-samples.
    cmp byte [pseudo_setup_done], 0
    jne .hxe_cfg_resample
    mov byte [pseudo_setup_done], 1
.hxe_cfg_resample:
    call setup_pseudo_transparency
    call render_screen
    call x11_flush
.hxe_cfg_no_pseudo:
    pop r12
    pop rbx
    add rbx, 32
    jmp .hxe_loop

.hxe_button_press:
    ; ButtonPress event: mouse reporting, selection, scroll, or Ctrl+click URL
    ; event detail (button number) at offset 1
    movzx eax, byte [x11_buf + rbx + 1]
    push rbx
    push r12
    push r13
    mov r13d, eax            ; button number

    ; Handle scroll wheel (buttons 4/5) first
    cmp r13d, 4
    je .hxe_bp_scroll_up
    cmp r13d, 5
    je .hxe_bp_scroll_down

    ; Only handle buttons 1-3 for click/selection
    cmp r13d, 1
    jb .hxe_bp_done2
    cmp r13d, 3
    ja .hxe_bp_done2

    ; Calculate row/col from pixel coordinates
    movzx eax, word [x11_buf + rbx + 24]
    movzx ecx, word [char_width]
    test ecx, ecx
    jz .hxe_bp_done2
    xor edx, edx
    div ecx
    mov r12, rax             ; col
    movzx eax, word [x11_buf + rbx + 26]
    movzx ecx, word [char_height]
    test ecx, ecx
    jz .hxe_bp_done2
    xor edx, edx
    div ecx
    ; rax = row, r12 = col

    ; Check for Ctrl held (state bit 2) - Ctrl always overrides mouse reporting
    movzx ecx, word [x11_buf + rbx + 28]
    test ecx, 4
    jnz .hxe_bp_ctrl

    ; Check if mouse tracking is active
    cmp qword [mouse_tracking], 0
    jne .hxe_bp_mouse_report

    ; Normal click: start selection (button 1 only)
    cmp r13d, 1
    jne .hxe_bp_done2
.hxe_bp_selection:
    ; Save row/col across click_now_ms call (uses syscall)
    push rax
    push r12
    call click_now_ms        ; rax = ms (monotonic)
    mov rcx, rax             ; rcx = now
    pop r12
    pop rax
    ; Compare with last click: same row+col and within 400ms?
    mov rdx, rcx
    sub rdx, [last_click_time]
    cmp rdx, 400
    ja .hxe_bp_sel_single
    cmp rax, [last_click_row]
    jne .hxe_bp_sel_single
    cmp r12, [last_click_col]
    jne .hxe_bp_sel_single
    ; Multi-click: bump count (cap at 3)
    mov rdx, [click_count]
    inc rdx
    cmp rdx, 3
    jbe .hxe_bp_sel_count_ok
    mov rdx, 1
.hxe_bp_sel_count_ok:
    mov [click_count], rdx
    jmp .hxe_bp_sel_apply
.hxe_bp_sel_single:
    mov qword [click_count], 1
.hxe_bp_sel_apply:
    mov [last_click_time], rcx
    mov [last_click_row], rax
    mov [last_click_col], r12
    ; Common defaults: anchor at click, no active selection until drag
    mov [sel_start_row], rax
    mov [sel_end_row], rax
    mov [sel_start_col], r12
    mov [sel_end_col], r12
    mov qword [sel_button_held], 1
    mov qword [sel_mode], 0
    ; Branch on click count
    mov rdx, [click_count]
    cmp rdx, 2
    je .hxe_bp_sel_word
    cmp rdx, 3
    je .hxe_bp_sel_line
    ; Single click: clear any prior selection and redraw
    cmp qword [sel_active], 0
    je .hxe_bp_done2
    mov qword [sel_active], 0
    call render_screen
    call x11_flush
    jmp .hxe_bp_done2
.hxe_bp_sel_word:
    mov qword [sel_mode], 1
    mov qword [sel_button_held], 0
    mov qword [sel_active], 1
    mov rdi, rax             ; row
    mov rsi, r12             ; col
    call find_word_at
    call selection_extract
    call selection_claim_primary
    call render_screen
    call x11_flush
    jmp .hxe_bp_done2
.hxe_bp_sel_line:
    mov qword [sel_mode], 2
    mov qword [sel_button_held], 0
    mov qword [sel_active], 1
    mov rdi, rax             ; row
    call select_line_at
    call selection_extract
    call selection_claim_primary
    call render_screen
    call x11_flush
    jmp .hxe_bp_done2

.hxe_bp_ctrl:
    ; Ctrl+click: try to open URL (button 1 only)
    cmp r13d, 1
    jne .hxe_bp_done2
    mov rdi, rax             ; row
    mov rsi, r12             ; col
    call url_open_at
    jmp .hxe_bp_done2

.hxe_bp_mouse_report:
    ; Send mouse press event to PTY
    ; SGR format: ESC[<button;col;row M
    ; button: 0=left, 1=middle, 2=right
    mov edi, r13d
    dec edi                  ; X11 button 1-3 to 0-2
    ; col and row are 1-based
    mov esi, r12d
    inc esi                  ; 1-based col
    mov edx, eax
    inc edx                  ; 1-based row
    mov ecx, 'M'             ; press
    call send_mouse_sgr
    jmp .hxe_bp_done2

.hxe_bp_scroll_up:
    ; Button 4 = scroll up
    ; Check mouse tracking for scroll report
    cmp qword [mouse_tracking], 0
    je .hxe_bp_scroll_up_view
    ; Report scroll as button 64 in SGR
    ; Calculate row/col
    movzx eax, word [x11_buf + rbx + 24]
    movzx ecx, word [char_width]
    test ecx, ecx
    jz .hxe_bp_done2
    xor edx, edx
    div ecx
    mov r12, rax             ; col
    movzx eax, word [x11_buf + rbx + 26]
    movzx ecx, word [char_height]
    test ecx, ecx
    jz .hxe_bp_done2
    xor edx, edx
    div ecx
    mov edi, 64              ; scroll up button
    mov esi, r12d
    inc esi
    mov edx, eax
    inc edx
    mov ecx, 'M'
    call send_mouse_sgr
    jmp .hxe_bp_done2
.hxe_bp_scroll_up_view:
    call scroll_view_up
    jmp .hxe_bp_done2

.hxe_bp_scroll_down:
    ; Button 5 = scroll down
    cmp qword [mouse_tracking], 0
    je .hxe_bp_scroll_down_view
    ; Report scroll as button 65 in SGR
    movzx eax, word [x11_buf + rbx + 24]
    movzx ecx, word [char_width]
    test ecx, ecx
    jz .hxe_bp_done2
    xor edx, edx
    div ecx
    mov r12, rax
    movzx eax, word [x11_buf + rbx + 26]
    movzx ecx, word [char_height]
    test ecx, ecx
    jz .hxe_bp_done2
    xor edx, edx
    div ecx
    mov edi, 65              ; scroll down button
    mov esi, r12d
    inc esi
    mov edx, eax
    inc edx
    mov ecx, 'M'
    call send_mouse_sgr
    jmp .hxe_bp_done2
.hxe_bp_scroll_down_view:
    call scroll_view_down

.hxe_bp_done2:
    pop r13
    pop r12
    pop rbx
    add rbx, 32
    jmp .hxe_loop

.hxe_motion:
    ; MotionNotify: mouse motion reporting or update selection
    push rbx
    push r12

    ; Check if mouse tracking wants motion events
    ; mode 2 (button) reports motion only while button held
    ; mode 3 (any) reports all motion
    cmp qword [mouse_tracking], 3
    je .hxe_mn_mouse_report
    cmp qword [mouse_tracking], 2
    jne .hxe_mn_selection

    ; Mode 2: only report motion if button is held (state has button mask)
    movzx eax, word [x11_buf + rbx + 28]
    test eax, 0x700          ; Button1-3 mask (bits 8-10)
    jz .hxe_mn_selection

.hxe_mn_mouse_report:
    ; Check Ctrl override
    movzx eax, word [x11_buf + rbx + 28]
    test eax, 4
    jnz .hxe_mn_selection    ; Ctrl held, do selection instead

    ; Calculate col/row
    movzx eax, word [x11_buf + rbx + 24]
    movzx ecx, word [char_width]
    test ecx, ecx
    jz .hxe_mn_done
    xor edx, edx
    div ecx
    mov r12, rax             ; col
    movzx eax, word [x11_buf + rbx + 26]
    movzx ecx, word [char_height]
    test ecx, ecx
    jz .hxe_mn_done
    xor edx, edx
    div ecx
    ; Determine which button is held for motion encoding
    ; button 32 + 0/1/2 for motion with button 1/2/3
    movzx ecx, word [x11_buf + rbx + 28]
    mov edi, 32              ; motion flag
    test ecx, 0x100          ; Button1Mask
    jnz .hxe_mn_send
    inc edi                   ; 33 = motion + middle
    test ecx, 0x200          ; Button2Mask
    jnz .hxe_mn_send
    inc edi                   ; 34 = motion + right
    test ecx, 0x400          ; Button3Mask
    jnz .hxe_mn_send
    mov edi, 35              ; motion with no button (mode 3)
.hxe_mn_send:
    mov esi, r12d
    inc esi                  ; 1-based col
    mov edx, eax
    inc edx                  ; 1-based row
    mov ecx, 'M'             ; motion
    call send_mouse_sgr
    jmp .hxe_mn_done

.hxe_mn_selection:
    ; Update selection end if button held (and not in word/line lock)
    cmp qword [sel_mode], 0
    jne .hxe_mn_done
    cmp qword [sel_button_held], 1
    jne .hxe_mn_done
    ; Drag in progress: activate selection now (cleared on press)
    mov qword [sel_active], 1
    movzx eax, word [x11_buf + rbx + 24]
    movzx ecx, word [char_width]
    test ecx, ecx
    jz .hxe_mn_done
    xor edx, edx
    div ecx
    mov [sel_end_col], rax
    movzx eax, word [x11_buf + rbx + 26]
    movzx ecx, word [char_height]
    test ecx, ecx
    jz .hxe_mn_done
    xor edx, edx
    div ecx
    mov [sel_end_row], rax
    ; Trigger re-render to show selection visually
    call render_screen
    call x11_flush
.hxe_mn_done:
    pop r12
    pop rbx
    add rbx, 32
    jmp .hxe_loop

.hxe_button_release:
    ; ButtonRelease: mouse release reporting, or end selection
    movzx eax, byte [x11_buf + rbx + 1]
    push rbx
    push r12
    push r13
    mov r13d, eax            ; button number

    ; Only handle buttons 1-3
    cmp r13d, 1
    jb .hxe_br_done2
    cmp r13d, 3
    ja .hxe_br_done2

    ; Check mouse tracking for release reporting
    cmp qword [mouse_tracking], 0
    je .hxe_br_selection

    ; Check Ctrl override
    movzx ecx, word [x11_buf + rbx + 28]
    test ecx, 4
    jnz .hxe_br_selection    ; Ctrl held, do selection

    ; Send mouse release to PTY
    movzx eax, word [x11_buf + rbx + 24]
    movzx ecx, word [char_width]
    test ecx, ecx
    jz .hxe_br_done2
    xor edx, edx
    div ecx
    mov r12, rax             ; col
    movzx eax, word [x11_buf + rbx + 26]
    movzx ecx, word [char_height]
    test ecx, ecx
    jz .hxe_br_done2
    xor edx, edx
    div ecx
    ; SGR release: ESC[<button;col;row m (lowercase m for release)
    mov edi, r13d
    dec edi                  ; button 0-2
    mov esi, r12d
    inc esi                  ; 1-based col
    mov edx, eax
    inc edx                  ; 1-based row
    mov ecx, 'm'             ; release
    call send_mouse_sgr
    jmp .hxe_br_done2

.hxe_br_selection:
    cmp r13d, 1
    jne .hxe_br_done2
    mov qword [sel_button_held], 0
    cmp qword [sel_active], 1
    jne .hxe_br_done2
    ; Word/line selections were finalized at button-press; skip release update
    cmp qword [sel_mode], 0
    jne .hxe_br_done2
    ; Update final position
    movzx eax, word [x11_buf + rbx + 24]
    movzx ecx, word [char_width]
    test ecx, ecx
    jz .hxe_br_copy
    xor edx, edx
    div ecx
    mov [sel_end_col], rax
    movzx eax, word [x11_buf + rbx + 26]
    movzx ecx, word [char_height]
    test ecx, ecx
    jz .hxe_br_copy
    xor edx, edx
    div ecx
    mov [sel_end_row], rax
.hxe_br_copy:
    ; Extract selected text from grid into sel_buf
    call selection_extract
    ; Claim PRIMARY selection ownership
    ; SetSelectionOwner: opcode=22, pad=0, length=4
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_SET_SELECTION_OWNER
    mov byte [rdi+1], 0
    mov word [rdi+2], 4
    mov eax, [win_id]
    mov [rdi+4], eax              ; owner
    mov dword [rdi+8], 1          ; selection = XA_PRIMARY
    mov dword [rdi+12], 0         ; time = CurrentTime
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]
    call x11_flush
.hxe_br_done2:
    pop r13
    pop r12
    pop rbx
    add rbx, 32
    jmp .hxe_loop

.hxe_sel_request:
    ; SelectionRequest event (type 30)
    ; Format: pad(4), time(4), owner(4), requestor(4), selection(4),
    ;         target(4), property(4)
    ; Offsets: 4=time, 8=owner, 12=requestor, 16=selection, 20=target, 24=property
    push rbx
    push r12
    ; Read requestor, target, property from event
    mov r12d, [x11_buf + rbx + 12]   ; requestor window
    mov eax, [x11_buf + rbx + 20]    ; target atom

    ; Check if target is TARGETS
    cmp eax, [targets_atom]
    je .hxe_sr_targets

    ; Check if target is UTF8_STRING or STRING (31)
    cmp eax, [utf8_string_atom]
    je .hxe_sr_string
    cmp eax, 31                      ; XA_STRING
    je .hxe_sr_string

    ; Unsupported target: send SelectionNotify with property=None
    mov ecx, 0                       ; property = None
    jmp .hxe_sr_notify

.hxe_sr_targets:
    ; ChangeProperty on requestor: list supported targets
    ; We support TARGETS and UTF8_STRING
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_PROPERTY
    mov byte [rdi+1], 0              ; mode = Replace
    mov word [rdi+2], 8              ; length (6 + 2 atoms)
    mov [rdi+4], r12d                ; window = requestor
    mov eax, [x11_buf + rbx + 24]    ; property from request
    mov [rdi+8], eax
    mov dword [rdi+12], 4            ; type = ATOM
    mov byte [rdi+16], 32            ; format
    mov byte [rdi+17], 0
    mov word [rdi+18], 0
    mov dword [rdi+20], 2            ; 2 atoms
    mov eax, [targets_atom]
    mov [rdi+24], eax
    mov eax, [utf8_string_atom]
    mov [rdi+28], eax
    lea rsi, [tmp_buf]
    mov rdx, 32
    call x11_buffer
    inc dword [x11_seq]
    mov ecx, [x11_buf + rbx + 24]    ; property = as requested
    jmp .hxe_sr_notify

.hxe_sr_string:
    ; ChangeProperty on requestor: set selection text
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_PROPERTY
    mov byte [rdi+1], 0              ; mode = Replace
    mov rax, [sel_len]
    ; length = (24 + data_len + 3) / 4
    mov edx, eax
    add edx, 24
    add edx, 3
    shr edx, 2
    mov word [rdi+2], dx             ; request length
    mov [rdi+4], r12d                ; window = requestor
    mov ecx, [x11_buf + rbx + 24]    ; property from request
    mov [rdi+8], ecx
    push rcx                         ; save property for notify
    mov eax, [utf8_string_atom]
    mov [rdi+12], eax                ; type = UTF8_STRING
    mov byte [rdi+16], 8             ; format = 8 (bytes)
    mov byte [rdi+17], 0
    mov word [rdi+18], 0
    mov eax, [sel_len]
    mov [rdi+20], eax                ; data length
    ; Copy selection text
    xor ecx, ecx
    mov eax, [sel_len]
.hxe_sr_cp:
    cmp ecx, eax
    jge .hxe_sr_cp_done
    movzx edx, byte [sel_buf + rcx]
    mov [tmp_buf + 24 + rcx], dl
    inc ecx
    jmp .hxe_sr_cp
.hxe_sr_cp_done:
    ; Pad to 4 bytes
    mov eax, [sel_len]
    add eax, 24
    add eax, 3
    and eax, ~3
    mov rdx, rax
    lea rsi, [tmp_buf]
    call x11_buffer
    inc dword [x11_seq]
    pop rcx                          ; restore property
    jmp .hxe_sr_notify

.hxe_sr_notify:
    ; Send SelectionNotify event to requestor
    ; SendEvent: opcode=25, propagate=0, length=11
    ; Event to send is SelectionNotify (31), 32 bytes
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_SEND_EVENT
    mov byte [rdi+1], 0              ; propagate = false
    mov word [rdi+2], 11             ; length
    mov [rdi+4], r12d                ; destination = requestor
    mov dword [rdi+8], 0             ; event-mask = 0
    ; SelectionNotify event (32 bytes) at offset 12
    mov byte [rdi+12], 31            ; type = SelectionNotify
    mov byte [rdi+13], 0
    mov word [rdi+14], 0             ; sequence (ignored)
    mov eax, [x11_buf + rbx + 4]     ; time from request
    mov [rdi+16], eax
    mov [rdi+20], r12d               ; requestor
    mov eax, [x11_buf + rbx + 16]    ; selection
    mov [rdi+24], eax
    mov eax, [x11_buf + rbx + 20]    ; target
    mov [rdi+28], eax
    mov [rdi+32], ecx                ; property (or 0=None)
    ; Pad remaining bytes
    mov dword [rdi+36], 0
    mov dword [rdi+40], 0
    lea rsi, [tmp_buf]
    mov rdx, 44
    call x11_buffer
    inc dword [x11_seq]
    call x11_flush
    pop r12
    pop rbx
    add rbx, 32
    jmp .hxe_loop

.hxe_sel_notify:
    ; SelectionNotify event (type 31): paste data arrived
    ; property at offset 20 (CARD32)
    push rbx
    push r12
    mov eax, [x11_buf + rbx + 20]
    test eax, eax
    jz .hxe_sn_done                  ; property = None, paste failed
    ; GetProperty to read the pasted data
    ; opcode=20, delete=1, length=6
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_GET_PROPERTY
    mov byte [rdi+1], 1              ; delete = true
    mov word [rdi+2], 6              ; length
    mov eax, [win_id]
    mov [rdi+4], eax                 ; window
    mov eax, [glass_sel_atom]
    mov [rdi+8], eax                 ; property = GLASS_SEL
    mov dword [rdi+12], 0            ; type = AnyPropertyType
    mov dword [rdi+16], 0            ; long-offset
    mov dword [rdi+20], 4096         ; long-length (max words to read)
    lea rsi, [tmp_buf]
    mov rdx, 24
    call x11_buffer
    inc dword [x11_seq]
    ; Flush and read reply
    call x11_flush
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 65536
    syscall
    cmp rax, 32
    jl .hxe_sn_done
    ; Reply: type at offset 8, bytes-after at offset 16, value-length at offset 16
    ; Format at offset 1, length at offset 4 (in 4-byte units)
    ; Data at offset 32, data length = value_length (at offset 16)
    mov r12d, [x11_buf + 16]        ; value_length (number of items)
    movzx eax, byte [x11_buf + 1]   ; format (8, 16, or 32 bits)
    cmp al, 8
    jne .hxe_sn_done                 ; we only handle 8-bit format
    ; r12d = number of bytes of paste data
    test r12d, r12d
    jz .hxe_sn_done
    ; Write paste data to PTY (with optional bracketed paste)
    ; Send bracket start if bracketed paste mode is on
    cmp qword [bracketed_paste], 1
    jne .hxe_sn_no_bracket_start
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [bracket_paste_start]
    mov rdx, bracket_paste_start_len
    syscall
.hxe_sn_no_bracket_start:
    ; Write the actual paste data
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [x11_buf + 32]
    mov edx, r12d
    syscall
    ; Send bracket end if bracketed paste mode is on
    cmp qword [bracketed_paste], 1
    jne .hxe_sn_done
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [bracket_paste_end]
    mov rdx, bracket_paste_end_len
    syscall
.hxe_sn_done:
    pop r12
    pop rbx
    add rbx, 32
    jmp .hxe_loop

.hxe_client_msg:
    ; Check for WM_DELETE_WINDOW
    mov eax, [x11_buf + rbx + 8]  ; message type
    cmp eax, [wm_protocols_atom]
    jne .hxe_skip
    mov eax, [x11_buf + rbx + 12] ; data
    cmp eax, [wm_delete_atom]
    jne .hxe_skip
    ; Window close requested
    mov rdi, 0
    mov rax, SYS_EXIT
    syscall

.hxe_done:
    pop r12
    pop rbx
    ret

; Handle keypress using X11 keysym map
; eax = keycode, ecx = state (modifiers)
handle_keypress:
    push rbx
    push r12
    push r13
    mov r12d, eax            ; keycode
    mov ebx, ecx             ; state (modifier mask)

    ; Determine shift_index: 0 = unshifted, 1 = shifted
    xor r13d, r13d           ; shift_index = 0
    test ebx, 1              ; ShiftMask = bit 0
    jz .hkp_lookup
    mov r13d, 1

.hkp_lookup:
    ; First, get unshifted keysym (index 0) for special-key checks
    mov eax, r12d
    shl eax, 3               ; keycode * 8
    cmp eax, 2048
    jge .hkp_done
    mov ecx, [keysym_map + rax*4]  ; ecx = unshifted keysym
    mov [hkp_unshifted_ksym], ecx

    ; Check for Shift+Insert (XK_Insert = 0xFF63) on unshifted keysym
    ; Shift+Insert pastes from PRIMARY selection (X11 tradition)
    test ebx, 1                    ; Shift held?
    jz .hkp_no_shift_insert
    cmp ecx, 0xFF63                ; XK_Insert
    je .hkp_paste_primary
.hkp_no_shift_insert:

    ; Now look up the shifted/Mode_switch keysym based on modifiers
    ; X11 state: bit 0 = Shift, bit 7 = Mod5 (AltGr/ISO_Level3_Shift)
    mov eax, r12d
    shl eax, 3                     ; keycode * 8
    ; If AltGr (Mod5, bit 7) held, use group 1 (indices 4-5)
    test ebx, 0x80
    jz .hkp_grp0
    add eax, 4                     ; AltGr group base
.hkp_grp0:
    add eax, r13d                  ; + shift_index (0 or 1)
    cmp eax, 2048
    jge .hkp_done
    mov eax, [keysym_map + rax*4]
    ; If keysym is 0 (no mapping in this group), fall back to unshifted
    test eax, eax
    jnz .hkp_have_ksym
    mov eax, [hkp_unshifted_ksym]
.hkp_have_ksym:

    ; Check for Ctrl+Shift+V (paste from clipboard)
    mov ecx, ebx
    and ecx, 5               ; ControlMask | ShiftMask
    cmp ecx, 5
    jne .hkp_no_paste
    cmp eax, 0x76            ; 'v'
    je .hkp_paste
    cmp eax, 0x56            ; 'V'
    je .hkp_paste
.hkp_no_paste:

    ; Configurable shortcut dispatch. Each binding is (mods, keysym).
    ; mods=0 means the binding is disabled. Only Shift|Ctrl|Alt bits
    ; (0|2|3 = mask 0x0D) participate in the comparison so AltGr/Lock
    ; don't accidentally suppress matches.
    xor ecx, ecx
.hkp_kbd_loop:
    cmp ecx, KB_COUNT
    jge .hkp_no_alt
    movzx edx, byte [keybind_mods + rcx]
    test edx, edx
    jz .hkp_kbd_next
    mov esi, ebx
    and esi, 0x0D
    cmp esi, edx
    jne .hkp_kbd_next
    cmp eax, [keybind_keysyms + rcx*4]
    jne .hkp_kbd_next
    ; Match — dispatch by index
    cmp ecx, KB_FONT_INC
    je .hkp_font_inc
    cmp ecx, KB_FONT_DEC
    je .hkp_font_dec
    cmp ecx, KB_FONT_RESET
    je .hkp_font_reset
    cmp ecx, KB_BG_CYCLE
    je .hkp_bg_cycle
    cmp ecx, KB_OPACITY
    je .hkp_opacity_toggle
.hkp_kbd_next:
    inc ecx
    jmp .hkp_kbd_loop
.hkp_no_alt:

    ; Dead-key composition. Two cases:
    ;   1. The current keysym IS a dead key (0xFE50..0xFE7F): stash it
    ;      in pending_dead and emit nothing. The user's *next* keypress
    ;      decides what to produce.
    ;   2. A dead key is already pending: try to compose (pending, key)
    ;      via compose_table. On hit emit the composed codepoint;
    ;      on miss emit the pending dead key's spacing equivalent
    ;      first, then fall through to handle the new key normally.
    ;      Special case: pending + space → just the spacing char (lets
    ;      the user produce a bare ¨/´/^/~ when they don't want to
    ;      compose).
    cmp eax, 0xFE50
    jb .hkp_check_pending
    cmp eax, 0xFE7F
    ja .hkp_check_pending
    sub eax, 0xFE50
    mov [pending_dead], al                ; stash dead-key offset
    jmp .hkp_done                         ; do not emit yet
.hkp_check_pending:
    movzx ecx, byte [pending_dead]
    cmp cl, 0xFF
    je .hkp_no_dead                       ; nothing pending
    mov byte [pending_dead], 0xFF         ; consume regardless of outcome

    ; pending + space → emit just the spacing dead-char.
    cmp eax, 0x20
    jne .hkp_compose_lookup
    movzx eax, word [dead_to_ucs + rcx*2]
    test eax, eax
    jz .hkp_done
    jmp .hkp_emit_ucs

.hkp_compose_lookup:
    ; Walk compose_table for (cl, al-low-byte). edx scratches over entries.
    push rax                              ; preserve current keysym
    xor ebx, ebx
.hkp_cl_loop:
    mov edx, [compose_table + rbx*4]
    test edx, edx
    jz .hkp_cl_miss
    cmp dl, cl
    jne .hkp_cl_next
    pop rax                               ; restore key (also into al)
    push rax
    mov dh, al                            ; key low byte
    shr edx, 8
    cmp dl, dh
    jne .hkp_cl_next
    ; Match — composed UCS-2 sits in the high 16 bits of the original
    ; entry. Re-load it cleanly.
    mov edx, [compose_table + rbx*4]
    shr edx, 16
    movzx eax, dx
    add rsp, 8                            ; drop saved keysym (consumed)
    jmp .hkp_emit_ucs
.hkp_cl_next:
    inc ebx
    jmp .hkp_cl_loop

.hkp_cl_miss:
    ; No composition. Emit the dead char's spacing equivalent first,
    ; then fall through to process the new key normally below.
    movzx eax, word [dead_to_ucs + rcx*2]
    test eax, eax
    jz .hkp_cl_miss_no_dead_char
    call emit_ucs_inline
.hkp_cl_miss_no_dead_char:
    pop rax                               ; restore the new key
    jmp .hkp_no_dead

.hkp_emit_ucs:
    ; eax = composed/spacing codepoint. Emit as UTF-8 and finish.
    cmp eax, 0x80
    jb .hkp_eu_1b
    ; 2-byte UTF-8 (U+0080..U+07FF covers everything we compose).
    mov ecx, eax
    shr ecx, 6
    or ecx, 0xC0
    mov [key_out_buf], cl
    and eax, 0x3F
    or eax, 0x80
    mov [key_out_buf+1], al
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [key_out_buf]
    mov rdx, 2
    syscall
    jmp .hkp_done
.hkp_eu_1b:
    mov [key_out_buf], al
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [key_out_buf]
    mov rdx, 1
    syscall
    jmp .hkp_done

.hkp_no_dead:

    ; Dispatch on keysym ranges
    ; Special keys (0xFF00-0xFFFF)
    cmp eax, 0xFF00
    jge .hkp_special

    ; Anything in U+0080..U+07FF (Latin-1 supplement, Latin Extended-A,
    ; spacing modifier letters incl. dead-key equivalents) → 2-byte UTF-8.
    cmp eax, 0x80
    jb .hkp_check_ascii
    cmp eax, 0x07FF
    ja .hkp_done
    ; 2-byte UTF-8: 110xxxxx 10xxxxxx
    mov ecx, eax
    shr ecx, 6               ; high 5 bits → first byte low bits
    or ecx, 0xC0
    mov [key_out_buf], cl
    and eax, 0x3F            ; low 6 bits
    or eax, 0x80
    mov [key_out_buf+1], al
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [key_out_buf]
    mov rdx, 2
    syscall
    jmp .hkp_done

.hkp_check_ascii:
    ; XK_space (0xFF20 handled below in special, but also 0x0020)
    cmp eax, 0x20
    je .hkp_ascii

    ; Printable ASCII range: 0x0020-0x007E
    cmp eax, 0x0020
    jb .hkp_done
    cmp eax, 0x007E
    ja .hkp_done

.hkp_ascii:
    ; keysym IS the ASCII value for this range
    ; Apply Ctrl modifier (bit 2 of state)
    test ebx, 4              ; ControlMask
    jz .hkp_send_byte
    ; Ctrl+letter: keysym & 0x1F
    and eax, 0x1F
.hkp_send_byte:
    mov [key_out_buf], al
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [key_out_buf]
    mov rdx, 1
    syscall
    jmp .hkp_done

.hkp_special:
    ; XK_BackSpace = 0xFF08
    cmp eax, 0xFF08
    je .hkp_bs
    ; XK_Tab = 0xFF09
    cmp eax, 0xFF09
    je .hkp_tab
    ; XK_Return = 0xFF0D
    cmp eax, 0xFF0D
    je .hkp_return
    ; XK_Escape = 0xFF1B
    cmp eax, 0xFF1B
    je .hkp_escape
    ; XK_space = 0xFF20
    cmp eax, 0xFF20
    je .hkp_space
    ; XK_Home = 0xFF50
    cmp eax, 0xFF50
    je .hkp_home
    ; XK_Left = 0xFF51
    cmp eax, 0xFF51
    je .hkp_left
    ; XK_Up = 0xFF52
    cmp eax, 0xFF52
    je .hkp_up
    ; XK_Right = 0xFF53
    cmp eax, 0xFF53
    je .hkp_right
    ; XK_Down = 0xFF54
    cmp eax, 0xFF54
    je .hkp_down
    ; XK_Page_Up = 0xFF55
    cmp eax, 0xFF55
    je .hkp_pgup
    ; XK_Page_Down = 0xFF56
    cmp eax, 0xFF56
    je .hkp_pgdn
    ; XK_End = 0xFF57
    cmp eax, 0xFF57
    je .hkp_end
    ; XK_Insert = 0xFF63 (Shift+Insert = paste)
    cmp eax, 0xFF63
    je .hkp_insert
    ; XK_Delete = 0xFFFF
    cmp eax, 0xFFFF
    je .hkp_delete
    ; Modifier keys (Shift, Ctrl, etc) - ignore
    jmp .hkp_done

.hkp_bs:
    mov byte [key_out_buf], 0x7F
    mov rdx, 1
    jmp .hkp_send_seq

.hkp_tab:
    mov byte [key_out_buf], 0x09
    mov rdx, 1
    jmp .hkp_send_seq

.hkp_return:
    mov byte [key_out_buf], 0x0D
    mov rdx, 1
    jmp .hkp_send_seq

.hkp_escape:
    mov byte [key_out_buf], 0x1B
    mov rdx, 1
    jmp .hkp_send_seq

.hkp_space:
    test ebx, 4              ; Ctrl?
    jnz .hkp_ctrl_space
    mov byte [key_out_buf], 0x20
    mov rdx, 1
    jmp .hkp_send_seq
.hkp_ctrl_space:
    mov byte [key_out_buf], 0x00
    mov rdx, 1
    jmp .hkp_send_seq

.hkp_home:
    mov byte [key_out_buf], 0x1B
    mov byte [key_out_buf+1], '['
    mov byte [key_out_buf+2], 'H'
    mov rdx, 3
    jmp .hkp_send_seq

.hkp_end:
    mov byte [key_out_buf], 0x1B
    mov byte [key_out_buf+1], '['
    mov byte [key_out_buf+2], 'F'
    mov rdx, 3
    jmp .hkp_send_seq

.hkp_up:
    mov al, 'A'
    jmp .hkp_arrow_emit
.hkp_down:
    mov al, 'B'
    jmp .hkp_arrow_emit
.hkp_right:
    mov al, 'C'
    jmp .hkp_arrow_emit
.hkp_left:
    mov al, 'D'
    ; fall through

; Arrow emit: al = final letter (A/B/C/D); ebx = X11 modifier mask.
; Modifier param per xterm: 1 + Shift(1) + Alt(2) + Ctrl(4). Plain arrow
; stays 3 bytes (ESC[A); modified arrow becomes ESC[1;<n><L> so vim sees
; <C-Up>, <S-Down>, <A-Right> etc. (Ctrl+Up was the trigger.)
.hkp_arrow_emit:
    xor ecx, ecx
    test ebx, 1                  ; Shift
    jz .ha_ns
    inc ecx
.ha_ns:
    test ebx, 8                  ; Alt (Mod1)
    jz .ha_na
    add ecx, 2
.ha_na:
    test ebx, 4                  ; Ctrl
    jz .ha_nc
    add ecx, 4
.ha_nc:
    mov byte [key_out_buf], 0x1B
    mov byte [key_out_buf+1], '['
    test ecx, ecx
    jnz .ha_mod
    mov byte [key_out_buf+2], al
    mov rdx, 3
    jmp .hkp_send_seq
.ha_mod:
    inc ecx                      ; param = 1 + modifier bits
    add cl, '0'
    mov byte [key_out_buf+2], '1'
    mov byte [key_out_buf+3], ';'
    mov byte [key_out_buf+4], cl
    mov byte [key_out_buf+5], al
    mov rdx, 6
    jmp .hkp_send_seq

.hkp_pgup:
    ; Shift+PageUp = scroll back
    test ebx, 1
    jnz .hkp_scroll_back
    ; Normal PageUp: send ESC[5~
    mov byte [key_out_buf], 0x1B
    mov byte [key_out_buf+1], '['
    mov byte [key_out_buf+2], '5'
    mov byte [key_out_buf+3], '~'
    mov rdx, 4
    jmp .hkp_send_seq

.hkp_pgdn:
    ; Shift+PageDown = scroll forward
    test ebx, 1
    jnz .hkp_scroll_fwd
    ; Normal PageDown: send ESC[6~
    mov byte [key_out_buf], 0x1B
    mov byte [key_out_buf+1], '['
    mov byte [key_out_buf+2], '6'
    mov byte [key_out_buf+3], '~'
    mov rdx, 4
    jmp .hkp_send_seq

.hkp_insert:
    ; Shift+Insert = paste
    test ebx, 1
    jnz .hkp_paste
    jmp .hkp_done

.hkp_delete:
    mov byte [key_out_buf], 0x1B
    mov byte [key_out_buf+1], '['
    mov byte [key_out_buf+2], '3'
    mov byte [key_out_buf+3], '~'
    mov rdx, 4
    jmp .hkp_send_seq

.hkp_send_seq:
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [key_out_buf]
    ; rdx already set by caller
    syscall
    jmp .hkp_done

.hkp_scroll_back:
    call scroll_view_up
    jmp .hkp_done

.hkp_scroll_fwd:
    call scroll_view_down
    jmp .hkp_done

.hkp_paste:
    ; Request CLIPBOARD selection via ConvertSelection
    mov ecx, [clipboard_atom]
    jmp .hkp_paste_send
.hkp_paste_primary:
    ; Request PRIMARY selection
    mov ecx, [primary_atom]
.hkp_paste_send:
    ; ConvertSelection: opcode=24, pad, length=6
    ; requestor, selection, target, property, time
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CONVERT_SELECTION
    mov byte [rdi+1], 0
    mov word [rdi+2], 6              ; length
    mov eax, [win_id]
    mov [rdi+4], eax                 ; requestor
    mov [rdi+8], ecx                 ; selection (CLIPBOARD or PRIMARY)
    mov eax, [utf8_string_atom]
    mov [rdi+12], eax                ; target = UTF8_STRING
    mov eax, [glass_sel_atom]
    mov [rdi+16], eax                ; property = GLASS_SEL
    mov dword [rdi+20], 0            ; time = CurrentTime
    lea rsi, [tmp_buf]
    mov rdx, 24
    call x11_buffer
    inc dword [x11_seq]
    call x11_flush
    jmp .hkp_done

.hkp_font_inc:
    mov edi, 1
    call font_change_step
    jmp .hkp_done
.hkp_font_dec:
    mov edi, -1
    call font_change_step
    jmp .hkp_done
.hkp_font_reset:
    xor edi, edi
    call font_change_step
    jmp .hkp_done
.hkp_bg_cycle:
    call bg_cycle_advance
    jmp .hkp_done
.hkp_opacity_toggle:
    call opacity_toggle_apply
    jmp .hkp_done

.hkp_done:
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; VT100 escape sequence parser
; ══════════════════════════════════════════════════════════════════════

; Process bytes from PTY
; rsi = buffer, rcx = length
vt_process:
    push rbx
    push r12
    push r13
    push r14

    mov r12, rsi             ; buffer
    mov r13, rcx             ; length
    xor r14, r14             ; current position

.vtp_loop:
    cmp r14, r13
    jge .vtp_done

    movzx eax, byte [r12 + r14]
    inc r14

    ; Dispatch based on state
    mov rcx, [vt_state]
    cmp rcx, VT_ESC
    je .vtp_esc
    cmp rcx, VT_CSI
    je .vtp_csi
    cmp rcx, VT_CSI_PARAM
    je .vtp_csi
    cmp rcx, VT_OSC
    je .vtp_osc
    cmp rcx, VT_CHARSET
    je .vtp_charset
    cmp rcx, VT_STRING
    je .vtp_string_discard
    cmp rcx, VT_APC
    je .vtp_apc_capture

    ; VT_NORMAL
    cmp al, 27               ; ESC
    je .vtp_start_esc
    cmp al, 13               ; CR
    je .vtp_cr
    cmp al, 10               ; LF
    je .vtp_lf
    cmp al, 8                ; BS
    je .vtp_bs
    cmp al, 9                ; TAB
    je .vtp_tab
    cmp al, 7                ; BEL
    je .vtp_bel
    cmp al, 0x20
    jb .vtp_loop             ; ignore other control chars

    ; UTF-8 decoder
    cmp al, 0x80
    jb .vtp_put_char         ; ASCII: put directly

    ; Check if continuation byte (10xxxxxx)
    cmp al, 0xBF
    ja .vtp_utf8_lead

    ; Continuation byte
    cmp dword [utf8_remaining], 0
    je .vtp_loop             ; unexpected continuation, skip
    movzx eax, al
    and eax, 0x3F
    mov ecx, [utf8_char]
    shl ecx, 6
    or ecx, eax
    mov [utf8_char], ecx
    dec dword [utf8_remaining]
    cmp dword [utf8_remaining], 0
    jne .vtp_loop            ; more bytes coming
    ; Complete: dispatch BMP to grid_put_char as before; route non-BMP
    ; codepoints (the SMP emoji blocks) into the emoji cache so they
    ; can be rendered via XRender Composite. Falls back to U+FFFD if
    ; RENDER isn't available or the cache is full.
    mov eax, [utf8_char]
    cmp eax, 0xFFFF
    jle .vtp_put_char_bmp
    cmp dword [render_major], 0
    je .vtp_put_emoji_fallback
    push rax
    mov edi, eax
    call find_or_alloc_emoji
    test rax, rax
    js .vtp_put_emoji_fallback_pop
    mov [cur_emoji_index], ax
    or byte [cur_attrs], 8       ; ATTR_IS_EMOJI
    pop rax
    mov eax, 0x20                 ; cell glyph fallback (overlaid by emoji)
    call grid_put_char
    and byte [cur_attrs], ~8
    jmp .vtp_loop
.vtp_put_emoji_fallback_pop:
    pop rax
.vtp_put_emoji_fallback:
    mov eax, 0xFFFD
    jmp .vtp_put_char
.vtp_put_char_bmp:
    movzx eax, ax
    jmp .vtp_put_char

.vtp_utf8_lead:
    ; Lead byte
    cmp al, 0xDF
    jbe .vtp_utf8_2          ; 110xxxxx = 2-byte
    cmp al, 0xEF
    jbe .vtp_utf8_3          ; 1110xxxx = 3-byte
    cmp al, 0xF7
    jbe .vtp_utf8_4          ; 11110xxx = 4-byte
    jmp .vtp_loop            ; invalid, skip

.vtp_utf8_2:
    movzx eax, al
    and eax, 0x1F
    mov [utf8_char], eax
    mov dword [utf8_remaining], 1
    jmp .vtp_loop
.vtp_utf8_3:
    movzx eax, al
    and eax, 0x0F
    mov [utf8_char], eax
    mov dword [utf8_remaining], 2
    jmp .vtp_loop
.vtp_utf8_4:
    movzx eax, al
    and eax, 0x07
    mov [utf8_char], eax
    mov dword [utf8_remaining], 3
    jmp .vtp_loop

.vtp_put_char:
    ; ax = UCS-2 character
    call grid_put_char
    jmp .vtp_loop

.vtp_start_esc:
    mov qword [vt_state], VT_ESC
    jmp .vtp_loop

.vtp_cr:
    mov byte [pending_wrap], 0
    mov qword [cursor_col], 0
    jmp .vtp_loop

.vtp_lf:
    mov byte [pending_wrap], 0
    mov rax, [cursor_row]
    inc rax
    ; Check scroll region bottom (use scroll_bottom if set, else grid_rows-1)
    mov rcx, [scroll_bottom]
    test rcx, rcx
    jnz .vtp_lf_check
    mov rcx, [grid_rows]
    dec rcx
.vtp_lf_check:
    cmp rax, rcx
    jle .vtp_lf_ok
    ; Scroll up within scroll region
    call grid_scroll_region_up
    mov rax, [scroll_bottom]
    test rax, rax
    jnz .vtp_lf_ok
    mov rax, [grid_rows]
    dec rax
.vtp_lf_ok:
    mov [cursor_row], rax
    jmp .vtp_loop

.vtp_bs:
    mov byte [pending_wrap], 0
    cmp qword [cursor_col], 0
    je .vtp_loop
    dec qword [cursor_col]
    jmp .vtp_loop

.vtp_tab:
    mov byte [pending_wrap], 0
    mov rax, [cursor_col]
    add rax, 8
    and rax, ~7
    cmp rax, [grid_cols]
    jl .vtp_tab_ok
    mov rax, [grid_cols]
    dec rax
.vtp_tab_ok:
    mov [cursor_col], rax
    jmp .vtp_loop

.vtp_bel:
    ; Visual bell: set bell_flash_until = now + 100ms
    sub rsp, 16
    mov rax, SYS_CLOCK_GETTIME
    xor edi, edi             ; CLOCK_REALTIME
    mov rsi, rsp
    syscall
    ; Convert sec*1e9 + nsec
    mov rax, [rsp]
    imul rax, 1000000000
    add rax, [rsp + 8]
    add rax, 100000000       ; +100ms
    mov [bell_flash_until], rax
    ; Force redraw to show flash
    mov qword [all_dirty], 1
    add rsp, 16
    jmp .vtp_loop

.vtp_esc:
    mov qword [vt_state], VT_NORMAL
    cmp al, '['
    je .vtp_start_csi
    cmp al, '7'
    je .vtp_save_cursor
    cmp al, '8'
    je .vtp_restore_cursor
    cmp al, 'D'
    je .vtp_lf              ; index = LF
    cmp al, 'M'
    je .vtp_reverse_index
    cmp al, ']'
    je .vtp_start_osc
    cmp al, 'c'
    je .vtp_full_reset
    ; Charset designators ESC ( / ) / * / + <X>: swallow the next byte
    ; (the charset designator like 'B' for ASCII, '0' for DEC graphics).
    ; ncurses sends ESC ( B liberally to reset the G0 charset; without
    ; this the 'B' would be written to the screen as a literal char.
    cmp al, '('
    je .vtp_charset_start
    cmp al, ')'
    je .vtp_charset_start
    cmp al, '*'
    je .vtp_charset_start
    cmp al, '+'
    je .vtp_charset_start
    ; Application Program Command (kitty graphics): capture body and
    ; dispatch on terminator. DCS / PM still get discarded silently.
    cmp al, '_'
    je .vtp_start_apc
    cmp al, 'P'
    je .vtp_start_string
    cmp al, '^'
    je .vtp_start_string
    jmp .vtp_loop

.vtp_charset_start:
    mov qword [vt_state], VT_CHARSET
    jmp .vtp_loop

.vtp_charset:
    ; Discard the designator byte and return to normal.
    mov qword [vt_state], VT_NORMAL
    jmp .vtp_loop

.vtp_start_string:
    mov qword [vt_state], VT_STRING
    jmp .vtp_loop

.vtp_string_discard:
    ; BEL terminates (xterm-style)
    cmp al, 7
    je .vtp_string_end
    ; ESC could start ST (ESC \) — peek next byte
    cmp al, 27
    jne .vtp_loop
    cmp r14, r13
    jge .vtp_loop
    mov al, [r12 + r14]
    inc r14
    cmp al, '\'
    jne .vtp_string_discard      ; nested ESC? keep discarding
.vtp_string_end:
    mov qword [vt_state], VT_NORMAL
    jmp .vtp_loop

.vtp_start_apc:
    mov qword [vt_state], VT_APC
    mov qword [apc_body_len], 0
    jmp .vtp_loop

.vtp_apc_capture:
    ; BEL terminates and dispatches.
    cmp al, 7
    je .vtp_apc_dispatch
    ; ESC could start ST (ESC \).
    cmp al, 27
    jne .vtp_apc_store
    cmp r14, r13
    jge .vtp_loop                    ; out of bytes; resume next read
    mov al, [r12 + r14]
    inc r14
    cmp al, '\'
    je .vtp_apc_dispatch
    ; Stray ESC inside body: keep capturing both the ESC and this byte
    ; (rare, but pessimistically preserve so we don't break weird apps).
    push rax
    mov al, 27
    call .vtp_apc_store_helper
    pop rax
.vtp_apc_store:
    call .vtp_apc_store_helper
    jmp .vtp_loop

.vtp_apc_store_helper:
    mov rcx, [apc_body_len]
    cmp rcx, APC_BODY_MAX
    jge .vtp_apc_store_full
    mov [apc_body + rcx], al
    inc qword [apc_body_len]
.vtp_apc_store_full:
    ret

.vtp_apc_dispatch:
    mov qword [vt_state], VT_NORMAL
    ; Only handle 'G' (kitty graphics). Everything else is silently
    ; dropped — mostly tmux passthrough or app-specific extensions.
    cmp qword [apc_body_len], 1
    jl .vtp_loop
    cmp byte [apc_body], 'G'
    jne .vtp_loop
    call handle_kitty_apc
    jmp .vtp_loop

.vtp_start_csi:
    mov qword [vt_state], VT_CSI
    mov qword [vt_param_count], 0
    ; Zero the whole vt_params array (16 dwords = 64 bytes). Just zeroing
    ; the first dword leaves stale params from previous CSIs, which bit
    ; us with `[H` reading vt_params[1]=49 left over from a preceding
    ; `[39;49m`, sending the cursor to col 48 instead of col 0.
    push rdi
    push rcx
    push rax
    lea rdi, [vt_params]
    mov ecx, 16
    xor eax, eax
    rep stosd
    pop rax
    pop rcx
    pop rdi
    mov byte [vt_private], 0
    jmp .vtp_loop

.vtp_save_cursor:
    mov byte [pending_wrap], 0
    mov rax, [cursor_row]
    mov [cursor_saved_row], rax
    mov rax, [cursor_col]
    mov [cursor_saved_col], rax
    jmp .vtp_loop

.vtp_restore_cursor:
    mov byte [pending_wrap], 0
    mov rax, [cursor_saved_row]
    mov [cursor_row], rax
    mov rax, [cursor_saved_col]
    mov [cursor_col], rax
    jmp .vtp_loop

.vtp_reverse_index:
    mov byte [pending_wrap], 0
    ; Scroll the region down if cursor is at scroll_top (or row 0 if no
    ; region is set); otherwise just move the cursor up one row.
    mov rax, [scroll_top]
    cmp [cursor_row], rax
    je .vtp_ri_scroll
    cmp qword [cursor_row], 0
    je .vtp_loop                 ; already at top, can't go up
    dec qword [cursor_row]
    jmp .vtp_loop
.vtp_ri_scroll:
    call grid_scroll_region_down
    jmp .vtp_loop

.vtp_start_osc:
    mov qword [vt_state], VT_OSC
    mov qword [osc_pos], 0
    mov qword [osc_num], 0
    mov qword [osc_collecting], 0
    mov qword [osc_in_num], 1    ; start by parsing the number
    jmp .vtp_loop

.vtp_osc:
    ; Parse OSC: number ; text BEL/ST
    cmp al, 7
    je .vtp_osc_end
    cmp al, 27               ; might be ESC \ (ST)
    jne .vtp_osc_collect
    ; Check next byte for backslash
    cmp r14, r13
    jge .vtp_loop
    cmp byte [r12 + r14], '\'
    jne .vtp_loop
    inc r14
    jmp .vtp_osc_end

.vtp_osc_collect:
    ; Still parsing OSC number?
    cmp qword [osc_in_num], 1
    jne .vtp_osc_text
    ; Semicolon ends the number, starts text
    cmp al, ';'
    je .vtp_osc_start_text
    ; Digit: build number, capped at 65535. The largest OSC code used
    ; in practice is 1337 (iTerm) and we only dispatch on 0/2/8/52, so
    ; cap well above what any sane app emits while preventing 32-bit
    ; wrap into garbage that could match a real opcode.
    cmp al, '0'
    jb .vtp_loop
    cmp al, '9'
    ja .vtp_loop
    mov rcx, [osc_num]
    cmp rcx, 65535
    ja .vtp_loop                     ; saturated; ignore further digits
    imul ecx, 10
    movzx edx, al
    sub edx, '0'
    add ecx, edx
    cmp ecx, 65535
    jbe .vtp_osc_num_store
    mov ecx, 65535
.vtp_osc_num_store:
    mov [osc_num], rcx
    jmp .vtp_loop

.vtp_osc_start_text:
    mov qword [osc_in_num], 0
    mov qword [osc_collecting], 1
    jmp .vtp_loop

.vtp_osc_text:
    ; Collecting title text
    cmp qword [osc_collecting], 1
    jne .vtp_loop
    mov rcx, [osc_pos]
    cmp rcx, 254
    jge .vtp_loop            ; buffer full
    mov [osc_buf + rcx], al
    inc rcx
    mov [osc_pos], rcx
    jmp .vtp_loop

.vtp_osc_end:
    mov qword [vt_state], VT_NORMAL
    ; Null-terminate the captured text
    mov rcx, [osc_pos]
    mov byte [osc_buf + rcx], 0
    ; Check if this is OSC 0 or 2 (set window title)
    mov rax, [osc_num]
    cmp rax, 0
    je .vtp_osc_set_title
    cmp rax, 2
    je .vtp_osc_set_title
    cmp rax, 8
    je .vtp_osc_8
    cmp rax, 52
    je .vtp_osc_52
    jmp .vtp_loop

.vtp_osc_52:
    ; osc_buf = "spec;base64data". Find first ';'.
    xor ecx, ecx
.vtp_osc52_find_sep:
    cmp ecx, [osc_pos]
    jge .vtp_loop
    cmp byte [osc_buf + rcx], ';'
    je .vtp_osc52_data_at
    inc ecx
    jmp .vtp_osc52_find_sep
.vtp_osc52_data_at:
    inc ecx                       ; first byte of base64 data
    mov rdx, [osc_pos]
    sub rdx, rcx                  ; data length
    test rdx, rdx
    jz .vtp_loop                  ; empty: ignore (clear semantics not implemented)
    cmp byte [osc_buf + rcx], '?'
    je .vtp_loop                  ; query: we don't reply
    ; Decode straight into sel_buf.
    lea rdi, [osc_buf + rcx]
    lea rsi, [sel_buf]
    mov rcx, rdx
    call b64_decode
    test rax, rax
    jz .vtp_loop
    cmp rax, 16384
    jle .vtp_osc52_len_ok
    mov rax, 16384
.vtp_osc52_len_ok:
    mov [sel_len], rax
    ; Claim both PRIMARY and CLIPBOARD so middle-click and Ctrl-V both
    ; pick up what the program just wrote.
    call selection_claim_primary
    call selection_claim_clipboard
    jmp .vtp_loop

.vtp_osc_8:
    ; osc_buf = "params;URI" (already null-terminated)
    ; Find the first ';' to skip params; URI follows.
    xor ecx, ecx
.vtp_osc8_find_sep:
    cmp ecx, [osc_pos]
    jge .vtp_osc8_no_sep
    cmp byte [osc_buf + rcx], ';'
    je .vtp_osc8_uri_at
    inc ecx
    jmp .vtp_osc8_find_sep
.vtp_osc8_no_sep:
    ; No semicolon: malformed, treat as end-of-link
    mov byte [cur_osc8_id], 0
    jmp .vtp_loop
.vtp_osc8_uri_at:
    inc ecx                     ; ecx = offset of first URI byte
    mov rdx, [osc_pos]
    sub rdx, rcx                ; URI length
    test rdx, rdx
    jz .vtp_osc8_close
    ; Allocate next link id (1..255). Wrap when full.
    mov rax, [osc8_count]
    inc rax
    cmp rax, 255
    jbe .vtp_osc8_id_ok
    mov rax, 1
    mov qword [osc8_uris_pos], 0
.vtp_osc8_id_ok:
    mov [osc8_count], rax
    mov byte [cur_osc8_id], al
    ; Cap URI length at 511 to keep things sane.
    cmp rdx, 511
    jle .vtp_osc8_uri_len_ok
    mov rdx, 511
.vtp_osc8_uri_len_ok:
    ; Bail if remaining osc8_uris space is insufficient (need rdx + 1 bytes)
    mov r8, [osc8_uris_pos]
    mov r9, r8
    add r9, rdx
    inc r9
    cmp r9, 4096
    jle .vtp_osc8_uri_room
    mov byte [cur_osc8_id], 0    ; out of room, drop
    jmp .vtp_loop
.vtp_osc8_uri_room:
    ; offsets[id] = current pos
    mov [osc8_uri_offsets + rax*4], r8d
    ; Copy URI bytes from osc_buf+rcx (length rdx) into osc8_uris+r8
    xor r10d, r10d
.vtp_osc8_uri_cp:
    cmp r10, rdx
    jge .vtp_osc8_uri_done
    movzx r11d, byte [osc_buf + rcx + r10]
    mov [osc8_uris + r8 + r10], r11b
    inc r10
    jmp .vtp_osc8_uri_cp
.vtp_osc8_uri_done:
    mov byte [osc8_uris + r8 + rdx], 0
    inc rdx
    add [osc8_uris_pos], rdx
    jmp .vtp_loop
.vtp_osc8_close:
    mov byte [cur_osc8_id], 0
    jmp .vtp_loop

.vtp_osc_set_title:
    ; Set X11 window title via ChangeProperty WM_NAME
    mov rcx, [osc_pos]
    test rcx, rcx
    jz .vtp_loop             ; empty title, skip
    push r14
    push r13
    push r12
    mov r13, rcx             ; title length
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_PROPERTY
    mov byte [rdi+1], 0      ; mode = Replace
    ; length = (6 + (title_len + 3) / 4) words
    mov eax, r13d
    add eax, 3
    shr eax, 2
    add eax, 6
    mov word [rdi+2], ax
    mov eax, [win_id]
    mov [rdi+4], eax
    mov dword [rdi+8], 39    ; WM_NAME atom
    mov dword [rdi+12], 31   ; STRING type
    mov byte [rdi+16], 8     ; format
    mov byte [rdi+17], 0
    mov word [rdi+18], 0
    mov [rdi+20], r13d       ; data length
    ; Copy title text
    xor ecx, ecx
.vtp_osc_cp_title:
    cmp ecx, r13d
    jge .vtp_osc_send_title
    movzx eax, byte [osc_buf + rcx]
    mov [tmp_buf + 24 + rcx], al
    inc ecx
    jmp .vtp_osc_cp_title
.vtp_osc_send_title:
    mov eax, r13d
    add eax, 3
    and eax, ~3
    add eax, 24
    mov rdx, rax
    lea rsi, [tmp_buf]
    call x11_buffer
    inc dword [x11_seq]
    pop r12
    pop r13
    pop r14
    jmp .vtp_loop

.vtp_full_reset:
    call grid_clear
    mov qword [cursor_row], 0
    mov qword [cursor_col], 0
    mov byte [cur_fg_default], 1
    mov byte [cur_bg_default], 1
    mov dword [cur_fg_pixel], 0
    mov dword [cur_bg_pixel], 0
    mov byte [cur_attrs], 0
    mov byte [cur_osc8_id], 0           ; clear stale hyperlink span
    ; Reset DECSET modes
    mov qword [cursor_visible], 1
    mov qword [autowrap], 1
    mov qword [cursor_style], 0
    mov qword [mouse_tracking], 0
    mov qword [mouse_sgr], 0
    mov qword [bracketed_paste], 0
    ; If on alt screen, switch back to main
    cmp qword [alt_screen_active], 0
    je .vtp_full_reset_done
    ; Restore main screen from alt_grid. Bound the copy to the current
    ; grid_rows × grid_cols using rep movsq instead of the previous
    ; byte-by-byte walk over the full 800KB slab.
    push rdi
    push rsi
    push rcx
    push r12
    push r13
    xor r12, r12                     ; row index
    mov r13, [grid_rows]
.vtp_fr_row:
    cmp r12, r13
    jge .vtp_fr_restore_done
    mov rax, r12
    imul rax, MAX_COLS * CELL_SIZE
    lea rsi, [alt_grid + rax]
    lea rdi, [grid + rax]
    mov rcx, [grid_cols]
    shl rcx, 1                       ; qwords per row (cells * 2)
    rep movsq
    inc r12
    jmp .vtp_fr_row
.vtp_fr_restore_done:
    pop r13
    pop r12
    pop rcx
    pop rsi
    pop rdi
    mov rax, [alt_cursor_row]
    mov [cursor_row], rax
    mov rax, [alt_cursor_col]
    mov [cursor_col], rax
    mov qword [alt_screen_active], 0
.vtp_full_reset_done:
    jmp .vtp_loop

.vtp_csi:
    ; Build parameters
    cmp al, '?'
    je .vtp_csi_private
    cmp al, '>'
    je .vtp_csi_private_gt
    cmp al, '<'
    je .vtp_csi_private_lt
    cmp al, '='
    je .vtp_csi_private_eq
    cmp al, '0'
    jb .vtp_csi_final
    cmp al, '9'
    ja .vtp_csi_sep
    ; Digit: build param value, capped at 65535 so a hostile app
    ; sending CSI 999999999999m can't wrap into a negative/garbage
    ; value that downstream cursor / SGR / scroll handlers then act on.
    mov qword [vt_state], VT_CSI_PARAM
    mov rcx, [vt_param_count]
    mov edx, [vt_params + rcx*4]
    cmp edx, 65535
    ja .vtp_csi_loop_skip            ; already saturated, ignore further digits
    imul edx, 10
    movzx ebx, al
    sub ebx, '0'
    add edx, ebx
    cmp edx, 65535
    jbe .vtp_csi_store
    mov edx, 65535
.vtp_csi_store:
    mov [vt_params + rcx*4], edx
.vtp_csi_loop_skip:
    jmp .vtp_loop

.vtp_csi_sep:
    cmp al, ';'
    je .vtp_csi_next_param
    ; ':' is the ITU-T sub-parameter separator (e.g. CC's \e[4:3m for
    ; curly underline, \e[38:2:R:G:Bm for truecolor). Most terminals
    ; just split on it like ';'. Without this, params after ':' get
    ; lost and the trailing 'm' falls through to .vtp_csi_final → the
    ; intended SGR (e.g. \e[24m to clear underline encoded as \e[4:0m)
    ; never fires, leaving everything underlined.
    cmp al, ':'
    jne .vtp_csi_final
.vtp_csi_next_param:
    inc qword [vt_param_count]
    mov rcx, [vt_param_count]
    cmp rcx, 15
    jge .vtp_loop
    mov dword [vt_params + rcx*4], 0
    jmp .vtp_loop

.vtp_csi_private:
    mov byte [vt_private], '?'
    jmp .vtp_loop
.vtp_csi_private_gt:
    mov byte [vt_private], '>'
    jmp .vtp_loop
.vtp_csi_private_lt:
    mov byte [vt_private], '<'
    jmp .vtp_loop
.vtp_csi_private_eq:
    mov byte [vt_private], '='
    jmp .vtp_loop

.vtp_csi_final:
    ; Final character = dispatch
    mov qword [vt_state], VT_NORMAL
    ; If we have params being built, count the last one
    mov rcx, [vt_param_count]
    inc rcx
    mov [vt_param_count], rcx

    ; Private-prefix sequences with '>', '<', or '=' are xterm/kitty
    ; extensions glass doesn't implement (modifyOtherKeys, kitty
    ; keyboard protocol, etc.). Without this guard, e.g. CC's
    ; \e[>1u (kitty keyboard set) would dispatch as 'u' = restore
    ; cursor → cursor lands at whatever was last DECSC'd, completely
    ; out of place. '?' private (DEC modes) DOES dispatch (h/l for
    ; ?25h, ?2004h, etc.) — those handlers themselves still need to
    ; check vt_private to distinguish DEC modes from standard ones.
    movzx ecx, byte [vt_private]
    test ecx, ecx
    jz .vtp_csi_dispatch_open
    cmp ecx, '?'
    jne .vtp_loop
.vtp_csi_dispatch_open:
    cmp al, 'A'
    je .vtp_csi_cuu
    cmp al, 'B'
    je .vtp_csi_cud
    cmp al, 'C'
    je .vtp_csi_cuf
    cmp al, 'D'
    je .vtp_csi_cub
    cmp al, 'H'
    je .vtp_csi_cup
    cmp al, 'f'
    je .vtp_csi_cup
    cmp al, 'J'
    je .vtp_csi_ed
    cmp al, 'K'
    je .vtp_csi_el
    cmp al, 'm'
    je .vtp_csi_sgr
    cmp al, 'G'
    je .vtp_csi_cha
    cmp al, 'd'
    je .vtp_csi_vpa
    cmp al, 'S'
    je .vtp_csi_su
    cmp al, 'T'
    je .vtp_csi_sd
    cmp al, 's'
    je .vtp_csi_save_cursor
    cmp al, 'u'
    je .vtp_csi_restore_cursor
    cmp al, 'P'
    je .vtp_csi_dch
    cmp al, '@'
    je .vtp_csi_ich
    cmp al, 'L'
    je .vtp_csi_il
    cmp al, 'M'
    je .vtp_csi_dl
    cmp al, 'X'
    je .vtp_csi_ech
    cmp al, 'r'
    je .vtp_csi_decstbm
    cmp al, 'h'
    je .vtp_csi_set_mode
    cmp al, 'l'
    je .vtp_csi_reset_mode
    cmp al, ' '
    je .vtp_csi_space       ; intermediate byte for CSI Ps SP q
    ; Check for 'q' with space intermediate (cursor style)
    cmp al, 'q'
    je .vtp_csi_check_q
    jmp .vtp_loop

; CSI SP: intermediate byte; stay in CSI state for next char
.vtp_csi_space:
    mov byte [vt_private], ' '
    mov qword [vt_state], VT_CSI_PARAM
    jmp .vtp_loop

; CSI q: check if preceded by space (cursor style)
.vtp_csi_check_q:
    cmp byte [vt_private], ' '
    jne .vtp_loop           ; not SP q, ignore
    ; CSI Ps SP q - Set cursor style
    mov eax, [vt_params]
    cmp eax, 2
    jle .vtp_cs_block
    cmp eax, 4
    jle .vtp_cs_underline
    cmp eax, 6
    jle .vtp_cs_bar
    jmp .vtp_loop
.vtp_cs_block:
    mov qword [cursor_style], 0
    jmp .vtp_loop
.vtp_cs_underline:
    mov qword [cursor_style], 1
    jmp .vtp_loop
.vtp_cs_bar:
    mov qword [cursor_style], 2
    jmp .vtp_loop

; CSI ? N h - DECSET (set mode)
.vtp_csi_set_mode:
    cmp byte [vt_private], '?'
    jne .vtp_loop               ; non-DEC modes: ignore
    mov eax, [vt_params]
    cmp eax, 1049
    je .vtp_alt_screen_on
    cmp eax, 25
    je .vtp_cursor_show
    cmp eax, 7
    je .vtp_autowrap_on
    cmp eax, 1000
    je .vtp_mouse_normal_on
    cmp eax, 1002
    je .vtp_mouse_button_on
    cmp eax, 1003
    je .vtp_mouse_any_on
    cmp eax, 1006
    je .vtp_mouse_sgr_on
    cmp eax, 2004
    je .vtp_bracketed_paste_on
    jmp .vtp_loop

; CSI ? N l - DECRST (reset mode)
.vtp_csi_reset_mode:
    cmp byte [vt_private], '?'
    jne .vtp_loop
    mov eax, [vt_params]
    cmp eax, 1049
    je .vtp_alt_screen_off
    cmp eax, 25
    je .vtp_cursor_hide
    cmp eax, 7
    je .vtp_autowrap_off
    cmp eax, 1000
    je .vtp_mouse_off
    cmp eax, 1002
    je .vtp_mouse_off
    cmp eax, 1003
    je .vtp_mouse_off
    cmp eax, 1006
    je .vtp_mouse_sgr_off
    cmp eax, 2004
    je .vtp_bracketed_paste_off
    jmp .vtp_loop

; DECSET/DECRST handlers
.vtp_alt_screen_on:
    cmp qword [alt_screen_active], 1
    je .vtp_loop                ; already on alt screen
    ; Save cursor position
    mov rax, [cursor_row]
    mov [alt_cursor_row], rax
    mov rax, [cursor_col]
    mov [alt_cursor_col], rax
    ; Save main grid to alt_grid: only the active grid_rows × grid_cols
    ; cells, copied a row at a time via rep movsq.
    push rdi
    push rsi
    push rcx
    push r12
    push r13
    xor r12, r12
    mov r13, [grid_rows]
.vtp_alt_save_row:
    cmp r12, r13
    jge .vtp_alt_save_done
    mov rax, r12
    imul rax, MAX_COLS * CELL_SIZE
    lea rsi, [grid + rax]
    lea rdi, [alt_grid + rax]
    mov rcx, [grid_cols]
    shl rcx, 1
    rep movsq
    inc r12
    jmp .vtp_alt_save_row
.vtp_alt_save_done:
    pop r13
    pop r12
    pop rcx
    pop rsi
    pop rdi
    ; Clear the grid for alt screen use. Also drop any in-progress
    ; hyperlink + colour span from the main screen so the alt-screen
    ; app starts with a clean attribute baseline.
    call grid_clear
    mov qword [cursor_row], 0
    mov qword [cursor_col], 0
    mov byte [cur_attrs], 0
    mov byte [cur_osc8_id], 0
    mov byte [cur_fg_default], 1
    mov byte [cur_bg_default], 1
    mov qword [alt_screen_active], 1
    mov qword [all_dirty], 1               ; force full redraw post-clear
    jmp .vtp_loop

.vtp_alt_screen_off:
    cmp qword [alt_screen_active], 0
    je .vtp_loop                ; already on main screen
    ; Drop any kitty-graphics placements from the alt screen so they
    ; don't bleed onto the restored main screen (e.g. pointer leaving
    ; an image visible after exit).
    call place_clear_all
    ; Restore main grid from alt_grid: only the active dims.
    push rdi
    push rsi
    push rcx
    push r12
    push r13
    xor r12, r12
    mov r13, [grid_rows]
.vtp_alt_restore_row:
    cmp r12, r13
    jge .vtp_alt_restore_done
    mov rax, r12
    imul rax, MAX_COLS * CELL_SIZE
    lea rsi, [alt_grid + rax]
    lea rdi, [grid + rax]
    mov rcx, [grid_cols]
    shl rcx, 1
    rep movsq
    inc r12
    jmp .vtp_alt_restore_row
.vtp_alt_restore_done:
    pop r13
    pop r12
    pop rcx
    pop rsi
    pop rdi
    ; Restore cursor position
    mov rax, [alt_cursor_row]
    mov [cursor_row], rax
    mov rax, [alt_cursor_col]
    mov [cursor_col], rax
    mov qword [alt_screen_active], 0
    ; Reset scroll region, modes, and attributes
    mov qword [scroll_top], 0
    mov qword [scroll_bottom], 0
    mov qword [cursor_visible], 1
    mov qword [mouse_tracking], 0
    mov qword [mouse_sgr], 0
    mov qword [bracketed_paste], 0
    mov byte [cur_fg_default], 1
    mov byte [cur_bg_default], 1
    mov dword [cur_fg_pixel], 0
    mov dword [cur_bg_pixel], 0
    mov byte [cur_attrs], 0
    ; Clear any in-progress OSC 8 hyperlink span. A long-lived terminal
    ; can otherwise inherit a stale cur_osc8_id from the previous app
    ; (vim, CC, etc. that opened a link and never sent the
    ; \e]8;;\e\\ close), causing every subsequently written cell to
    ; render with a hyperlink underline.
    mov byte [cur_osc8_id], 0
    mov qword [cursor_style], 0
    ; Force a full redraw — without this, glass's per-row dirty tracker
    ; sees the restored cells as "the same" as what was just on screen
    ; (because we copied alt_grid → grid wholesale rather than via the
    ; usual write-cell-and-mark-row-dirty path), so the alt-screen
    ; pixels stay visible until the user types something that updates
    ; a row. all_dirty=1 makes the next render_screen repaint
    ; everything.
    mov qword [all_dirty], 1
    jmp .vtp_loop

.vtp_cursor_show:
    mov qword [cursor_visible], 1
    jmp .vtp_loop

.vtp_cursor_hide:
    mov qword [cursor_visible], 0
    jmp .vtp_loop

.vtp_autowrap_on:
    mov qword [autowrap], 1
    jmp .vtp_loop

.vtp_autowrap_off:
    mov qword [autowrap], 0
    jmp .vtp_loop

.vtp_mouse_normal_on:
    mov qword [mouse_tracking], 1
    jmp .vtp_loop

.vtp_mouse_button_on:
    mov qword [mouse_tracking], 2
    jmp .vtp_loop

.vtp_mouse_any_on:
    mov qword [mouse_tracking], 3
    jmp .vtp_loop

.vtp_mouse_off:
    mov qword [mouse_tracking], 0
    mov qword [mouse_sgr], 0
    jmp .vtp_loop

.vtp_mouse_sgr_on:
    mov qword [mouse_sgr], 1
    jmp .vtp_loop

.vtp_mouse_sgr_off:
    mov qword [mouse_sgr], 0
    jmp .vtp_loop

.vtp_bracketed_paste_on:
    mov qword [bracketed_paste], 1
    jmp .vtp_loop

.vtp_bracketed_paste_off:
    mov qword [bracketed_paste], 0
    jmp .vtp_loop

; CSI A - Cursor Up
.vtp_csi_cuu:
    mov byte [pending_wrap], 0
    mov eax, [vt_params]
    test eax, eax
    jnz .vtp_cuu_go
    mov eax, 1
.vtp_cuu_go:
    mov rcx, [cursor_row]
    sub rcx, rax
    test rcx, rcx
    jns .vtp_cuu_ok
    xor ecx, ecx
.vtp_cuu_ok:
    mov [cursor_row], rcx
    jmp .vtp_loop

; CSI B - Cursor Down
.vtp_csi_cud:
    mov byte [pending_wrap], 0
    mov eax, [vt_params]
    test eax, eax
    jnz .vtp_cud_go
    mov eax, 1
.vtp_cud_go:
    mov rcx, [cursor_row]
    add rcx, rax
    mov rdx, [grid_rows]
    dec rdx
    cmp rcx, rdx
    jle .vtp_cud_ok
    mov rcx, rdx
.vtp_cud_ok:
    mov [cursor_row], rcx
    jmp .vtp_loop

; CSI C - Cursor Forward
.vtp_csi_cuf:
    mov byte [pending_wrap], 0
    mov eax, [vt_params]
    test eax, eax
    jnz .vtp_cuf_go
    mov eax, 1
.vtp_cuf_go:
    mov rcx, [cursor_col]
    add rcx, rax
    mov rdx, [grid_cols]
    dec rdx
    cmp rcx, rdx
    jle .vtp_cuf_ok
    mov rcx, rdx
.vtp_cuf_ok:
    mov [cursor_col], rcx
    jmp .vtp_loop

; CSI D - Cursor Backward
.vtp_csi_cub:
    mov byte [pending_wrap], 0
    mov eax, [vt_params]
    test eax, eax
    jnz .vtp_cub_go
    mov eax, 1
.vtp_cub_go:
    mov rcx, [cursor_col]
    sub rcx, rax
    test rcx, rcx
    jns .vtp_cub_ok
    xor ecx, ecx
.vtp_cub_ok:
    mov [cursor_col], rcx
    jmp .vtp_loop

; CSI H - Cursor Position
; Hostile apps can send \x1b[999999;999999H. Clamp BEFORE storing so a
; malformed sequence can never write a huge cursor coord that
; grid_put_char would translate into an OOB grid offset.
.vtp_csi_cup:
    mov byte [pending_wrap], 0
    mov eax, [vt_params]     ; row (1-based)
    test eax, eax
    jnz .vtp_cup_row
    mov eax, 1
.vtp_cup_row:
    dec eax                  ; 0-based; eax always zero-extends to rax
    mov rcx, [grid_rows]
    test rcx, rcx
    jz .vtp_cup_col_init     ; grid not sized yet
    dec rcx
    cmp rax, rcx
    jbe .vtp_cup_row_ok      ; unsigned compare catches both huge and wrapped
    mov rax, rcx
.vtp_cup_row_ok:
    mov [cursor_row], rax
.vtp_cup_col_init:
    mov eax, [vt_params + 4] ; col (1-based)
    test eax, eax
    jnz .vtp_cup_c
    mov eax, 1
.vtp_cup_c:
    dec eax
    mov rcx, [grid_cols]
    test rcx, rcx
    jz .vtp_loop
    dec rcx
    cmp rax, rcx
    jbe .vtp_cup_col_ok
    mov rax, rcx
.vtp_cup_col_ok:
    mov [cursor_col], rax
    jmp .vtp_loop

; CSI J - Erase in Display
.vtp_csi_ed:
    mov eax, [vt_params]
    cmp eax, 2
    je .vtp_ed_all
    cmp eax, 1
    je .vtp_loop            ; TODO: erase above
    ; Default: erase below
    call grid_clear_below
    jmp .vtp_loop
.vtp_ed_all:
    call grid_clear
    jmp .vtp_loop

; CSI K - Erase in Line
.vtp_csi_el:
    mov eax, [vt_params]
    cmp eax, 2
    je .vtp_el_all
    cmp eax, 1
    je .vtp_loop            ; TODO: erase left
    ; Default: erase to right
    call grid_clear_right
    jmp .vtp_loop
.vtp_el_all:
    call grid_clear_line
    jmp .vtp_loop

; CSI G - Cursor Horizontal Absolute (clamp first; see CUP note above)
.vtp_csi_cha:
    mov byte [pending_wrap], 0
    mov eax, [vt_params]
    test eax, eax
    jnz .vtp_cha_go
    mov eax, 1
.vtp_cha_go:
    dec eax
    mov rcx, [grid_cols]
    test rcx, rcx
    jz .vtp_loop
    dec rcx
    cmp rax, rcx
    jbe .vtp_cha_ok
    mov rax, rcx
.vtp_cha_ok:
    mov [cursor_col], rax
    jmp .vtp_loop

; CSI d - Line Position Absolute (clamp first; see CUP note above)
.vtp_csi_vpa:
    mov byte [pending_wrap], 0
    mov eax, [vt_params]
    test eax, eax
    jnz .vtp_vpa_go
    mov eax, 1
.vtp_vpa_go:
    dec eax
    mov rcx, [grid_rows]
    test rcx, rcx
    jz .vtp_loop
    dec rcx
    cmp rax, rcx
    jbe .vtp_vpa_ok
    mov rax, rcx
.vtp_vpa_ok:
    mov [cursor_row], rax
    jmp .vtp_loop

; CSI S - Scroll Up (within active scroll region)
.vtp_csi_su:
    mov eax, [vt_params]
    test eax, eax
    jnz .vtp_su_go
    mov eax, 1
.vtp_su_go:
    mov ecx, eax
.vtp_su_loop:
    test ecx, ecx
    jz .vtp_loop
    push rcx
    call grid_scroll_region_up
    pop rcx
    dec ecx
    jmp .vtp_su_loop

; CSI T - Scroll Down
.vtp_csi_sd:
    mov eax, [vt_params]
    test eax, eax
    jnz .vtp_sd_go
    mov eax, 1
.vtp_sd_go:
    mov ecx, eax
.vtp_sd_loop:
    test ecx, ecx
    jz .vtp_loop
    push rcx
    call grid_scroll_down
    pop rcx
    dec ecx
    jmp .vtp_sd_loop

; CSI s - Save Cursor Position
.vtp_csi_save_cursor:
    mov byte [pending_wrap], 0
    mov rax, [cursor_row]
    mov [cursor_saved_row], rax
    mov rax, [cursor_col]
    mov [cursor_saved_col], rax
    jmp .vtp_loop

; CSI u - Restore Cursor Position
.vtp_csi_restore_cursor:
    mov byte [pending_wrap], 0
    mov rax, [cursor_saved_row]
    mov [cursor_row], rax
    mov rax, [cursor_saved_col]
    mov [cursor_col], rax
    jmp .vtp_loop

; CSI P - Delete Characters
.vtp_csi_dch:
    mov eax, [vt_params]
    test eax, eax
    jnz .vtp_dch_go
    mov eax, 1
.vtp_dch_go:
    ; Shift cells left from cursor_col+n to end of line
    push rbx
    mov ecx, eax              ; count to delete
    mov rbx, [cursor_row]
    imul rbx, MAX_COLS
    mov rax, [cursor_col]
.vtp_dch_shift:
    mov rdx, rax
    add rdx, rcx
    cmp rdx, [grid_cols]
    jge .vtp_dch_clear
    ; Copy cell at col+n to col (16 bytes)
    mov rdx, rbx
    add rdx, rax
    add rdx, rcx
    imul rdx, CELL_SIZE
    mov r8, [grid + rdx]
    mov r9, [grid + rdx + 8]
    mov rdx, rbx
    add rdx, rax
    imul rdx, CELL_SIZE
    mov [grid + rdx], r8
    mov [grid + rdx + 8], r9
    inc rax
    jmp .vtp_dch_shift
.vtp_dch_clear:
    ; Clear remaining cells
    cmp rax, [grid_cols]
    jge .vtp_dch_done
    mov rdx, rbx
    add rdx, rax
    imul rdx, CELL_SIZE
    mov qword [grid + rdx], DEFAULT_CELL_LO
    mov qword [grid + rdx + 8], 0
    inc rax
    jmp .vtp_dch_clear
.vtp_dch_done:
    pop rbx
    jmp .vtp_loop

; CSI r - Set Scrolling Region (DECSTBM)
.vtp_csi_decstbm:
    mov byte [pending_wrap], 0
    mov eax, [vt_params]
    test eax, eax
    jnz .vtp_stbm_top
    mov eax, 1
.vtp_stbm_top:
    dec eax                  ; 0-based
    mov [scroll_top], rax
    cmp qword [vt_param_count], 2
    jl .vtp_stbm_default_bot
    mov eax, [vt_params + 4]
    test eax, eax
    jnz .vtp_stbm_bot
.vtp_stbm_default_bot:
    mov rax, [grid_rows]
.vtp_stbm_bot:
    dec eax                  ; 0-based
    mov [scroll_bottom], rax
    ; Move cursor to home
    mov qword [cursor_row], 0
    mov qword [cursor_col], 0
    jmp .vtp_loop

; CSI @ - Insert Characters (ICH)
.vtp_csi_ich:
    mov eax, [vt_params]
    test eax, eax
    jnz .vtp_ich_go
    mov eax, 1
.vtp_ich_go:
    push rbx
    mov ecx, eax              ; count to insert
    mov rbx, [cursor_row]
    imul rbx, MAX_COLS
    ; Shift cells right from end of line
    mov rax, [grid_cols]
    dec rax
.vtp_ich_shift:
    mov rdx, rax
    sub rdx, rcx
    cmp rdx, [cursor_col]
    jl .vtp_ich_clear
    ; Copy cell at col-n to col (16 bytes)
    mov rdx, rbx
    add rdx, rax
    sub rdx, rcx
    imul rdx, CELL_SIZE
    mov r8, [grid + rdx]
    mov r9, [grid + rdx + 8]
    mov rdx, rbx
    add rdx, rax
    imul rdx, CELL_SIZE
    mov [grid + rdx], r8
    mov [grid + rdx + 8], r9
    dec rax
    jmp .vtp_ich_shift
.vtp_ich_clear:
    ; Clear inserted cells
    mov rax, [cursor_col]
    mov rdx, rax
    add rdx, rcx
.vtp_ich_clear_loop:
    cmp rax, rdx
    jge .vtp_ich_done
    cmp rax, [grid_cols]
    jge .vtp_ich_done
    push rdx
    mov rdx, rbx
    add rdx, rax
    imul rdx, CELL_SIZE
    mov qword [grid + rdx], DEFAULT_CELL_LO
    mov qword [grid + rdx + 8], 0
    pop rdx
    inc rax
    jmp .vtp_ich_clear_loop
.vtp_ich_done:
    pop rbx
    jmp .vtp_loop

; CSI L - Insert Lines (IL)
.vtp_csi_il:
    mov eax, [vt_params]
    test eax, eax
    jnz .vtp_il_go
    mov eax, 1
.vtp_il_go:
    push rbx
    push r12
    mov ecx, eax              ; count
    mov r12, [scroll_bottom]
    test r12, r12
    jnz .vtp_il_have_bot
    mov r12, [grid_rows]
    dec r12
.vtp_il_have_bot:
    ; Shift rows down from scroll_bottom to cursor_row+count
    mov rax, r12
.vtp_il_shift:
    mov rdx, rax
    sub rdx, rcx
    cmp rdx, [cursor_row]
    jl .vtp_il_clear
    ; Copy row rdx to row rax
    push rcx
    push rax
    mov rsi, rdx
    imul rsi, MAX_COLS
    imul rsi, CELL_SIZE
    lea rsi, [grid + rsi]
    mov rdi, rax
    imul rdi, MAX_COLS
    imul rdi, CELL_SIZE
    lea rdi, [grid + rdi]
    mov rcx, MAX_COLS
.vtp_il_cp:
    mov r8, [rsi]
    mov [rdi], r8
    mov r8, [rsi + 8]
    mov [rdi + 8], r8
    add rsi, CELL_SIZE
    add rdi, CELL_SIZE
    dec rcx
    jnz .vtp_il_cp
    pop rax
    pop rcx
    dec rax
    jmp .vtp_il_shift
.vtp_il_clear:
    ; Clear inserted rows at cursor_row
    mov rax, [cursor_row]
    mov rdx, rax
    add rdx, rcx
.vtp_il_clear_loop:
    cmp rax, rdx
    jge .vtp_il_done
    cmp rax, r12
    jg .vtp_il_done
    push rdx
    mov rbx, rax
    imul rbx, MAX_COLS
    xor edx, edx
.vtp_il_clear_row:
    cmp rdx, [grid_cols]
    jge .vtp_il_clear_next
    mov rdi, rbx
    add rdi, rdx
    imul rdi, CELL_SIZE
    mov qword [grid + rdi], DEFAULT_CELL_LO
    mov qword [grid + rdi + 8], 0
    inc rdx
    jmp .vtp_il_clear_row
.vtp_il_clear_next:
    pop rdx
    inc rax
    jmp .vtp_il_clear_loop
.vtp_il_done:
    pop r12
    pop rbx
    jmp .vtp_loop

; CSI M - Delete Lines (DL)
.vtp_csi_dl:
    mov eax, [vt_params]
    test eax, eax
    jnz .vtp_dl_go
    mov eax, 1
.vtp_dl_go:
    push rbx
    push r12
    mov ecx, eax              ; count
    mov r12, [scroll_bottom]
    test r12, r12
    jnz .vtp_dl_have_bot
    mov r12, [grid_rows]
    dec r12
.vtp_dl_have_bot:
    ; Shift rows up from cursor_row+count to scroll_bottom
    mov rax, [cursor_row]
.vtp_dl_shift:
    mov rdx, rax
    add rdx, rcx
    cmp rdx, r12
    jg .vtp_dl_clear
    ; Copy row rax+count to row rax
    push rcx
    push rax
    mov rsi, rdx
    imul rsi, MAX_COLS
    imul rsi, CELL_SIZE
    lea rsi, [grid + rsi]
    mov rdi, rax
    imul rdi, MAX_COLS
    imul rdi, CELL_SIZE
    lea rdi, [grid + rdi]
    mov rcx, MAX_COLS
.vtp_dl_cp:
    mov r8, [rsi]
    mov [rdi], r8
    mov r8, [rsi + 8]
    mov [rdi + 8], r8
    add rsi, CELL_SIZE
    add rdi, CELL_SIZE
    dec rcx
    jnz .vtp_dl_cp
    pop rax
    pop rcx
    inc rax
    jmp .vtp_dl_shift
.vtp_dl_clear:
    ; Clear bottom rows
    mov rax, r12
    sub rax, rcx
    inc rax
    cmp rax, [cursor_row]
    jge .vtp_dl_clear_start
    mov rax, [cursor_row]
.vtp_dl_clear_start:
.vtp_dl_clear_loop:
    cmp rax, r12
    jg .vtp_dl_done
    push rax
    mov rbx, rax
    imul rbx, MAX_COLS
    xor edx, edx
.vtp_dl_clear_row:
    cmp rdx, [grid_cols]
    jge .vtp_dl_clear_rnext
    mov rdi, rbx
    add rdi, rdx
    imul rdi, CELL_SIZE
    mov qword [grid + rdi], DEFAULT_CELL_LO
    mov qword [grid + rdi + 8], 0
    inc rdx
    jmp .vtp_dl_clear_row
.vtp_dl_clear_rnext:
    pop rax
    inc rax
    jmp .vtp_dl_clear_loop
.vtp_dl_done:
    pop r12
    pop rbx
    jmp .vtp_loop

; CSI X - Erase Characters (ECH)
.vtp_csi_ech:
    mov eax, [vt_params]
    test eax, eax
    jnz .vtp_ech_go
    mov eax, 1
.vtp_ech_go:
    push rbx
    mov ecx, eax
    mov rbx, [cursor_row]
    imul rbx, MAX_COLS
    mov rax, [cursor_col]
.vtp_ech_loop:
    test ecx, ecx
    jz .vtp_ech_done
    cmp rax, [grid_cols]
    jge .vtp_ech_done
    mov rdx, rbx
    add rdx, rax
    imul rdx, CELL_SIZE
    mov qword [grid + rdx], DEFAULT_CELL_LO
    mov qword [grid + rdx + 8], 0
    inc rax
    dec ecx
    jmp .vtp_ech_loop
.vtp_ech_done:
    pop rbx
    jmp .vtp_loop

; CSI m - Select Graphic Rendition (SGR)
.vtp_csi_sgr:
    ; A leading private prefix changes 'm' from SGR to something else
    ; entirely. The classic case is `\e[>4m` (xterm modifyOtherKeys),
    ; which CC and other modern apps send to enable extended keyboard
    ; encoding. Without this guard, glass treats `>4m` as SGR 4 →
    ; underline ON, with no matching clear, leaving the entire screen
    ; underlined for the rest of the session.
    cmp byte [vt_private], 0
    jne .vtp_loop
    xor ebx, ebx            ; param index
.vtp_sgr_loop:
    cmp rbx, [vt_param_count]
    jge .vtp_loop
    mov eax, [vt_params + rbx*4]

    ; Process SGR parameter
    test eax, eax
    jz .vtp_sgr_reset
    cmp eax, 1
    je .vtp_sgr_bold
    cmp eax, 4
    je .vtp_sgr_underline
    cmp eax, 7
    je .vtp_sgr_inverse
    cmp eax, 22
    je .vtp_sgr_no_bold
    cmp eax, 24
    je .vtp_sgr_no_underline
    cmp eax, 27
    je .vtp_sgr_no_inverse
    cmp eax, 39
    je .vtp_sgr_default_fg
    cmp eax, 49
    je .vtp_sgr_default_bg

    ; 30-37: foreground colors
    cmp eax, 30
    jl .vtp_sgr_check_bg
    cmp eax, 37
    jg .vtp_sgr_check_bg
    sub eax, 30
    mov ecx, [palette + rax*4]
    mov [cur_fg_pixel], ecx
    mov byte [cur_fg_default], 0
    jmp .vtp_sgr_next

    ; 40-47: background colors
.vtp_sgr_check_bg:
    cmp eax, 40
    jl .vtp_sgr_check_bright_fg
    cmp eax, 47
    jg .vtp_sgr_check_bright_fg
    sub eax, 40
    mov ecx, [palette + rax*4]
    mov [cur_bg_pixel], ecx
    mov byte [cur_bg_default], 0
    jmp .vtp_sgr_next

    ; 90-97: bright foreground
.vtp_sgr_check_bright_fg:
    cmp eax, 90
    jl .vtp_sgr_check_bright_bg
    cmp eax, 97
    jg .vtp_sgr_check_bright_bg
    sub eax, 82              ; 90-82 = 8
    mov ecx, [palette + rax*4]
    mov [cur_fg_pixel], ecx
    mov byte [cur_fg_default], 0
    jmp .vtp_sgr_next

    ; 100-107: bright background
.vtp_sgr_check_bright_bg:
    cmp eax, 100
    jl .vtp_sgr_check_256
    cmp eax, 107
    jg .vtp_sgr_check_256
    sub eax, 92
    mov ecx, [palette + rax*4]
    mov [cur_bg_pixel], ecx
    mov byte [cur_bg_default], 0
    jmp .vtp_sgr_next

    ; 38;5;N or 48;5;N: 256-color
.vtp_sgr_check_256:
    cmp eax, 38
    je .vtp_sgr_fg256
    cmp eax, 48
    je .vtp_sgr_bg256
    jmp .vtp_sgr_next

.vtp_sgr_fg256:
    ; Next param: 5 = 256-color, 2 = truecolor
    inc rbx
    cmp rbx, [vt_param_count]
    jge .vtp_loop
    cmp dword [vt_params + rbx*4], 5
    je .vtp_sgr_fg256_idx
    cmp dword [vt_params + rbx*4], 2
    je .vtp_sgr_fg_true
    jmp .vtp_sgr_next
.vtp_sgr_fg256_idx:
    inc rbx
    cmp rbx, [vt_param_count]
    jge .vtp_loop
    mov eax, [vt_params + rbx*4]
    and eax, 0xFF                       ; clamp 0..255
    mov ecx, [palette + rax*4]
    mov [cur_fg_pixel], ecx
    mov byte [cur_fg_default], 0
    jmp .vtp_sgr_next
.vtp_sgr_fg_true:
    ; 38;2;R;G;B - store the explicit RGB pixel directly. The
    ; TrueColor visual interprets the 32-bit pixel as 0xAARRGGBB,
    ; so we set alpha=0xFF and pack the components as-is.
    inc rbx
    cmp rbx, [vt_param_count]
    jge .vtp_loop
    mov ecx, [vt_params + rbx*4]   ; R
    and ecx, 0xFF
    inc rbx
    cmp rbx, [vt_param_count]
    jge .vtp_loop
    mov edx, [vt_params + rbx*4]   ; G
    and edx, 0xFF
    inc rbx
    cmp rbx, [vt_param_count]
    jge .vtp_loop
    mov esi, [vt_params + rbx*4]   ; B
    and esi, 0xFF
    shl ecx, 16
    shl edx, 8
    or ecx, edx
    or ecx, esi
    or ecx, 0xFF000000
    mov [cur_fg_pixel], ecx
    mov byte [cur_fg_default], 0
    jmp .vtp_sgr_next

.vtp_sgr_bg256:
    ; Next param: 5 = 256-color, 2 = truecolor
    inc rbx
    cmp rbx, [vt_param_count]
    jge .vtp_loop
    cmp dword [vt_params + rbx*4], 5
    je .vtp_sgr_bg256_idx
    cmp dword [vt_params + rbx*4], 2
    je .vtp_sgr_bg_true
    jmp .vtp_sgr_next
.vtp_sgr_bg256_idx:
    inc rbx
    cmp rbx, [vt_param_count]
    jge .vtp_loop
    mov eax, [vt_params + rbx*4]
    and eax, 0xFF
    mov ecx, [palette + rax*4]
    mov [cur_bg_pixel], ecx
    mov byte [cur_bg_default], 0
    jmp .vtp_sgr_next
.vtp_sgr_bg_true:
    ; 48;2;R;G;B - store the explicit RGB pixel directly.
    inc rbx
    cmp rbx, [vt_param_count]
    jge .vtp_loop
    mov ecx, [vt_params + rbx*4]   ; R
    and ecx, 0xFF
    inc rbx
    cmp rbx, [vt_param_count]
    jge .vtp_loop
    mov edx, [vt_params + rbx*4]   ; G
    and edx, 0xFF
    inc rbx
    cmp rbx, [vt_param_count]
    jge .vtp_loop
    mov esi, [vt_params + rbx*4]   ; B
    and esi, 0xFF
    shl ecx, 16
    shl edx, 8
    or ecx, edx
    or ecx, esi
    or ecx, 0xFF000000
    mov [cur_bg_pixel], ecx
    mov byte [cur_bg_default], 0
    jmp .vtp_sgr_next

.vtp_sgr_reset:
    mov byte [cur_fg_default], 1
    mov byte [cur_bg_default], 1
    mov dword [cur_fg_pixel], 0
    mov dword [cur_bg_pixel], 0
    mov byte [cur_attrs], 0
    jmp .vtp_sgr_next
.vtp_sgr_bold:
    or byte [cur_attrs], 1
    jmp .vtp_sgr_next
.vtp_sgr_underline:
    or byte [cur_attrs], 2
    jmp .vtp_sgr_next
.vtp_sgr_inverse:
    or byte [cur_attrs], 4
    jmp .vtp_sgr_next
.vtp_sgr_no_bold:
    and byte [cur_attrs], ~1
    jmp .vtp_sgr_next
.vtp_sgr_no_underline:
    and byte [cur_attrs], ~2
    jmp .vtp_sgr_next
.vtp_sgr_no_inverse:
    and byte [cur_attrs], ~4
    jmp .vtp_sgr_next
.vtp_sgr_default_fg:
    mov byte [cur_fg_default], 1
    mov dword [cur_fg_pixel], 0
    jmp .vtp_sgr_next
.vtp_sgr_default_bg:
    mov byte [cur_bg_default], 1
    mov dword [cur_bg_pixel], 0
    jmp .vtp_sgr_next

.vtp_sgr_next:
    inc rbx
    jmp .vtp_sgr_loop

.vtp_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Grid operations
; ══════════════════════════════════════════════════════════════════════

; Put character at cursor position
; ax = UCS-2 character (16-bit)
grid_put_char:
    ; Substitute a few BMP glyphs that the default xos4-terminus and
    ; misc-fixed bitmap fonts don't ship — when a glyph is missing, the
    ; X server falls back to the font's "default character" which is
    ; usually a literal '?'. The pairs below pick the closest visually
    ; equivalent glyph that IS present in terminus.
    cmp ax, 0x25B3
    jne .gpc_subst_25BD
    mov ax, 0x25B2                   ; △ (outline) → ▲ (filled)
    jmp .gpc_subst_done
.gpc_subst_25BD:
    cmp ax, 0x25BD
    jne .gpc_subst_done
    mov ax, 0x25BC                   ; ▽ (outline) → ▼ (filled)
.gpc_subst_done:
    push rbx
    ; Honor any pending deferred wrap from the previous char written at
    ; the last column, but only if autowrap is still enabled. Apps like
    ; htop disable autowrap (DECRST 7), write the bottom-right cell to
    ; fill the corner, then re-enable autowrap; if we wrap during that
    ; write the bottom-right char lands on the wrong row and the whole
    ; layout drifts on every refresh.
    cmp byte [pending_wrap], 0
    je .gpc_no_pending
    cmp qword [autowrap], 0
    je .gpc_drop_pending
    mov byte [pending_wrap], 0
    mov rbx, [cursor_row]
    mov byte [row_wrapped + rbx], 1
    mov qword [cursor_col], 0
    inc rbx
    cmp rbx, [grid_rows]
    jl .gpc_pw_row_ok
    push rax
    call grid_scroll_up
    pop rax
    mov rbx, [grid_rows]
    dec rbx
.gpc_pw_row_ok:
    mov [cursor_row], rbx
    jmp .gpc_no_pending
.gpc_drop_pending:
    ; Autowrap was disabled while a wrap was queued: drop the queue and
    ; let this char overwrite the cell at the current (last-col) cursor.
    mov byte [pending_wrap], 0
.gpc_no_pending:
    mov rbx, [cursor_row]
    imul rbx, MAX_COLS
    add rbx, [cursor_col]
    imul rbx, CELL_SIZE
    mov [grid + rbx], ax             ; [0-1] char (16-bit)
    movzx ecx, byte [cur_fg_default]
    mov [grid + rbx + 2], cl         ; [2] fg default flag
    movzx ecx, byte [cur_bg_default]
    mov [grid + rbx + 3], cl         ; [3] bg default flag
    movzx ecx, byte [cur_attrs]
    mov [grid + rbx + 4], cl         ; [4] attrs
    movzx ecx, byte [cur_osc8_id]
    mov [grid + rbx + 5], cl         ; [5] OSC 8 link id
    ; [6-7]: emoji cache index when ATTR_IS_EMOJI (0x08) is set in
    ; cur_attrs, otherwise zero. The render path uses this to compose
    ; the cached emoji Picture onto the cell.
    test byte [cur_attrs], 8
    jz .gpc_no_emoji
    movzx ecx, word [cur_emoji_index]
    mov [grid + rbx + 6], cx
    jmp .gpc_after_emoji
.gpc_no_emoji:
    mov word [grid + rbx + 6], 0
.gpc_after_emoji:
    mov ecx, [cur_fg_pixel]
    mov [grid + rbx + 8], ecx        ; [8-11] fg pixel
    mov ecx, [cur_bg_pixel]
    mov [grid + rbx + 12], ecx       ; [12-15] bg pixel

    ; Advance cursor
    mov rax, [cursor_col]
    inc rax
    cmp rax, [grid_cols]
    jl .gpc_ok
    ; Reached past the last column.
    cmp qword [autowrap], 0
    je .gpc_clamp             ; no wrap: stay at last column
    ; Defer the wrap: leave cursor at last col, set pending_wrap. The
    ; next printable char performs the actual advance; CR/LF/cursor
    ; positioning between now and then clears the flag and the wrap
    ; is silently dropped, which is exactly what apps expect when they
    ; pad to grid_cols and then send [K\r\n.
    mov rax, [grid_cols]
    dec rax
    mov [cursor_col], rax
    mov byte [pending_wrap], 1
    pop rbx
    ret
.gpc_clamp:
    ; Stay at last column
    mov rax, [grid_cols]
    dec rax
    mov [cursor_col], rax
    pop rbx
    ret
.gpc_ok:
    mov [cursor_col], rax
    pop rbx
    ret

; Clear entire grid.
grid_clear:
    push rbx
    push r12
    xor rbx, rbx
    mov r12, MAX_COLS * MAX_ROWS
.gc_loop:
    cmp rbx, r12
    jge .gc_done
    mov rax, rbx
    imul rax, CELL_SIZE
    mov qword [grid + rax], DEFAULT_CELL_LO
    mov qword [grid + rax + 8], 0
    inc rbx
    jmp .gc_loop
.gc_done:
    ; Reset wrap flags for all rows
    xor rbx, rbx
.gc_wrap_reset:
    cmp rbx, MAX_ROWS
    jge .gc_wrap_done
    mov byte [row_wrapped + rbx], 0
    inc rbx
    jmp .gc_wrap_reset
.gc_wrap_done:
    pop r12
    pop rbx
    ret

; Clear from cursor to end of screen
grid_clear_below:
    push rbx
    push r12
    mov rbx, [cursor_row]
    imul rbx, MAX_COLS
    add rbx, [cursor_col]
    mov r12, [grid_rows]
    imul r12, MAX_COLS
.gcb_loop:
    cmp rbx, r12
    jge .gcb_done
    mov rax, rbx
    imul rax, CELL_SIZE
    mov qword [grid + rax], DEFAULT_CELL_LO
    mov qword [grid + rax + 8], 0
    inc rbx
    jmp .gcb_loop
.gcb_done:
    pop r12
    pop rbx
    ret

; Clear from cursor to end of line
; Erase from cursor to end of line, filling cleared cells with the
; CURRENT SGR attributes (Background Color Erase / BCE — default xterm
; behavior). Apps like htop rely on this to extend an inverse-video
; header/footer bar to the right edge of the screen by setting SGR 7
; then sending [K, instead of writing N spaces.
grid_clear_right:
    push rbx
    push r12
    push r13
    mov rbx, [cursor_col]
    mov r12, [cursor_row]
    imul r12, MAX_COLS
    ; Pre-pack the cell low qword with current attrs/flags/space.
    ; Layout: [0]=' ', [1]=0, [2]=fg_default, [3]=bg_default, [4]=attrs,
    ;         [5]=0 (osc8), [6]=0, [7]=0
    movzx eax, byte [cur_fg_default]
    shl eax, 16
    movzx edx, byte [cur_bg_default]
    shl edx, 24
    or eax, edx
    movzx edx, byte [cur_attrs]
    shl rdx, 32
    or rax, rdx
    or rax, 0x20                      ; space char
    mov r13, rax                      ; cell_lo template
    ; Pack pixel hi qword: [8-11]=fg_pixel, [12-15]=bg_pixel
    mov eax, [cur_bg_pixel]
    shl rax, 32
    mov edx, [cur_fg_pixel]
    or rax, rdx
    push rax                          ; save cell_hi for the loop
.gcr_loop:
    cmp rbx, [grid_cols]
    jge .gcr_done
    mov rax, r12
    add rax, rbx
    imul rax, CELL_SIZE
    mov [grid + rax], r13             ; lo qword (char + flags + attrs)
    mov rdx, [rsp]                    ; hi qword (pixels)
    mov [grid + rax + 8], rdx
    inc rbx
    jmp .gcr_loop
.gcr_done:
    pop rax                           ; discard cell_hi
    pop r13
    pop r12
    pop rbx
    ret

; Clear entire current line
grid_clear_line:
    push rbx
    mov rcx, [cursor_row]
    imul rcx, MAX_COLS
    xor rbx, rbx
.gcl_loop:
    cmp rbx, [grid_cols]
    jge .gcl_done
    mov rax, rcx
    add rax, rbx
    imul rax, CELL_SIZE
    mov qword [grid + rax], DEFAULT_CELL_LO
    mov qword [grid + rax + 8], 0
    inc rbx
    jmp .gcl_loop
.gcl_done:
    ; Clearing a line breaks any wrap that ended on it.
    mov rax, [cursor_row]
    mov byte [row_wrapped + rax], 0
    test rax, rax
    jz .gcl_no_prev
    dec rax
    mov byte [row_wrapped + rax], 0
.gcl_no_prev:
    pop rbx
    ret

; Scroll grid up by one line (saves top row to scrollback)
; Scroll up within scroll region (scroll_top..scroll_bottom)
grid_scroll_region_up:
    push rbx
    push r12
    push r13
    mov r12, [scroll_top]
    mov r13, [scroll_bottom]
    test r13, r13
    jnz .gsru_have_region
    ; No scroll region set, use full grid
    jmp grid_scroll_up.gsu_entry
.gsru_have_region:
    ; Move rows scroll_top+1..scroll_bottom to scroll_top..scroll_bottom-1
    mov rbx, r12
    imul rbx, MAX_COLS
.gsru_loop:
    mov rax, r12
    cmp rax, r13
    jge .gsru_clear
    mov rax, rbx
    add rax, MAX_COLS
    imul rax, CELL_SIZE
    mov rcx, rbx
    imul rcx, CELL_SIZE
    ; Copy one row
    push rbx
    xor edx, edx
.gsru_cp:
    cmp rdx, MAX_COLS
    jge .gsru_cp_done
    mov r8, [grid + rax]
    mov [grid + rcx], r8
    mov r8, [grid + rax + 8]
    mov [grid + rcx + 8], r8
    add rax, CELL_SIZE
    add rcx, CELL_SIZE
    inc rdx
    jmp .gsru_cp
.gsru_cp_done:
    pop rbx
    add rbx, MAX_COLS
    inc r12
    jmp .gsru_loop
.gsru_clear:
    ; Clear the bottom row of the scroll region
    mov rbx, r13
    imul rbx, MAX_COLS
    xor edx, edx
.gsru_cl:
    cmp rdx, [grid_cols]
    jge .gsru_done
    mov rax, rbx
    add rax, rdx
    imul rax, CELL_SIZE
    mov qword [grid + rax], DEFAULT_CELL_LO
    mov qword [grid + rax + 8], 0
    inc rdx
    jmp .gsru_cl
.gsru_done:
    pop r13
    pop r12
    pop rbx
    ret

grid_scroll_up:
    push rbx
    push r12
    push r13
.gsu_entry:

    ; Save top row to scrollback circular buffer before scrolling
    mov rax, [scroll_write_pos]
    imul r13, rax, MAX_COLS * CELL_SIZE  ; byte offset in scroll_buf
    ; Copy grid row 0 to scroll_buf[write_pos]
    xor ecx, ecx
    mov rdx, [grid_cols]
.gsu_save:
    cmp rcx, rdx
    jge .gsu_save_done
    mov rax, rcx
    imul rax, CELL_SIZE
    mov rbx, rcx
    imul rbx, CELL_SIZE         ; scale 16 isn't a valid LEA factor
    add rbx, r13
    mov r8, [grid + rax]
    mov [scroll_buf + rbx], r8
    mov r8, [grid + rax + 8]
    mov [scroll_buf + rbx + 8], r8
    inc rcx
    jmp .gsu_save
.gsu_save_done:
    ; Fill remaining cols with spaces (if grid_cols < MAX_COLS)
    mov rdx, [grid_cols]
.gsu_save_pad:
    cmp rdx, MAX_COLS
    jge .gsu_save_advance
    mov rbx, rdx
    imul rbx, CELL_SIZE
    add rbx, r13
    mov qword [scroll_buf + rbx], DEFAULT_CELL_LO
    mov qword [scroll_buf + rbx + 8], 0
    inc rdx
    jmp .gsu_save_pad
.gsu_save_advance:
    ; Advance write position (circular, wraps at 1000)
    mov rax, [scroll_write_pos]
    inc rax
    cmp rax, 1000
    jl .gsu_no_wrap
    xor eax, eax
.gsu_no_wrap:
    mov [scroll_write_pos], rax
    ; Track total lines (cap at 1000)
    mov rax, [scroll_lines]
    cmp rax, 1000
    jge .gsu_lines_ok
    inc rax
    mov [scroll_lines], rax
.gsu_lines_ok:
    ; If user was scrolled back, adjust offset to keep view stable
    mov rax, [scroll_offset]
    test rax, rax
    jz .gsu_do_scroll
    inc rax
    ; Cap at scroll_lines
    mov rcx, [scroll_lines]
    cmp rax, rcx
    jle .gsu_offset_ok
    mov rax, rcx
.gsu_offset_ok:
    mov [scroll_offset], rax

.gsu_do_scroll:
    pop r13

    ; Move rows 1..N-1 to 0..N-2
    xor rbx, rbx
    mov r12, [grid_rows]
    dec r12
    imul r12, MAX_COLS
.gsu_loop:
    cmp rbx, r12
    jge .gsu_clear_last
    mov rax, rbx
    add rax, MAX_COLS
    imul rax, CELL_SIZE
    mov rcx, rbx
    imul rcx, CELL_SIZE
    ; Copy one cell (16 bytes)
    mov rdx, [grid + rax]
    mov [grid + rcx], rdx
    mov rdx, [grid + rax + 8]
    mov [grid + rcx + 8], rdx
    inc rbx
    jmp .gsu_loop
.gsu_clear_last:
    ; Clear last row
    mov rbx, [grid_rows]
    dec rbx
    imul rbx, MAX_COLS
    mov r12, rbx
    add r12, [grid_cols]
.gsu_clear:
    cmp rbx, r12
    jge .gsu_clear_done
    mov rax, rbx
    imul rax, CELL_SIZE
    mov qword [grid + rax], DEFAULT_CELL_LO
    mov qword [grid + rax + 8], 0
    inc rbx
    jmp .gsu_clear
.gsu_clear_done:
    ; Shift wrap flags up: row_wrapped[i] = row_wrapped[i+1]
    xor rbx, rbx
    mov r12, [grid_rows]
    dec r12
.gsu_wrap_shift:
    cmp rbx, r12
    jge .gsu_wrap_done
    movzx eax, byte [row_wrapped + rbx + 1]
    mov [row_wrapped + rbx], al
    inc rbx
    jmp .gsu_wrap_shift
.gsu_wrap_done:
    mov byte [row_wrapped + r12], 0
.gsu_done:
    pop r12
    pop rbx
    ret

; Scroll one line DOWN within the active scroll region. If no region
; is set (scroll_bottom == 0), scrolls the entire grid down. Used by
; Reverse Index (ESC M) when the cursor is at scroll_top — htop relies
; on this to insert a row in its narrowed process-list region without
; touching the header rows above.
grid_scroll_region_down:
    push rbx
    push r12
    push r13
    mov r12, [scroll_top]
    mov r13, [scroll_bottom]
    test r13, r13
    jnz .gsrd_have_region
    ; No region: full-grid scroll
    xor r12, r12
    mov r13, [grid_rows]
    dec r13
.gsrd_have_region:
    ; Move rows scroll_top..scroll_bottom-1 DOWN by 1 (work bottom-up)
    mov rbx, r13
    dec rbx                     ; rbx = scroll_bottom - 1 (source row)
.gsrd_loop:
    cmp rbx, r12
    jl .gsrd_clear_top
    ; Copy row rbx to row rbx+1
    mov rax, rbx
    imul rax, MAX_COLS
    imul rax, CELL_SIZE
    mov rcx, rbx
    inc rcx
    imul rcx, MAX_COLS
    imul rcx, CELL_SIZE
    mov rdx, MAX_COLS
.gsrd_cp:
    test rdx, rdx
    jz .gsrd_cp_done
    mov rdi, [grid + rax]
    mov [grid + rcx], rdi
    mov rdi, [grid + rax + 8]
    mov [grid + rcx + 8], rdi
    add rax, CELL_SIZE
    add rcx, CELL_SIZE
    dec rdx
    jmp .gsrd_cp
.gsrd_cp_done:
    dec rbx
    jmp .gsrd_loop
.gsrd_clear_top:
    ; Clear scroll_top row
    mov rax, r12
    imul rax, MAX_COLS
    imul rax, CELL_SIZE
    xor rdx, rdx
.gsrd_clear:
    cmp rdx, [grid_cols]
    jge .gsrd_done
    mov qword [grid + rax], DEFAULT_CELL_LO
    mov qword [grid + rax + 8], 0
    add rax, CELL_SIZE
    inc rdx
    jmp .gsrd_clear
.gsrd_done:
    pop r13
    pop r12
    pop rbx
    ret

; Old full-grid scroll-down kept for callers that want it explicitly
; (CSI T). Both ultimately go through grid_scroll_region_down now.
grid_scroll_down:
    jmp grid_scroll_region_down

; Scroll view backward (into scrollback history)
scroll_view_up:
    push rbx
    mov rax, [scroll_offset]
    mov rbx, [grid_rows]
    shr rbx, 1                       ; scroll by half a screen
    cmp rbx, 1
    jge .svu_ok
    mov rbx, 1
.svu_ok:
    add rax, rbx
    ; Cap at scroll_lines
    mov rcx, [scroll_lines]
    cmp rax, rcx
    jle .svu_set
    mov rax, rcx
.svu_set:
    mov [scroll_offset], rax
    call render_screen
    call x11_flush
    pop rbx
    ret

; Scroll view forward (toward live terminal)
scroll_view_down:
    push rbx
    mov rax, [scroll_offset]
    test rax, rax
    jz .svd_done                     ; already at live view
    mov rbx, [grid_rows]
    shr rbx, 1
    cmp rbx, 1
    jge .svd_ok
    mov rbx, 1
.svd_ok:
    sub rax, rbx
    test rax, rax
    jns .svd_set
    xor eax, eax
.svd_set:
    mov [scroll_offset], rax
    call render_screen
    call x11_flush
.svd_done:
    pop rbx
    ret

; Returns AL=1 if (r12=row, rbx=col) is in current selection range.
; Preserves all registers except rax.
is_cell_selected:
    push rcx
    push rdx
    push rsi
    push rdi
    cmp qword [sel_active], 0
    je .ics_no
    ; Normalize start/end so (start_row, start_col) <= (end_row, end_col)
    mov rcx, [sel_start_row]
    mov rdx, [sel_start_col]
    mov rsi, [sel_end_row]
    mov rdi, [sel_end_col]
    cmp rcx, rsi
    jl .ics_normalized
    jg .ics_swap
    cmp rdx, rdi
    jle .ics_normalized
.ics_swap:
    xchg rcx, rsi
    xchg rdx, rdi
.ics_normalized:
    ; rcx=start_row, rdx=start_col, rsi=end_row, rdi=end_col
    ; Check (r12, rbx) >= (start_row, start_col)
    cmp r12, rcx
    jl .ics_no
    jg .ics_check_end
    cmp rbx, rdx
    jl .ics_no
.ics_check_end:
    ; Check (r12, rbx) <= (end_row, end_col)
    cmp r12, rsi
    jg .ics_no
    jl .ics_yes
    cmp rbx, rdi
    jg .ics_no
.ics_yes:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    mov al, 1
    ret
.ics_no:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    xor al, al
    ret

; Extract selected text from grid into sel_buf
; Walks from sel_start to sel_end, extracting characters
selection_extract:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Normalize selection: ensure start <= end
    mov rax, [sel_start_row]
    mov rcx, [sel_end_row]
    cmp rax, rcx
    jl .se_order_ok
    jg .se_swap
    ; Same row: check columns
    mov rax, [sel_start_col]
    cmp rax, [sel_end_col]
    jle .se_order_ok
.se_swap:
    ; Swap start and end
    mov rax, [sel_start_row]
    mov rcx, [sel_end_row]
    mov [sel_start_row], rcx
    mov [sel_end_row], rax
    mov rax, [sel_start_col]
    mov rcx, [sel_end_col]
    mov [sel_start_col], rcx
    mov [sel_end_col], rax
.se_order_ok:

    xor r15d, r15d              ; output index in sel_buf
    mov r12, [sel_start_row]    ; current row

.se_row_loop:
    cmp r12, [sel_end_row]
    jg .se_done

    ; Determine col range for this row
    xor r13d, r13d              ; start col
    cmp r12, [sel_start_row]
    jne .se_col_start_ok
    mov r13, [sel_start_col]
.se_col_start_ok:
    mov r14, [grid_cols]        ; end col (exclusive)
    cmp r12, [sel_end_row]
    jne .se_col_end_ok
    mov r14, [sel_end_col]
    inc r14                     ; inclusive end
    cmp r14, [grid_cols]
    jle .se_col_end_ok
    mov r14, [grid_cols]
.se_col_end_ok:

    ; Extract characters for this row
.se_col_loop:
    cmp r13, r14
    jge .se_row_end
    cmp r15, 16380
    jge .se_done                ; buffer limit

    ; Get cell character from grid (16-bit UCS-2, use low byte for ASCII)
    mov rax, r12
    imul rax, MAX_COLS
    add rax, r13
    imul rax, CELL_SIZE
    movzx eax, word [grid + rax]
    cmp eax, 0x7F
    jbe .se_ascii_char
    mov al, '?'              ; non-ASCII: placeholder in selection
.se_ascii_char:
    mov [sel_buf + r15], al
    inc r15
    inc r13
    jmp .se_col_loop

.se_row_end:
    ; Add newline at end of each row (except last).
    cmp r12, [sel_end_row]
    je .se_row_next
    ; If this row wrapped to the next, treat them as one logical
    ; line: no newline, no trailing-space trim. bare emits visible
    ; padding right up to grid_cols on wrap, so the space before
    ; the wrap is part of the content.
    movzx eax, byte [row_wrapped + r12]
    test eax, eax
    jnz .se_row_next
    ; Trim trailing spaces before adding newline
.se_trim:
    test r15d, r15d
    jz .se_add_nl
    cmp byte [sel_buf + r15 - 1], ' '
    jne .se_add_nl
    dec r15
    jmp .se_trim
.se_add_nl:
    cmp r15, 16380
    jge .se_done
    mov byte [sel_buf + r15], 10
    inc r15

.se_row_next:
    inc r12
    jmp .se_row_loop

.se_done:
    mov [sel_len], r15

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Multi-click helpers (word/line selection, monotonic clock)
; ══════════════════════════════════════════════════════════════════════

; click_now_ms: returns CLOCK_MONOTONIC milliseconds in rax
click_now_ms:
    mov rax, SYS_CLOCK_GETTIME
    mov edi, 1                    ; CLOCK_MONOTONIC
    lea rsi, [click_ts_buf]
    syscall
    mov rax, [click_ts_buf]       ; sec
    imul rax, 1000                ; → ms
    push rax
    mov rax, [click_ts_buf + 8]   ; nsec
    mov rcx, 1000000
    xor edx, edx
    div rcx                       ; rax = ms part of nsec
    mov rcx, rax
    pop rax
    add rax, rcx
    ret

; is_word_char_al: ZF=1 iff al is a word char (alnum + _-./~+@:%=)
; May clobber al on negative result (callers don't depend on al after).
is_word_char_al:
    cmp al, '0'
    jb .iwc_punct
    cmp al, '9'
    jbe .iwc_y
    cmp al, 'A'
    jb .iwc_punct
    cmp al, 'Z'
    jbe .iwc_y
    cmp al, 'a'
    jb .iwc_punct
    cmp al, 'z'
    jbe .iwc_y
.iwc_punct:
    cmp al, '_'
    je .iwc_y
    cmp al, '-'
    je .iwc_y
    cmp al, '.'
    je .iwc_y
    cmp al, '/'
    je .iwc_y
    cmp al, '~'
    je .iwc_y
    cmp al, '+'
    je .iwc_y
    cmp al, '@'
    je .iwc_y
    cmp al, ':'
    je .iwc_y
    cmp al, '%'
    je .iwc_y
    cmp al, '='
    je .iwc_y
    or al, 1                  ; ZF=0
    ret
.iwc_y:
    cmp al, al                ; ZF=1
    ret

; cell_char_at: rdi=row, rsi=col → al = ASCII char (or '?' for non-ASCII)
cell_char_at:
    mov rax, rdi
    imul rax, MAX_COLS
    add rax, rsi
    imul rax, CELL_SIZE
    movzx eax, word [grid + rax]
    cmp eax, 0x7F
    jbe .cca_done
    mov al, '?'
.cca_done:
    ret

; find_word_at: rdi=row, rsi=col → sets sel_start_col/sel_end_col on row
; sel_start_row and sel_end_row already = rdi
find_word_at:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi              ; row
    mov r13, rsi              ; col (anchor)
    ; Check if anchor cell is a word char
    mov rdi, r12
    mov rsi, r13
    call cell_char_at
    call is_word_char_al
    jne .fwa_single           ; not a word char: single-cell selection
    ; Scan left
    mov r14, r13              ; left = col
.fwa_left:
    test r14, r14
    jz .fwa_left_done
    dec r14
    mov rdi, r12
    mov rsi, r14
    call cell_char_at
    call is_word_char_al
    je .fwa_left
    inc r14                   ; back up to last word char
.fwa_left_done:
    mov [sel_start_col], r14
    ; Scan right
    mov rbx, r13              ; right = col
.fwa_right:
    mov rdi, [grid_cols]
    dec rdi
    cmp rbx, rdi
    jge .fwa_right_done
    inc rbx
    mov rdi, r12
    mov rsi, rbx
    call cell_char_at
    call is_word_char_al
    je .fwa_right
    dec rbx                   ; back up to last word char
.fwa_right_done:
    mov [sel_end_col], rbx
    jmp .fwa_done
.fwa_single:
    mov [sel_start_col], r13
    mov [sel_end_col], r13
.fwa_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; select_line_at: rdi=row → sel_*_row=rdi, sel_start_col=0, sel_end_col=last col
select_line_at:
    mov [sel_start_row], rdi
    mov [sel_end_row], rdi
    mov qword [sel_start_col], 0
    mov rax, [grid_cols]
    test rax, rax
    jz .sla_zero
    dec rax
.sla_zero:
    mov [sel_end_col], rax
    ret

; selection_claim_primary: SetSelectionOwner on PRIMARY (atom 1)
selection_claim_primary:
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_SET_SELECTION_OWNER
    mov byte [rdi+1], 0
    mov word [rdi+2], 4
    mov eax, [win_id]
    mov [rdi+4], eax
    mov dword [rdi+8], 1          ; XA_PRIMARY
    mov dword [rdi+12], 0         ; CurrentTime
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]
    call x11_flush
    ret

; selection_claim_clipboard: SetSelectionOwner on CLIPBOARD (interned).
; No-op if the clipboard atom didn't intern.
selection_claim_clipboard:
    cmp dword [clipboard_atom], 0
    je .scc_done
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_SET_SELECTION_OWNER
    mov byte [rdi+1], 0
    mov word [rdi+2], 4
    mov eax, [win_id]
    mov [rdi+4], eax
    mov eax, [clipboard_atom]
    mov [rdi+8], eax
    mov dword [rdi+12], 0
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]
    call x11_flush
.scc_done:
    ret

; b64_decode: rdi = src, rcx = src_len, rsi = dst.
; Returns rax = number of bytes written. Skips whitespace and '=' pad,
; ignores any other invalid character. No clobber of caller-saved regs
; beyond the standard ABI.
b64_decode:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r15, rcx                  ; src_len (rcx is reused for shift counts)
    xor r12, r12                  ; out position
    xor rbx, rbx                  ; in position
.b64d_loop:
    xor r13, r13                  ; 24-bit accumulator
    xor r14d, r14d                ; valid char count (0..4)
.b64d_chunk:
    cmp r14, 4
    jge .b64d_emit
    cmp rbx, r15
    jge .b64d_emit
    movzx eax, byte [rdi + rbx]
    inc rbx
    cmp al, 'A'
    jb .b64d_check_digit
    cmp al, 'Z'
    jbe .b64d_upper
    cmp al, 'a'
    jb .b64d_chunk
    cmp al, 'z'
    ja .b64d_chunk
    sub eax, 'a' - 26
    jmp .b64d_have
.b64d_upper:
    sub eax, 'A'
    jmp .b64d_have
.b64d_check_digit:
    cmp al, '0'
    jb .b64d_check_special
    cmp al, '9'
    ja .b64d_chunk
    sub eax, '0' - 52
    jmp .b64d_have
.b64d_check_special:
    cmp al, '+'
    jne .b64d_check_slash
    mov eax, 62
    jmp .b64d_have
.b64d_check_slash:
    cmp al, '/'
    jne .b64d_chunk
    mov eax, 63
.b64d_have:
    shl r13, 6
    or r13, rax
    inc r14
    jmp .b64d_chunk
.b64d_emit:
    cmp r14, 1
    jle .b64d_done
    cmp r14, 4
    je .b64d_full
    mov rax, 4
    sub rax, r14
    mov rcx, rax
    imul rcx, 6
    shl r13, cl
.b64d_full:
    mov rax, r13
    shr rax, 16
    mov [rsi + r12], al
    inc r12
    cmp r14, 2
    je .b64d_check_more
    mov rax, r13
    shr rax, 8
    mov [rsi + r12], al
    inc r12
    cmp r14, 3
    je .b64d_check_more
    mov rax, r13
    mov [rsi + r12], al
    inc r12
.b64d_check_more:
    cmp rbx, r15
    jl .b64d_loop
.b64d_done:
    mov rax, r12
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Screen rendering
; ══════════════════════════════════════════════════════════════════════

; Render entire screen to X11
render_screen:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; In pseudo-transparency mode, ImageText16's bg fill is replaced
    ; with PolyText16 for default-bg cells, so previous frame's text
    ; and the previous cursor block don't get painted over. Clear the
    ; whole window first to repaint the wallpaper-tinted BackPixmap;
    ; cells then redraw cleanly on top.
    cmp byte [pseudo_full], 1
    jne .rs_no_pseudo_clear
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CLEAR_AREA
    mov byte [rdi+1], 0
    mov word [rdi+2], 4
    mov eax, [win_id]
    mov [rdi+4], eax
    mov word [rdi+8], 0
    mov word [rdi+10], 0
    mov word [rdi+12], 0
    mov word [rdi+14], 0
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]
.rs_no_pseudo_clear:

    ; Check visual bell - if active, fill window with bell color first
    cmp qword [bell_flash_until], 0
    jz .rs_no_bell
    sub rsp, 16
    mov rax, SYS_CLOCK_GETTIME
    xor edi, edi
    mov rsi, rsp
    syscall
    mov rax, [rsp]
    imul rax, 1000000000
    add rax, [rsp + 8]
    add rsp, 16
    cmp rax, [bell_flash_until]
    jl .rs_bell_active
    mov qword [bell_flash_until], 0
    jmp .rs_no_bell
.rs_bell_active:
    ; Set GC fg to bright color for fill
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_GC
    mov byte [rdi+1], 0
    mov word [rdi+2], 4
    mov eax, [gc_id]
    mov [rdi+4], eax
    mov dword [rdi+8], GC_FOREGROUND
    mov eax, 0x00666666             ; medium gray flash
    cmp dword [x11_argb_colormap], 0
    je .rs_bell_no_alpha
    or eax, 0xFF000000
.rs_bell_no_alpha:
    mov [rdi+12], eax
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]
    ; PolyFillRectangle covering entire window
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_POLY_FILL_RECT
    mov byte [rdi+1], 0
    mov word [rdi+2], 5
    mov eax, [win_id]
    mov [rdi+4], eax
    mov eax, [gc_id]
    mov [rdi+8], eax
    mov word [rdi+12], 0
    mov word [rdi+14], 0
    mov eax, [win_width]
    mov word [rdi+16], ax
    mov eax, [win_height]
    mov word [rdi+18], ax
    lea rsi, [tmp_buf]
    mov rdx, 20
    call x11_buffer
    inc dword [x11_seq]
    jmp .rs_after_clear
.rs_no_bell:
    ; Skip ClearArea - cells fully cover the grid area via ImageText16
    ; backgrounds. ClearArea was causing flicker during selection drag.
.rs_after_clear:

    ; Draw each row with per-color-run rendering
    ; When scroll_offset > 0, top rows come from scrollback buffer
    xor r12, r12             ; display row
.rs_row:
    cmp r12, [grid_rows]
    jge .rs_after_rows

    ; Compute row base pointer accounting for scrollback
    mov rax, [scroll_offset]
    test rax, rax
    jz .rs_row_live

    ; Scrolled back: which source row?
    ; scroll_offset = N means show N lines of history above
    ; display_row < grid_rows is mapped to:
    ;   if display_row < scroll_offset: read from scrollback
    ;   else: read from grid row (display_row - scroll_offset)
    mov rax, [scroll_offset]
    cmp r12, rax
    jge .rs_row_grid_shifted

    ; This row comes from scrollback
    ; scrollback line index = scroll_lines - scroll_offset + display_row
    ; position in circular buffer = (write_pos - scroll_offset + display_row) mod 1000
    mov rax, [scroll_write_pos]
    sub rax, [scroll_offset]
    add rax, r12
    ; Make positive (mod 1000)
    test rax, rax
    jns .rs_sb_pos
    add rax, 1000
.rs_sb_pos:
    ; rax might still be >= 1000 if write_pos wrapped around
    cmp rax, 1000
    jl .rs_sb_ok
    sub rax, 1000
.rs_sb_ok:
    imul rax, MAX_COLS * CELL_SIZE
    lea rax, [scroll_buf + rax]
    mov [rs_row_base], rax
    jmp .rs_row_ready

.rs_row_grid_shifted:
    ; This row comes from grid, shifted
    mov rax, r12
    sub rax, [scroll_offset]
    imul rax, MAX_COLS
    imul rax, CELL_SIZE
    lea rax, [grid + rax]
    mov [rs_row_base], rax
    jmp .rs_row_ready

.rs_row_live:
    ; Normal (live view): row directly from grid
    mov rax, r12
    imul rax, MAX_COLS
    imul rax, CELL_SIZE
    lea rax, [grid + rax]
    mov [rs_row_base], rax

.rs_row_ready:
    ; r12 = display row, scan columns for color runs
    xor r13, r13             ; col = start of current run

.rs_run_start:
    cmp r13, [grid_cols]
    jge .rs_next_row

    ; Get effective fg/bg pixel of cell (apply inverse attr + selection).
    ; cell[2] bit 0 = use palette[7] for fg; otherwise cell[8-11] is the
    ; explicit 32-bit pixel. Same for bg via cell[3] / cell[12-15].
    mov rax, [rs_row_base]
    mov rdx, r13
    imul rdx, CELL_SIZE
    add rax, rdx
    mov r14d, [palette + 7*4]
    mov edx, [rax + 8]
    test byte [rax + 2], 1
    cmovz r14d, edx
    mov r15d, [palette]
    mov edx, [rax + 12]
    test byte [rax + 3], 1
    cmovz r15d, edx
    movzx edx, byte [rax + 4]   ; attrs (read before is_cell_selected
                                ; clobbers rax — cell pointer dies there)
    ; Capture this run's bold + underline bits (cell[4] bits 0/1).
    mov ecx, edx
    and ecx, 1
    mov [run_bold], cl
    mov ecx, edx
    shr ecx, 1
    and ecx, 1
    mov [run_underline], cl
    and edx, 4                  ; inverse bit
    ; XOR with selection state at (r12, r13)
    push rbx
    mov rbx, r13
    call is_cell_selected       ; al = 1 if selected
    pop rbx
    movzx eax, al
    shl eax, 2                  ; al<<2 maps 1->4
    xor edx, eax                ; toggle inverse
    jz .rs_no_inv_start
    xchg r14d, r15d             ; swap fg/bg for inverse
.rs_no_inv_start:

    ; Scan ahead for cells with same effective fg/bg, build CHAR2B text
    lea rdi, [tmp_buf + 20]  ; text buffer (2 bytes per char)
    mov rbx, r13             ; current col
    xor ecx, ecx             ; character count
.rs_run_scan:
    cmp rbx, [grid_cols]
    jge .rs_run_draw
    cmp ecx, 254             ; PolyText16 max m (255 = font-change marker)
    jge .rs_run_draw
    mov rax, [rs_row_base]
    mov rdx, rbx
    imul rdx, CELL_SIZE
    add rax, rdx
    ; Compute effective fg/bg pixel for this cell (with selection XOR)
    mov edx, [palette + 7*4]
    mov r10d, [rax + 8]
    test byte [rax + 2], 1
    cmovz edx, r10d
    mov esi, [palette]
    mov r10d, [rax + 12]
    test byte [rax + 3], 1
    cmovz esi, r10d
    movzx r10d, byte [rax + 4] ; attrs (use r10 to preserve rax)
    and r10d, 4                ; inverse bit
    push rax                   ; preserve cell base
    push rcx                   ; preserve char count
    push rdx
    push rsi
    push r10
    ; rbx is the col, r12 is the row
    call is_cell_selected      ; al = 1 if selected
    movzx r11d, al             ; use r11 to avoid clobbering ecx
    shl r11d, 2
    pop r10
    pop rsi
    pop rdx
    pop rcx                    ; restore char count
    pop rax                    ; restore cell base
    xor r10d, r11d             ; toggle inverse if selected
    test r10d, r10d
    jz .rs_no_inv_scan
    xchg edx, esi
.rs_no_inv_scan:
    ; Check if effective fg/bg matches current run
    cmp edx, r14d
    jne .rs_run_draw
    cmp esi, r15d
    jne .rs_run_draw
    ; Also break on bold/underline change so we can switch GC font and
    ; draw an underline rectangle that matches just this run.
    movzx edx, byte [rax + 4]
    mov esi, edx
    and esi, 1                       ; this cell's bold
    movzx r11d, byte [run_bold]
    cmp esi, r11d
    jne .rs_run_draw
    shr edx, 1
    and edx, 1                       ; this cell's underline
    movzx r11d, byte [run_underline]
    cmp edx, r11d
    jne .rs_run_draw
    ; Same color, add to run as CHAR2B (big-endian: byte1=high, byte2=low)
    movzx edx, word [rax]           ; UCS-2 char (little-endian)
    mov [rdi + rcx*2 + 1], dl       ; low byte (byte2)
    shr edx, 8
    mov [rdi + rcx*2], dl           ; high byte (byte1)
    inc ecx
    inc rbx
    jmp .rs_run_scan

.rs_run_draw:
    ; ecx = run length, r13 = start col, r14 = fg, r15 = bg
    test ecx, ecx
    jz .rs_next_row

    ; TTF path (XRender CompositeGlyphs32) bypasses the X core font /
    ; ImageText16 / PolyText16 wiring entirely. Falls back to the bitmap
    ; path if no font_path is configured (ttf_active = 0).
    cmp qword [ttf_active], 0
    jne .rs_run_ttf

    ; Pick desired font for this run (medium or bold). Only emit a
    ; ChangeGC font request when the GC's current font actually needs
    ; to change.
    cmp byte [run_bold], 0
    jne .rs_want_bold
    mov eax, [font_id]
    jmp .rs_have_font
.rs_want_bold:
    mov eax, [font_id_bold]
.rs_have_font:
    cmp eax, [gc_current_font]
    je .rs_after_font
    push rcx
    push rax
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_GC
    mov byte [rdi+1], 0
    mov word [rdi+2], 4              ; 3 + 1 value
    mov edx, [gc_id]
    mov [rdi+4], edx
    mov dword [rdi+8], GC_FONT
    mov [rdi+12], eax
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]
    pop rax
    mov [gc_current_font], eax
    pop rcx
.rs_after_font:

    ; ChangeGC fg/bg (r14d/r15d already hold resolved 32-bit pixels).
    push rcx
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_GC
    mov byte [rdi+1], 0
    mov word [rdi+2], 5
    mov eax, [gc_id]
    mov [rdi+4], eax
    mov dword [rdi+8], GC_FOREGROUND | GC_BACKGROUND
    mov [rdi+12], r14d
    mov [rdi+16], r15d
    lea rsi, [tmp_buf]
    mov rdx, 20
    call x11_buffer
    inc dword [x11_seq]
    pop rcx

    ; If pseudo-transparency is active and this run's effective bg pixel
    ; equals palette[0] (the see-through default), draw text without
    ; filling so the wallpaper-tinted BackPixmap shows through.
    cmp byte [pseudo_full], 1
    jne .rs_imagetext
    mov eax, [palette]
    cmp r15d, eax
    jne .rs_imagetext
    jmp .rs_polytext

.rs_imagetext:
    ; ImageText16 (text + bg fill)
    push rcx
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_IMAGE_TEXT16
    mov byte [rdi+1], cl     ; string length (CHAR2B count)
    ; request length = (16 + 2*n + 3) / 4
    mov eax, ecx
    shl eax, 1               ; 2*n bytes of text
    add eax, 16
    add eax, 3
    shr eax, 2
    mov word [rdi+2], ax
    mov eax, [win_id]
    mov [rdi+4], eax
    mov eax, [gc_id]
    mov [rdi+8], eax
    ; x = start_col * char_width
    mov rax, r13
    movzx edx, word [char_width]
    imul eax, edx
    mov word [rdi+12], ax
    ; y = row * char_height + font_ascent
    movzx eax, word [char_height]
    imul eax, r12d
    movzx edx, word [font_ascent]
    add eax, edx
    mov word [rdi+14], ax
    ; Copy CHAR2B text from tmp_buf+20 to tmp_buf+16 (2*n bytes)
    pop rcx
    push rcx
    mov eax, ecx
    shl eax, 1               ; 2*n bytes to copy
    xor edx, edx
.rs_cp_run:
    cmp edx, eax
    jge .rs_send_run
    movzx esi, byte [tmp_buf + 20 + rdx]
    mov [tmp_buf + 16 + rdx], sil
    inc edx
    jmp .rs_cp_run
.rs_send_run:
    pop rcx
    ; Send padded request: (16 + 2*n + 3) & ~3
    mov eax, ecx
    shl eax, 1
    add eax, 16
    add eax, 3
    and eax, ~3
    mov rdx, rax
    lea rsi, [tmp_buf]
    call x11_buffer
    inc dword [x11_seq]
    jmp .rs_after_text

.rs_polytext:
    ; PolyText16 (text only, no bg fill). One TEXTITEM16:
    ;   byte m, byte delta=0, then 2*m CHAR2B bytes.
    ; Body bytes after header = 2 + 2*m, padded to 4-byte boundary.
    push rcx
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_POLY_TEXT_16
    mov byte [rdi+1], 0
    ; request length = (16 + 2 + 2*m + 3) / 4
    mov eax, ecx
    shl eax, 1
    add eax, 16 + 2 + 3
    shr eax, 2
    mov word [rdi+2], ax
    mov eax, [win_id]
    mov [rdi+4], eax
    mov eax, [gc_id]
    mov [rdi+8], eax
    mov rax, r13
    movzx edx, word [char_width]
    imul eax, edx
    mov word [rdi+12], ax
    movzx eax, word [char_height]
    imul eax, r12d
    movzx edx, word [font_ascent]
    add eax, edx
    mov word [rdi+14], ax
    mov byte [rdi+16], cl    ; m
    mov byte [rdi+17], 0     ; delta
    ; Copy 2*m CHAR2B bytes from tmp_buf+20 to tmp_buf+18
    pop rcx
    push rcx
    mov eax, ecx
    shl eax, 1
    xor edx, edx
.rs_pt_cp:
    cmp edx, eax
    jge .rs_pt_send
    movzx esi, byte [tmp_buf + 20 + rdx]
    mov [tmp_buf + 18 + rdx], sil
    inc edx
    jmp .rs_pt_cp
.rs_pt_send:
    pop rcx
    mov eax, ecx
    shl eax, 1
    add eax, 16 + 2 + 3
    and eax, ~3
    mov rdx, rax
    lea rsi, [tmp_buf]
    call x11_buffer
    inc dword [x11_seq]

.rs_run_ttf:
    ; ttf_active path — paint bg as one PolyFillRectangle for the whole
    ; run, then emit ONE CompositeGlyphs32 with every cell in a single
    ; GLYPHELT (one X round-trip per run, matches kitty's batching).
    ; Per-cell calls flickered (visible bg-fill flash before the text
    ; arrived) and made scrollback paint visibly char-by-char on long
    ; lines.
    ;
    ; State on entry: ecx = run length, r12 = row, r13 = start col,
    ;                 r14 = fg pixel, r15 = bg pixel.
    ; State on exit (for .rs_after_text underline fill): ecx, r12, r13,
    ;                 r14 unchanged. GC fg restored to r14d so the
    ;                 underline draws in the correct colour.
    push rbx                              ; outer scan column
    push rcx                              ; run length

    ; Skip bg fill when pseudo-transparency is active and bg matches the
    ; default (palette[0]) — leaves the wallpaper-tinted BackPixmap
    ; visible behind the glyphs.
    cmp byte [pseudo_full], 1
    jne .rs_ttf_fill_bg
    mov eax, [palette]
    cmp r15d, eax
    je .rs_ttf_no_bg
.rs_ttf_fill_bg:
    ; ChangeGC fg = r15d (bg colour) for the fill.
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_GC
    mov byte [rdi+1], 0
    mov word [rdi+2], 4
    mov edx, [gc_id]
    mov [rdi+4], edx
    mov dword [rdi+8], GC_FOREGROUND
    mov [rdi+12], r15d
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]

    ; PolyFillRectangle: x = start_col*char_w, y = row*char_h,
    ; w = run_length*char_w, h = char_h.
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_POLY_FILL_RECT
    mov byte [rdi+1], 0
    mov word [rdi+2], 5                   ; 3 header + 2 (one rect)
    mov eax, [win_id]
    mov [rdi+4], eax
    mov eax, [gc_id]
    mov [rdi+8], eax
    movzx edx, word [char_width]
    mov rax, r13
    imul rax, rdx
    mov word [rdi+12], ax                 ; x
    movzx eax, word [char_height]
    imul eax, r12d
    mov word [rdi+14], ax                 ; y
    mov rax, [rsp]                        ; run length
    imul rax, rdx
    mov word [rdi+16], ax                 ; w
    movzx eax, word [char_height]
    mov word [rdi+18], ax                 ; h
    lea rsi, [tmp_buf]
    mov rdx, 20
    call x11_buffer
    inc dword [x11_seq]
.rs_ttf_no_bg:

    ; Restore GC fg to r14d (text colour) so the underline fill in
    ; .rs_after_text uses the right colour.
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_GC
    mov byte [rdi+1], 0
    mov word [rdi+2], 4
    mov edx, [gc_id]
    mov [rdi+4], edx
    mov dword [rdi+8], GC_FOREGROUND
    mov [rdi+12], r14d
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]

    ; --- Pre-upload every glyph in the run (idempotent per cp). ---
    ; Cells are read directly from the grid (rs_row_base + col*CELL_SIZE).
    ; Codepoint 0 (uninitialised cells) is substituted with 0x20 (space)
    ; — the run-scan above includes empty cells in same-colour runs, and
    ; glyph 0 was never AddGlyphs'd, so leaving it would produce stray
    ; "comma"-shaped artifacts where the X server falls back on whatever
    ; bytes happen to be in glyph slot 0.
    xor ebx, ebx
.rs_ttf_upload_loop:
    cmp rbx, [rsp]                        ; vs run length
    jge .rs_ttf_upload_done
    mov rax, [rs_row_base]
    mov rdx, r13
    add rdx, rbx
    imul rdx, CELL_SIZE
    movzx edi, word [rax + rdx]
    test edi, edi
    jnz .rs_ttf_upload_have_cp
    mov edi, 0x20
.rs_ttf_upload_have_cp:
    call ttf_upload_glyph
    inc rbx
    jmp .rs_ttf_upload_loop
.rs_ttf_upload_done:

    ; --- Set pen colour once for the whole run. ---
    mov edi, r14d
    or edi, 0xFF000000
    call ttf_set_pen_color

    ; --- Build one CompositeGlyphs32 with every cell in a single GLYPHELT. ---
    ; Layout:
    ;   28 bytes fixed header (op, src, dst, maskFmt, gset, srcXY)
    ;   8 bytes GLYPHELT header (count + dx + dy)
    ;   4*N bytes glyph IDs
    ; Length in 4-byte units = 7 (fixed) + 2 (elt header) + N = 9 + N.
    ;
    ; XRender protocol caps a GLYPHELT count at 252 (next byte ≥ 254 is
    ; reinterpreted as a sub-element marker). Cap our run-batch at 240
    ; for headroom; runs longer than that get truncated for now (rare on
    ; an 80-col terminal; full multi-elt support is a follow-up).
    mov rcx, [rsp]                        ; run length
    cmp rcx, 240
    jle .rs_ttf_have_n
    mov rcx, 240
.rs_ttf_have_n:
    ; rcx = N (cells in this batched element)

    lea rdi, [tmp_buf]
    mov al, [render_major]
    mov [rdi], al
    mov byte [rdi+1], RENDER_COMPOSITE_GLYPHS_32
    lea rax, [rcx + 9]                    ; length = 9 + N (dwords)
    mov [rdi+2], ax
    mov byte [rdi+4], RENDER_OP_OVER
    mov byte [rdi+5], 0
    mov word [rdi+6], 0
    mov eax, [ttf_pen_picture]
    mov [rdi+8], eax                      ; src
    mov eax, [render_window_picture]
    mov [rdi+12], eax                     ; dst
    mov eax, [render_format_a8]
    mov [rdi+16], eax                     ; maskFormat
    mov eax, [ttf_glyphset]
    mov [rdi+20], eax
    mov word [rdi+24], 0                  ; src x
    mov word [rdi+26], 0                  ; src y

    ; GLYPHELT header.
    mov [rdi+28], cl                      ; numGlyphs
    mov byte [rdi+29], 0
    mov word [rdi+30], 0
    ; dx = start_col * char_width  (initial pen x for the element)
    mov rax, r13
    movzx edx, word [char_width]
    imul rax, rdx
    mov [rdi+32], ax
    ; dy = row * char_height + font_ascent  (baseline)
    movzx eax, word [char_height]
    imul eax, r12d
    movzx edx, word [font_ascent]
    add eax, edx
    mov [rdi+34], ax

    ; Glyph IDs at offset 36..36+4*N. Each cell's UCS-2 codepoint IS the
    ; glyph id (we used cp as the gid in AddGlyphs). cp=0 → 0x20 to match
    ; the upload-loop substitution.
    xor ebx, ebx
.rs_ttf_id_loop:
    cmp rbx, rcx
    jge .rs_ttf_id_done
    mov rax, [rs_row_base]
    mov rdx, r13
    add rdx, rbx
    imul rdx, CELL_SIZE
    movzx eax, word [rax + rdx]
    test eax, eax
    jnz .rs_ttf_id_have_cp
    mov eax, 0x20
.rs_ttf_id_have_cp:
    mov rdx, rbx
    shl rdx, 2
    mov [rdi + rdx + 36], eax
    inc rbx
    jmp .rs_ttf_id_loop
.rs_ttf_id_done:

    ; Send: 36 + 4*N bytes.
    mov rdx, rcx
    shl rdx, 2
    add rdx, 36
    lea rsi, [tmp_buf]
    call x11_buffer
    inc dword [x11_seq]

    pop rcx                               ; run length restored
    pop rbx                               ; outer scan column restored
    jmp .rs_after_text

.rs_after_text:
    ; If this run had SGR 4 (underline), draw a 1px line under it using
    ; the run's foreground color (already loaded in the GC). Use
    ; PolyFillRectangle with one rectangle covering all run cells.
    cmp byte [run_underline], 0
    je .rs_no_underline
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_POLY_FILL_RECT
    mov byte [rdi+1], 0
    mov word [rdi+2], 5              ; 3 header + 2 (one rectangle)
    mov eax, [win_id]
    mov [rdi+4], eax
    mov eax, [gc_id]
    mov [rdi+8], eax
    ; x = start_col * char_width
    mov rax, r13
    movzx edx, word [char_width]
    imul eax, edx
    mov word [rdi+12], ax
    ; y = row * char_height + font_ascent + 1 (just below the baseline)
    movzx eax, word [char_height]
    imul eax, r12d
    movzx edx, word [font_ascent]
    add eax, edx
    inc eax
    mov word [rdi+14], ax
    ; width = (rbx - r13) * char_width
    mov rax, rbx
    sub rax, r13
    movzx edx, word [char_width]
    imul eax, edx
    mov word [rdi+16], ax
    mov word [rdi+18], 1             ; height
    lea rsi, [tmp_buf]
    mov rdx, 20
    call x11_buffer
    inc dword [x11_seq]
.rs_no_underline:
    ; Advance to next run
    mov r13, rbx
    jmp .rs_run_start

.rs_next_row:
    inc r12
    jmp .rs_row

.rs_after_rows:
    ; OSC 8 hyperlink underline pass — gated by cfg_osc8_underline so
    ; the user can disable it for apps that abuse OSC 8 (CC opens
    ; spans that effectively never close).
    cmp byte [cfg_osc8_underline], 0
    je .rs_link_done
    ; Scan grid for cells whose link id is non-zero and draw an
    ; underline per contiguous span. Done as a separate pass so it
    ; doesn't perturb the per-color text-run logic.
    xor r12, r12
.rs_link_row:
    cmp r12, [grid_rows]
    jge .rs_link_done
    xor r13, r13
.rs_link_scan:
    cmp r13, [grid_cols]
    jge .rs_link_next_row
    mov rax, r12
    imul rax, MAX_COLS
    add rax, r13
    imul rax, CELL_SIZE
    movzx ecx, byte [grid + rax + 5]
    test ecx, ecx
    jnz .rs_link_span
    inc r13
    jmp .rs_link_scan
.rs_link_span:
    mov r14, r13                 ; span start col
    ; Resolve fg pixel of first cell (used for underline color)
    mov r15d, [palette + 7*4]
    mov edx, [grid + rax + 8]
    test byte [grid + rax + 2], 1
    cmovz r15d, edx
.rs_link_extend:
    inc r13
    cmp r13, [grid_cols]
    jge .rs_link_draw
    mov rax, r12
    imul rax, MAX_COLS
    add rax, r13
    imul rax, CELL_SIZE
    movzx eax, byte [grid + rax + 5]
    cmp eax, ecx
    jne .rs_link_draw
    jmp .rs_link_extend
.rs_link_draw:
    ; ChangeGC fg = r15 (already a resolved pixel)
    push rcx
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_GC
    mov byte [rdi+1], 0
    mov word [rdi+2], 4
    mov eax, [gc_id]
    mov [rdi+4], eax
    mov dword [rdi+8], GC_FOREGROUND
    mov [rdi+12], r15d
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]
    ; PolyFillRect at (r14*char_w, (r12+1)*char_h - 1, span_w*char_w, 1)
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_POLY_FILL_RECT
    mov byte [rdi+1], 0
    mov word [rdi+2], 5
    mov eax, [win_id]
    mov [rdi+4], eax
    mov eax, [gc_id]
    mov [rdi+8], eax
    mov rax, r14
    movzx ecx, word [char_width]
    imul eax, ecx
    mov word [rdi+12], ax
    mov rax, r12
    inc rax
    movzx ecx, word [char_height]
    imul eax, ecx
    sub eax, 2
    mov word [rdi+14], ax
    mov rax, r13
    sub rax, r14
    movzx ecx, word [char_width]
    imul eax, ecx
    mov word [rdi+16], ax
    mov word [rdi+18], 2
    lea rsi, [tmp_buf]
    mov rdx, 20
    call x11_buffer
    inc dword [x11_seq]
    pop rcx
    jmp .rs_link_scan
.rs_link_next_row:
    inc r12
    jmp .rs_link_row
.rs_link_done:

    ; ─── Fallback-glyph pass (DISABLED) ───────────────────────────────
    ; First-cut fallback had two cell-byte-order bugs that mis-marked
    ; codepoints in glyph_present and sent wrong CHAR2B to ImageText16.
    ; Skipping the whole pass until the rewrite lands; the X server's
    ; default-glyph behaviour (the prior status quo) is restored.
    jmp .rs_fb_done
    cmp dword [fallback_font_id], 0
    je .rs_fb_done
    xor r12, r12                           ; row
.rs_fb_row:
    cmp r12, [grid_rows]
    jge .rs_fb_done
    xor r13, r13                           ; col
.rs_fb_col:
    cmp r13, [grid_cols]
    jge .rs_fb_row_done
    mov rax, r12
    imul rax, MAX_COLS
    add rax, r13
    imul rax, CELL_SIZE
    lea rdi, [grid + rax]
    ; Codepoint = (cell[0] << 8) | cell[1]
    movzx ecx, byte [rdi]
    shl ecx, 8
    movzx edx, byte [rdi + 1]
    or ecx, edx                            ; ecx = codepoint
    ; Skip blanks: codepoint 0 and SPACE (0x20) — primary handles them.
    test ecx, ecx
    jz .rs_fb_next
    cmp ecx, 0x20
    je .rs_fb_next
    ; Skip if primary has the glyph: bit set in glyph_present[cp/8].
    mov rax, rcx
    shr rax, 3
    mov bl, cl
    and bl, 7
    mov dl, 1
    push rcx
    mov cl, bl
    shl dl, cl
    pop rcx
    test [glyph_present + rax], dl
    jnz .rs_fb_next
    ; Skip emoji cells (already handled by the emoji pass below).
    test byte [rdi + 4], 8                  ; ATTR_IS_EMOJI
    jnz .rs_fb_next
    ; Resolve effective fg / bg for this cell, accounting for default
    ; flags and the inverse attribute.
    movzx eax, byte [rdi + 2]               ; fg_default flag
    test eax, eax
    jnz .rs_fb_fg_default
    mov r14d, [rdi + 8]                     ; explicit fg pixel
    jmp .rs_fb_have_fg
.rs_fb_fg_default:
    movzx eax, byte [default_fg]
    mov r14d, [palette + rax*4]
.rs_fb_have_fg:
    movzx eax, byte [rdi + 3]               ; bg_default flag
    test eax, eax
    jnz .rs_fb_bg_default
    mov r15d, [rdi + 12]                    ; explicit bg pixel
    jmp .rs_fb_have_bg
.rs_fb_bg_default:
    movzx eax, byte [default_bg]
    mov r15d, [palette + rax*4]
.rs_fb_have_bg:
    ; Inverse swap (bit 2 of attrs).
    test byte [rdi + 4], 4
    jz .rs_fb_no_inv
    xchg r14d, r15d
.rs_fb_no_inv:
    ; Clear the cell area with bg (PolyFillRectangle on gc_id with
    ; foreground temporarily set to r15 = bg). Saves us caring about
    ; whether the fallback glyph's natural box covers the full cell.
    push rcx
    push rdi
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_GC
    mov byte [rdi+1], 0
    mov word [rdi+2], 4
    mov eax, [gc_id]
    mov [rdi+4], eax
    mov dword [rdi+8], GC_FOREGROUND
    mov [rdi+12], r15d
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_POLY_FILL_RECT
    mov byte [rdi+1], 0
    mov word [rdi+2], 5
    mov eax, [win_id]
    mov [rdi+4], eax
    mov eax, [gc_id]
    mov [rdi+8], eax
    mov rax, r13
    movzx edx, word [char_width]
    imul eax, edx
    mov word [rdi+12], ax
    mov rax, r12
    movzx edx, word [char_height]
    imul eax, edx
    mov word [rdi+14], ax
    movzx eax, word [char_width]
    mov word [rdi+16], ax
    movzx eax, word [char_height]
    mov word [rdi+18], ax
    lea rsi, [tmp_buf]
    mov rdx, 20
    call x11_buffer
    inc dword [x11_seq]
    pop rdi
    pop rcx
    ; Set fallback GC fg + bg.
    push rcx
    push rdi
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_GC
    mov byte [rdi+1], 0
    mov word [rdi+2], 5                     ; 3 base + 2 value words
    mov eax, [fallback_gc_id]
    mov [rdi+4], eax
    mov dword [rdi+8], GC_FOREGROUND | GC_BACKGROUND
    mov [rdi+12], r14d                      ; foreground
    mov [rdi+16], r15d                      ; background
    lea rsi, [tmp_buf]
    mov rdx, 20
    call x11_buffer
    inc dword [x11_seq]
    pop rdi
    pop rcx
    ; ImageText16 the fallback glyph at the cell's baseline. Big-endian
    ; CHAR2B = the codepoint bytes already in cell[0..1] in the right
    ; order.
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_IMAGE_TEXT16
    mov byte [rdi+1], 1                     ; n = 1 char
    mov word [rdi+2], 5                     ; 4 base + 1 data word (2 bytes char + 2 bytes pad)
    mov eax, [win_id]
    mov [rdi+4], eax
    mov eax, [fallback_gc_id]
    mov [rdi+8], eax
    mov rax, r13
    movzx edx, word [char_width]
    imul eax, edx
    mov word [rdi+12], ax                   ; x
    mov rax, r12
    movzx edx, word [char_height]
    imul eax, edx
    movzx edx, word [font_ascent]           ; baseline at primary's ascent so
    add eax, edx                            ; fallback aligns with primary text
    mov word [rdi+14], ax                   ; y (baseline)
    ; Copy the CHAR2B codepoint bytes from the cell directly.
    mov rax, r12
    imul rax, MAX_COLS
    add rax, r13
    imul rax, CELL_SIZE
    movzx ecx, byte [grid + rax]
    movzx edx, byte [grid + rax + 1]
    mov [rdi+16], cl
    mov [rdi+17], dl
    mov word [rdi+18], 0                    ; pad
    lea rsi, [tmp_buf]
    mov rdx, 20
    call x11_buffer
    inc dword [x11_seq]
.rs_fb_next:
    inc r13
    jmp .rs_fb_col
.rs_fb_row_done:
    inc r12
    jmp .rs_fb_row
.rs_fb_done:

    ; Emoji pass: composite each ATTR_IS_EMOJI cell's cached Picture
    ; onto the window via XRender. Lazy: any not-yet-rendered emoji
    ; gets forked-and-rasterized here on first sight.
    cmp dword [render_major], 0
    je .rs_emoji_done
    xor r12, r12
.rs_emoji_row:
    cmp r12, [grid_rows]
    jge .rs_emoji_done
    xor r13, r13
.rs_emoji_col:
    cmp r13, [grid_cols]
    jge .rs_emoji_next_row
    mov rax, r12
    imul rax, MAX_COLS
    add rax, r13
    imul rax, CELL_SIZE
    test byte [grid + rax + 4], 8       ; ATTR_IS_EMOJI
    jz .rs_emoji_inc
    movzx r14d, word [grid + rax + 6]   ; emoji index
    cmp r14d, MAX_EMOJI
    jae .rs_emoji_inc
    mov edi, r14d
    call render_emoji_glyph
    mov eax, [emoji_pictures + r14*4]
    test eax, eax
    jz .rs_emoji_inc
    ; Composite: src=picture, mask=0, dst=window_picture, op=Over
    push rax
    lea rdi, [tmp_buf]
    mov al, [render_major]
    mov [rdi], al
    mov byte [rdi+1], RENDER_COMPOSITE
    mov word [rdi+2], 9
    mov byte [rdi+4], RENDER_OP_OVER
    mov byte [rdi+5], 0
    mov word [rdi+6], 0
    pop rax
    mov [rdi+8], eax                    ; src
    mov dword [rdi+12], 0               ; mask = None
    mov eax, [render_window_picture]
    mov [rdi+16], eax                   ; dst
    mov word [rdi+20], 0                ; src x
    mov word [rdi+22], 0                ; src y
    mov word [rdi+24], 0                ; mask x
    mov word [rdi+26], 0                ; mask y
    ; dst x = col * char_width
    mov rax, r13
    movzx ecx, word [char_width]
    imul eax, ecx
    mov word [rdi+28], ax
    ; dst y = row * char_height
    mov rax, r12
    movzx ecx, word [char_height]
    imul eax, ecx
    mov word [rdi+30], ax
    ; width = char_width * 2 (emoji are double-cell wide)
    movzx eax, word [char_width]
    add eax, eax
    mov word [rdi+32], ax
    ; height = char_height
    movzx eax, word [char_height]
    mov word [rdi+34], ax
    lea rsi, [tmp_buf]
    mov rdx, 36
    call x11_buffer
    inc dword [x11_seq]
.rs_emoji_inc:
    inc r13
    jmp .rs_emoji_col
.rs_emoji_next_row:
    inc r12
    jmp .rs_emoji_row
.rs_emoji_done:

    ; Image overlay pass: composite each entry in place_table via
    ; XRender, scaled into its declared cell rectangle.
    cmp dword [render_major], 0
    je .rs_imgs_done
    xor r12, r12
.rs_imgs_loop:
    cmp r12, PLACE_SLOTS
    jge .rs_imgs_done
    mov eax, r12d
    imul eax, PLACE_SLOT_SIZE
    lea r13, [place_table + rax]
    mov edi, [r13]
    test edi, edi
    jz .rs_imgs_next
    call img_find
    test rsi, rsi
    jz .rs_imgs_next
    mov r14d, [rsi + 16]             ; picture id (r14 callee-saved)
    test r14d, r14d
    jz .rs_imgs_next

    ; SetPictureTransform: rescale the source picture so Composite's
    ; 1:1 sampling maps the full source into the destination cell
    ; rectangle. Matrix is
    ;   ( src_w/dst_w   0             0 )
    ;   ( 0             src_h/dst_h   0 )
    ;   ( 0             0             1 )
    ; in 16.16 fixed-point. Values are stored big-endian per RENDER.
    mov ebx, [rsi + 4]               ; src_w
    mov r15d, [rsi + 8]              ; src_h
    movzx eax, word [r13 + 8]        ; cell_w
    movzx ecx, word [char_width]
    imul eax, ecx
    mov r9d, eax                     ; dst_w
    test r9d, r9d
    jz .rs_imgs_skip_xform
    movzx eax, word [r13 + 10]       ; cell_h
    movzx ecx, word [char_height]
    imul eax, ecx
    mov r10d, eax                    ; dst_h
    test r10d, r10d
    jz .rs_imgs_skip_xform
    lea rdi, [tmp_buf]
    mov al, [render_major]
    mov [rdi], al
    mov byte [rdi+1], RENDER_SET_PICTURE_TRANSFORM
    mov word [rdi+2], 11
    mov [rdi+4], r14d                ; source picture
    ; m11 = (src_w << 16) / dst_w
    mov eax, ebx
    shl rax, 16
    xor edx, edx
    div r9d
    mov [rdi+8], eax
    mov dword [rdi+12], 0            ; m12
    mov dword [rdi+16], 0            ; m13
    mov dword [rdi+20], 0            ; m21
    ; m22 = (src_h << 16) / dst_h
    mov eax, r15d
    shl rax, 16
    xor edx, edx
    div r10d
    mov [rdi+24], eax
    mov dword [rdi+28], 0            ; m23
    mov dword [rdi+32], 0            ; m31
    mov dword [rdi+36], 0            ; m32
    mov dword [rdi+40], 0x00010000   ; m33 = 1.0
    lea rsi, [tmp_buf]
    mov rdx, 44
    call x11_buffer
    inc dword [x11_seq]
.rs_imgs_skip_xform:
    lea rdi, [tmp_buf]
    mov al, [render_major]
    mov [rdi], al
    mov byte [rdi+1], RENDER_COMPOSITE
    mov word [rdi+2], 9
    mov byte [rdi+4], RENDER_OP_OVER
    mov byte [rdi+5], 0
    mov word [rdi+6], 0
    mov [rdi+8], r14d                ; src picture
    mov dword [rdi+12], 0            ; mask = None
    mov eax, [render_window_picture]
    mov [rdi+16], eax                ; dst
    mov word [rdi+20], 0             ; src x
    mov word [rdi+22], 0             ; src y
    mov word [rdi+24], 0             ; mask x
    mov word [rdi+26], 0             ; mask y
    movzx eax, word [r13 + 6]        ; anchor_col
    movzx ecx, word [char_width]
    imul eax, ecx
    mov word [rdi+28], ax
    movzx eax, word [r13 + 4]        ; anchor_row
    movzx ecx, word [char_height]
    imul eax, ecx
    mov word [rdi+30], ax
    movzx eax, word [r13 + 8]        ; cell_w
    movzx ecx, word [char_width]
    imul eax, ecx
    mov word [rdi+32], ax
    movzx eax, word [r13 + 10]       ; cell_h
    movzx ecx, word [char_height]
    imul eax, ecx
    mov word [rdi+34], ax
    lea rsi, [tmp_buf]
    mov rdx, 36
    call x11_buffer
    inc dword [x11_seq]
.rs_imgs_next:
    inc r12
    jmp .rs_imgs_loop
.rs_imgs_done:

.rs_cursor:
    ; Skip cursor drawing if cursor_visible == 0
    cmp qword [cursor_visible], 0
    je .rs_cursor_done
    ; Skip if blink is on and we're in the hidden phase
    cmp qword [cfg_blink_ms], 0
    je .rs_cursor_no_blink
    cmp qword [cursor_blink_state], 0
    je .rs_cursor_done
.rs_cursor_no_blink:

    ; Draw cursor at cursor position
    lea rdi, [tmp_buf]
    ; Set GC foreground for cursor (config or white)
    mov byte [rdi], X11_CHANGE_GC
    mov byte [rdi+1], 0
    mov word [rdi+2], 4
    mov eax, [gc_id]
    mov [rdi+4], eax
    mov dword [rdi+8], GC_FOREGROUND
    cmp byte [cfg_cursor_set], 1
    jne .rs_cursor_default
    mov eax, [cfg_cursor_pixel]
    jmp .rs_cursor_color_set
.rs_cursor_default:
    mov eax, [x11_white_pixel]
.rs_cursor_color_set:
    ; In ARGB mode the cursor pixel needs alpha=0xFF or it is invisible.
    cmp dword [x11_argb_colormap], 0
    je .rs_cursor_no_alpha
    or eax, 0xFF000000
.rs_cursor_no_alpha:
    mov [rdi+12], eax
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]

    ; PolyFillRectangle with shape based on cursor_style
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_POLY_FILL_RECT
    mov byte [rdi+1], 0
    mov word [rdi+2], 5      ; length (3 + 2 per rect)
    mov eax, [win_id]
    mov [rdi+4], eax
    mov eax, [gc_id]
    mov [rdi+8], eax

    ; Dispatch on cursor_style: 0=block, 1=underline, 2=bar
    mov rax, [cursor_style]
    cmp rax, 2
    je .rs_cursor_bar
    cmp rax, 1
    je .rs_cursor_underline

    ; Block cursor (0): full cell
    mov rax, [cursor_col]
    movzx ecx, word [char_width]
    imul eax, ecx
    mov word [rdi+12], ax
    mov rax, [cursor_row]
    movzx ecx, word [char_height]
    imul eax, ecx
    mov word [rdi+14], ax
    movzx eax, word [char_width]
    mov word [rdi+16], ax
    movzx eax, word [char_height]
    mov word [rdi+18], ax
    jmp .rs_cursor_draw

.rs_cursor_underline:
    ; Underline cursor (1): bottom 2px
    mov rax, [cursor_col]
    movzx ecx, word [char_width]
    imul eax, ecx
    mov word [rdi+12], ax
    mov rax, [cursor_row]
    movzx ecx, word [char_height]
    imul eax, ecx
    movzx ecx, word [char_height]
    add eax, ecx
    sub eax, 2
    mov word [rdi+14], ax
    movzx eax, word [char_width]
    mov word [rdi+16], ax
    mov word [rdi+18], 2
    jmp .rs_cursor_draw

.rs_cursor_bar:
    ; Bar cursor (2): left 2px
    mov rax, [cursor_col]
    movzx ecx, word [char_width]
    imul eax, ecx
    mov word [rdi+12], ax
    mov rax, [cursor_row]
    movzx ecx, word [char_height]
    imul eax, ecx
    mov word [rdi+14], ax
    mov word [rdi+16], 2
    movzx eax, word [char_height]
    mov word [rdi+18], ax

.rs_cursor_draw:
    lea rsi, [tmp_buf]
    mov rdx, 20
    call x11_buffer
    inc dword [x11_seq]

.rs_cursor_done:

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Palette initialization (256-color)
; ══════════════════════════════════════════════════════════════════════

init_palette:
    push rbx
    push r12

    ; Colors 0-15: standard colors
    xor rbx, rbx
.ip_std:
    cmp rbx, 16
    jge .ip_cube
    mov eax, [std_colors + rbx*4]
    mov [palette + rbx*4], eax
    inc rbx
    jmp .ip_std

.ip_cube:
    ; Colors 16-231: 6x6x6 color cube
    ; index = 16 + 36*r + 6*g + b
    ; Component values: 0, 0x5F, 0x87, 0xAF, 0xD7, 0xFF
    mov rbx, 16
    xor r12, r12             ; r
.ip_r:
    cmp r12, 6
    jge .ip_gray
    xor rcx, rcx             ; g
.ip_g:
    cmp rcx, 6
    jge .ip_r_next
    xor rdx, rdx             ; b
.ip_b:
    cmp rdx, 6
    jge .ip_g_next
    ; Calculate pixel: 0x00RRGGBB
    push rcx
    push rdx
    lea rdi, [.ip_vals]
    ; R component
    movzx eax, byte [rdi + r12]
    shl eax, 16
    mov esi, eax
    ; G component (rcx = g index, preserved on stack)
    movzx eax, byte [rdi + rcx]
    shl eax, 8
    or esi, eax
    ; B component (rdx = b index, preserved on stack)
    movzx eax, byte [rdi + rdx]
    or esi, eax
    mov [palette + rbx*4], esi
    pop rdx
    pop rcx
    inc rbx
    inc rdx
    jmp .ip_b
.ip_g_next:
    inc rcx
    jmp .ip_g
.ip_r_next:
    inc r12
    jmp .ip_r

.ip_gray:
    ; Colors 232-255: grayscale
    mov rbx, 232
    mov ecx, 8
.ip_gray_loop:
    cmp rbx, 256
    jge .ip_done
    ; value = 8 + 10 * (index - 232)
    mov eax, ecx
    mov edx, eax
    shl eax, 16
    or eax, edx
    shl edx, 8
    or eax, edx
    mov [palette + rbx*4], eax
    add ecx, 10
    inc rbx
    jmp .ip_gray_loop

.ip_done:
    pop r12
    pop rbx
    ret

.ip_vals: db 0, 0x5F, 0x87, 0xAF, 0xD7, 0xFF

; check_compositor: intern _NET_WM_CM_S0 and read its owner. Sets
; [compositor_active] = 1 if a compositor owns the selection.
check_compositor:
    push rbx
    call x11_flush
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_INTERN_ATOM
    mov byte [rdi+1], 0
    mov word [rdi+2], 2 + (netwm_cm_len + 3) / 4
    mov word [rdi+4], netwm_cm_len
    mov word [rdi+6], 0
    lea rsi, [netwm_cm_str]
    lea rbx, [tmp_buf + 8]
    xor ecx, ecx
.cc_cp:
    cmp ecx, netwm_cm_len
    jge .cc_send
    movzx eax, byte [rsi + rcx]
    mov [rbx + rcx], al
    inc ecx
    jmp .cc_cp
.cc_send:
    mov eax, netwm_cm_len
    add eax, 3
    and eax, ~3
    add eax, 8
    mov rdx, rax
    lea rsi, [tmp_buf]
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    inc dword [x11_seq]
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 32
    syscall
    cmp rax, 32
    jl .cc_done
    mov eax, [x11_buf + 8]
    test eax, eax
    jz .cc_done
    mov [netwm_cm_atom], eax

    lea rdi, [tmp_buf]
    mov byte [rdi], X11_GET_SELECTION_OWNER
    mov byte [rdi+1], 0
    mov word [rdi+2], 2
    mov [rdi+4], eax
    lea rsi, [tmp_buf]
    mov rdx, 8
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    inc dword [x11_seq]
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 32
    syscall
    cmp rax, 32
    jl .cc_done
    mov eax, [x11_buf + 8]
    test eax, eax
    jz .cc_done
    mov byte [compositor_active], 1
.cc_done:
    pop rbx
    ret

; Pseudo-transparency setup: when no real compositor is running, sample
; the desktop wallpaper at the window's screen position, average it, and
; blend with the configured bg. The resulting solid color is used as
; palette[0] so glass color-matches the area behind it. This gives a
; "tint" effect rather than true per-pixel see-through transparency, but
; needs no compositor and no renderer changes.
;
; Skipped if:
;   - opacity not configured or = 100
;   - the ARGB visual path was already taken (real transparency available)
;   - a compositor owns _NET_WM_CM_S0 (real transparency will work)
;   - root window has no _XROOTPMAP_ID (no wallpaper)
setup_pseudo_transparency:
    push rbx
    push r12
    push r13
    push r14
    push r15

    cmp byte [cfg_opacity_set], 1
    jne .spt_done
    movzx eax, byte [cfg_opacity]
    cmp eax, 255
    jae .spt_done
    cmp dword [x11_argb_colormap], 0
    jne .spt_done                       ; ARGB path took it
    cmp byte [compositor_active], 1
    je .spt_done                        ; real transparency available, skip
    call x11_flush

    ; --- Intern _XROOTPMAP_ID and read root pixmap ID ---------------
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_INTERN_ATOM
    mov byte [rdi+1], 0
    mov word [rdi+2], 2 + (xrootpmap_len + 3) / 4
    mov word [rdi+4], xrootpmap_len
    mov word [rdi+6], 0
    lea rsi, [xrootpmap_str]
    lea rbx, [tmp_buf + 8]
    xor ecx, ecx
.spt_cp_rp:
    cmp ecx, xrootpmap_len
    jge .spt_send_rp
    movzx eax, byte [rsi + rcx]
    mov [rbx + rcx], al
    inc ecx
    jmp .spt_cp_rp
.spt_send_rp:
    mov eax, xrootpmap_len
    add eax, 3
    and eax, ~3
    add eax, 8
    mov rdx, rax
    lea rsi, [tmp_buf]
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    inc dword [x11_seq]
    call x11_drain_until_reply
    test rax, rax
    js .spt_done
    mov eax, [x11_buf + 8]
    test eax, eax
    jz .spt_done
    mov [xrootpmap_atom], eax

    ; GetProperty(root, _XROOTPMAP_ID, AnyPropertyType, 0, 1)
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_GET_PROPERTY
    mov byte [rdi+1], 0
    mov word [rdi+2], 6
    mov eax, [x11_root_window]
    mov [rdi+4], eax
    mov eax, [xrootpmap_atom]
    mov [rdi+8], eax
    mov dword [rdi+12], 0
    mov dword [rdi+16], 0
    mov dword [rdi+20], 1
    lea rsi, [tmp_buf]
    mov rdx, 24
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    inc dword [x11_seq]
    call x11_drain_until_reply
    test rax, rax
    js .spt_done
    mov eax, [x11_buf + 16]              ; value-length
    test eax, eax
    jz .spt_done
    mov r12d, [x11_buf + 32]             ; root pixmap id
    test r12d, r12d
    jz .spt_done

    ; r12 = root pixmap id (kept across the rest of the routine)
    mov [pseudo_root_pmap], r12d

    ; --- TranslateCoordinates(win_id, root, 0, 0) -> root_x, root_y
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_TRANSLATE_COORDINATES
    mov byte [rdi+1], 0
    mov word [rdi+2], 4
    mov eax, [win_id]
    mov [rdi+4], eax
    mov eax, [x11_root_window]
    mov [rdi+8], eax
    mov word [rdi+12], 0
    mov word [rdi+14], 0
    lea rsi, [tmp_buf]
    mov rdx, 16
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    inc dword [x11_seq]
    call x11_drain_until_reply
    test rax, rax
    js .spt_done
    movzx eax, word [x11_buf + 12]
    mov [pseudo_root_x], eax
    movzx eax, word [x11_buf + 14]
    mov [pseudo_root_y], eax

    ; --- (Re)create server pixmap if window size changed -------------
    mov eax, [win_width]
    mov ecx, [win_height]
    cmp eax, [bg_pixmap_w]
    jne .spt_recreate
    cmp ecx, [bg_pixmap_h]
    jne .spt_recreate
    cmp dword [bg_pixmap_id], 0
    jne .spt_pixmap_ready
.spt_recreate:
    cmp dword [bg_pixmap_id], 0
    je .spt_alloc_new
    ; FreePixmap the old one
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_FREE_PIXMAP
    mov byte [rdi+1], 0
    mov word [rdi+2], 2
    mov eax, [bg_pixmap_id]
    mov [rdi+4], eax
    lea rsi, [tmp_buf]
    mov rdx, 8
    call x11_buffer
    inc dword [x11_seq]
.spt_alloc_new:
    call alloc_xid
    mov [bg_pixmap_id], eax
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CREATE_PIXMAP
    mov al, [x11_root_depth]
    mov byte [rdi+1], al
    mov word [rdi+2], 4
    mov eax, [bg_pixmap_id]
    mov [rdi+4], eax
    mov eax, [win_id]
    mov [rdi+8], eax                     ; drawable (matches depth)
    mov eax, [win_width]
    mov word [rdi+12], ax
    mov eax, [win_height]
    mov word [rdi+14], ax
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]
    mov eax, [win_width]
    mov [bg_pixmap_w], eax
    mov eax, [win_height]
    mov [bg_pixmap_h], eax
.spt_pixmap_ready:
    call x11_flush

    ; --- Strip-by-strip wallpaper fetch + blend + upload --------------
    ; strip_h = 8 rows: GetImage reply data = win_w * 8 * 4 bytes,
    ; comfortably under the 64KB x11_buf for any sane width.
    xor r12d, r12d                       ; current y in window
.spt_strip:
    cmp r12d, [win_height]
    jge .spt_strips_done
    mov ecx, [win_height]
    sub ecx, r12d
    cmp ecx, 8
    jle .spt_strip_h_ok
    mov ecx, 8
.spt_strip_h_ok:
    mov [pseudo_strip_h], ecx

    ; GetImage(root_pmap, root_x+0, root_y+r12, win_w, strip_h)
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_GET_IMAGE
    mov byte [rdi+1], 2                  ; ZPixmap
    mov word [rdi+2], 5
    mov eax, [pseudo_root_pmap]
    mov [rdi+4], eax
    mov eax, [pseudo_root_x]
    mov word [rdi+8], ax
    mov eax, [pseudo_root_y]
    add eax, r12d
    mov word [rdi+10], ax
    mov eax, [win_width]
    mov word [rdi+12], ax
    mov eax, [pseudo_strip_h]
    mov word [rdi+14], ax
    mov dword [rdi+16], 0xFFFFFFFF
    lea rsi, [tmp_buf]
    mov rdx, 20
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    inc dword [x11_seq]
    call x11_drain_until_reply
    test rax, rax
    js .spt_done

    ; Blend strip in place: bytes B,G,R,X per pixel.
    mov eax, [win_width]
    mul dword [pseudo_strip_h]
    mov [pseudo_strip_pixels], eax       ; pixel count for this strip
    mov ecx, eax                         ; loop counter (pixels)
    test ecx, ecx
    jz .spt_strip_blended
    movzx ebx, byte [cfg_opacity]        ; bg weight
    mov edx, 255
    sub edx, ebx                         ; wp weight
    mov [pseudo_wp_w], edx
    mov [pseudo_bg_w], ebx
    mov r13d, [cfg_bg_pixel]
    lea rsi, [x11_buf + 32]              ; first pixel
.spt_blend_pixel:
    ; B = (wp_B * wp_w + bg_B * bg_w) / 255
    movzx eax, byte [rsi]                ; wp B
    imul eax, [pseudo_wp_w]
    mov edi, r13d
    and edi, 0xFF                        ; bg B
    imul edi, [pseudo_bg_w]
    add eax, edi
    mov edi, 255
    xor edx, edx
    div edi
    mov [rsi], al
    ; G
    movzx eax, byte [rsi + 1]
    imul eax, [pseudo_wp_w]
    mov edi, r13d
    shr edi, 8
    and edi, 0xFF
    imul edi, [pseudo_bg_w]
    add eax, edi
    mov edi, 255
    xor edx, edx
    div edi
    mov [rsi + 1], al
    ; R
    movzx eax, byte [rsi + 2]
    imul eax, [pseudo_wp_w]
    mov edi, r13d
    shr edi, 16
    and edi, 0xFF
    imul edi, [pseudo_bg_w]
    add eax, edi
    mov edi, 255
    xor edx, edx
    div edi
    mov [rsi + 2], al
    add rsi, 4
    dec ecx
    jnz .spt_blend_pixel
.spt_strip_blended:

    ; PutImage(bg_pixmap, gc, win_w, strip_h, 0, r12, 0, depth, data)
    ; request length in 4-byte words = (24 + data_bytes_padded) / 4
    ; data_bytes = pixel_count * 4 (already 4-aligned)
    mov eax, [pseudo_strip_pixels]
    shl eax, 2                           ; data bytes
    mov [pseudo_data_bytes], eax
    add eax, 24                          ; + header
    add eax, 3
    and eax, ~3
    mov edi, eax
    shr edi, 2                           ; words
    mov [pseudo_pi_words], edi
    ; Build PutImage header in place (bytes 0..23) just before data
    ; The data already lives at x11_buf+32, so put header at x11_buf+8
    ; so it sits contiguously with the pixel data.
    lea rdi, [x11_buf + 8]
    mov byte [rdi], X11_PUT_IMAGE
    mov byte [rdi+1], 2                  ; ZPixmap
    mov ax, [pseudo_pi_words + 0]
    mov word [rdi+2], ax
    mov eax, [bg_pixmap_id]
    mov [rdi+4], eax
    mov eax, [gc_id]
    mov [rdi+8], eax
    mov eax, [win_width]
    mov word [rdi+12], ax
    mov eax, [pseudo_strip_h]
    mov word [rdi+14], ax
    mov word [rdi+16], 0                 ; dst-x
    mov ax, r12w
    mov word [rdi+18], ax                ; dst-y
    mov byte [rdi+20], 0                 ; left-pad
    mov al, [x11_root_depth]
    mov byte [rdi+21], al
    mov word [rdi+22], 0                 ; pad
    ; Send header (24 bytes) + data (pseudo_data_bytes) directly. The
    ; data alone can be 60+ KB which overruns the 16 KB x11_write_buf
    ; if routed via x11_buffer. Flush any pending buffered requests
    ; first to keep ordering, then write straight to the socket.
    call x11_flush
    mov eax, [pseudo_data_bytes]
    add eax, 24
    mov [pseudo_total_bytes], eax
    mov r13d, 0                          ; bytes sent so far
.spt_pi_send_loop:
    mov eax, [pseudo_total_bytes]
    sub eax, r13d
    test eax, eax
    jle .spt_pi_send_done
    mov rdx, rax
    lea rsi, [x11_buf + 8]
    add rsi, r13
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    test rax, rax
    jle .spt_pi_send_done                ; abort on EAGAIN/error
    add r13d, eax
    jmp .spt_pi_send_loop
.spt_pi_send_done:
    inc dword [x11_seq]

    add r12d, [pseudo_strip_h]
    jmp .spt_strip
.spt_strips_done:

    ; --- Set window's background pixmap and clear to apply ----------
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_WINDOW_ATTRS
    mov byte [rdi+1], 0
    mov word [rdi+2], 4
    mov eax, [win_id]
    mov [rdi+4], eax
    mov dword [rdi+8], CW_BACK_PIXMAP
    mov eax, [bg_pixmap_id]
    mov [rdi+12], eax
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]

    ; ClearArea entire window so the new BackPixmap shows immediately
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CLEAR_AREA
    mov byte [rdi+1], 0
    mov word [rdi+2], 4
    mov eax, [win_id]
    mov [rdi+4], eax
    mov word [rdi+8], 0
    mov word [rdi+10], 0
    mov word [rdi+12], 0                 ; w=0 means "to right edge"
    mov word [rdi+14], 0                 ; h=0 means "to bottom edge"
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]
    call x11_flush

    mov byte [pseudo_full], 1
    mov byte [pseudo_bg_set], 1

.spt_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Apply alpha to the palette for ARGB rendering.
; palette[0] gets cfg_opacity (the see-through bg).
; palette[1..255] get 0xFF (fully opaque) so foreground glyphs and
; non-default cell backgrounds stay solid.
palette_apply_alpha:
    push rbx
    movzx ecx, byte [cfg_opacity]
    shl ecx, 24
    mov eax, [palette]
    and eax, 0x00FFFFFF
    or eax, ecx
    mov [palette], eax
    mov ebx, 1
.paa_loop:
    cmp ebx, 256
    jge .paa_done
    mov eax, [palette + rbx*4]
    and eax, 0x00FFFFFF
    or eax, 0xFF000000
    mov [palette + rbx*4], eax
    inc ebx
    jmp .paa_loop
.paa_done:
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Configuration loading (~/.glassrc)
; ══════════════════════════════════════════════════════════════════════

; Load configuration from ~/.glassrc
; Format: key = #RRGGBB or key = number, one per line
load_config:
    push rbx
    push r12
    push r13

    ; Find $HOME
    mov rdi, [envp]
.lc_env_loop:
    mov rax, [rdi]
    test rax, rax
    jz .lc_done
    cmp dword [rax], 'HOME'
    jne .lc_env_next
    cmp byte [rax+4], '='
    jne .lc_env_next
    lea rsi, [rax + 5]
    jmp .lc_build_path
.lc_env_next:
    add rdi, 8
    jmp .lc_env_loop

.lc_build_path:
    ; Build $HOME/.glassrc in tmp_buf
    lea rdi, [tmp_buf]
.lc_cp_home:
    mov al, [rsi]
    test al, al
    jz .lc_append_suffix
    mov [rdi], al
    inc rsi
    inc rdi
    jmp .lc_cp_home
.lc_append_suffix:
    lea rsi, [glassrc_suffix]
.lc_cp_suffix:
    mov al, [rsi]
    mov [rdi], al
    test al, al
    jz .lc_open
    inc rsi
    inc rdi
    jmp .lc_cp_suffix

.lc_open:
    mov rax, SYS_OPEN
    lea rdi, [tmp_buf]
    xor esi, esi             ; O_RDONLY
    xor edx, edx
    syscall
    test rax, rax
    js .lc_done              ; file doesn't exist, use defaults
    mov rbx, rax             ; fd

    mov rax, SYS_READ
    mov rdi, rbx
    lea rsi, [cfg_buf]
    mov rdx, 4095
    syscall
    mov r12, rax             ; bytes read

    push rbx
    mov rax, SYS_CLOSE
    mov rdi, [rsp]
    syscall
    pop rbx

    test r12, r12
    jle .lc_done
    ; Null-terminate
    mov byte [cfg_buf + r12], 0

    ; Parse lines
    lea rsi, [cfg_buf]
.lc_line_loop:
    cmp byte [rsi], 0
    je .lc_done
    ; Skip leading whitespace
.lc_skip_ws:
    cmp byte [rsi], ' '
    je .lc_skip_ws_next
    cmp byte [rsi], 9       ; tab
    je .lc_skip_ws_next
    jmp .lc_check_comment
.lc_skip_ws_next:
    inc rsi
    jmp .lc_skip_ws

.lc_check_comment:
    cmp byte [rsi], '#'
    je .lc_skip_line
    cmp byte [rsi], 10       ; newline
    je .lc_next_line
    cmp byte [rsi], 0
    je .lc_done

    ; Try to match "bg"
    cmp word [rsi], 'bg'
    jne .lc_try_fg
    cmp byte [rsi+2], ' '
    je .lc_parse_bg
    cmp byte [rsi+2], '='
    je .lc_parse_bg
    jmp .lc_try_fg

.lc_parse_bg:
    add rsi, 2
    call lc_skip_to_value
    cmp byte [rsi], '#'
    jne .lc_skip_line
    inc rsi
    call hex_to_pixel
    mov [cfg_bg_pixel], eax
    mov byte [cfg_bg_set], 1
    ; Update palette[0] with configured bg
    mov [palette], eax
    jmp .lc_skip_line

.lc_try_fg:
    cmp word [rsi], 'fg'
    jne .lc_try_cursor
    cmp byte [rsi+2], ' '
    je .lc_parse_fg
    cmp byte [rsi+2], '='
    je .lc_parse_fg
    jmp .lc_try_cursor

.lc_parse_fg:
    add rsi, 2
    call lc_skip_to_value
    cmp byte [rsi], '#'
    jne .lc_skip_line
    inc rsi
    call hex_to_pixel
    mov [cfg_fg_pixel], eax
    mov byte [cfg_fg_set], 1
    ; Update palette[7] with configured fg
    mov [palette + 7*4], eax
    jmp .lc_skip_line

.lc_try_cursor:
    ; Match "cursor" but NOT "cursor_blink" (which we handle separately)
    cmp dword [rsi], 'curs'
    jne .lc_try_font_size
    cmp word [rsi+4], 'or'
    jne .lc_try_font_size
    movzx eax, byte [rsi+6]
    cmp al, ' '
    je .lc_cursor_color
    cmp al, 9
    je .lc_cursor_color
    cmp al, '='
    je .lc_cursor_color
    jmp .lc_try_font_size           ; not "cursor", try next
.lc_cursor_color:
    add rsi, 6
    call lc_skip_to_value
    cmp byte [rsi], '#'
    jne .lc_skip_line
    inc rsi
    call hex_to_pixel
    mov [cfg_cursor_pixel], eax
    mov byte [cfg_cursor_set], 1
    jmp .lc_skip_line

.lc_try_font_size:
    ; Keys starting with "font_": dispatch on the 6th character.
    cmp dword [rsi], 'font'
    jne .lc_try_blink
    cmp byte [rsi+4], '_'
    jne .lc_try_blink
    movzx eax, byte [rsi+5]
    cmp al, 's'
    je .lc_handle_font_size
    cmp al, 'p'
    je .lc_handle_font_path
    cmp al, 'w'
    je .lc_handle_font_weight
    jmp .lc_try_blink

.lc_handle_font_size:
    cmp dword [rsi+4], '_siz'
    jne .lc_try_blink
    cmp byte [rsi+8], 'e'
    jne .lc_try_blink
    add rsi, 9
    call lc_skip_to_value
    xor eax, eax
.lc_fs_digit:
    movzx ecx, byte [rsi]
    cmp cl, '0'
    jb .lc_fs_done
    cmp cl, '9'
    ja .lc_fs_done
    imul eax, 10
    sub ecx, '0'
    add eax, ecx
    inc rsi
    jmp .lc_fs_digit
.lc_fs_done:
    mov [cfg_font_size], rax
    jmp .lc_skip_line

.lc_handle_font_path:
    ; "font_path = /full/path/to/font.ttf"
    cmp dword [rsi+4], '_pat'
    jne .lc_try_blink
    cmp byte [rsi+8], 'h'
    jne .lc_try_blink
    add rsi, 9
    call lc_skip_to_value
    lea rdi, [cfg_font_path]
    xor rcx, rcx
.lc_fp_copy:
    movzx eax, byte [rsi]
    test al, al
    jz .lc_fp_done
    cmp al, 10
    je .lc_fp_done
    cmp al, 13
    je .lc_fp_done
    cmp rcx, 510
    jge .lc_fp_done
    mov [rdi + rcx], al
    inc rsi
    inc rcx
    jmp .lc_fp_copy
.lc_fp_done:
    mov byte [rdi + rcx], 0
    test rcx, rcx
    jz .lc_skip_line
    mov qword [cfg_font_path_set], 1
    jmp .lc_skip_line

.lc_handle_font_weight:
    ; "font_weight = 100..900" (variable-font axis position)
    ; Note: glass also has a different cfg_font_bold "font_weight = bold"
    ; key — we re-use the same key but only consume it when the value
    ; starts with a digit (so "font_weight = bold" still falls through
    ; to the existing string-parsing block).
    cmp dword [rsi+4], '_wei'
    jne .lc_try_blink
    cmp word [rsi+8], 'gh'
    jne .lc_try_blink
    cmp byte [rsi+10], 't'
    jne .lc_try_blink
    push rsi                          ; remember key start so we can fall through
    add rsi, 11
    call lc_skip_to_value
    movzx eax, byte [rsi]
    cmp al, '0'
    jb .lc_fw_fall
    cmp al, '9'
    ja .lc_fw_fall
    xor eax, eax
.lc_fw_digit:
    movzx ecx, byte [rsi]
    cmp cl, '0'
    jb .lc_fw_done
    cmp cl, '9'
    ja .lc_fw_done
    imul eax, 10
    sub ecx, '0'
    add eax, ecx
    inc rsi
    jmp .lc_fw_digit
.lc_fw_done:
    mov [cfg_ttf_weight], rax
    pop rsi                           ; (discard saved start)
    jmp .lc_skip_line
.lc_fw_fall:
    pop rsi                           ; restore for the legacy "bold" matcher
    jmp .lc_try_blink

.lc_try_blink:
    ; Match "cursor_blink"
    cmp dword [rsi], 'curs'
    jne .lc_try_opacity
    cmp dword [rsi+4], 'or_b'
    jne .lc_try_opacity
    cmp word [rsi+8], 'li'
    jne .lc_try_opacity
    cmp word [rsi+10], 'nk'
    jne .lc_try_opacity
    add rsi, 12
    call lc_skip_to_value
    xor eax, eax
.lc_blink_digit:
    movzx ecx, byte [rsi]
    cmp cl, '0'
    jb .lc_blink_done
    cmp cl, '9'
    ja .lc_blink_done
    imul eax, 10
    sub ecx, '0'
    add eax, ecx
    inc rsi
    jmp .lc_blink_digit
.lc_blink_done:
    mov [cfg_blink_ms], rax
    jmp .lc_skip_line

.lc_try_opacity:
    ; Match "opacity" but NOT "opacity_cycle" (handled separately).
    cmp dword [rsi], 'opac'
    jne .lc_try_opacity_cycle
    cmp word [rsi+4], 'it'
    jne .lc_try_opacity_cycle
    cmp byte [rsi+6], 'y'
    jne .lc_try_opacity_cycle
    movzx eax, byte [rsi+7]
    cmp al, '_'
    je .lc_try_opacity_cycle         ; this is opacity_cycle, not opacity
    cmp al, 'a'
    jb .lc_op_is_opacity
    cmp al, 'z'
    jbe .lc_try_opacity_cycle        ; some other "opacityXXX" key
.lc_op_is_opacity:
    add rsi, 7
    call lc_skip_to_value
    ; Parse percentage 0..100
    xor eax, eax
.lc_op_digit:
    movzx ecx, byte [rsi]
    cmp cl, '0'
    jb .lc_op_done
    cmp cl, '9'
    ja .lc_op_done
    imul eax, 10
    sub ecx, '0'
    add eax, ecx
    inc rsi
    jmp .lc_op_digit
.lc_op_done:
    cmp eax, 100
    jbe .lc_op_clamped
    mov eax, 100
.lc_op_clamped:
    ; Convert percent to 0..255: byte = pct * 255 / 100
    imul eax, 255
    mov ecx, 100
    xor edx, edx
    div ecx
    mov [cfg_opacity], al
    mov byte [cfg_opacity_set], 1
    jmp .lc_skip_line

.lc_try_opacity_cycle:
    ; Match "opacity_cycle = 100,75,50,25,0" (decimal percentages).
    cmp dword [rsi], 'opac'
    jne .lc_try_bg_cycle
    cmp dword [rsi+4], 'ity_'
    jne .lc_try_bg_cycle
    cmp dword [rsi+8], 'cycl'
    jne .lc_try_bg_cycle
    cmp byte [rsi+12], 'e'
    jne .lc_try_bg_cycle
    add rsi, 13
    call lc_skip_to_value
    xor r12, r12                    ; count
.lc_oc_one:
    movzx eax, byte [rsi]
    cmp al, '0'
    jb .lc_oc_done
    cmp al, '9'
    ja .lc_oc_done
    ; Parse one decimal number into eax
    xor eax, eax
.lc_oc_digits:
    movzx ecx, byte [rsi]
    cmp cl, '0'
    jb .lc_oc_have
    cmp cl, '9'
    ja .lc_oc_have
    imul eax, 10
    sub ecx, '0'
    add eax, ecx
    inc rsi
    jmp .lc_oc_digits
.lc_oc_have:
    cmp eax, 100
    jbe .lc_oc_clamped
    mov eax, 100
.lc_oc_clamped:
    cmp r12, 16
    jge .lc_oc_skip_sep
    mov [opacity_cycle_vals + r12], al
    inc r12
.lc_oc_skip_sep:
    movzx ecx, byte [rsi]
    cmp cl, ','
    je .lc_oc_sep_inc
    cmp cl, ' '
    je .lc_oc_sep_inc
    cmp cl, 9
    je .lc_oc_sep_inc
    jmp .lc_oc_done
.lc_oc_sep_inc:
    inc rsi
    jmp .lc_oc_one
.lc_oc_done:
    mov [opacity_cycle_count], r12
    jmp .lc_skip_line

.lc_try_bg_cycle:
    ; Match "bg_cycle = #aaa,#bbb,#ccc,..."
    cmp dword [rsi], 'bg_c'
    jne .lc_try_font_weight
    cmp dword [rsi+4], 'ycle'
    jne .lc_try_font_weight
    add rsi, 8
    call lc_skip_to_value
    xor r12, r12                    ; count of colors parsed
.lc_bgc_one:
    cmp byte [rsi], '#'
    jne .lc_bgc_done
    inc rsi
    call hex_to_pixel
    cmp r12, 16
    jge .lc_bgc_skip                ; cap at 16 entries
    mov [bg_cycle_pixels + r12*4], eax
    inc r12
.lc_bgc_skip:
    ; Skip remaining hex chars
.lc_bgc_skip_hex:
    movzx eax, byte [rsi]
    cmp al, '0'
    jb .lc_bgc_after_hex
    cmp al, '9'
    jbe .lc_bgc_skip_hex_inc
    cmp al, 'a'
    jb .lc_bgc_chk_upper
    cmp al, 'f'
    jbe .lc_bgc_skip_hex_inc
    jmp .lc_bgc_after_hex
.lc_bgc_chk_upper:
    cmp al, 'A'
    jb .lc_bgc_after_hex
    cmp al, 'F'
    ja .lc_bgc_after_hex
.lc_bgc_skip_hex_inc:
    inc rsi
    jmp .lc_bgc_skip_hex
.lc_bgc_after_hex:
    ; Skip whitespace + commas between entries
.lc_bgc_skip_sep:
    movzx eax, byte [rsi]
    cmp al, ','
    je .lc_bgc_sep_inc
    cmp al, ' '
    je .lc_bgc_sep_inc
    cmp al, 9
    je .lc_bgc_sep_inc
    jmp .lc_bgc_check_more
.lc_bgc_sep_inc:
    inc rsi
    jmp .lc_bgc_skip_sep
.lc_bgc_check_more:
    cmp byte [rsi], '#'
    je .lc_bgc_one
.lc_bgc_done:
    mov [bg_cycle_count], r12
    jmp .lc_skip_line

.lc_try_font_weight:
    ; Match "font_weight = bold"
    cmp dword [rsi], 'font'
    jne .lc_try_osc8_underline
    cmp dword [rsi+4], '_wei'
    jne .lc_skip_line
    cmp word [rsi+8], 'gh'
    jne .lc_skip_line
    cmp byte [rsi+10], 't'
    jne .lc_skip_line
    add rsi, 11
    call lc_skip_to_value
    cmp dword [rsi], 'bold'
    jne .lc_skip_line
    mov byte [cfg_font_bold], 1
    jmp .lc_skip_line

.lc_try_osc8_underline:
    ; Match "osc8_underline = 0" or "osc8_underline = 1". Default 1
    ; (matches the de-facto terminal convention). Set to 0 if you use
    ; an app that abuses OSC 8 — e.g. CC opens spans that effectively
    ; never close, leaving the whole screen visually underlined.
    cmp dword [rsi], 'osc8'
    jne .lc_try_palette
    cmp dword [rsi+4], '_und'
    jne .lc_skip_line
    cmp dword [rsi+8], 'erli'
    jne .lc_skip_line
    cmp word [rsi+12], 'ne'
    jne .lc_skip_line
    add rsi, 14
    call lc_skip_to_value
    movzx eax, byte [rsi]
    sub eax, '0'
    cmp eax, 1
    ja .lc_skip_line
    mov [cfg_osc8_underline], al
    jmp .lc_skip_line

.lc_try_palette:
    ; Match "palette = NAME" — bundled themes that overwrite slots 0..15.
    ; Re-applies any cfg_bg/cfg_fg that were set BEFORE this line, so an
    ; earlier "bg = #..." doesn't get clobbered by the theme. Lines after
    ; this one (bg/fg/colorN) override individual slots normally.
    cmp dword [rsi], 'pale'
    jne .lc_try_color
    cmp word [rsi+4], 'tt'
    jne .lc_try_color
    cmp byte [rsi+6], 'e'
    jne .lc_try_color
    movzx eax, byte [rsi+7]
    cmp al, ' '
    je .lc_pal_val
    cmp al, 9
    je .lc_pal_val
    cmp al, '='
    je .lc_pal_val
    jmp .lc_try_color
.lc_pal_val:
    add rsi, 7
    call lc_skip_to_value
    ; Try each known theme name (.lc_match_token is a local helper below).
    mov ecx, 5
    lea rdi, [.lcp_n_kitty]
    call .lc_match_token
    je .lcp_use_kitty
    mov ecx, 3
    lea rdi, [.lcp_n_vga]
    call .lc_match_token
    je .lcp_use_vga
    mov ecx, 14
    lea rdi, [.lcp_n_solarized]
    call .lc_match_token
    je .lcp_use_solarized
    mov ecx, 7
    lea rdi, [.lcp_n_dracula]
    call .lc_match_token
    je .lcp_use_dracula
    mov ecx, 12
    lea rdi, [.lcp_n_gruvbox]
    call .lc_match_token
    je .lcp_use_gruvbox
    mov ecx, 4
    lea rdi, [.lcp_n_nord]
    call .lc_match_token
    je .lcp_use_nord
    mov ecx, 11
    lea rdi, [.lcp_n_tokyonight]
    call .lc_match_token
    je .lcp_use_tokyonight
    mov ecx, 7
    lea rdi, [.lcp_n_monokai]
    call .lc_match_token
    je .lcp_use_monokai
    jmp .lc_skip_line                     ; unknown name → ignore
.lcp_use_kitty:      lea rsi, [theme_kitty]            ; jmp .lcp_apply
                     jmp .lcp_apply
.lcp_use_vga:        lea rsi, [theme_vga]
                     jmp .lcp_apply
.lcp_use_solarized:  lea rsi, [theme_solarized_dark]
                     jmp .lcp_apply
.lcp_use_dracula:    lea rsi, [theme_dracula]
                     jmp .lcp_apply
.lcp_use_gruvbox:    lea rsi, [theme_gruvbox_dark]
                     jmp .lcp_apply
.lcp_use_nord:       lea rsi, [theme_nord]
                     jmp .lcp_apply
.lcp_use_tokyonight: lea rsi, [theme_tokyonight]
                     jmp .lcp_apply
.lcp_use_monokai:    lea rsi, [theme_monokai]
.lcp_apply:
    lea rdi, [palette]
    mov ecx, 16
.lcp_copy:
    mov eax, [rsi]
    mov [rdi], eax
    add rsi, 4
    add rdi, 4
    dec ecx
    jnz .lcp_copy
    ; Re-apply any earlier bg/fg overrides so the theme doesn't undo them.
    cmp byte [cfg_bg_set], 1
    jne .lcp_chk_fg
    mov eax, [cfg_bg_pixel]
    mov [palette], eax
.lcp_chk_fg:
    cmp byte [cfg_fg_set], 1
    jne .lcp_done
    mov eax, [cfg_fg_pixel]
    mov [palette + 7*4], eax
.lcp_done:
    jmp .lc_skip_line

.lcp_n_kitty:      db "kitty"
.lcp_n_vga:        db "vga"
.lcp_n_solarized:  db "solarized-dark"
.lcp_n_dracula:    db "dracula"
.lcp_n_gruvbox:    db "gruvbox-dark"
.lcp_n_nord:       db "nord"
.lcp_n_tokyonight: db "tokyonight"
.lcp_n_monokai:    db "monokai"

.lc_try_color:
    ; Match "colorN = #RRGGBB" or "colorNN = #RRGGBB" (N = 0..15). Sets
    ; palette[N] directly. Order in the file matters: a theme line later
    ; than this one would overwrite — that's documented.
    cmp dword [rsi], 'colo'
    jne .lc_try_keybind
    cmp byte [rsi+4], 'r'
    jne .lc_try_keybind
    movzx eax, byte [rsi+5]
    cmp al, '0'
    jb .lc_try_keybind
    cmp al, '9'
    ja .lc_try_keybind
    sub eax, '0'
    movzx ecx, byte [rsi+6]
    cmp cl, '0'
    jb .lc_color_idx_done
    cmp cl, '9'
    ja .lc_color_idx_done
    sub ecx, '0'
    imul eax, 10
    add eax, ecx
    add rsi, 7
    jmp .lc_color_check
.lc_color_idx_done:
    add rsi, 6
.lc_color_check:
    cmp eax, 15
    ja .lc_skip_line                      ; out of range
    push rax                              ; index
    call lc_skip_to_value
    cmp byte [rsi], '#'
    jne .lc_color_drop
    inc rsi
    call hex_to_pixel
    pop rcx
    mov [palette + rcx*4], eax
    jmp .lc_skip_line
.lc_color_drop:
    pop rax
    jmp .lc_skip_line

; Local helper: rdi = static name string (no terminator), ecx = length.
; rsi = current value cursor in cfg_buf. Returns ZF=1 if the next `ecx`
; bytes at rsi exactly equal [rdi..rdi+ecx) AND the byte at rsi+ecx is
; an end-of-token (whitespace, newline, NUL, '#'). rsi/rdi/rcx preserved.
; Defined as a local label of load_config so .lc_try_keybind below stays
; in load_config's local-label scope.
.lc_match_token:
    push rsi
    push rdi
    push rcx
.lc_mt_cp:
    test ecx, ecx
    jz .lc_mt_check_end
    movzx eax, byte [rsi]
    cmp al, byte [rdi]
    jne .lc_mt_no
    inc rsi
    inc rdi
    dec ecx
    jmp .lc_mt_cp
.lc_mt_check_end:
    movzx eax, byte [rsi]
    test al, al
    jz .lc_mt_yes
    cmp al, 10
    je .lc_mt_yes
    cmp al, 13
    je .lc_mt_yes
    cmp al, ' '
    je .lc_mt_yes
    cmp al, 9
    je .lc_mt_yes
    cmp al, '#'
    je .lc_mt_yes
.lc_mt_no:
    pop rcx
    pop rdi
    pop rsi
    or eax, 1                              ; clear ZF
    ret
.lc_mt_yes:
    pop rcx
    pop rdi
    pop rsi
    xor eax, eax                           ; ZF=1
    ret

.lc_try_keybind:
    ; Match "key.NAME = ..." for the five Alt-action bindings.
    cmp dword [rsi], 'key.'
    jne .lc_skip_line
    add rsi, 4
    ; Identify the binding name; advance rsi past it on match.
    cmp dword [rsi], 'font'
    jne .lc_kb_try_bg
    cmp byte [rsi+4], '_'
    jne .lc_kb_try_bg
    ; "font_inc", "font_dec", or "font_reset"
    cmp dword [rsi+5], 'inc '
    je .lc_kb_font_inc
    cmp dword [rsi+5], 'inc='
    je .lc_kb_font_inc
    cmp dword [rsi+5], 'dec '
    je .lc_kb_font_dec
    cmp dword [rsi+5], 'dec='
    je .lc_kb_font_dec
    cmp dword [rsi+5], 'rese'
    jne .lc_skip_line
    cmp byte [rsi+9], 't'
    jne .lc_skip_line
    add rsi, 10
    mov edi, KB_FONT_RESET
    jmp .lc_kb_call
.lc_kb_font_inc:
    add rsi, 8
    mov edi, KB_FONT_INC
    jmp .lc_kb_call
.lc_kb_font_dec:
    add rsi, 8
    mov edi, KB_FONT_DEC
    jmp .lc_kb_call
.lc_kb_try_bg:
    cmp dword [rsi], 'bg_c'
    jne .lc_kb_try_opacity
    cmp dword [rsi+4], 'ycle'
    jne .lc_kb_try_opacity
    add rsi, 8
    mov edi, KB_BG_CYCLE
    jmp .lc_kb_call
.lc_kb_try_opacity:
    cmp dword [rsi], 'opac'
    jne .lc_skip_line
    cmp word [rsi+4], 'it'
    jne .lc_skip_line
    cmp byte [rsi+6], 'y'
    jne .lc_skip_line
    add rsi, 7
    mov edi, KB_OPACITY
.lc_kb_call:
    call lc_skip_to_value
    call parse_keybinding
    jmp .lc_skip_line

.lc_skip_line:
    cmp byte [rsi], 0
    je .lc_done
    cmp byte [rsi], 10
    je .lc_next_line
    inc rsi
    jmp .lc_skip_line
.lc_next_line:
    inc rsi
    jmp .lc_line_loop

.lc_done:
    pop r13
    pop r12
    pop rbx
    ret

; Helper: skip whitespace and '=' to reach value
; rsi points past key name, advances to value start
lc_skip_to_value:
.lcstv_loop:
    cmp byte [rsi], ' '
    je .lcstv_next
    cmp byte [rsi], 9
    je .lcstv_next
    cmp byte [rsi], '='
    je .lcstv_next
    ret
.lcstv_next:
    inc rsi
    jmp .lcstv_loop

; Parse "#RRGGBB" hex string to 0x00RRGGBB pixel value
; rsi = pointer to first hex char (after '#')
; Returns: eax = pixel value, advances rsi by 6
hex_to_pixel:
    push rbx
    xor eax, eax
    ; Parse 6 hex digits
    mov ecx, 6
.htp_loop:
    test ecx, ecx
    jz .htp_done
    shl eax, 4
    movzx ebx, byte [rsi]
    cmp bl, '0'
    jb .htp_zero
    cmp bl, '9'
    jbe .htp_digit
    cmp bl, 'a'
    jb .htp_upper
    cmp bl, 'f'
    jbe .htp_lower
    jmp .htp_upper
.htp_digit:
    sub ebx, '0'
    jmp .htp_add
.htp_lower:
    sub ebx, 'a'
    add ebx, 10
    jmp .htp_add
.htp_upper:
    cmp bl, 'A'
    jb .htp_zero
    cmp bl, 'F'
    ja .htp_zero
    sub ebx, 'A'
    add ebx, 10
    jmp .htp_add
.htp_zero:
    xor ebx, ebx
.htp_add:
    or eax, ebx
    inc rsi
    dec ecx
    jmp .htp_loop
.htp_done:
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; URL detection and clicking
; ══════════════════════════════════════════════════════════════════════

; Scan visible grid for URLs (http:// or https://)
scan_urls:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov qword [url_count], 0
    mov qword [url_str_pos], 0
    xor r12, r12             ; current row

.su_row_loop:
    cmp r12, [grid_rows]
    jge .su_done
    xor r13, r13             ; current col

.su_col_loop:
    cmp r13, [grid_cols]
    jge .su_next_row

    ; Check for 'h' at this position
    mov rax, r12
    imul rax, MAX_COLS
    add rax, r13
    imul rax, CELL_SIZE
    movzx edx, word [grid + rax]
    cmp dl, 'h'
    jne .su_next_col

    ; Check "http" at positions col, col+1, col+2, col+3
    mov rax, r13
    add rax, 3
    cmp rax, [grid_cols]
    jge .su_next_col

    ; Check 't'
    mov rax, r12
    imul rax, MAX_COLS
    add rax, r13
    inc rax
    imul rax, CELL_SIZE
    movzx edx, word [grid + rax]
    cmp dl, 't'
    jne .su_next_col

    ; Check 't'
    mov rax, r12
    imul rax, MAX_COLS
    add rax, r13
    add rax, 2
    imul rax, CELL_SIZE
    movzx edx, word [grid + rax]
    cmp dl, 't'
    jne .su_next_col

    ; Check 'p'
    mov rax, r12
    imul rax, MAX_COLS
    add rax, r13
    add rax, 3
    imul rax, CELL_SIZE
    movzx edx, word [grid + rax]
    cmp dl, 'p'
    jne .su_next_col

    ; Check for "://" after "http" or "https"
    mov r14, r13
    add r14, 4               ; position after "http"
    cmp r14, [grid_cols]
    jge .su_next_col

    ; Check if next char is 's' (https) or ':' (http)
    mov rax, r12
    imul rax, MAX_COLS
    add rax, r14
    imul rax, CELL_SIZE
    movzx edx, word [grid + rax]
    cmp dl, 's'
    jne .su_check_colon
    inc r14                  ; skip 's'
.su_check_colon:
    ; Need "://" at r14, r14+1, r14+2
    mov rax, r14
    add rax, 2
    cmp rax, [grid_cols]
    jge .su_next_col

    mov rax, r12
    imul rax, MAX_COLS
    add rax, r14
    imul rax, CELL_SIZE
    movzx edx, word [grid + rax]
    cmp dl, ':'
    jne .su_next_col

    mov rax, r12
    imul rax, MAX_COLS
    add rax, r14
    inc rax
    imul rax, CELL_SIZE
    movzx edx, word [grid + rax]
    cmp dl, '/'
    jne .su_next_col

    mov rax, r12
    imul rax, MAX_COLS
    add rax, r14
    add rax, 2
    imul rax, CELL_SIZE
    movzx edx, word [grid + rax]
    cmp dl, '/'
    jne .su_next_col

    ; Found URL start at (r12, r13). Scan to find end.
    mov r15, r14
    add r15, 3               ; position after "://"

.su_url_scan:
    cmp r15, [grid_cols]
    jge .su_url_found
    mov rax, r12
    imul rax, MAX_COLS
    add rax, r15
    imul rax, CELL_SIZE
    movzx edx, word [grid + rax]
    ; Stop at whitespace or certain delimiters
    cmp dl, ' '
    je .su_url_found
    cmp dl, 0x20             ; space (redundant but clear)
    jb .su_url_found
    cmp dl, ')'
    je .su_url_found
    cmp dl, ']'
    je .su_url_found
    cmp dl, '>'
    je .su_url_found
    cmp dl, '"'
    je .su_url_found
    cmp dl, 0x27             ; single quote
    je .su_url_found
    inc r15
    jmp .su_url_scan

.su_url_found:
    ; URL spans from (r12, r13) to (r12, r15-1)
    ; Store in url_list if room
    mov rax, [url_count]
    cmp rax, 32
    jge .su_next_col

    ; Extract URL text into url_strings
    mov rbx, [url_str_pos]
    mov rcx, r13             ; start col
.su_extract:
    cmp rcx, r15
    jge .su_extract_done
    mov rax, rbx
    cmp rax, 8190
    jge .su_extract_done
    ; Read char from grid
    push rcx
    mov rax, r12
    imul rax, MAX_COLS
    add rax, rcx
    imul rax, CELL_SIZE
    movzx edx, word [grid + rax]
    pop rcx
    cmp dl, 0x7F
    jbe .su_ext_store
    mov dl, '?'
.su_ext_store:
    mov [url_strings + rbx], dl
    inc rbx
    inc rcx
    jmp .su_extract
.su_extract_done:
    mov byte [url_strings + rbx], 0  ; null-terminate
    mov rcx, rbx
    sub rcx, [url_str_pos]  ; str_len

    ; Store url_list entry (24 bytes)
    ; start_row(2), start_col(2), end_row(2), end_col(2),
    ; str_offset(4), str_len(4), pad(8)
    mov rax, [url_count]
    imul rax, 24
    mov word [url_list + rax], r12w       ; start_row
    mov word [url_list + rax + 2], r13w   ; start_col
    mov word [url_list + rax + 4], r12w   ; end_row (same row)
    mov rdx, r15
    dec rdx
    mov word [url_list + rax + 6], dx     ; end_col
    mov edx, [url_str_pos]
    mov [url_list + rax + 8], edx         ; str_offset
    mov [url_list + rax + 12], ecx        ; str_len
    mov qword [url_list + rax + 16], 0    ; pad

    inc rbx                  ; skip null terminator
    mov [url_str_pos], rbx
    inc qword [url_count]
    ; Skip past URL in column scan
    mov r13, r15
    jmp .su_col_loop

.su_next_col:
    inc r13
    jmp .su_col_loop
.su_next_row:
    inc r12
    jmp .su_row_loop

.su_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Open URL at grid position (row, col) if one exists
; rdi = row, rsi = col
url_open_at:
    push rbx
    push r12
    push r13
    mov r12, rdi             ; row
    mov r13, rsi             ; col

    ; First, check if this cell has an OSC 8 hyperlink id.
    mov rax, r12
    imul rax, MAX_COLS
    add rax, r13
    imul rax, CELL_SIZE
    movzx eax, byte [grid + rax + 5]
    test eax, eax
    jz .uoa_no_osc8
    ; Look up URI offset (must survive the upcoming syscall, so park it
    ; in r13 — we no longer need the col after this point).
    mov r13d, [osc8_uri_offsets + rax*4]
    mov rax, SYS_FORK
    syscall
    test rax, rax
    jnz .uoa_done            ; parent done
    sub rsp, 32
    lea rax, [xdg_open]
    mov [rsp], rax
    lea rax, [osc8_uris + r13]
    mov [rsp+8], rax
    mov qword [rsp+16], 0
    mov rax, SYS_EXECVE
    lea rdi, [xdg_open]
    mov rsi, rsp
    mov rdx, [envp]
    syscall
    mov rdi, 1
    mov rax, SYS_EXIT
    syscall
.uoa_no_osc8:

    xor rbx, rbx             ; url index
.uoa_loop:
    cmp rbx, [url_count]
    jge .uoa_done

    mov rax, rbx
    imul rax, 24
    ; Check if (row, col) is within this URL's range
    movzx ecx, word [url_list + rax]       ; start_row
    cmp r12d, ecx
    jl .uoa_next
    movzx ecx, word [url_list + rax + 4]   ; end_row
    cmp r12d, ecx
    jg .uoa_next
    movzx ecx, word [url_list + rax + 2]   ; start_col
    cmp r13d, ecx
    jl .uoa_next
    movzx ecx, word [url_list + rax + 6]   ; end_col
    cmp r13d, ecx
    jg .uoa_next

    ; Match! Fork and exec xdg-open with the URL
    mov r12d, [url_list + rax + 8]   ; str_offset
    mov r13d, [url_list + rax + 12]  ; str_len (for reference)

    mov rax, SYS_FORK
    syscall
    test rax, rax
    jnz .uoa_done            ; parent: done
    ; Child process
    ; Build argv: ["/usr/bin/xdg-open", url_string, NULL]
    sub rsp, 32
    lea rax, [xdg_open]
    mov [rsp], rax
    lea rax, [url_strings + r12]
    mov [rsp+8], rax
    mov qword [rsp+16], 0
    mov rax, SYS_EXECVE
    lea rdi, [xdg_open]
    mov rsi, rsp
    mov rdx, [envp]
    syscall
    ; If exec fails, exit child
    mov rdi, 1
    mov rax, SYS_EXIT
    syscall

.uoa_next:
    inc rbx
    jmp .uoa_loop

.uoa_done:
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Utility functions
; ══════════════════════════════════════════════════════════════════════

strlen:
    push rdi
    xor eax, eax
.sl_loop:
    cmp byte [rdi], 0
    je .sl_done
    inc rdi
    inc eax
    jmp .sl_loop
.sl_done:
    pop rdi
    ret

itoa:
    push rbx
    push rcx
    mov rbx, rdi
    xor ecx, ecx
    mov r8, 10
.itoa_div:
    xor edx, edx
    div r8
    add dl, '0'
    push rdx
    inc ecx
    test rax, rax
    jnz .itoa_div
    xor eax, eax
.itoa_pop:
    pop rdx
    mov [rbx + rax], dl
    inc eax
    dec ecx
    jnz .itoa_pop
    mov byte [rbx + rax], 0
    pop rcx
    pop rbx
    ret


; hkp_dbg_itoa: rax = number, rdi = output (advances rdi).
; Preserves all registers except rax, rdi, rdx.
hkp_dbg_itoa:
    push rbx
    push rcx
    push r8
    mov rbx, rdi
    xor ecx, ecx
    mov r8, 10
.hi_div:
    xor edx, edx
    div r8
    add dl, '0'
    push rdx
    inc ecx
    test rax, rax
    jnz .hi_div
    xor eax, eax
.hi_pop:
    pop rdx
    mov [rbx + rax], dl
    inc eax
    dec ecx
    jnz .hi_pop
    add rdi, rax
    pop r8
    pop rcx
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Mouse SGR reporting
; ══════════════════════════════════════════════════════════════════════

; Send mouse event in SGR format: ESC[<button;col;row(M|m)
; edi = button (0-2 for click, 32+ for motion, 64+ for scroll)
; esi = col (1-based)
; edx = row (1-based)
; ecx = final char ('M' for press/motion, 'm' for release)
send_mouse_sgr:
    push rbx
    push r12
    push r13
    push r14
    mov r12d, edi            ; button
    mov r13d, esi            ; col
    mov r14d, edx            ; row
    mov ebx, ecx             ; final char

    ; Build ESC[< prefix
    lea rdi, [mouse_seq_buf]
    mov byte [rdi], 27       ; ESC
    mov byte [rdi+1], '['
    mov byte [rdi+2], '<'
    add rdi, 3

    ; Append button number
    mov eax, r12d
    call write_decimal

    ; Semicolon
    mov byte [rdi], ';'
    inc rdi

    ; Append col
    mov eax, r13d
    call write_decimal

    ; Semicolon
    mov byte [rdi], ';'
    inc rdi

    ; Append row
    mov eax, r14d
    call write_decimal

    ; Final char (M or m)
    mov [rdi], bl
    inc rdi

    ; Calculate length
    lea rax, [mouse_seq_buf]
    sub rdi, rax
    mov rdx, rdi             ; length

    ; Write to PTY
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [mouse_seq_buf]
    syscall

    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Write decimal number to [rdi], advance rdi
; eax = number to write
write_decimal:
    push rbx
    push rcx
    ; Handle 0 specially
    test eax, eax
    jnz .wd_nonzero
    mov byte [rdi], '0'
    inc rdi
    pop rcx
    pop rbx
    ret
.wd_nonzero:
    ; Push digits in reverse
    xor ecx, ecx
    mov ebx, 10
.wd_div:
    xor edx, edx
    div ebx
    add dl, '0'
    push rdx
    inc ecx
    test eax, eax
    jnz .wd_div
    ; Pop digits in order
.wd_pop:
    pop rax
    mov [rdi], al
    inc rdi
    dec ecx
    jnz .wd_pop
    pop rcx
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Font name setup
; ══════════════════════════════════════════════════════════════════════

; Build dynamic font name based on cfg_font_size
; Called after load_config, before x11_open_font
setup_font_name:
    push rbx
    push r12

    ; Always clear stale font names before a (possibly repeat) build.
    ; This matters for runtime size changes: e.g., a 13→10 jump must
    ; not leave the previous bold companion (13-bold) in place since
    ; 10 has no matching bold variant.
    mov qword [dyn_font_name_len], 0
    mov qword [dyn_bold_font_name_len], 0

    mov rax, [cfg_font_size]
    test rax, rax
    jz .sfn_done             ; no font_size configured, use default

    ; Find matching font entry
    cmp rax, 10
    je .sfn_10
    cmp rax, 13
    je .sfn_13
    cmp rax, 15
    je .sfn_15
    cmp rax, 18
    je .sfn_18
    cmp rax, 20
    je .sfn_20
    cmp rax, 22
    je .sfn_22
    cmp rax, 24
    je .sfn_24
    cmp rax, 28
    je .sfn_28
    cmp rax, 32
    je .sfn_32
    jmp .sfn_done            ; unsupported size, use default

.sfn_10:
    lea rsi, [font_10]
    mov r12, font_10_len
    jmp .sfn_copy
.sfn_13:
    lea rsi, [font_13]
    mov r12, font_13_len
    jmp .sfn_copy
.sfn_15:
    lea rsi, [font_15]
    mov r12, font_15_len
    jmp .sfn_copy
.sfn_18:
    lea rsi, [font_18]
    mov r12, font_18_len
    jmp .sfn_copy
.sfn_20:
    lea rsi, [font_20]
    mov r12, font_20_len
    jmp .sfn_copy
.sfn_22:
    lea rsi, [font_22]
    mov r12, font_22_len
    jmp .sfn_copy
.sfn_24:
    lea rsi, [font_24]
    mov r12, font_24_len
    jmp .sfn_copy
.sfn_28:
    lea rsi, [font_28]
    mov r12, font_28_len
    jmp .sfn_copy
.sfn_32:
    lea rsi, [font_32]
    mov r12, font_32_len

.sfn_copy:
    ; Copy font name to dyn_font_name
    lea rdi, [dyn_font_name]
    xor ecx, ecx
.sfn_cp:
    cmp rcx, r12
    jge .sfn_set_len
    movzx eax, byte [rsi + rcx]
    mov [rdi + rcx], al
    inc rcx
    jmp .sfn_cp
.sfn_set_len:
    mov byte [rdi + rcx], 0  ; null-terminate
    mov [dyn_font_name_len], r12

    ; Pick bold companion (skipped for sizes with no matching bold)
    mov rax, [cfg_font_size]
    cmp rax, 13
    je .sfn_b13
    cmp rax, 15
    je .sfn_b15
    cmp rax, 18
    je .sfn_b18
    cmp rax, 22
    je .sfn_b22
    cmp rax, 24
    je .sfn_b24
    cmp rax, 28
    je .sfn_b28
    cmp rax, 32
    je .sfn_b32
    jmp .sfn_done            ; no bold for this size
.sfn_b13:
    lea rsi, [font_13_bold]
    mov r12, font_13_bold_len
    jmp .sfn_bcopy
.sfn_b15:
    lea rsi, [font_15_bold]
    mov r12, font_15_bold_len
    jmp .sfn_bcopy
.sfn_b18:
    lea rsi, [font_18_bold]
    mov r12, font_18_bold_len
    jmp .sfn_bcopy
.sfn_b22:
    lea rsi, [font_22_bold]
    mov r12, font_22_bold_len
    jmp .sfn_bcopy
.sfn_b24:
    lea rsi, [font_24_bold]
    mov r12, font_24_bold_len
    jmp .sfn_bcopy
.sfn_b28:
    lea rsi, [font_28_bold]
    mov r12, font_28_bold_len
    jmp .sfn_bcopy
.sfn_b32:
    lea rsi, [font_32_bold]
    mov r12, font_32_bold_len
.sfn_bcopy:
    lea rdi, [dyn_bold_font_name]
    xor ecx, ecx
.sfn_bcp:
    cmp rcx, r12
    jge .sfn_bset_len
    movzx eax, byte [rsi + rcx]
    mov [rdi + rcx], al
    inc rcx
    jmp .sfn_bcp
.sfn_bset_len:
    mov byte [rdi + rcx], 0
    mov [dyn_bold_font_name_len], r12

    ; If the user set font_weight = bold, alias the regular font to
    ; the bold XLFD. Bitmap "regular" is just a 1px stroke at 22pt
    ; which feels thin next to TTF terminals; using the bold variant
    ; everywhere thickens the baseline. (SGR 1 then has no further
    ; effect since terminus has no extra-bold beyond bold.)
    cmp byte [cfg_font_bold], 1
    jne .sfn_done
    mov rcx, [dyn_bold_font_name_len]
    test rcx, rcx
    jz .sfn_done
    lea rsi, [dyn_bold_font_name]
    lea rdi, [dyn_font_name]
    xor edx, edx
.sfn_alias_cp:
    cmp rdx, rcx
    jge .sfn_alias_term
    movzx eax, byte [rsi + rdx]
    mov [rdi + rdx], al
    inc rdx
    jmp .sfn_alias_cp
.sfn_alias_term:
    mov byte [rdi + rdx], 0
    mov [dyn_font_name_len], rcx

.sfn_done:
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Kitty graphics protocol — APC body handler
; ══════════════════════════════════════════════════════════════════════
; Wire format (all chunks are framed by VT_APC capture):
;   first chunk:  Ga=t,f=100,i=ID,q=2,m=1;<base64>
;   continue:     Gm=1;<base64>
;   final:        Gm=0;<base64>
;   place:        Ga=p,i=ID,c=W,r=H,q=2,C=1
;   delete:       Ga=d,d=i,i=ID,q=2
;
; Parsed key=value parameters end up in apc_kv_* BSS slots, then we
; dispatch by action.
section .bss
apc_kv_a:           resb 1          ; action: 't','p','T','d', 0=missing
apc_kv_i:           resd 1          ; image id (decimal)
apc_kv_f:           resd 1          ; format (24/32/100; default 32)
apc_kv_m:           resb 1          ; more chunks (0/1; default 0)
apc_kv_q:           resb 1          ; quiet level
apc_kv_C:           resb 1          ; 1 = don't move cursor
apc_kv_c:           resw 1          ; dest cell columns
apc_kv_r:           resw 1          ; dest cell rows
apc_kv_s:           resd 1          ; source pixel width (raw RGBA)
apc_kv_v:           resd 1          ; source pixel height (raw RGBA)
apc_kv_d:           resb 1          ; delete target ('a' / 'i')
apc_payload_off:    resq 1          ; offset of payload start in apc_body

section .text

; Reset apc_kv_* to safe defaults at the start of every APC.
apc_reset_kv:
    mov byte [apc_kv_a], 0
    mov dword [apc_kv_i], 0
    mov dword [apc_kv_f], 32
    mov byte [apc_kv_m], 0
    mov byte [apc_kv_q], 0
    mov byte [apc_kv_C], 0
    mov word [apc_kv_c], 0
    mov word [apc_kv_r], 0
    mov dword [apc_kv_s], 0
    mov dword [apc_kv_v], 0
    mov byte [apc_kv_d], 0
    ret

; Parse decimal at [rsi] into rax. Stops on first non-digit. rsi
; advances past the digits. Caller must zero rax beforehand if needed.
apc_parse_uint:
    xor eax, eax
.apu_loop:
    movzx ecx, byte [rsi]
    cmp cl, '0'
    jb .apu_done
    cmp cl, '9'
    ja .apu_done
    imul eax, eax, 10
    sub ecx, '0'
    add eax, ecx
    inc rsi
    jmp .apu_loop
.apu_done:
    ret

; Walk apc_body[1..apc_body_len], parsing comma-separated key=value
; tokens until ';' (start of payload) or end of body. On return,
; apc_payload_off holds the offset just past ';' (or apc_body_len if
; there's no payload in this chunk).
apc_parse_header:
    push rbx
    push r12
    call apc_reset_kv
    mov rbx, 1                       ; skip leading 'G'
    mov r12, [apc_body_len]
.aph_token:
    cmp rbx, r12
    jge .aph_done_no_payload
    movzx eax, byte [apc_body + rbx]
    cmp al, ';'
    je .aph_have_payload
    cmp al, ','
    jne .aph_key
    inc rbx
    jmp .aph_token
.aph_key:
    ; al = key letter (one byte), then expect '='.
    inc rbx
    cmp rbx, r12
    jge .aph_done_no_payload
    cmp byte [apc_body + rbx], '='
    jne .aph_skip_to_sep             ; malformed — skip to next , or ;
    inc rbx
    cmp rbx, r12
    jge .aph_done_no_payload
    lea rsi, [apc_body + rbx]
    call apc_parse_value             ; reads al as key, advances rsi past value
    sub rsi, apc_body
    mov rbx, rsi                     ; offset of the next ',' / ';' / end
    jmp .aph_token

.aph_skip_to_sep:
    cmp rbx, r12
    jge .aph_done_no_payload
    movzx eax, byte [apc_body + rbx]
    cmp al, ','
    je .aph_token
    cmp al, ';'
    je .aph_have_payload
    inc rbx
    jmp .aph_skip_to_sep

.aph_have_payload:
    inc rbx                          ; skip the ';'
    mov [apc_payload_off], rbx
    jmp .aph_ret
.aph_done_no_payload:
    mov [apc_payload_off], r12
.aph_ret:
    pop r12
    pop rbx
    ret

; rax = key letter, rsi = pointer to value start. Reads/parses based
; on key, advances rsi past the value (stops at ',' / ';' / EOL).
apc_parse_value:
    cmp al, 'a'
    je .apv_a
    cmp al, 'i'
    je .apv_i
    cmp al, 'f'
    je .apv_f
    cmp al, 'm'
    je .apv_m
    cmp al, 'q'
    je .apv_q
    cmp al, 'C'
    je .apv_C_kv
    cmp al, 'c'
    je .apv_c
    cmp al, 'r'
    je .apv_r
    cmp al, 's'
    je .apv_s
    cmp al, 'v'
    je .apv_v
    cmp al, 'd'
    je .apv_d
    jmp .apv_skip                    ; unknown key — skip
.apv_a:
    movzx eax, byte [rsi]
    mov [apc_kv_a], al
    inc rsi
    jmp .apv_skip                    ; tolerate trailing junk after 1-char val
.apv_i:
    call apc_parse_uint
    mov [apc_kv_i], eax
    jmp .apv_skip
.apv_f:
    call apc_parse_uint
    mov [apc_kv_f], eax
    jmp .apv_skip
.apv_m:
    call apc_parse_uint
    mov [apc_kv_m], al
    jmp .apv_skip
.apv_q:
    call apc_parse_uint
    mov [apc_kv_q], al
    jmp .apv_skip
.apv_C_kv:
    call apc_parse_uint
    mov [apc_kv_C], al
    jmp .apv_skip
.apv_c:
    call apc_parse_uint
    mov [apc_kv_c], ax
    jmp .apv_skip
.apv_r:
    call apc_parse_uint
    mov [apc_kv_r], ax
    jmp .apv_skip
.apv_s:
    call apc_parse_uint
    mov [apc_kv_s], eax
    jmp .apv_skip
.apv_v:
    call apc_parse_uint
    mov [apc_kv_v], eax
    jmp .apv_skip
.apv_d:
    movzx eax, byte [rsi]
    mov [apc_kv_d], al
    inc rsi
.apv_skip:
    movzx ecx, byte [rsi]
    test cl, cl
    jz .apv_done
    cmp cl, ','
    je .apv_done
    cmp cl, ';'
    je .apv_done
    inc rsi
    jmp .apv_skip
.apv_done:
    ret

; ──────────────────────────────────────────────────────────────────
; Base64 decoder.
;   rdi = src bytes (base64 ASCII), rsi = src length
;   rdx = dst buffer
; Returns rax = bytes written. Skips whitespace and '=' padding.
; Uses a 256-entry lookup table built lazily on first call.
; ──────────────────────────────────────────────────────────────────
section .bss
b64_table:          resb 256
b64_table_init:     resb 1
section .text

b64_init_table:
    push rdi
    push rcx
    push rax
    cmp byte [b64_table_init], 1
    je .b64it_done
    ; Mark all entries 0xFF (invalid)
    lea rdi, [b64_table]
    mov ecx, 256
    mov al, 0xFF
    rep stosb
    ; A..Z = 0..25
    xor ecx, ecx
.b64it_az:
    cmp ecx, 26
    jge .b64it_after_az
    mov eax, ecx
    add eax, 'A'
    mov [b64_table + rax], cl
    inc ecx
    jmp .b64it_az
.b64it_after_az:
    ; a..z = 26..51
    xor ecx, ecx
.b64it_atoz:
    cmp ecx, 26
    jge .b64it_after_atoz
    mov eax, ecx
    add eax, 'a'
    lea edx, [ecx + 26]
    mov [b64_table + rax], dl
    inc ecx
    jmp .b64it_atoz
.b64it_after_atoz:
    ; 0..9 = 52..61
    xor ecx, ecx
.b64it_09:
    cmp ecx, 10
    jge .b64it_after_09
    mov eax, ecx
    add eax, '0'
    lea edx, [ecx + 52]
    mov [b64_table + rax], dl
    inc ecx
    jmp .b64it_09
.b64it_after_09:
    mov byte [b64_table + '+'], 62
    mov byte [b64_table + '/'], 63
    mov byte [b64_table_init], 1
.b64it_done:
    pop rax
    pop rcx
    pop rdi
    ret

base64_decode:
    push rbx
    push r12
    push r13
    push r14
    push r15
    ; Stash params BEFORE the table init, since that helper does not
    ; preserve rdx (it iterates with edx during the build).
    mov r12, rdi                     ; src
    mov r13, rsi                     ; src len
    mov r14, rdx                     ; dst
    call b64_init_table
    xor r15, r15                     ; src index
    xor rbx, rbx                     ; dst written
    xor edx, edx                     ; running 24-bit accumulator
    xor ecx, ecx                     ; bits accumulated
.b64d_loop:
    cmp r15, r13
    jge .b64d_done
    movzx eax, byte [r12 + r15]
    inc r15
    movzx eax, byte [b64_table + rax]
    cmp al, 0xFF
    je .b64d_loop                    ; whitespace / '=' / unknown
    shl edx, 6
    or edx, eax
    add ecx, 6
    cmp ecx, 8
    jl .b64d_loop
    sub ecx, 8
    mov eax, edx
    mov esi, ecx
    shr eax, cl
    mov [r14 + rbx], al
    inc rbx
    ; Mask off the byte we just emitted from the accumulator.
    mov eax, 1
    shl eax, cl
    dec eax
    and edx, eax
    jmp .b64d_loop
.b64d_done:
    mov rax, rbx
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ──────────────────────────────────────────────────────────────────
; PNG header parser.
;   rdi = PNG data, rsi = data length
; Returns: eax = width, edx = height, rcx = 1 on success / 0 on
; failure. PNG layout: 8-byte sig, then 13-byte IHDR chunk whose
; data is at offset 16: width(4 BE), height(4 BE).
; ──────────────────────────────────────────────────────────────────
png_dimensions:
    cmp rsi, 24
    jl .pd_fail
    cmp byte [rdi + 0], 0x89
    jne .pd_fail
    cmp byte [rdi + 1], 'P'
    jne .pd_fail
    cmp byte [rdi + 2], 'N'
    jne .pd_fail
    cmp byte [rdi + 3], 'G'
    jne .pd_fail
    ; Width at offset 16, big-endian
    mov al, [rdi + 16]
    mov ah, [rdi + 17]
    rol ax, 8                        ; ah:al -> al:ah => big-endian
    movzx eax, ax
    mov cl, [rdi + 18]
    mov ch, [rdi + 19]
    shl eax, 16
    movzx ecx, cx
    rol cx, 8
    movzx ecx, cx
    or eax, ecx                      ; full 32-bit width
    push rax
    ; Height at offset 20
    mov al, [rdi + 20]
    mov ah, [rdi + 21]
    rol ax, 8
    movzx eax, ax
    mov cl, [rdi + 22]
    mov ch, [rdi + 23]
    shl eax, 16
    rol cx, 8
    movzx ecx, cx
    or eax, ecx
    mov edx, eax
    pop rax
    mov ecx, 1
    ret
.pd_fail:
    xor eax, eax
    xor edx, edx
    xor ecx, ecx
    ret

; ──────────────────────────────────────────────────────────────────
; Fork convert to decode PNG → RGBA into the mmap'd img_decode_buf.
;   rdi = pointer to PNG bytes, rsi = byte count, edx = expected RGBA
;   bytes (width*height*4). Returns rax = bytes actually read, or 0
;   on failure.
;
; Pipeline:  parent → pipe1 → child stdin (PNG bytes)
;            child stdout → pipe2 → parent (RGBA bytes)
; Child:     execve("/usr/bin/convert", ["convert","png:-","rgba:-"])
; ──────────────────────────────────────────────────────────────────
png_decode_to_rgba:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi                     ; PNG data
    mov r13, rsi                     ; PNG length
    mov r14, rdx                     ; expected RGBA bytes

    ; mmap a fresh decode buffer if needed (or larger)
    mov rax, [img_decode_len]
    cmp r14, rax
    jbe .pdr_have_buf
    ; Need bigger buf — unmap existing then mmap fresh
    mov rax, [img_decode_buf]
    test rax, rax
    jz .pdr_alloc
    push rax
    mov rax, SYS_MUNMAP
    mov rdi, [img_decode_buf]
    mov rsi, [img_decode_len]
    syscall
    pop rax
    mov qword [img_decode_buf], 0
.pdr_alloc:
    mov rax, SYS_MMAP
    xor edi, edi
    mov rsi, r14
    mov rdx, MMAP_PROT_RW
    mov r10, MMAP_FLAGS_PRIV
    mov r8, -1
    xor r9, r9
    syscall
    cmp rax, -4096
    ja .pdr_fail
    mov [img_decode_buf], rax
    mov [img_decode_len], r14
.pdr_have_buf:

    ; Build argv: convert png:- -depth 8 rgba:-
    ; -depth 8 is critical: high-precision PNGs (16-bit channels) would
    ; otherwise emit 8 bytes/pixel, doubling the output and corrupting
    ; the strip layout.
    lea rax, [convert_path]
    mov [png_argv + 0*8], rax
    lea rax, [convert_arg_png_in]
    mov [png_argv + 1*8], rax
    lea rax, [convert_arg_depth]
    mov [png_argv + 2*8], rax
    lea rax, [convert_arg_8]
    mov [png_argv + 3*8], rax
    lea rax, [convert_arg_rgba_lower]
    mov [png_argv + 4*8], rax
    mov qword [png_argv + 5*8], 0

    ; Two pipes (stdin: parent → child PNG, stdout: child → parent RGBA)
    sub rsp, 16
    mov rax, SYS_PIPE
    lea rdi, [rsp]
    syscall
    test rax, rax
    js .pdr_pipe_fail1               ; first pipe failed: nothing open yet
    mov eax, [rsp]
    mov [png_in_read], eax
    mov eax, [rsp + 4]
    mov [png_in_write], eax
    mov rax, SYS_PIPE
    lea rdi, [rsp]
    syscall
    test rax, rax
    js .pdr_pipe_fail2               ; second pipe failed: must close first pair
    mov eax, [rsp]
    mov [png_out_read], eax
    mov eax, [rsp + 4]
    mov [png_out_write], eax
    add rsp, 16

    mov rax, SYS_FORK
    syscall
    test rax, rax
    js .pdr_fork_fail                ; fork failed: must close ALL four pipe fds
    jnz .pdr_parent

    ; ── Child ──
    mov rax, SYS_DUP2
    mov edi, [png_in_read]
    xor esi, esi
    syscall
    mov rax, SYS_DUP2
    mov edi, [png_out_write]
    mov esi, 1
    syscall
    mov rax, SYS_CLOSE
    mov edi, [png_in_read]
    syscall
    mov rax, SYS_CLOSE
    mov edi, [png_in_write]
    syscall
    mov rax, SYS_CLOSE
    mov edi, [png_out_read]
    syscall
    mov rax, SYS_CLOSE
    mov edi, [png_out_write]
    syscall
    mov rax, SYS_EXECVE
    lea rdi, [convert_path]
    lea rsi, [png_argv]
    mov rdx, [envp]
    syscall
    mov rax, SYS_EXIT
    mov rdi, 127
    syscall

.pdr_parent:
    mov r15, rax                     ; child pid
    mov rax, SYS_CLOSE
    mov edi, [png_in_read]
    syscall
    mov rax, SYS_CLOSE
    mov edi, [png_out_write]
    syscall

    ; Write all PNG bytes to png_in_write. r12=src, r13=remaining.
    mov rdi, r12                     ; restore src into rdi
    mov r12, r13                     ; remaining = original length
.pdr_write:
    test r12, r12
    jz .pdr_write_done
    mov rsi, rdi
    mov rdx, r12
    mov rax, SYS_WRITE
    push rdi
    mov edi, [png_in_write]
    syscall
    pop rdi
    test rax, rax
    jle .pdr_write_done
    add rdi, rax
    sub r12, rax
    jmp .pdr_write
.pdr_write_done:
    mov rax, SYS_CLOSE
    mov edi, [png_in_write]
    syscall

    ; Read RGBA from png_out_read into img_decode_buf.
    xor r12, r12                     ; bytes received
.pdr_read:
    cmp r12, r14
    jge .pdr_read_done
    mov rax, SYS_READ
    mov edi, [png_out_read]
    mov rsi, [img_decode_buf]
    add rsi, r12
    mov rdx, r14
    sub rdx, r12
    syscall
    test rax, rax
    jle .pdr_read_done
    add r12, rax
    jmp .pdr_read
.pdr_read_done:
    mov rax, SYS_CLOSE
    mov edi, [png_out_read]
    syscall

    ; Reap child to avoid zombies.
    sub rsp, 16
    mov rax, SYS_WAIT4
    mov rdi, r15
    mov rsi, rsp
    xor edx, edx
    xor r10, r10
    syscall
    add rsp, 16

    mov rax, r12
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.pdr_fork_fail:
    ; All four fds open; close them before returning.
    mov rax, SYS_CLOSE
    mov edi, [png_out_write]
    syscall
    mov rax, SYS_CLOSE
    mov edi, [png_out_read]
    syscall
    jmp .pdr_close_inpair
.pdr_pipe_fail2:
    ; Second pipe failed: only first pair is open. rsp already had 16
    ; reserved for the (failed) second pipe write — restore it.
    add rsp, 16
.pdr_close_inpair:
    mov rax, SYS_CLOSE
    mov edi, [png_in_write]
    syscall
    mov rax, SYS_CLOSE
    mov edi, [png_in_read]
    syscall
    jmp .pdr_fail
.pdr_pipe_fail1:
    add rsp, 16
.pdr_fail:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ──────────────────────────────────────────────────────────────────
; Image table helpers.
; Slot layout (32 bytes):
;   +0  id (dword)
;   +4  width (dword)
;   +8  height (dword)
;   +12 pixmap_id (dword)
;   +16 picture_id (dword)
;   +20 in_use (byte)
;   +21..31 padding
; ──────────────────────────────────────────────────────────────────
img_find:
    ; rdi = id. Returns rsi = slot pointer or 0 if not found.
    xor ecx, ecx
.if_loop:
    cmp ecx, IMG_SLOTS
    jge .if_miss
    mov eax, ecx
    imul eax, IMG_SLOT_SIZE
    lea rsi, [img_table + rax]
    cmp byte [rsi + 20], 0
    je .if_next
    cmp [rsi], edi
    je .if_hit
.if_next:
    inc ecx
    jmp .if_loop
.if_miss:
    xor esi, esi
.if_hit:
    ret

img_alloc:
    ; rdi = id. Find existing or pick free slot. Returns rsi = slot.
    push rdi
    call img_find
    pop rdi
    test rsi, rsi
    jnz .ia_done
    xor ecx, ecx
.ia_scan:
    cmp ecx, IMG_SLOTS
    jge .ia_evict
    mov eax, ecx
    imul eax, IMG_SLOT_SIZE
    lea rsi, [img_table + rax]
    cmp byte [rsi + 20], 0
    je .ia_take
    inc ecx
    jmp .ia_scan
.ia_evict:
    ; All used — evict slot 0 (simple FIFO; could be smarter)
    lea rsi, [img_table]
    call img_release_picture_in_rsi
.ia_take:
    mov [rsi], edi
    mov dword [rsi + 4], 0
    mov dword [rsi + 8], 0
    mov dword [rsi + 12], 0
    mov dword [rsi + 16], 0
    mov byte [rsi + 20], 1
.ia_done:
    ret

; rsi = slot pointer; release server-side picture/pixmap and mark free.
img_release_picture_in_rsi:
    push rbx
    mov ebx, [rsi + 16]              ; picture_id
    test ebx, ebx
    jz .irp_no_pic
    lea rdi, [tmp_buf]
    mov al, [render_major]
    mov [rdi], al
    mov byte [rdi+1], RENDER_FREE_PICTURE
    mov word [rdi+2], 2
    mov [rdi+4], ebx
    push rsi
    lea rsi, [tmp_buf]
    mov rdx, 8
    call x11_buffer
    pop rsi
    inc dword [x11_seq]
.irp_no_pic:
    mov ebx, [rsi + 12]              ; pixmap_id
    test ebx, ebx
    jz .irp_no_pix
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_FREE_PIXMAP
    mov byte [rdi+1], 0
    mov word [rdi+2], 2
    mov [rdi+4], ebx
    push rsi
    lea rsi, [tmp_buf]
    mov rdx, 8
    call x11_buffer
    pop rsi
    inc dword [x11_seq]
.irp_no_pix:
    mov byte [rsi + 20], 0
    pop rbx
    ret

; ──────────────────────────────────────────────────────────────────
; Upload RGBA bytes from img_decode_buf into a new server pixmap +
; XRender Picture, store XIDs in slot at rsi.
;   rsi = slot pointer (must already be allocated, in_use=1)
;   rdi = width, rdx = height, r8 = byte count (w*h*4)
; ──────────────────────────────────────────────────────────────────
img_upload_rsi:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rsi                     ; slot
    mov r13, rdi                     ; width
    mov r14, rdx                     ; height
    mov r15, r8                      ; bytes

    ; Swap R and B bytes in img_decode_buf. ARGB32 picture format has
    ; R=bit16, G=bit8, B=bit0, so on a little-endian server the bytes
    ; in memory are [B, G, R, A]. Kitty wire format and `convert
    ; rgba:-` both deliver [R, G, B, A], so the red and blue channels
    ; would be swapped on screen without this pass.
    mov rdi, [img_decode_buf]
    test rdi, rdi
    jz .iur_swap_done
    mov rcx, r15
    shr rcx, 2                       ; pixel count
    test rcx, rcx
    jz .iur_swap_done
.iur_swap:
    mov al, [rdi]
    mov dl, [rdi+2]
    mov [rdi], dl
    mov [rdi+2], al
    add rdi, 4
    dec rcx
    jnz .iur_swap
.iur_swap_done:

    ; Sanity check
    cmp dword [render_major], 0
    je .iur_fail

    ; CreatePixmap depth=32, w=r13, h=r14, drawable=win
    call alloc_xid
    mov [r12 + 12], eax              ; pixmap_id
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CREATE_PIXMAP
    mov byte [rdi+1], 32
    mov word [rdi+2], 4
    mov [rdi+4], eax
    mov eax, [win_id]
    mov [rdi+8], eax
    mov word [rdi+12], r13w
    mov word [rdi+14], r14w
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]

    ; Make sure render_temp_gc exists for depth-32 pixmaps
    cmp byte [render_gc_ready], 1
    je .iur_gc_done
    call alloc_xid
    mov [render_temp_gc], eax
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CREATE_GC
    mov byte [rdi+1], 0
    mov word [rdi+2], 4
    mov eax, [render_temp_gc]
    mov [rdi+4], eax
    mov eax, [r12 + 12]              ; depth-32 drawable
    mov [rdi+8], eax
    mov dword [rdi+12], 0
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]
    mov byte [render_gc_ready], 1
.iur_gc_done:

    ; PutImage in row-stride chunks. X11 caps requests around 16MB
    ; even with BIG-REQUESTS, but keeping each PutImage ≤ 256KB lets
    ; us avoid that whole code path. Send strips of N rows at a time
    ; where N*width*4 ≤ 200000 bytes.
    call x11_flush
    xor rcx, rcx                     ; current y
    mov rax, 200000
    xor edx, edx
    mov ebx, r13d
    shl ebx, 2                       ; bytes per row
    test ebx, ebx
    jz .iur_after_putimage
    div rbx                          ; rax = rows-per-strip
    test rax, rax
    jnz .iur_have_strip
    mov rax, 1                       ; at minimum one row per strip
.iur_have_strip:
    mov r8, rax                      ; rows per strip
.iur_strip_loop:
    cmp rcx, r14
    jge .iur_after_putimage
    mov r9, r14
    sub r9, rcx
    cmp r9, r8
    jle .iur_strip_h_ok
    mov r9, r8
.iur_strip_h_ok:
    ; strip_bytes = r9 * width * 4
    mov rax, r9
    imul rax, r13
    shl rax, 2
    push rcx
    push r9
    push rax                         ; strip bytes

    ; Header
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_PUT_IMAGE
    mov byte [rdi+1], 2              ; ZPixmap
    mov rdx, rax
    add rdx, 24 + 3
    shr rdx, 2
    mov word [rdi+2], dx
    mov edx, [r12 + 12]
    mov [rdi+4], edx
    mov edx, [render_temp_gc]
    mov [rdi+8], edx
    mov word [rdi+12], r13w          ; width
    mov word [rdi+14], r9w           ; strip height
    mov word [rdi+16], 0
    mov word [rdi+18], cx            ; dst-y
    mov byte [rdi+20], 0
    mov byte [rdi+21], 32
    mov word [rdi+22], 0
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    lea rsi, [tmp_buf]
    mov rdx, 24
    syscall

    ; Strip data
    pop rax                          ; strip bytes
    pop r9
    pop rcx
    push r9
    push rcx
    mov rsi, [img_decode_buf]
    mov rdi, rcx                     ; y
    imul rdi, r13                    ; * width
    shl rdi, 2                       ; * 4 = byte offset
    add rsi, rdi
    mov rdx, rax
    push rax
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    pop rax
    ; Pad to 4
    test al, 3
    jz .iur_no_pad
    mov edx, 4
    sub edx, eax
    and edx, 3
    sub rsp, 8
    mov qword [rsp], 0
    push rdx
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    mov rsi, rsp
    add rsi, 8
    pop rdx
    syscall
    add rsp, 8
.iur_no_pad:
    inc dword [x11_seq]
    pop rcx
    pop r9
    add rcx, r9
    jmp .iur_strip_loop
.iur_after_putimage:

    ; Create XRender Picture
    call alloc_xid
    mov [r12 + 16], eax              ; picture_id
    lea rdi, [tmp_buf]
    mov al, [render_major]
    mov [rdi], al
    mov byte [rdi+1], RENDER_CREATE_PICTURE
    mov word [rdi+2], 5
    mov eax, [r12 + 16]
    mov [rdi+4], eax
    mov eax, [r12 + 12]
    mov [rdi+8], eax
    mov eax, [render_format_argb32]
    mov [rdi+12], eax
    mov dword [rdi+16], 0
    lea rsi, [tmp_buf]
    mov rdx, 20
    call x11_buffer
    inc dword [x11_seq]

    ; Stash dimensions
    mov [r12 + 4], r13d
    mov [r12 + 8], r14d
    call x11_flush
    mov rax, 1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.iur_fail:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ──────────────────────────────────────────────────────────────────
; Place table — record where each placed image goes.
; Slot layout (16 bytes):
;   +0 image_id (dword, 0 = empty)
;   +4 anchor_row (word)
;   +6 anchor_col (word)
;   +8 cell_w (word)
;   +10 cell_h (word)
;   +12 pad
; ──────────────────────────────────────────────────────────────────
place_add:
    ; rdi=id, esi=row, edx=col, ecx=cw, r8d=ch
    push rbx
    xor ebx, ebx
.pa_scan:
    cmp ebx, PLACE_SLOTS
    jge .pa_full
    mov eax, ebx
    imul eax, PLACE_SLOT_SIZE
    lea r9, [place_table + rax]
    cmp dword [r9], 0
    je .pa_take
    cmp [r9], edi
    jne .pa_next
.pa_take:
    mov [r9], edi
    mov [r9 + 4], si
    mov [r9 + 6], dx
    mov [r9 + 8], cx
    mov [r9 + 10], r8w
    mov dword [r9 + 12], 0
    pop rbx
    ret
.pa_next:
    inc ebx
    jmp .pa_scan
.pa_full:
    pop rbx
    ret

place_clear_image:
    ; rdi = id; remove all entries that match
    xor ecx, ecx
.pci_loop:
    cmp ecx, PLACE_SLOTS
    jge .pci_done
    mov eax, ecx
    imul eax, PLACE_SLOT_SIZE
    lea rsi, [place_table + rax]
    cmp [rsi], edi
    jne .pci_next
    mov dword [rsi], 0
.pci_next:
    inc ecx
    jmp .pci_loop
.pci_done:
    ret

; Clear all placements.
place_clear_all:
    lea rdi, [place_table]
    mov ecx, PLACE_SLOTS * PLACE_SLOT_SIZE / 8
    xor eax, eax
    rep stosq
    ret

; ──────────────────────────────────────────────────────────────────
; The actual dispatcher: called when one APC chunk has been captured
; into apc_body. apc_body[0] is 'G'.
; ──────────────────────────────────────────────────────────────────
handle_kitty_apc:
    push rbx
    push r12
    push r13
    push r14
    call apc_parse_header

    ; If continuation chunk, infer action from pending state.
    movzx eax, byte [apc_kv_a]
    test al, al
    jnz .hka_have_action
    cmp byte [apc_pending_active], 1
    jne .hka_done                    ; orphan chunk — drop
    mov al, 't'
    mov [apc_kv_a], al
.hka_have_action:

    ; Dispatch on action
    cmp al, 'd'
    je .hka_delete
    cmp al, 'p'
    je .hka_place
    cmp al, 't'
    je .hka_transmit
    cmp al, 'T'
    je .hka_transmit_place
    jmp .hka_done

.hka_transmit_place:
    mov al, 1
    jmp .hka_xmit_common
.hka_transmit:
    xor al, al
.hka_xmit_common:
    ; al = "place after finalize" flag for THIS chunk's action.
    ; Only honor it on the first chunk; on continuations the action
    ; is inferred as 't', which would otherwise wipe the pending
    ; place flag set by the original a=T.
    cmp byte [apc_pending_active], 1
    je .hka_append
    mov [apc_pending_place], al
    mov eax, [apc_kv_i]
    mov [apc_pending_id], eax
    mov eax, [apc_kv_f]
    mov [apc_pending_fmt], eax
    mov eax, [apc_kv_s]
    mov [apc_pending_w], eax
    mov eax, [apc_kv_v]
    mov [apc_pending_h], eax
    movzx eax, byte [apc_kv_q]
    mov [apc_pending_q], al
    mov qword [apc_payload_len], 0
    mov byte [apc_pending_active], 1
.hka_append:
    ; Append apc_body[apc_payload_off..apc_body_len] to apc_payload.
    mov rsi, [apc_payload_off]
    mov rcx, [apc_body_len]
    sub rcx, rsi
    jbe .hka_after_append
    mov rdx, [apc_payload_len]
    add rdx, rcx
    cmp rdx, APC_PAYLOAD_MAX
    ja .hka_after_append             ; overflow — drop silently
    lea rdi, [apc_payload]
    add rdi, [apc_payload_len]
    lea rsi, [apc_body]
    add rsi, [apc_payload_off]
.hka_copy:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .hka_copy
    mov rdx, [apc_payload_len]
    add rdx, [apc_body_len]
    sub rdx, [apc_payload_off]
    mov [apc_payload_len], rdx
.hka_after_append:

    ; If more chunks coming, wait for them.
    cmp byte [apc_kv_m], 1
    je .hka_done

    ; Last chunk — decode the accumulated payload and store the image.
    call kitty_finalize_image
    mov byte [apc_pending_active], 0
    jmp .hka_done

.hka_place:
    ; Place an existing image at the cursor.
    mov edi, [apc_kv_i]
    test edi, edi
    jz .hka_done
    call img_find
    test rsi, rsi
    jz .hka_done
    ; Compute cell_w / cell_h: explicit c=/r=, else native pixels / cell.
    movzx ecx, word [apc_kv_c]       ; cell_w request
    test ecx, ecx
    jnz .hka_have_cw
    mov eax, [rsi + 4]               ; image width in pixels
    movzx edx, word [char_width]
    test edx, edx
    jz .hka_done
    add eax, edx
    dec eax                          ; ceil division
    xor edx, edx
    movzx r8d, word [char_width]
    div r8d
    mov ecx, eax
.hka_have_cw:
    movzx r8d, word [apc_kv_r]       ; cell_h request
    test r8d, r8d
    jnz .hka_have_ch
    mov eax, [rsi + 8]               ; image height
    movzx edx, word [char_height]
    test edx, edx
    jz .hka_done
    add eax, edx
    dec eax
    xor edx, edx
    movzx r9d, word [char_height]
    div r9d
    mov r8d, eax
.hka_have_ch:
    ; place_add: rdi=id, esi=row, edx=col, ecx=cw, r8d=ch
    mov rdi, [cursor_row]
    mov rsi, rdi
    mov edi, [apc_kv_i]
    mov rdx, [cursor_col]
    call place_add
    ; Ask the renderer to redraw the image overlay.
    call render_screen
    call x11_flush
    jmp .hka_done

.hka_delete:
    ; Per kitty spec:
    ;   d=i (lowercase) → delete placements of image i, KEEP image
    ;   d=I (uppercase) → delete image data AND its placements
    ;   d=a (lowercase) → delete all placements, KEEP all images
    ;   d=A (uppercase) → delete all images and placements
    ; Default when d= is missing is 'a' (with no id, the only sane
    ; reading is "all placements").
    movzx eax, byte [apc_kv_d]
    test al, al
    jnz .hka_d_have
    mov al, 'a'
.hka_d_have:
    cmp al, 'a'
    je .hka_d_clear_all_placements
    cmp al, 'A'
    je .hka_d_release_all
    cmp al, 'i'
    je .hka_d_clear_one_placement
    cmp al, 'I'
    je .hka_d_release_one
    jmp .hka_done

.hka_d_clear_one_placement:
    mov edi, [apc_kv_i]
    test edi, edi
    jz .hka_done
    call place_clear_image
    call render_screen
    call x11_flush
    jmp .hka_done

.hka_d_release_one:
    mov edi, [apc_kv_i]
    test edi, edi
    jz .hka_done
    push rdi
    call img_find
    pop rdi
    test rsi, rsi
    jz .hka_done
    call img_release_picture_in_rsi
    mov edi, [apc_kv_i]
    call place_clear_image
    call render_screen
    call x11_flush
    jmp .hka_done

.hka_d_clear_all_placements:
    call place_clear_all
    call render_screen
    call x11_flush
    jmp .hka_done

.hka_d_release_all:
    xor ecx, ecx
.hka_da_loop:
    cmp ecx, IMG_SLOTS
    jge .hka_da_done
    mov eax, ecx
    imul eax, IMG_SLOT_SIZE
    lea rsi, [img_table + rax]
    cmp byte [rsi + 20], 0
    je .hka_da_next
    push rcx
    call img_release_picture_in_rsi
    pop rcx
.hka_da_next:
    inc ecx
    jmp .hka_da_loop
.hka_da_done:
    call place_clear_all
    call render_screen
    call x11_flush

.hka_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ──────────────────────────────────────────────────────────────────
; Decode the accumulated base64 payload, run convert if PNG, then
; upload as XRender Picture into the image table.
; ──────────────────────────────────────────────────────────────────
kitty_finalize_image:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Reuse apc_body as the base64-decoded scratch (no good reason it
    ; can't be repurposed; the body for the next chunk is rebuilt).
    ; Decoded size = ceil(payload_len * 3 / 4) which fits in
    ; APC_PAYLOAD_MAX comfortably; we mmap separately to be safe.
    mov rax, [apc_payload_len]
    test rax, rax
    jz .kfi_done
    mov rdi, rax
    add rdi, 3
    shr rdi, 2
    imul rdi, 3                      ; max decoded bytes
    cmp rdi, APC_PAYLOAD_MAX
    ja .kfi_done

    ; Allocate decode scratch via mmap (simpler than juggling buffers).
    mov rax, SYS_MMAP
    mov r13, rdi                     ; remember requested size
    xor edi, edi
    mov rsi, r13
    mov rdx, MMAP_PROT_RW
    mov r10, MMAP_FLAGS_PRIV
    mov r8, -1
    xor r9, r9
    syscall
    cmp rax, -4096
    ja .kfi_done
    mov r12, rax                     ; decoded buffer

    ; base64_decode(apc_payload, apc_payload_len, r12)
    lea rdi, [apc_payload]
    mov rsi, [apc_payload_len]
    mov rdx, r12
    call base64_decode
    mov r14, rax                     ; decoded byte count

    ; Branch on format.
    mov eax, [apc_pending_fmt]
    cmp eax, 32
    je .kfi_raw_rgba
    cmp eax, 24
    je .kfi_raw_rgb
    ; Default: PNG (f=100). Read dimensions from header, fork convert.
    mov rdi, r12
    mov rsi, r14
    call png_dimensions
    test rcx, rcx
    jz .kfi_unmap_decoded
    mov ebx, eax                     ; width
    mov r15d, edx                    ; height
    test ebx, ebx
    jz .kfi_unmap_decoded            ; reject 0-width
    test r15d, r15d
    jz .kfi_unmap_decoded            ; reject 0-height
    cmp ebx, MAX_IMG_DIM
    ja .kfi_unmap_decoded
    cmp r15d, MAX_IMG_DIM
    ja .kfi_unmap_decoded

    ; Need width*height*4 bytes. Compute in 64-bit so a hostile width
    ; like 0x10000 with height 0x10000 can't wrap eax to 0 and slip
    ; past the IMG_DECODE_MAX cap.
    mov rax, rbx
    mov rcx, r15
    imul rax, rcx
    shl rax, 2
    cmp rax, IMG_DECODE_MAX
    ja .kfi_unmap_decoded
    mov rdi, r12                     ; PNG src
    mov rsi, r14                     ; PNG len
    mov edx, eax                     ; expected RGBA bytes
    call png_decode_to_rgba
    mov r14, rax                     ; bytes received
    test r14, r14
    jz .kfi_unmap_decoded
    jmp .kfi_have_rgba

.kfi_raw_rgba:
    ; Width/height come from s/v parameters; r14 bytes already in r12.
    mov ebx, [apc_pending_w]
    mov r15d, [apc_pending_h]
    cmp ebx, MAX_IMG_DIM
    ja .kfi_unmap_decoded
    cmp r15d, MAX_IMG_DIM
    ja .kfi_unmap_decoded
    ; Verify byte count = w*h*4
    mov eax, ebx
    imul eax, r15d
    shl eax, 2
    cmp r14, rax
    jne .kfi_unmap_decoded
    ; Move into img_decode_buf so img_upload_rsi finds it
    cmp eax, [img_decode_len]
    jbe .kfi_have_idb
    mov rax, [img_decode_buf]
    test rax, rax
    jz .kfi_alloc_idb
    push rax
    mov rax, SYS_MUNMAP
    mov rdi, [img_decode_buf]
    mov rsi, [img_decode_len]
    syscall
    pop rax
    mov qword [img_decode_buf], 0
.kfi_alloc_idb:
    mov rax, SYS_MMAP
    xor edi, edi
    mov rsi, r14
    mov rdx, MMAP_PROT_RW
    mov r10, MMAP_FLAGS_PRIV
    mov r8, -1
    xor r9, r9
    syscall
    cmp rax, -4096
    ja .kfi_unmap_decoded
    mov [img_decode_buf], rax
    mov [img_decode_len], r14
.kfi_have_idb:
    ; copy r14 bytes from r12 to img_decode_buf
    mov rsi, r12
    mov rdi, [img_decode_buf]
    mov rcx, r14
    rep movsb
    jmp .kfi_have_rgba

.kfi_raw_rgb:
    ; Not implemented for now — drop.
    jmp .kfi_unmap_decoded

.kfi_have_rgba:
    ; Allocate (or re-use) image slot and upload.
    mov edi, [apc_pending_id]
    call img_alloc
    ; img_upload_rsi: rsi=slot, rdi=w, rdx=h, r8=bytes
    mov rdi, rbx
    mov edx, r15d
    mov r8, r14
    call img_upload_rsi

    ; If a=T, place at cursor immediately.
    cmp byte [apc_pending_place], 1
    jne .kfi_unmap_decoded
    mov edi, [apc_pending_id]
    call img_find
    test rsi, rsi
    jz .kfi_unmap_decoded
    mov eax, [rsi + 4]
    movzx edx, word [char_width]
    test edx, edx
    jz .kfi_unmap_decoded
    add eax, edx
    dec eax
    xor edx, edx
    movzx r8d, word [char_width]
    div r8d
    mov ecx, eax                     ; cell_w
    mov eax, [rsi + 8]
    movzx edx, word [char_height]
    test edx, edx
    jz .kfi_unmap_decoded
    add eax, edx
    dec eax
    xor edx, edx
    movzx r9d, word [char_height]
    div r9d
    mov r8d, eax                     ; cell_h
    mov rsi, [cursor_row]
    mov rdx, [cursor_col]
    mov edi, [apc_pending_id]
    call place_add
    call render_screen
    call x11_flush

.kfi_unmap_decoded:
    mov rax, SYS_MUNMAP
    mov rdi, r12
    mov rsi, r13
    syscall
.kfi_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Default keybinding table (Alt+key Shortcuts)
; ══════════════════════════════════════════════════════════════════════
; Modifier bits: Shift=1, Ctrl=4, Alt=8 (matches X11 state mask).
init_keybindings:
    ; font_inc: Alt + plus
    mov byte [keybind_mods + KB_FONT_INC], 8
    mov dword [keybind_keysyms + KB_FONT_INC*4], 0x2B
    ; font_dec: Alt + minus
    mov byte [keybind_mods + KB_FONT_DEC], 8
    mov dword [keybind_keysyms + KB_FONT_DEC*4], 0x2D
    ; font_reset: Alt + underscore (Alt+Shift+- on most layouts)
    mov byte [keybind_mods + KB_FONT_RESET], 8
    mov dword [keybind_keysyms + KB_FONT_RESET*4], 0x5F
    ; bg_cycle: Alt + b
    mov byte [keybind_mods + KB_BG_CYCLE], 8
    mov dword [keybind_keysyms + KB_BG_CYCLE*4], 0x62
    ; opacity_toggle: Alt + t
    mov byte [keybind_mods + KB_OPACITY], 8
    mov dword [keybind_keysyms + KB_OPACITY*4], 0x74
    ret

; ══════════════════════════════════════════════════════════════════════
; Parse a single key.NAME = MOD+...+KEY entry from .glassrc.
; ══════════════════════════════════════════════════════════════════════
; rsi points at the value string (e.g. "alt+plus" or "ctrl+alt+t" or
; an empty value to disable). rdi = binding index. Modifies the
; binding in place; on parse failure leaves the slot unchanged.
parse_keybinding:
    push rbx
    push r12
    push r13
    mov r12, rdi                      ; index
    xor r13d, r13d                    ; mods accumulator
    xor ebx, ebx                      ; keysym (final)

.pkb_skip_ws:
    movzx eax, byte [rsi]
    cmp al, ' '
    je .pkb_skip_ws_inc
    cmp al, 9
    je .pkb_skip_ws_inc
    jmp .pkb_token
.pkb_skip_ws_inc:
    inc rsi
    jmp .pkb_skip_ws

.pkb_token:
    ; Empty / EOL / comment? Disable the binding.
    movzx eax, byte [rsi]
    test al, al
    jz .pkb_disable
    cmp al, 10
    je .pkb_disable
    cmp al, '#'
    je .pkb_disable

    ; Try modifiers: alt, ctrl, shift (followed by '+').
    cmp dword [rsi], 'alt+'
    jne .pkb_try_ctrl
    or r13d, 8
    add rsi, 4
    jmp .pkb_token
.pkb_try_ctrl:
    cmp dword [rsi], 'ctrl'
    jne .pkb_try_shift
    cmp byte [rsi+4], '+'
    jne .pkb_try_shift
    or r13d, 4
    add rsi, 5
    jmp .pkb_token
.pkb_try_shift:
    cmp dword [rsi], 'shif'
    jne .pkb_named_keys
    cmp word [rsi+4], 't+'
    jne .pkb_named_keys
    or r13d, 1
    add rsi, 6
    jmp .pkb_token

.pkb_named_keys:
    ; Multi-character key names — order matters when prefixes overlap.
    cmp dword [rsi], 'plus'
    jne .pkb_try_minus
    mov ebx, 0x2B
    jmp .pkb_apply
.pkb_try_minus:
    cmp dword [rsi], 'minu'
    jne .pkb_try_underscore
    cmp byte [rsi+4], 's'
    jne .pkb_try_underscore
    mov ebx, 0x2D
    jmp .pkb_apply
.pkb_try_underscore:
    cmp dword [rsi], 'unde'
    jne .pkb_try_equal
    cmp dword [rsi+4], 'rsco'
    jne .pkb_try_equal
    cmp word [rsi+8], 're'
    jne .pkb_try_equal
    mov ebx, 0x5F
    jmp .pkb_apply
.pkb_try_equal:
    cmp dword [rsi], 'equa'
    jne .pkb_try_space
    cmp byte [rsi+4], 'l'
    jne .pkb_try_space
    mov ebx, 0x3D
    jmp .pkb_apply
.pkb_try_space:
    cmp dword [rsi], 'spac'
    jne .pkb_single_char
    cmp byte [rsi+4], 'e'
    jne .pkb_single_char
    mov ebx, 0x20
    jmp .pkb_apply

.pkb_single_char:
    ; Fall back to a single printable ASCII keysym (a..z, A..Z, 0..9,
    ; or any 0x20..0x7E literal).
    movzx eax, byte [rsi]
    cmp al, 0x20
    jb .pkb_done
    cmp al, 0x7E
    ja .pkb_done
    mov ebx, eax

.pkb_apply:
    mov [keybind_mods + r12], r13b
    mov [keybind_keysyms + r12*4], ebx
.pkb_done:
    pop r13
    pop r12
    pop rbx
    ret

.pkb_disable:
    mov byte [keybind_mods + r12], 0
    jmp .pkb_done

; ══════════════════════════════════════════════════════════════════════
; Runtime font size change (Alt+plus / Alt+minus / Alt+_)
; ══════════════════════════════════════════════════════════════════════
; edi = direction: +1 step up, -1 step down, 0 reset to original
font_change_step:
    push rbx
    push r12
    push r13

    mov r12d, edi                    ; save direction

    ; Reset?
    test r12d, r12d
    jnz .fcs_step
    mov rax, [original_font_size]
    test rax, rax
    jnz .fcs_have_size
    mov rax, DEFAULT_FONT_SIZE
    jmp .fcs_have_size

.fcs_step:
    ; Find current cfg_font_size in preset table.
    mov rax, [cfg_font_size]
    test rax, rax
    jnz .fcs_search
    mov rax, DEFAULT_FONT_SIZE       ; treat unset as default
.fcs_search:
    xor ecx, ecx
.fcs_search_loop:
    cmp ecx, FONT_SIZE_PRESET_COUNT
    jge .fcs_off_table
    cmp rax, [font_size_presets + rcx*8]
    je .fcs_found_idx
    inc ecx
    jmp .fcs_search_loop

.fcs_off_table:
    ; Current size isn't in the preset table (e.g. user picked 16 via
    ; .glassrc, the table is 10/13/15/18/20/22/24/28/32). Snap
    ; directionally: Alt+plus jumps to the smallest preset larger than
    ; current; Alt+minus jumps to the largest preset smaller than
    ; current. The previous fallback was a hard-coded ecx=1 (size 13),
    ; which made Alt+plus from 16 go to 15 — felt like "smaller, then
    ; back, then bigger" instead of monotonically growing.
    test r12d, r12d
    js .fcs_off_down

    ; Up: find first preset[i] > rax. Set ecx = i-1 so the inc below
    ; lands on i. If none larger, clamp to last.
    xor ecx, ecx
.fcs_off_up_loop:
    cmp ecx, FONT_SIZE_PRESET_COUNT
    jge .fcs_off_up_clamp
    cmp [font_size_presets + rcx*8], rax
    ja .fcs_off_up_done
    inc ecx
    jmp .fcs_off_up_loop
.fcs_off_up_clamp:
    mov ecx, FONT_SIZE_PRESET_COUNT  ; the inc will clamp below
.fcs_off_up_done:
    dec ecx                          ; the .fcs_step_ok logic will inc
    jmp .fcs_found_idx

.fcs_off_down:
    ; Down: find largest preset[i] < rax. Set ecx = i+1 so the dec
    ; below lands on i. If none smaller, clamp to 0.
    mov ecx, FONT_SIZE_PRESET_COUNT
    dec ecx
.fcs_off_down_loop:
    test ecx, ecx
    js .fcs_off_down_clamp
    cmp [font_size_presets + rcx*8], rax
    jb .fcs_off_down_done
    dec ecx
    jmp .fcs_off_down_loop
.fcs_off_down_clamp:
    mov ecx, -1                      ; the dec will clamp below
.fcs_off_down_done:
    inc ecx                          ; the .fcs_step_down logic will dec
    jmp .fcs_found_idx

.fcs_found_idx:
    ; Step
    test r12d, r12d
    js .fcs_step_down
    inc ecx
    cmp ecx, FONT_SIZE_PRESET_COUNT
    jl .fcs_step_ok
    mov ecx, FONT_SIZE_PRESET_COUNT - 1
    jmp .fcs_step_ok
.fcs_step_down:
    dec ecx
    jns .fcs_step_ok
    xor ecx, ecx
.fcs_step_ok:
    mov rax, [font_size_presets + rcx*8]

.fcs_have_size:
    cmp rax, [cfg_font_size]
    je .fcs_done                     ; nothing to do
    mov [cfg_font_size], rax

    ; Rebuild XLFDs and re-open. (We deliberately leak the previous
    ; font IDs — CloseFont could race a queued ChangeGC; the leak is
    ; tiny relative to the convenience.)
    call setup_font_name
    call x11_open_font
    call x11_query_font

    ; TTF path: re-derive char_width/height/font_ascent at the new size
    ; AND drop the cached glyphs so subsequent renders re-upload at the
    ; new size. Without these, cells widen but glyphs keep their old
    ; bearings/advances → tiny glyphs rattling around in oversized cells.
    call ttf_compute_metrics
    call ttf_invalidate_glyph_cache

    ; Tell the GC about the new font and refresh tracking.
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_GC
    mov byte [rdi+1], 0
    mov word [rdi+2], 4              ; 3 + 1 value
    mov eax, [gc_id]
    mov [rdi+4], eax
    mov dword [rdi+8], GC_FONT
    mov eax, [font_id]
    mov [rdi+12], eax
    mov [gc_current_font], eax
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]

    ; Recompute grid_cols/grid_rows from current window pixels.
    movzx ecx, word [char_width]
    test ecx, ecx
    jz .fcs_skip_resize
    mov rax, [win_width]
    xor edx, edx
    div rcx
    cmp rax, MAX_COLS
    jle .fcs_cols_ok
    mov rax, MAX_COLS
.fcs_cols_ok:
    mov [grid_cols], rax
    movzx ecx, word [char_height]
    test ecx, ecx
    jz .fcs_skip_resize
    mov rax, [win_height]
    xor edx, edx
    div rcx
    cmp rax, MAX_ROWS
    jle .fcs_rows_ok
    mov rax, MAX_ROWS
.fcs_rows_ok:
    mov [grid_rows], rax

    ; Tell PTY about the new size + signal the child to redraw. Fill
    ; ws_xpixel/ws_ypixel so kitty-graphics clients (pointer, etc.)
    ; can size images to the actual pane in pixels.
    sub rsp, 8
    movzx eax, word [grid_rows]
    mov word [rsp], ax
    movzx eax, word [grid_cols]
    mov word [rsp+2], ax
    movzx eax, word [grid_cols]
    movzx ecx, word [char_width]
    imul eax, ecx
    mov word [rsp+4], ax
    movzx eax, word [grid_rows]
    movzx ecx, word [char_height]
    imul eax, ecx
    mov word [rsp+6], ax
    mov rax, SYS_IOCTL
    mov rdi, [pty_master]
    mov rsi, TIOCSWINSZ
    mov rdx, rsp
    syscall
    add rsp, 8
    cmp qword [child_pid], 0
    je .fcs_skip_signal
    mov rax, SYS_KILL
    mov rdi, [child_pid]
    neg rdi                          ; process group
    mov rsi, SIGWINCH
    syscall
.fcs_skip_signal:

.fcs_skip_resize:
    call render_screen
    call x11_flush

.fcs_done:
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Background cycling (Alt+b)
; ══════════════════════════════════════════════════════════════════════
bg_cycle_advance:
    push rbx
    mov rax, [bg_cycle_count]
    test rax, rax
    jz .bca_done                     ; no cycle list configured

    ; Save the original bg pixel once so we can later restore it if
    ; we ever add a 'reset bg' command.
    cmp byte [saved_bg_set], 0
    jne .bca_have_save
    mov eax, [cfg_bg_pixel]
    mov [saved_bg_pixel], eax
    mov byte [saved_bg_set], 1
.bca_have_save:

    mov rax, [bg_cycle_idx]
    inc rax
    cmp rax, [bg_cycle_count]
    jb .bca_idx_ok
    xor eax, eax
.bca_idx_ok:
    mov [bg_cycle_idx], rax

    ; Apply: write the new pixel into the slots that drive rendering.
    mov ebx, [bg_cycle_pixels + rax*4]
    mov [cfg_bg_pixel], ebx
    mov byte [cfg_bg_set], 1
    mov [palette], ebx               ; default-bg cells re-route here

    call render_screen
    call x11_flush
.bca_done:
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Tear down pseudo-transparency: free the wallpaper-blended back-pixmap,
; restore the window to a solid bg pixel, drop the pseudo_full flag so
; the renderer goes back to ImageText16 (with bg fill).
; ══════════════════════════════════════════════════════════════════════
pseudo_disable:
    ; Fast path: nothing to tear down if pseudo isn't currently active.
    ; Avoids any X11 traffic when the user toggles opacity at 100%
    ; without ever having gone transparent.
    cmp byte [pseudo_full], 0
    jne .pdis_active
    cmp dword [bg_pixmap_id], 0
    jne .pdis_active
    ret
.pdis_active:
    push rbx
    mov ebx, [bg_pixmap_id]
    test ebx, ebx
    jz .pdis_skip_free
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_FREE_PIXMAP
    mov byte [rdi+1], 0
    mov word [rdi+2], 2
    mov [rdi+4], ebx
    lea rsi, [tmp_buf]
    mov rdx, 8
    call x11_buffer
    inc dword [x11_seq]
    mov dword [bg_pixmap_id], 0
.pdis_skip_free:
    ; ChangeWindowAttributes(window, BACK_PIXEL = cfg_bg)
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_WINDOW_ATTRS
    mov byte [rdi+1], 0
    mov word [rdi+2], 4
    mov eax, [win_id]
    mov [rdi+4], eax
    mov dword [rdi+8], 0x02          ; CW_BACK_PIXEL
    cmp byte [cfg_bg_set], 1
    jne .pdis_def_bg
    mov eax, [cfg_bg_pixel]
    jmp .pdis_set_pixel
.pdis_def_bg:
    mov eax, [x11_black_pixel]
.pdis_set_pixel:
    mov [rdi+12], eax
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]
    mov byte [pseudo_full], 0
    mov byte [cfg_opacity], 255
    mov byte [pseudo_setup_done], 0
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Opacity toggle (Alt+t)
; ══════════════════════════════════════════════════════════════════════
; Two paths run side-by-side so the binding does something visible
; regardless of how the user's session is set up:
;   * _NET_WM_WINDOW_OPACITY     — picked up by picom / KWin / Mutter
;   * pseudo-transparency rebuild — wallpaper-blend BackPixmap when no
;                                   compositor owns _NET_WM_CM_S0.
opacity_toggle_apply:
    push rbx
    push r12

    ; Pick target percent (r12d, 0..100). If opacity_cycle is set in
    ; .glassrc, advance through the cycle list. Otherwise toggle
    ; between 100 (opaque) and 50.
    mov rax, [opacity_cycle_count]
    test rax, rax
    jz .ota_use_toggle
    mov rax, [opacity_cycle_idx]
    inc rax
    cmp rax, [opacity_cycle_count]
    jb .ota_cycle_ok
    xor eax, eax
.ota_cycle_ok:
    mov [opacity_cycle_idx], rax
    movzx r12d, byte [opacity_cycle_vals + rax]
    jmp .ota_have_pct
.ota_use_toggle:
    movzx eax, byte [opacity_toggle]
    xor eax, 1
    mov [opacity_toggle], al
    test al, al
    mov r12d, 100
    jz .ota_have_pct
    mov r12d, 50
.ota_have_pct:

    ; Skip all transparency work when the target percent equals the
    ; last one we applied — avoids any ChangeProperty / pseudo traffic
    ; when the user happens to land on the same value (or, at startup
    ; when pct=100 and we've never gone transparent, avoids touching
    ; the X11 connection at all).
    cmp byte [last_opacity_init], 1
    jne .ota_first_apply
    movzx eax, byte [last_opacity_pct]
    cmp eax, r12d
    je .ota_done
.ota_first_apply:
    mov [last_opacity_pct], r12b
    mov byte [last_opacity_init], 1

    ; Skip the ChangeProperty entirely when going to 100% AND we
    ; never set the property in the first place — the compositor's
    ; default is fully opaque, so writing 0xFFFFFFFF is a no-op.
    cmp r12d, 100
    jne .ota_must_set_prop
    cmp byte [opacity_prop_set], 0
    je .ota_skip_prop
.ota_must_set_prop:

    ; Compute _NET_WM_WINDOW_OPACITY cardinal: pct * 0xFFFFFFFF / 100,
    ; with exact fast-paths at the endpoints.
    cmp r12d, 100
    je .ota_card_full
    test r12d, r12d
    jnz .ota_card_scale
    xor ebx, ebx
    jmp .ota_card_done
.ota_card_full:
    mov ebx, 0xFFFFFFFF
    jmp .ota_card_done
.ota_card_scale:
    mov rax, r12
    mov rcx, 0xFFFFFFFF
    imul rax, rcx
    mov rcx, 100
    xor edx, edx
    div rcx
    mov ebx, eax
.ota_card_done:

    ; Lazily intern the atom on first use.
    cmp byte [opacity_atom_set], 1
    je .ota_have_atom
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_INTERN_ATOM
    mov byte [rdi+1], 0
    mov word [rdi+2], 2 + (opacity_atom_len + 3) / 4
    mov word [rdi+4], opacity_atom_len
    mov word [rdi+6], 0
    lea rsi, [opacity_atom_str]
    push rbx
    lea rbx, [tmp_buf + 8]
    xor ecx, ecx
.ota_cp:
    cmp ecx, opacity_atom_len
    jge .ota_send_intern
    movzx eax, byte [rsi + rcx]
    mov [rbx + rcx], al
    inc ecx
    jmp .ota_cp
.ota_send_intern:
    pop rbx
    mov eax, opacity_atom_len
    add eax, 3
    and eax, ~3
    add eax, 8
    mov rdx, rax
    lea rsi, [tmp_buf]
    mov rax, SYS_WRITE
    mov rdi, [x11_fd]
    syscall
    inc dword [x11_seq]
    call x11_drain_until_reply
    test rax, rax
    js .ota_done
    mov eax, [x11_buf + 8]
    test eax, eax
    jz .ota_done
    mov [opacity_atom], eax
    mov byte [opacity_atom_set], 1
.ota_have_atom:

    ; ChangeProperty(window, _NET_WM_WINDOW_OPACITY, CARDINAL, 32, 1, ebx)
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_PROPERTY
    mov byte [rdi+1], 0
    mov word [rdi+2], 7
    mov eax, [win_id]
    mov [rdi+4], eax
    mov eax, [opacity_atom]
    mov [rdi+8], eax
    mov dword [rdi+12], 6            ; XA_CARDINAL
    mov byte [rdi+16], 32
    mov byte [rdi+17], 0
    mov word [rdi+18], 0
    mov dword [rdi+20], 1
    mov [rdi+24], ebx
    lea rsi, [tmp_buf]
    mov rdx, 28
    call x11_buffer
    inc dword [x11_seq]
    call x11_flush
    mov byte [opacity_prop_set], 1
.ota_skip_prop:

    ; Without a compositor, _NET_WM_WINDOW_OPACITY is silently
    ; ignored — drive glass's pseudo-transparency path so the user
    ; still sees an effect.
    cmp byte [compositor_active], 1
    je .ota_done
    cmp r12d, 100
    je .ota_pseudo_off

    ; Pseudo on with target percent → cfg_opacity = pct * 255 / 100
    mov rax, r12
    imul rax, 255
    xor edx, edx
    mov rcx, 100
    div rcx
    mov [cfg_opacity], al
    mov byte [cfg_opacity_set], 1
    mov byte [pseudo_setup_done], 0
    call setup_pseudo_transparency
    call render_screen
    call x11_flush
    jmp .ota_done
.ota_pseudo_off:
    call pseudo_disable
    call render_screen
    call x11_flush
.ota_done:
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════
; TTF rendering via XRender CompositeGlyphs32
; ════════════════════════════════════════════════════════════════════
; Wire-protocol helpers that bridge glass's render path to the embedded
; glyph engine. Activated only when ttf_active = 1 (which happens iff
; ~/.glassrc has a working font_path).
;
;   ttf_xrender_init       — once, after x11_setup_render. Creates
;                             GlyphSet + a 1×1 ARGB Picture used as
;                             the foreground "pen" source.
;   ttf_set_pen_color      — rdi = ARGB. Updates the pen pixmap.
;                             Cached so back-to-back same-color cells
;                             are free.
;   ttf_upload_glyph       — rdi = codepoint. Renders via
;                             glyph_render_to_alpha, sends AddGlyphs.
;                             Marks ttf_glyph_uploaded[cp] = 1.
;   ttf_render_cp          — rdi = cp, rsi = x, rdx = y, rcx = ARGB
;                             Composites one glyph at (x, y).
; ---------------------------------------------------------------------

; Per-codepoint upload state. Linear bitmap: 1 byte per BMP cp.
; 64KB BSS; only touched pages cost RAM (typically a handful of KB).

section .bss
ttf_glyph_uploaded:     resb 65536

section .text

; ---------------------------------------------------------------------
ttf_xrender_init:
    cmp dword [render_format_a8], 0
    je .skip
    cmp dword [render_format_argb32], 0
    je .skip
    cmp qword [ttf_active], 0
    je .skip
    cmp dword [render_major], 0
    je .skip

    ; CreateGlyphSet: gsid, format
    call alloc_xid
    mov [ttf_glyphset], eax
    lea rdi, [tmp_buf]
    mov al, [render_major]
    mov [rdi], al
    mov byte [rdi+1], RENDER_CREATE_GLYPH_SET
    mov word [rdi+2], 3
    mov eax, [ttf_glyphset]
    mov [rdi+4], eax
    mov eax, [render_format_a8]
    mov [rdi+8], eax
    lea rsi, [tmp_buf]
    mov rdx, 12
    call x11_buffer
    inc dword [x11_seq]

    ; CreatePixmap (depth=32, 1×1)
    call alloc_xid
    mov [ttf_pen_pixmap], eax
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CREATE_PIXMAP
    mov byte [rdi+1], 32
    mov word [rdi+2], 4
    mov eax, [ttf_pen_pixmap]
    mov [rdi+4], eax
    mov eax, [win_id]
    mov [rdi+8], eax
    mov word [rdi+12], 1
    mov word [rdi+14], 1
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]

    ; CreatePicture (pen_picture, pen_pixmap, ARGB32, value-mask=CPRepeat)
    call alloc_xid
    mov [ttf_pen_picture], eax
    lea rdi, [tmp_buf]
    mov al, [render_major]
    mov [rdi], al
    mov byte [rdi+1], RENDER_CREATE_PICTURE
    mov word [rdi+2], 6
    mov eax, [ttf_pen_picture]
    mov [rdi+4], eax
    mov eax, [ttf_pen_pixmap]
    mov [rdi+8], eax
    mov eax, [render_format_argb32]
    mov [rdi+12], eax
    mov dword [rdi+16], 1               ; CPRepeat = bit 0
    mov dword [rdi+20], 1               ; Repeat = Normal
    lea rsi, [tmp_buf]
    mov rdx, 24
    call x11_buffer
    inc dword [x11_seq]

    mov dword [ttf_pen_color], 0xFFFFFFFE  ; force first set_pen_color
    call x11_flush
.skip:
    ret

; ---------------------------------------------------------------------
; ttf_invalidate_glyph_cache — drop every cached glyph and recreate the
; GlyphSet so subsequent renders re-upload at the current size. Called
; from font_change_step (Alt+plus / Alt+minus / Alt+_): without it,
; cached glyphs keep their old size's bearings/advances, so on a size
; bump the cells widen but the glyphs render at the previous (smaller)
; size with the previous (smaller) advance — text appears as small
; glyphs floating at the start of huge cells.
;
; Tactic: FreeGlyphSet old XID, alloc new XID, CreateGlyphSet new XID,
; zero the per-cp uploaded flags. The pen pixmap/picture survive — only
; the glyphset (which holds the rasterised alpha masks) needs replacing.
;
; No-op when ttf_active = 0.
ttf_invalidate_glyph_cache:
    cmp qword [ttf_active], 0
    je .tigc_ret
    cmp dword [render_major], 0
    je .tigc_ret

    ; Allocate a fresh GlyphSet XID and CreateGlyphSet at the new size.
    ; We deliberately do NOT FreeGlyphSet the old one — sending Free +
    ; Create back-to-back races against any in-flight render and several
    ; X servers crash glass before the second request lands. The old
    ; glyphset just leaks server-side until process exit (~64KB at
    ; worst), which is fine for a few-times-per-session size change.
    call alloc_xid
    mov [ttf_glyphset], eax
    lea rdi, [tmp_buf]
    mov al, [render_major]
    mov [rdi], al
    mov byte [rdi+1], RENDER_CREATE_GLYPH_SET
    mov word [rdi+2], 3
    mov eax, [ttf_glyphset]
    mov [rdi+4], eax
    mov eax, [render_format_a8]
    mov [rdi+8], eax
    lea rsi, [tmp_buf]
    mov rdx, 12
    call x11_buffer
    inc dword [x11_seq]

    ; Zero the per-cp uploaded bitmap so subsequent ttf_upload_glyph
    ; calls actually re-upload (now into the new glyphset). 65536 bytes
    ; via rep stosq. rdi/rcx/rax are caller-saved; restored by saver.
    push rdi
    push rcx
    push rax
    lea rdi, [ttf_glyph_uploaded]
    mov ecx, 65536 / 8
    xor eax, eax
    rep stosq
    pop rax
    pop rcx
    pop rdi

.tigc_ret:
    ret

; ---------------------------------------------------------------------
; ttf_set_pen_color — rdi = ARGB (0xAARRGGBB). Updates the 1×1 pen
; pixmap if the colour changed.
ttf_set_pen_color:
    cmp edi, [ttf_pen_color]
    je .ret
    mov [ttf_pen_color], edi

    ; Make sure we have a depth-32 GC. ensure_render_gc reuses tmp_buf,
    ; so call it BEFORE we start building PutImage in tmp_buf — otherwise
    ; the CreateGC bytes clobber our half-built PutImage header.
    cmp dword [render_temp_gc], 0
    jne .gc_ok
    push rdi
    call ensure_render_gc
    pop rdi
.gc_ok:

    ; PutImage: format=ZPixmap, depth=32, w=1, h=1, dst-x/y=0, then 4
    ; bytes ARGB. Length = (24 + 4) / 4 = 7 dwords.
    lea rsi, [tmp_buf]
    mov byte [rsi], X11_PUT_IMAGE
    mov byte [rsi+1], 2                ; ZPixmap
    mov word [rsi+2], 7
    mov eax, [ttf_pen_pixmap]
    mov [rsi+4], eax
    mov eax, [render_temp_gc]
    mov [rsi+8], eax
    mov word [rsi+12], 1               ; width
    mov word [rsi+14], 1               ; height
    mov word [rsi+16], 0               ; dst-x
    mov word [rsi+18], 0               ; dst-y
    mov byte [rsi+20], 0               ; left-pad
    mov byte [rsi+21], 32              ; depth
    mov word [rsi+22], 0               ; pad
    mov eax, edi                       ; the ARGB pixel
    mov [rsi+24], eax
    mov rdx, 28
    call x11_buffer
    inc dword [x11_seq]
.ret:
    ret

; ---------------------------------------------------------------------
; ttf_compute_metrics — derive cell width / height / ascent in pixels
; from the loaded TTF and overwrite glass's char_width / char_height /
; font_ascent / font_descent. Without this, those slots hold the X
; core bitmap font's metrics — typically shorter than the TTF cell, so
; descenders ('g', 'j', 'p', 'y') get clipped at the cell bottom.
;
; Cell width = monospace advance of glyph for 'M' (or '0' fallback).
; Cell height = (hhea_ascent + |hhea_descent|) * size / unitsPerEm.
; Ascent      = hhea_ascent  * size / unitsPerEm   (baseline from top).
; Descent     = |hhea_descent| * size / unitsPerEm (cells below baseline).
;
; Called after x11_query_font has run, so we cleanly override the X
; core font metrics. No-op when ttf_active = 0.
ttf_compute_metrics:
    cmp qword [ttf_active], 0
    je .tcm_ret
    push rbx
    push r12
    push r13

    ; arg_size = cfg_font_size (or DEFAULT_FONT_SIZE).
    mov rax, [cfg_font_size]
    test rax, rax
    jnz .tcm_have_size
    mov rax, DEFAULT_FONT_SIZE
.tcm_have_size:
    mov [arg_size], rax
    mov r12, rax                      ; r12 = size
    mov r13, [head_unitsPerEm]        ; r13 = UPE

    ; ----- char_width = advance(glyph 'M') * size / UPE -----
    mov rdi, 'M'
    call cmap_lookup
    test rax, rax
    jnz .tcm_have_glyph
    mov rdi, '0'                      ; fall back to '0'
    call cmap_lookup
    test rax, rax
    jz .tcm_metrics_only              ; can't measure width; keep bitmap value
.tcm_have_glyph:
    mov rdi, rax
    call hmtx_advance                 ; rax = advance in font units
    imul rax, r12
    mov rcx, r13
    shr rcx, 1
    add rax, rcx                      ; round
    xor edx, edx
    div r13
    mov [char_width], ax
.tcm_metrics_only:

    ; ----- ascent_px (baseline from top of cell) -----
    mov rax, [hhea_ascent]            ; signed; ascent is positive in spec
    imul rax, r12
    mov rcx, r13
    shr rcx, 1
    add rax, rcx
    cqo
    idiv r13
    mov [font_ascent], ax
    mov rbx, rax                      ; rbx = ascent_px

    ; ----- descent_px (positive number of pixels below baseline) -----
    mov rax, [hhea_descent]           ; usually negative
    neg rax                           ; flip to positive distance
    imul rax, r12
    mov rcx, r13
    shr rcx, 1
    add rax, rcx
    cqo
    idiv r13
    mov [font_descent], ax

    ; ----- cell height = ascent + |descent| -----
    add rbx, rax
    mov [char_height], bx

    pop r13
    pop r12
    pop rbx
.tcm_ret:
    ret

; ---------------------------------------------------------------------
; ttf_upload_glyph — rdi = codepoint. Renders the glyph via the
; embedded engine, then sends AddGlyphs to install it in the glyphset.
; Marks ttf_glyph_uploaded[cp]. No-op if already uploaded.
ttf_upload_glyph:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp

    cmp rdi, 65536
    jge .ret
    cmp byte [ttf_glyph_uploaded + rdi], 0
    jne .ret
    mov rbx, rdi                       ; remember cp

    ; Render via engine.
    mov rsi, [cfg_font_size]
    test rsi, rsi
    jnz .have_size
    mov rsi, DEFAULT_FONT_SIZE
.have_size:
    call glyph_render_to_alpha
    test eax, eax
    jnz .skip                          ; missing/oversize → just skip

    ; rcx=W rdx=H r8=bearing_x r9=bearing_y r10=advance
    mov r12, rcx                        ; W
    mov r13, rdx                        ; H
    mov r14, r8                         ; bearing_x (signed)
    mov r15, r9                         ; bearing_y
    mov rbp, r10                        ; advance

    ; SPACE (0x20) is the most-rendered "glyph" in any terminal, and
    ; for some fonts (e.g. DejaVu Sans Mono) the rasterizer returns a
    ; 1×1 alpha=0 bitmap rather than a true 0×0 empty. Some XRender
    ; servers visibly composite that 1-pixel "transparent" mask anyway,
    ; producing a stray dot at every empty cell — at large sizes the
    ; dots line up into visible dashes spanning the whole screen. Force
    ; W=H=0 for space so the server stores a zero-area bitmap (advance
    ; only, no mask) and CompositeGlyphs32 has nothing to paint.
    cmp rbx, 0x20
    jne .not_space
    xor r12, r12                        ; W = 0
    xor r13, r13                        ; H = 0
    xor r14, r14                        ; bearing_x = 0
    xor r15, r15                        ; bearing_y = 0
.not_space:

    ; XRender's A8 PictFormat requires scanline stride padded to 4 bytes
    ; (standard X11 image layout: stride = ((w*bpp + 31) >> 5) << 2;
    ; for A8, bpp=8 → stride = (w + 3) & ~3). The earlier "tight W*H,
    ; total padded" guess produced BadLength on RenderAddGlyphs because
    ; the server expected stride*H bytes, not W*H. Compute the padded
    ; stride here so each row has 0..3 zero bytes after its W real bytes.
    mov rax, r12                        ; W
    add rax, 3
    and rax, ~3
    mov rcx, rax                        ; rcx = stride (per row, 4-aligned)
    imul rax, r13                       ; stride * H
    mov r8, rax                         ; padded total alpha (always 4-aligned)

    ; Total request length: 28 (fixed) + padded alpha
    mov rdx, r8
    add rdx, 28
    mov rsi, rdx
    shr rsi, 2                          ; length in 4-byte units

    ; Build into tmp_buf (assumed large enough; cell glyphs at typical
    ; sizes are well under 4KB).
    lea rdi, [tmp_buf]
    mov al, [render_major]
    mov [rdi], al
    mov byte [rdi+1], RENDER_ADD_GLYPHS
    mov [rdi+2], si                     ; length (16-bit)
    mov eax, [ttf_glyphset]
    mov [rdi+4], eax
    mov dword [rdi+8], 1                ; num_glyphs
    mov [rdi+12], ebx                   ; gid = cp
    ; glyphInfo
    mov [rdi+16], r12w                  ; w
    mov [rdi+18], r13w                  ; h
    mov rax, r14
    neg rax                             ; x = -bearing_x
    mov [rdi+20], ax
    mov [rdi+22], r15w                  ; y = +bearing_y
    mov [rdi+24], bp                    ; off-x = advance (low 16 bits)
    mov word [rdi+26], 0                ; off-y = 0
    ; Alpha bytes: copy W*H bytes tightly from output_buf, then
    ; Copy alpha from glyph engine's output_buf, row by row, padding each
    ; row to `rcx` bytes (the 4-aligned stride). output_buf holds W*H
    ; tight bytes, top-left origin; pad bytes are zero so the server sees
    ; transparent extra columns past column W.
    lea rdi, [rdi + 28]                 ; destination
    lea rax, [output_buf]               ; source row cursor
    mov r9, r13                         ; remaining rows
    mov r11, rcx                        ; stride
    sub r11, r12                        ; trailing-zero count per row
.copy_row:
    test r9, r9
    jz .copy_done
    mov rdx, r12                        ; W bytes per row
.copy_byte:
    test rdx, rdx
    jz .copy_pad
    mov cl, [rax]
    mov [rdi], cl
    inc rax
    inc rdi
    dec rdx
    jmp .copy_byte
.copy_pad:
    mov rdx, r11                        ; trailing pad
.copy_pad_byte:
    test rdx, rdx
    jz .copy_row_next
    mov byte [rdi], 0
    inc rdi
    dec rdx
    jmp .copy_pad_byte
.copy_row_next:
    dec r9
    jmp .copy_row
.copy_done:

    ; Send the request. Total bytes = 28 + r8.
    mov rdx, r8
    add rdx, 28
    lea rsi, [tmp_buf]
    call x11_buffer
    inc dword [x11_seq]

.skip:
    mov byte [ttf_glyph_uploaded + rbx], 1
.ret:
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ---------------------------------------------------------------------
; ttf_render_cp — composite a single TTF glyph onto the window.
;   rdi = codepoint
;   rsi = x (pen position, i.e. left edge / baseline x)
;   rdx = y (baseline y)
;   rcx = ARGB foreground colour
;
; Performance-aware path: caller batches by colour where possible
; (we still skip the pen update if the colour matches the cached one).
ttf_render_cp:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp

    mov r12, rdi                       ; cp
    mov r13, rsi                       ; pen x
    mov r14, rdx                       ; pen y
    mov r15, rcx                       ; colour

    ; Upload glyph if first sighting.
    mov rdi, r12
    call ttf_upload_glyph

    ; Set pen colour.
    mov rdi, r15
    call ttf_set_pen_color

    ; Build CompositeGlyphs32 request:
    ;   header(4) + op(1)+pad(3) + src(4) + dst(4) + maskFmt(4) + gset(4)
    ;   + srcX(2) + srcY(2)  = 28 bytes fixed
    ; + element list:
    ;   numGlyphs(1) + pad(3) + dx(2) + dy(2) + glyphIds[1](4) = 12
    ; Total 40 bytes, length = 10 dwords.
    lea rdi, [tmp_buf]
    mov al, [render_major]
    mov [rdi], al
    mov byte [rdi+1], RENDER_COMPOSITE_GLYPHS_32
    mov word [rdi+2], 10                ; length
    ; OP_OVER: dst = src·α + dst·(1-α). OP_SRC overwrites with src·α
    ; everywhere, so transparent pixels in the alpha mask wrote pen·0=0
    ; (black), producing the dotted/speckled fringe around glyph edges.
    mov byte [rdi+4], RENDER_OP_OVER
    mov byte [rdi+5], 0
    mov word [rdi+6], 0
    mov eax, [ttf_pen_picture]
    mov [rdi+8], eax                    ; src
    mov eax, [render_window_picture]
    mov [rdi+12], eax                   ; dst
    mov eax, [render_format_a8]
    mov [rdi+16], eax                   ; maskFormat (explicit alpha8)
    mov eax, [ttf_glyphset]
    mov [rdi+20], eax
    mov word [rdi+24], 0                ; src x
    mov word [rdi+26], 0                ; src y
    ; element list:
    mov byte [rdi+28], 1                ; numGlyphs
    mov byte [rdi+29], 0
    mov word [rdi+30], 0
    mov [rdi+32], r13w                  ; dx (pen x)
    mov [rdi+34], r14w                  ; dy (pen y)
    mov [rdi+36], r12d                  ; glyph id

    lea rsi, [tmp_buf]
    mov rdx, 40
    call x11_buffer
    inc dword [x11_seq]

    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ---------------------------------------------------------------------
; ensure_render_gc — lazy-create a depth-32 GC bound to the pen pixmap.
; Only called from ttf_set_pen_color when render_temp_gc is still 0.
; The same GC is reused thereafter for all PutImage uploads to the pen.
ensure_render_gc:
    cmp dword [render_temp_gc], 0
    jne .ret
    call alloc_xid
    mov [render_temp_gc], eax
    lea rdi, [tmp_buf]
    mov byte [rdi], 55                  ; CreateGC opcode
    mov byte [rdi+1], 0
    mov word [rdi+2], 4                 ; length=4 (no values)
    mov eax, [render_temp_gc]
    mov [rdi+4], eax
    mov eax, [ttf_pen_pixmap]
    mov [rdi+8], eax                    ; drawable (depth-32)
    mov dword [rdi+12], 0               ; value-mask = 0
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]
.ret:
    ret

; ---------------------------------------------------------------------
; glyph TTF rasterizer engine — embedded for high-quality TTF text
; rendering via XRender CompositeGlyphs32. GLYPH_LIB suppresses the
; CLI parts so only the engine procedures (glyph_load_font,
; glyph_set_weight, glyph_render_to_alpha) come along — no _start,
; no PGM emit, no argv/CLI helpers. See ../glyph/README.md for the API.
%define GLYPH_LIB
%include "../glyph/glyph.asm"
