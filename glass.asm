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
%define RENDER_OP_OVER               3

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

; Standard 16-color palette (0x00RRGGBB)
std_colors:
    dd 0x00000000  ; 0  black
    dd 0x00AA0000  ; 1  red
    dd 0x0000AA00  ; 2  green
    dd 0x00AA5500  ; 3  yellow/brown
    dd 0x000000AA  ; 4  blue
    dd 0x00AA00AA  ; 5  magenta
    dd 0x0000AAAA  ; 6  cyan
    dd 0x00AAAAAA  ; 7  white
    dd 0x00555555  ; 8  bright black
    dd 0x00FF5555  ; 9  bright red
    dd 0x0055FF55  ; 10 bright green
    dd 0x00FFFF55  ; 11 bright yellow
    dd 0x005555FF  ; 12 bright blue
    dd 0x00FF55FF  ; 13 bright magenta
    dd 0x0055FFFF  ; 14 bright cyan
    dd 0x00FFFFFF  ; 15 bright white

; ══════════════════════════════════════════════════════════════════════
; BSS section
; ══════════════════════════════════════════════════════════════════════
section .bss

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
gc_current_font:    resd 1          ; tracks which font is loaded in gc_id
gc_current_fg:      resd 1          ; last fg pixel pushed via ChangeGC
gc_current_bg:      resd 1          ; last bg pixel pushed via ChangeGC
gc_colors_valid:    resb 1          ; 1 once gc_current_fg/bg are seeded

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

; Runtime-toggleable state (Alt+plus/minus/_, Alt+b, Alt+t)
bg_cycle_pixels:    resd 16         ; up to 16 cycle colors
bg_cycle_count:     resq 1          ; number of colors parsed from .glassrc
bg_cycle_idx:       resq 1          ; current index in cycle (0 = first entry)
saved_bg_pixel:     resd 1          ; configured cfg_bg before any cycling
saved_bg_set:      resb 1          ; 1 if saved_bg_pixel is valid
opacity_toggle:     resb 1          ; 0 = opaque (or untouched), 1 = ~50%
opacity_atom:       resd 1          ; _NET_WM_WINDOW_OPACITY atom id
opacity_atom_set:   resb 1          ; 1 once interned
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
dyn_font_name:      resb 128
dyn_font_name_len:  resq 1
dyn_bold_font_name: resb 128
dyn_bold_font_name_len: resq 1

; Mouse escape sequence buffer
mouse_seq_buf:      resb 32

; Misc
tmp_buf:            resb 4096
num_buf:            resb 32
key_out_buf:        resb 32
rs_row_base:        resq 1          ; pointer to current row's cell data

; ══════════════════════════════════════════════════════════════════════
; Text section
; ══════════════════════════════════════════════════════════════════════
section .text
global _start

_start:
    ; Save envp
    mov rdi, [rsp]          ; argc
    lea rsi, [rsp + 8]      ; argv
    lea rax, [rdi + 1]
    lea rcx, [rsi + rax*8]
    mov [envp], rcx

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
    jne .xsr_check_window
    cmp edx, 16
    jne .xsr_check_window
    cmp esi, 8
    jne .xsr_check_window
    test edi, edi
    jnz .xsr_check_window
    cmp r8d, 24
    jne .xsr_check_window
    cmp r9d, 0xFF
    jne .xsr_check_window
    cmp dword [render_format_argb32], 0
    jne .xsr_check_window               ; already found
    mov eax, [rbx]
    mov [render_format_argb32], eax
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

    ; Set window size from current grid dimensions (set by x11_get_geometry)
    sub rsp, 8
    movzx eax, word [grid_rows]
    mov word [rsp], ax
    movzx eax, word [grid_cols]
    mov word [rsp+2], ax
    mov word [rsp+4], 0
    mov word [rsp+6], 0
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
    jne .ptf_env_keep
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
.ptf_env_keep:
    mov [rdi + rcx*8], rax
    inc ecx
.ptf_env_skip:
    add rsi, 8
    jmp .ptf_env_copy
.ptf_env_add_term:
    test r8d, r8d
    jnz .ptf_env_done
    ; TERM wasn't in env, add it
    lea rax, [term_env]
    mov [rdi + rcx*8], rax
    inc ecx
.ptf_env_done:
    mov qword [rdi + rcx*8], 0  ; null terminate

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

    ; Check X11 events
    movzx eax, word [poll_fds + 6]
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
    je .hxe_skip

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
    ; Resize PTY
    sub rsp, 8
    movzx eax, word [grid_rows]
    mov word [rsp], ax        ; ws_row
    movzx eax, word [grid_cols]
    mov word [rsp+2], ax      ; ws_col
    mov word [rsp+4], 0
    mov word [rsp+6], 0
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
    ; First ConfigureNotify: do the wallpaper sample + blend. WMs often
    ; emit a burst of CNs at startup (initial map plus reparenting); we
    ; don't want to re-run this expensive path for each, otherwise we
    ; starve the PTY read in the event loop.
    cmp byte [cfg_opacity_set], 1
    jne .hxe_cfg_no_pseudo
    cmp byte [compositor_active], 1
    je .hxe_cfg_no_pseudo
    cmp byte [pseudo_setup_done], 0
    jne .hxe_cfg_no_pseudo
    mov byte [pseudo_setup_done], 1
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

    ; Dispatch on keysym ranges
    ; Special keys (0xFF00-0xFFFF)
    cmp eax, 0xFF00
    jge .hkp_special

    ; Latin-1 supplement (0x00A0-0x00FF) - encode as UTF-8 2-byte
    cmp eax, 0xA0
    jb .hkp_check_ascii
    cmp eax, 0xFF
    ja .hkp_done
    ; 2-byte UTF-8: 110xxxxx 10xxxxxx
    mov ecx, eax
    shr ecx, 6               ; high 2 bits → first byte low bits
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
    mov byte [key_out_buf], 0x1B
    mov byte [key_out_buf+1], '['
    mov byte [key_out_buf+2], 'A'
    mov rdx, 3
    jmp .hkp_send_seq

.hkp_down:
    mov byte [key_out_buf], 0x1B
    mov byte [key_out_buf+1], '['
    mov byte [key_out_buf+2], 'B'
    mov rdx, 3
    jmp .hkp_send_seq

.hkp_right:
    mov byte [key_out_buf], 0x1B
    mov byte [key_out_buf+1], '['
    mov byte [key_out_buf+2], 'C'
    mov rdx, 3
    jmp .hkp_send_seq

.hkp_left:
    mov byte [key_out_buf], 0x1B
    mov byte [key_out_buf+1], '['
    mov byte [key_out_buf+2], 'D'
    mov rdx, 3
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
    jne .vtp_csi_final
    ; Next parameter
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
    ; Clear the grid for alt screen use
    call grid_clear
    mov qword [cursor_row], 0
    mov qword [cursor_col], 0
    mov qword [alt_screen_active], 1
    jmp .vtp_loop

.vtp_alt_screen_off:
    cmp qword [alt_screen_active], 0
    je .vtp_loop                ; already on main screen
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
    mov qword [cursor_style], 0
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

; Clear entire grid. Bound the work to the active grid_rows ×
; grid_cols rather than walking the full MAX_ROWS × MAX_COLS slab
; (51200 cells, 800KB written) every time. For an 80x24 window that
; is a 27× speed-up on every CSI 2J / alt-screen toggle / startup.
;
; Cells past the current dims keep their old contents — that's safe
; because the configure handler reclears the freshly-exposed area
; whenever the grid grows (see .hxe_configure).
grid_clear:
    push rbx
    push r12
    push r13
    mov r13, [grid_rows]
    mov r12, [grid_cols]
    test r13, r13
    jnz .gc_have_dims
    ; Startup: dims not set yet. Clear the whole slab so the first
    ; render doesn't show NUL chars in stale cells.
    mov r13, MAX_ROWS
    mov r12, MAX_COLS
.gc_have_dims:
    xor rbx, rbx                     ; row index
    lea rdi, [grid]                  ; row base pointer
.gc_row:
    cmp rbx, r13
    jge .gc_after_rows
    mov rcx, r12                     ; cells in this row
    mov rsi, rdi                     ; cell cursor (preserve row base)
.gc_cell:
    mov qword [rsi], DEFAULT_CELL_LO
    mov qword [rsi + 8], 0
    add rsi, CELL_SIZE
    dec rcx
    jnz .gc_cell
    add rdi, MAX_COLS * CELL_SIZE    ; advance to next row's first cell
    inc rbx
    jmp .gc_row
.gc_after_rows:
    xor rbx, rbx
.gc_wrap_reset:
    cmp rbx, r13
    jge .gc_wrap_done
    mov byte [row_wrapped + rbx], 0
    inc rbx
    jmp .gc_wrap_reset
.gc_wrap_done:
    pop r13
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
    mov byte [gc_colors_valid], 0    ; bell flash trampled fg, invalidate cache
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
    ; Skip the request entirely when both colors match the values we
    ; already pushed — every avoided ChangeGC saves 20 bytes on the
    ; X11 socket and one server-side request dispatch. Adjacent same-
    ; colored runs are common (think a wall of dim grey text).
    cmp byte [gc_colors_valid], 1
    jne .rs_gc_color_send
    cmp r14d, [gc_current_fg]
    jne .rs_gc_color_send
    cmp r15d, [gc_current_bg]
    je .rs_gc_color_done
.rs_gc_color_send:
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
    mov [gc_current_fg], r14d
    mov [gc_current_bg], r15d
    mov byte [gc_colors_valid], 1
    pop rcx
.rs_gc_color_done:

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
    ; OSC 8 hyperlink underline pass: scan grid for cells whose link id
    ; is non-zero and draw an underline per contiguous span. Done as
    ; a separate pass so it doesn't perturb the per-color text-run logic.
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
    mov byte [gc_colors_valid], 0    ; URL underline changed fg
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
    mov byte [gc_colors_valid], 0    ; cursor draw changed fg

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
    ; Match "font_size"
    cmp dword [rsi], 'font'
    jne .lc_try_blink
    cmp dword [rsi+4], '_siz'
    jne .lc_try_blink
    cmp byte [rsi+8], 'e'
    jne .lc_try_blink
    add rsi, 9
    call lc_skip_to_value
    ; Parse decimal number
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
    ; Match "opacity"
    cmp dword [rsi], 'opac'
    jne .lc_try_bg_cycle
    cmp word [rsi+4], 'it'
    jne .lc_try_bg_cycle
    cmp byte [rsi+6], 'y'
    jne .lc_try_bg_cycle
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
    jne .lc_try_keybind
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
    ; Find current cfg_font_size in preset table
    mov rax, [cfg_font_size]
    test rax, rax
    jnz .fcs_search
    mov rax, DEFAULT_FONT_SIZE       ; treat unset as default
.fcs_search:
    xor ecx, ecx
.fcs_search_loop:
    cmp ecx, FONT_SIZE_PRESET_COUNT
    jge .fcs_use_default_idx
    cmp rax, [font_size_presets + rcx*8]
    je .fcs_found_idx
    inc ecx
    jmp .fcs_search_loop
.fcs_use_default_idx:
    mov ecx, 1                       ; index of 13 in the table
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

    ; Tell PTY about the new size + signal the child to redraw.
    sub rsp, 8
    movzx eax, word [grid_rows]
    mov word [rsp], ax
    movzx eax, word [grid_cols]
    mov word [rsp+2], ax
    mov word [rsp+4], 0
    mov word [rsp+6], 0
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
    ; Lazily intern the atom on first use.
    cmp byte [opacity_atom_set], 1
    je .ota_have_atom
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_INTERN_ATOM
    mov byte [rdi+1], 0              ; only-if-exists = false
    mov word [rdi+2], 2 + (opacity_atom_len + 3) / 4
    mov word [rdi+4], opacity_atom_len
    mov word [rdi+6], 0
    lea rsi, [opacity_atom_str]
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
    mov eax, [x11_buf + 8]           ; atom id at offset 8 of reply
    test eax, eax
    jz .ota_done
    mov [opacity_atom], eax
    mov byte [opacity_atom_set], 1

.ota_have_atom:
    ; Toggle state and pick the cardinal value.
    movzx eax, byte [opacity_toggle]
    xor eax, 1
    mov [opacity_toggle], al
    test al, al
    jz .ota_opaque
    mov ebx, 0x80000000              ; ~50% opacity
    jmp .ota_have_value
.ota_opaque:
    mov ebx, 0xFFFFFFFF              ; fully opaque
.ota_have_value:

    ; ChangeProperty(window, _NET_WM_WINDOW_OPACITY, CARDINAL, 32, 1, [value])
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_PROPERTY
    mov byte [rdi+1], 0              ; mode = Replace
    mov word [rdi+2], 7              ; 6 header + 1 data word
    mov eax, [win_id]
    mov [rdi+4], eax
    mov eax, [opacity_atom]
    mov [rdi+8], eax
    mov dword [rdi+12], 6            ; XA_CARDINAL = 6
    mov byte [rdi+16], 32            ; format
    mov byte [rdi+17], 0
    mov word [rdi+18], 0
    mov dword [rdi+20], 1            ; data length (in 32-bit units)
    mov [rdi+24], ebx                ; the cardinal value
    lea rsi, [tmp_buf]
    mov rdx, 28
    call x11_buffer
    inc dword [x11_seq]
    call x11_flush

    ; If no compositor is running, _NET_WM_WINDOW_OPACITY is silently
    ; ignored — fall through to glass's wallpaper-blend pseudo path so
    ; the user sees something happen.
    cmp byte [compositor_active], 1
    je .ota_done
    cmp byte [opacity_toggle], 1
    je .ota_pseudo_on
    call pseudo_disable
    call render_screen
    call x11_flush
    jmp .ota_done
.ota_pseudo_on:
    mov byte [cfg_opacity], 128
    mov byte [cfg_opacity_set], 1
    mov byte [pseudo_setup_done], 0
    call setup_pseudo_transparency
    call render_screen
    call x11_flush
.ota_done:
    pop rbx
    ret
