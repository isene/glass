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

; ══════════════════════════════════════════════════════════════════════
; Constants
; ══════════════════════════════════════════════════════════════════════
%define AF_UNIX         1
%define SOCK_STREAM     1
%define O_RDWR          2
%define O_RDONLY         0
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
%define X11_QUERY_FONT        47
%define X11_CREATE_GC         55
%define X11_CHANGE_GC         56
%define X11_CLEAR_AREA        61
%define X11_POLY_FILL_RECT    70
%define X11_IMAGE_TEXT8       76
%define X11_GET_KEYBOARD_MAPPING 101

; X11 event types
%define EV_KEY_PRESS        2
%define EV_KEY_RELEASE      3
%define EV_EXPOSE           12
%define EV_CONFIGURE_NOTIFY 22
%define EV_CLIENT_MESSAGE   33
%define EV_FOCUS_IN         9
%define EV_FOCUS_OUT        10

; X11 masks
%define KEY_PRESS_MASK      0x00000001
%define EXPOSURE_MASK       0x00008000
%define STRUCTURE_NOTIFY_MASK 0x00020000
%define FOCUS_CHANGE_MASK   0x00200000
%define EVENT_MASK_ALL      0x00228001

; CreateWindow value mask bits
%define CW_BACK_PIXEL       0x00000002
%define CW_EVENT_MASK       0x00000800

; CreateGC value mask bits
%define GC_FOREGROUND       0x00000004
%define GC_BACKGROUND       0x00000008
%define GC_FONT             0x00004000

; Terminal defaults
%define DEFAULT_COLS    80
%define DEFAULT_ROWS    24
%define MAX_COLS        256
%define MAX_ROWS        128
%define CELL_SIZE       4

; VT parser states
%define VT_NORMAL       0
%define VT_ESC          1
%define VT_CSI          2
%define VT_CSI_PARAM    3
%define VT_OSC          4

; ══════════════════════════════════════════════════════════════════════
; Data section
; ══════════════════════════════════════════════════════════════════════
section .data

; X11 auth
auth_name:      db "MIT-MAGIC-COOKIE-1"
auth_name_len   equ 18

; X11 socket path template
x11_sock_pre:   db "/tmp/.X11-unix/X", 0

; Font name
font_name:      db "fixed", 0
font_name_len   equ 5

; WM atom names
wm_protocols_str: db "WM_PROTOCOLS", 0
wm_protocols_len  equ 12
wm_delete_str:  db "WM_DELETE_WINDOW", 0
wm_delete_len   equ 16

; Window title
win_title:      db "glass", 0
win_title_len   equ 5

; WM_CLASS
wm_class:       db "glass", 0, "Glass", 0
wm_class_len    equ 12

; PTY paths
ptmx_path:      db "/dev/ptmx", 0
pts_prefix:     db "/dev/pts/", 0

; Shell to launch
shell_name:     db "bare", 0
shell_flag:     db "-l", 0

; Error messages
err_x11:        db "glass: cannot connect to X11", 10
err_x11_len     equ $ - err_x11
err_x11_auth:   db "glass: X11 auth failed", 10
err_x11_auth_len equ $ - err_x11_auth
err_pty:        db "glass: cannot open PTY", 10
err_pty_len     equ $ - err_pty
err_fork:       db "glass: fork failed", 10
err_fork_len    equ $ - err_fork

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
x11_root_depth:     resb 1
x11_white_pixel:    resd 1
x11_black_pixel:    resd 1
x11_min_keycode:    resb 1
x11_max_keycode:    resb 1

; Our resources
win_id:             resd 1
gc_id:              resd 1
gc_bg_id:           resd 1
font_id:            resd 1
wm_protocols_atom:  resd 1
wm_delete_atom:     resd 1

; Font metrics
font_ascent:        resw 1
font_descent:       resw 1
char_width:         resw 1
char_height:        resw 1

; Keyboard
keymap:             resd 512
keysyms_per_code:   resd 1

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

; VT parser
vt_state:           resq 1
vt_params:          resd 16
vt_param_count:     resq 1
vt_private:         resb 1

; Current attributes
cur_fg:             resb 1
cur_bg:             resb 1
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
display_num:        resq 1

; 256-color palette
palette:            resd 256

; Misc
tmp_buf:            resb 4096
num_buf:            resb 32
key_out_buf:        resb 32

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
    mov byte [cur_fg], 7
    mov byte [cur_bg], 0
    mov qword [grid_cols], DEFAULT_COLS
    mov qword [grid_rows], DEFAULT_ROWS

    ; Initialize grid with spaces
    call grid_clear

    ; Parse DISPLAY number
    call parse_display

    ; Read Xauthority
    call read_xauthority

    ; Connect to X11
    call x11_connect
    test rax, rax
    jnz .die_x11

    ; Parse X11 setup reply
    call x11_parse_setup

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

    ; Map window
    call x11_map_window

    ; Flush all pending X11 requests
    call x11_flush

    ; Open PTY
    call pty_open
    test rax, rax
    jnz .die_pty

    ; Fork child
    call pty_fork
    test rax, rax
    jnz .die_fork

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
    mov eax, [r12 + 32]
    mov [x11_root_visual], eax
    movzx eax, byte [r12 + 38]
    mov [x11_root_depth], al

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
x11_send_recv:
    call x11_flush
    ; Read reply
    mov rax, SYS_READ
    mov rdi, [x11_fd]
    lea rsi, [x11_buf]
    mov rdx, 8192
    syscall
    ret

; Open font
x11_open_font:
    push rbx
    call alloc_xid
    mov [font_id], eax

    ; Build OpenFont request
    ; opcode=45, pad, length, fid, name_len, pad, name...
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_OPEN_FONT
    mov byte [rdi+1], 0
    ; length = (3 + pad4(name_len)/4) words
    mov ecx, font_name_len
    add ecx, 3
    and ecx, ~3
    shr ecx, 2
    add ecx, 3
    mov word [rdi+2], cx
    mov eax, [font_id]
    mov [rdi+4], eax
    mov word [rdi+8], font_name_len
    mov word [rdi+10], 0
    ; Copy font name
    lea rsi, [font_name]
    lea rbx, [rdi + 12]
    xor ecx, ecx
.xof_cp:
    cmp ecx, font_name_len
    jge .xof_pad
    movzx eax, byte [rsi + rcx]
    mov [rbx + rcx], al
    inc ecx
    jmp .xof_cp
.xof_pad:
    ; Pad to 4
    mov eax, font_name_len
    add eax, 3
    and eax, ~3
    add eax, 12
    ; Send
    mov rdx, rax
    lea rsi, [tmp_buf]
    call x11_buffer
    inc dword [x11_seq]

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

    ; Calculate window size
    movzx eax, word [char_width]
    imul eax, DEFAULT_COLS
    mov [win_width], rax
    movzx eax, word [char_height]
    imul eax, DEFAULT_ROWS
    mov [win_height], rax

    ; Build CreateWindow request
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CREATE_WINDOW     ; opcode
    mov al, [x11_root_depth]
    mov byte [rdi+1], al                  ; depth
    mov word [rdi+2], 10                  ; length (8 + 2 values = 10 words)
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
    mov eax, [x11_root_visual]
    mov [rdi+24], eax                     ; visual
    mov dword [rdi+28], CW_BACK_PIXEL | CW_EVENT_MASK  ; value-mask
    mov eax, [x11_black_pixel]
    mov [rdi+32], eax                     ; back-pixel
    mov dword [rdi+36], EVENT_MASK_ALL    ; event-mask

    lea rsi, [tmp_buf]
    mov rdx, 40
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
    mov eax, [x11_white_pixel]
    mov [rdi+16], eax        ; foreground
    mov eax, [x11_black_pixel]
    mov [rdi+20], eax        ; background
    mov eax, [font_id]
    mov [rdi+24], eax        ; font

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
    mov eax, [x11_black_pixel]
    mov [rdi+16], eax

    lea rsi, [tmp_buf]
    mov rdx, 20
    call x11_buffer
    inc dword [x11_seq]

    pop rbx
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

    ; Set window size
    sub rsp, 8
    mov word [rsp], DEFAULT_ROWS
    mov word [rsp+2], DEFAULT_COLS
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

    ; Find shell in PATH
    ; For now, try common locations
    ; Try /home/geir/bin/bare first, then /usr/local/bin/bare, then /bin/sh
    sub rsp, 32
    lea rax, [.ptf_shell1]
    mov [rsp], rax
    lea rax, [shell_flag]
    mov [rsp+8], rax
    mov qword [rsp+16], 0
    mov rdi, [rsp]
    mov rsi, rsp
    mov rdx, [envp]
    mov rax, SYS_EXECVE
    syscall
    ; Try fallback
    lea rax, [.ptf_shell2]
    mov [rsp], rax
    mov rdi, [rsp]
    mov rsi, rsp
    mov rdx, [envp]
    mov rax, SYS_EXECVE
    syscall
    ; Last resort: /bin/sh
    lea rax, [.ptf_shell3]
    mov [rsp], rax
    mov qword [rsp+8], 0
    mov rdi, [rsp]
    mov rsi, rsp
    mov rdx, [envp]
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
    ; Poll
    mov rax, SYS_POLL
    lea rdi, [poll_fds]
    mov rsi, 2                ; nfds
    mov rdx, -1               ; timeout = infinite
    syscall
    test rax, rax
    jle .ev_loop              ; error or timeout, retry

    ; Check X11 events
    movzx eax, word [poll_fds + 6]
    test eax, POLLIN
    jz .ev_check_pty
    call handle_x11_events
    mov word [poll_fds + 6], 0

.ev_check_pty:
    ; Check PTY output
    movzx eax, word [poll_fds + 14]
    test eax, POLLIN
    jz .ev_loop
    mov word [poll_fds + 14], 0

    ; Read PTY output
    mov rax, SYS_READ
    mov rdi, [pty_master]
    lea rsi, [pty_read_buf]
    mov rdx, 4096
    syscall
    test rax, rax
    jle .ev_child_died

    ; Process VT sequences
    mov rcx, rax
    lea rsi, [pty_read_buf]
    call vt_process

    ; Render screen
    call render_screen
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
    cmp al, EV_EXPOSE
    je .hxe_expose
    cmp al, EV_CONFIGURE_NOTIFY
    je .hxe_configure
    cmp al, EV_CLIENT_MESSAGE
    je .hxe_client_msg

.hxe_skip:
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
    ; Send SIGWINCH to child process group
    mov rax, SYS_KILL
    mov rdi, [child_pid]
    neg rdi                   ; negative pid = process group
    mov rsi, SIGWINCH
    syscall
.hxe_cfg_done:
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

; Handle keypress
; eax = keycode, ecx = state (modifiers)
handle_keypress:
    push rbx
    push r12
    mov r12d, eax            ; keycode
    mov ebx, ecx             ; state

    ; Simple keycode to ASCII mapping
    ; For Phase 1: handle basic ASCII keys via direct mapping
    ; keycodes 10-19 = 1-9,0
    ; keycodes 24-33 = q-p
    ; keycodes 38-46 = a-l
    ; keycodes 52-58 = z-m
    ; keycode 65 = space
    ; keycode 36 = Return
    ; keycode 22 = BackSpace
    ; keycode 23 = Tab
    ; keycode 9 = Escape

    ; Check for Ctrl modifier (bit 2 of state)
    mov edx, ebx
    and edx, 4               ; ControlMask

    cmp r12d, 9
    je .hkp_escape
    cmp r12d, 22
    je .hkp_backspace
    cmp r12d, 23
    je .hkp_tab
    cmp r12d, 36
    je .hkp_return
    cmp r12d, 65
    je .hkp_space
    cmp r12d, 111
    je .hkp_up
    cmp r12d, 116
    je .hkp_down
    cmp r12d, 113
    je .hkp_left
    cmp r12d, 114
    je .hkp_right

    ; Map keycode to ASCII using simple table
    ; This is a simplified qwerty mapping
    lea rsi, [.hkp_keymap]
    cmp r12d, 128
    jge .hkp_done
    movzx eax, byte [rsi + r12]
    test al, al
    jz .hkp_done

    ; Check shift (bit 0 of state)
    test ebx, 1
    jz .hkp_no_shift
    ; Uppercase for letters
    cmp al, 'a'
    jb .hkp_shift_sym
    cmp al, 'z'
    ja .hkp_no_shift
    sub al, 32               ; to uppercase
    jmp .hkp_no_shift
.hkp_shift_sym:
    ; Shift symbols
    cmp al, '1'
    jb .hkp_no_shift
    cmp al, '='
    ja .hkp_no_shift
    lea rsi, [.hkp_shift_table]
    sub al, '!'
    movzx ecx, al
    movzx eax, byte [rsi + rcx]
    test al, al
    jz .hkp_done

.hkp_no_shift:
    ; Apply Ctrl modifier
    test edx, edx
    jz .hkp_send_char
    and al, 0x1F             ; Ctrl mask
.hkp_send_char:
    mov [key_out_buf], al
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [key_out_buf]
    mov rdx, 1
    syscall
    jmp .hkp_done

.hkp_escape:
    mov byte [key_out_buf], 27
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [key_out_buf]
    mov rdx, 1
    syscall
    jmp .hkp_done

.hkp_backspace:
    mov byte [key_out_buf], 127
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [key_out_buf]
    mov rdx, 1
    syscall
    jmp .hkp_done

.hkp_tab:
    mov byte [key_out_buf], 9
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [key_out_buf]
    mov rdx, 1
    syscall
    jmp .hkp_done

.hkp_return:
    mov byte [key_out_buf], 13
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [key_out_buf]
    mov rdx, 1
    syscall
    jmp .hkp_done

.hkp_space:
    mov byte [key_out_buf], ' '
    test edx, edx
    jz .hkp_send_space
    mov byte [key_out_buf], 0  ; Ctrl-Space = NUL
.hkp_send_space:
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [key_out_buf]
    mov rdx, 1
    syscall
    jmp .hkp_done

.hkp_up:
    mov dword [key_out_buf], 0x00415B1B  ; ESC[A
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [key_out_buf]
    mov rdx, 3
    syscall
    jmp .hkp_done

.hkp_down:
    mov dword [key_out_buf], 0x00425B1B  ; ESC[B
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [key_out_buf]
    mov rdx, 3
    syscall
    jmp .hkp_done

.hkp_right:
    mov dword [key_out_buf], 0x00435B1B  ; ESC[C
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [key_out_buf]
    mov rdx, 3
    syscall
    jmp .hkp_done

.hkp_left:
    mov dword [key_out_buf], 0x00445B1B  ; ESC[D
    mov rax, SYS_WRITE
    mov rdi, [pty_master]
    lea rsi, [key_out_buf]
    mov rdx, 3
    syscall
    jmp .hkp_done

.hkp_done:
    pop r12
    pop rbx
    ret

; Keycode to ASCII mapping (simplified US QWERTY)
; Index = X11 keycode, value = ASCII char (0 = unmapped)
.hkp_keymap:
    times 10 db 0             ; 0-9
    db '1','2','3','4','5','6','7','8','9','0'  ; 10-19
    db '-','=',0,0            ; 20-23
    db 'q','w','e','r','t','y','u','i','o','p'  ; 24-33
    db '[',']',0,0            ; 34-37
    db 'a','s','d','f','g','h','j','k','l'      ; 38-46
    db ';',0x27,'`'           ; 47-49 (semicolon, quote, backtick)
    db 0,'\'                  ; 50-51 (shift, backslash)
    db 'z','x','c','v','b','n','m'              ; 52-58
    db ',','.','/'            ; 59-61
    times 66 db 0             ; 62-127

; Shift symbol mapping (indexed by ASCII code - '!')
.hkp_shift_table:
    db '!','@','#',0x24,'%','^','&','*','(',')'   ; !-) (shift 1-0)
    db 0,0,0,'_','+'          ; shift -,=
    times 20 db 0
    db '{','|','}'            ; shift [,\,]
    times 10 db 0
    db ':','"','~'            ; shift ;,',`
    times 10 db 0
    db '<','>','?'            ; shift ,./
    times 30 db 0

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
    je .vtp_loop             ; ignore
    cmp al, 0x20
    jb .vtp_loop             ; ignore other control chars

    ; UTF-8 handling: skip continuation bytes (0x80-0xBF)
    ; so multi-byte chars occupy one grid cell (matching terminal width)
    cmp al, 0x80
    jb .vtp_ascii
    cmp al, 0xBF
    jbe .vtp_loop            ; skip continuation bytes
    ; UTF-8 lead byte (0xC0+): show placeholder
    mov al, '?'
.vtp_ascii:
    ; Printable character
    call grid_put_char
    jmp .vtp_loop

.vtp_start_esc:
    mov qword [vt_state], VT_ESC
    jmp .vtp_loop

.vtp_cr:
    mov qword [cursor_col], 0
    jmp .vtp_loop

.vtp_lf:
    mov rax, [cursor_row]
    inc rax
    cmp rax, [grid_rows]
    jl .vtp_lf_ok
    ; Scroll up
    call grid_scroll_up
    mov rax, [grid_rows]
    dec rax
.vtp_lf_ok:
    mov [cursor_row], rax
    jmp .vtp_loop

.vtp_bs:
    cmp qword [cursor_col], 0
    je .vtp_loop
    dec qword [cursor_col]
    jmp .vtp_loop

.vtp_tab:
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
    jmp .vtp_loop

.vtp_start_csi:
    mov qword [vt_state], VT_CSI
    mov qword [vt_param_count], 0
    mov dword [vt_params], 0
    mov byte [vt_private], 0
    jmp .vtp_loop

.vtp_save_cursor:
    mov rax, [cursor_row]
    mov [cursor_saved_row], rax
    mov rax, [cursor_col]
    mov [cursor_saved_col], rax
    jmp .vtp_loop

.vtp_restore_cursor:
    mov rax, [cursor_saved_row]
    mov [cursor_row], rax
    mov rax, [cursor_saved_col]
    mov [cursor_col], rax
    jmp .vtp_loop

.vtp_reverse_index:
    cmp qword [cursor_row], 0
    je .vtp_ri_scroll
    dec qword [cursor_row]
    jmp .vtp_loop
.vtp_ri_scroll:
    call grid_scroll_down
    jmp .vtp_loop

.vtp_start_osc:
    mov qword [vt_state], VT_OSC
    jmp .vtp_loop

.vtp_osc:
    ; Consume until BEL (7) or ST (ESC \)
    cmp al, 7
    je .vtp_osc_end
    cmp al, 27               ; might be ESC \ (ST)
    jne .vtp_loop
    ; Check next byte for backslash
    cmp r14, r13
    jge .vtp_loop
    cmp byte [r12 + r14], '\'
    jne .vtp_loop
    inc r14
.vtp_osc_end:
    mov qword [vt_state], VT_NORMAL
    jmp .vtp_loop

.vtp_full_reset:
    call grid_clear
    mov qword [cursor_row], 0
    mov qword [cursor_col], 0
    mov byte [cur_fg], 7
    mov byte [cur_bg], 0
    mov byte [cur_attrs], 0
    jmp .vtp_loop

.vtp_csi:
    ; Build parameters
    cmp al, '?'
    je .vtp_csi_private
    cmp al, '0'
    jb .vtp_csi_final
    cmp al, '9'
    ja .vtp_csi_sep
    ; Digit: build param value
    mov qword [vt_state], VT_CSI_PARAM
    mov rcx, [vt_param_count]
    ; params[count] = params[count] * 10 + (al - '0')
    mov edx, [vt_params + rcx*4]
    imul edx, 10
    movzx ebx, al
    sub ebx, '0'
    add edx, ebx
    mov [vt_params + rcx*4], edx
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
    cmp al, 'r'
    je .vtp_loop            ; ignore DECSTBM for now
    cmp al, 'h'
    je .vtp_loop            ; ignore set mode for now
    cmp al, 'l'
    je .vtp_loop            ; ignore reset mode for now
    jmp .vtp_loop

; CSI A - Cursor Up
.vtp_csi_cuu:
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
.vtp_csi_cup:
    mov eax, [vt_params]     ; row (1-based)
    test eax, eax
    jnz .vtp_cup_row
    mov eax, 1
.vtp_cup_row:
    dec eax                  ; 0-based
    mov [cursor_row], rax
    ; Clamp
    mov rcx, [grid_rows]
    dec rcx
    cmp rax, rcx
    jle .vtp_cup_col
    mov [cursor_row], rcx
.vtp_cup_col:
    mov eax, [vt_params + 4] ; col (1-based)
    test eax, eax
    jnz .vtp_cup_c
    mov eax, 1
.vtp_cup_c:
    dec eax
    mov [cursor_col], rax
    mov rcx, [grid_cols]
    dec rcx
    cmp rax, rcx
    jle .vtp_loop
    mov [cursor_col], rcx
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

; CSI G - Cursor Horizontal Absolute
.vtp_csi_cha:
    mov eax, [vt_params]
    test eax, eax
    jnz .vtp_cha_go
    mov eax, 1
.vtp_cha_go:
    dec eax
    mov [cursor_col], rax
    jmp .vtp_loop

; CSI d - Line Position Absolute
.vtp_csi_vpa:
    mov eax, [vt_params]
    test eax, eax
    jnz .vtp_vpa_go
    mov eax, 1
.vtp_vpa_go:
    dec eax
    mov [cursor_row], rax
    jmp .vtp_loop

; CSI S - Scroll Up
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
    call grid_scroll_up
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
    mov rax, [cursor_row]
    mov [cursor_saved_row], rax
    mov rax, [cursor_col]
    mov [cursor_saved_col], rax
    jmp .vtp_loop

; CSI u - Restore Cursor Position
.vtp_csi_restore_cursor:
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
    ; Copy cell at col+n to col
    mov rdx, rbx
    add rdx, rax
    add rdx, rcx
    imul rdx, CELL_SIZE
    mov r8d, [grid + rdx]
    mov rdx, rbx
    add rdx, rax
    imul rdx, CELL_SIZE
    mov [grid + rdx], r8d
    inc rax
    jmp .vtp_dch_shift
.vtp_dch_clear:
    ; Clear remaining cells
    cmp rax, [grid_cols]
    jge .vtp_dch_done
    mov rdx, rbx
    add rdx, rax
    imul rdx, CELL_SIZE
    mov byte [grid + rdx], ' '
    mov byte [grid + rdx + 1], 7
    mov byte [grid + rdx + 2], 0
    mov byte [grid + rdx + 3], 0
    inc rax
    jmp .vtp_dch_clear
.vtp_dch_done:
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
    mov [cur_fg], al
    jmp .vtp_sgr_next

    ; 40-47: background colors
.vtp_sgr_check_bg:
    cmp eax, 40
    jl .vtp_sgr_check_bright_fg
    cmp eax, 47
    jg .vtp_sgr_check_bright_fg
    sub eax, 40
    mov [cur_bg], al
    jmp .vtp_sgr_next

    ; 90-97: bright foreground
.vtp_sgr_check_bright_fg:
    cmp eax, 90
    jl .vtp_sgr_check_bright_bg
    cmp eax, 97
    jg .vtp_sgr_check_bright_bg
    sub eax, 82              ; 90-82 = 8
    mov [cur_fg], al
    jmp .vtp_sgr_next

    ; 100-107: bright background
.vtp_sgr_check_bright_bg:
    cmp eax, 100
    jl .vtp_sgr_check_256
    cmp eax, 107
    jg .vtp_sgr_check_256
    sub eax, 92
    mov [cur_bg], al
    jmp .vtp_sgr_next

    ; 38;5;N or 48;5;N: 256-color
.vtp_sgr_check_256:
    cmp eax, 38
    je .vtp_sgr_fg256
    cmp eax, 48
    je .vtp_sgr_bg256
    jmp .vtp_sgr_next

.vtp_sgr_fg256:
    ; Next param should be 5, then color
    inc rbx
    cmp rbx, [vt_param_count]
    jge .vtp_loop
    cmp dword [vt_params + rbx*4], 5
    jne .vtp_sgr_next
    inc rbx
    cmp rbx, [vt_param_count]
    jge .vtp_loop
    mov eax, [vt_params + rbx*4]
    mov [cur_fg], al
    jmp .vtp_sgr_next

.vtp_sgr_bg256:
    inc rbx
    cmp rbx, [vt_param_count]
    jge .vtp_loop
    cmp dword [vt_params + rbx*4], 5
    jne .vtp_sgr_next
    inc rbx
    cmp rbx, [vt_param_count]
    jge .vtp_loop
    mov eax, [vt_params + rbx*4]
    mov [cur_bg], al
    jmp .vtp_sgr_next

.vtp_sgr_reset:
    mov byte [cur_fg], 7
    mov byte [cur_bg], 0
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
    mov byte [cur_fg], 7
    jmp .vtp_sgr_next
.vtp_sgr_default_bg:
    mov byte [cur_bg], 0
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
grid_put_char:
    push rbx
    mov rbx, [cursor_row]
    imul rbx, MAX_COLS
    add rbx, [cursor_col]
    imul rbx, CELL_SIZE
    mov [grid + rbx], al             ; char
    movzx ecx, byte [cur_fg]
    mov [grid + rbx + 1], cl         ; fg
    movzx ecx, byte [cur_bg]
    mov [grid + rbx + 2], cl         ; bg
    movzx ecx, byte [cur_attrs]
    mov [grid + rbx + 3], cl         ; attrs

    ; Advance cursor
    mov rax, [cursor_col]
    inc rax
    cmp rax, [grid_cols]
    jl .gpc_ok
    ; Wrap to next line
    xor eax, eax
    mov [cursor_col], rax
    mov rax, [cursor_row]
    inc rax
    cmp rax, [grid_rows]
    jl .gpc_row_ok
    push rax
    call grid_scroll_up
    pop rax
    mov rax, [grid_rows]
    dec rax
.gpc_row_ok:
    mov [cursor_row], rax
    pop rbx
    ret
.gpc_ok:
    mov [cursor_col], rax
    pop rbx
    ret

; Clear entire grid
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
    mov byte [grid + rax], ' '
    mov byte [grid + rax + 1], 7     ; default fg
    mov byte [grid + rax + 2], 0     ; default bg
    mov byte [grid + rax + 3], 0     ; no attrs
    inc rbx
    jmp .gc_loop
.gc_done:
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
    mov byte [grid + rax], ' '
    mov byte [grid + rax + 1], 7
    mov byte [grid + rax + 2], 0
    mov byte [grid + rax + 3], 0
    inc rbx
    jmp .gcb_loop
.gcb_done:
    pop r12
    pop rbx
    ret

; Clear from cursor to end of line
grid_clear_right:
    push rbx
    mov rbx, [cursor_col]
    mov rcx, [cursor_row]
    imul rcx, MAX_COLS
.gcr_loop:
    cmp rbx, [grid_cols]
    jge .gcr_done
    mov rax, rcx
    add rax, rbx
    imul rax, CELL_SIZE
    mov byte [grid + rax], ' '
    mov byte [grid + rax + 1], 7
    mov byte [grid + rax + 2], 0
    mov byte [grid + rax + 3], 0
    inc rbx
    jmp .gcr_loop
.gcr_done:
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
    mov byte [grid + rax], ' '
    mov byte [grid + rax + 1], 7
    mov byte [grid + rax + 2], 0
    mov byte [grid + rax + 3], 0
    inc rbx
    jmp .gcl_loop
.gcl_done:
    pop rbx
    ret

; Scroll grid up by one line
grid_scroll_up:
    push rbx
    push r12
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
    ; Copy 4 bytes (one cell)
    mov edx, [grid + rax]
    mov [grid + rcx], edx
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
    jge .gsu_done
    mov rax, rbx
    imul rax, CELL_SIZE
    mov byte [grid + rax], ' '
    mov byte [grid + rax + 1], 7
    mov byte [grid + rax + 2], 0
    mov byte [grid + rax + 3], 0
    inc rbx
    jmp .gsu_clear
.gsu_done:
    pop r12
    pop rbx
    ret

; Scroll grid down by one line
grid_scroll_down:
    push rbx
    push r12
    ; Move rows 0..N-2 to 1..N-1 (backwards)
    mov rbx, [grid_rows]
    dec rbx
    imul rbx, MAX_COLS
    dec rbx
.gsd_loop:
    cmp rbx, 0
    jl .gsd_clear_first
    mov rax, rbx
    imul rax, CELL_SIZE
    mov rcx, rbx
    add rcx, MAX_COLS
    imul rcx, CELL_SIZE
    mov edx, [grid + rax]
    mov [grid + rcx], edx
    dec rbx
    jmp .gsd_loop
.gsd_clear_first:
    ; Clear first row
    xor rbx, rbx
.gsd_clear:
    cmp rbx, [grid_cols]
    jge .gsd_done
    mov rax, rbx
    imul rax, CELL_SIZE
    mov byte [grid + rax], ' '
    mov byte [grid + rax + 1], 7
    mov byte [grid + rax + 2], 0
    mov byte [grid + rax + 3], 0
    inc rbx
    jmp .gsd_clear
.gsd_done:
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

    ; Clear window first
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CLEAR_AREA
    mov byte [rdi+1], 0      ; exposures = false
    mov word [rdi+2], 4      ; length
    mov eax, [win_id]
    mov [rdi+4], eax
    mov word [rdi+8], 0      ; x
    mov word [rdi+10], 0     ; y
    mov word [rdi+12], 0     ; width = 0 (entire window)
    mov word [rdi+14], 0     ; height = 0
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]

    ; Draw each row with per-color-run rendering
    xor r12, r12             ; row
.rs_row:
    cmp r12, [grid_rows]
    jge .rs_cursor

    ; r12 = row, scan columns for color runs
    xor r13, r13             ; col = start of current run

.rs_run_start:
    cmp r13, [grid_cols]
    jge .rs_next_row

    ; Get fg/bg of cell at (row, col)
    mov rax, r12
    imul rax, MAX_COLS
    add rax, r13
    imul rax, CELL_SIZE
    movzx r14d, byte [grid + rax + 1]  ; run fg
    movzx r15d, byte [grid + rax + 2]  ; run bg

    ; Scan ahead for cells with same fg/bg, build text
    lea rdi, [tmp_buf + 20]  ; text buffer
    mov rbx, r13             ; current col
    xor ecx, ecx             ; text length
.rs_run_scan:
    cmp rbx, [grid_cols]
    jge .rs_run_draw
    cmp ecx, 255             ; ImageText8 max
    jge .rs_run_draw
    mov rax, r12
    imul rax, MAX_COLS
    add rax, rbx
    imul rax, CELL_SIZE
    ; Check if fg/bg matches current run
    movzx edx, byte [grid + rax + 1]
    cmp edx, r14d
    jne .rs_run_draw
    movzx edx, byte [grid + rax + 2]
    cmp edx, r15d
    jne .rs_run_draw
    ; Same color, add to run
    movzx edx, byte [grid + rax]       ; char
    mov [rdi + rcx], dl
    inc ecx
    inc rbx
    jmp .rs_run_scan

.rs_run_draw:
    ; ecx = run length, r13 = start col, r14 = fg, r15 = bg
    test ecx, ecx
    jz .rs_next_row

    ; ChangeGC fg/bg
    push rcx
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_CHANGE_GC
    mov byte [rdi+1], 0
    mov word [rdi+2], 5      ; length (3 + 2 values)
    mov eax, [gc_id]
    mov [rdi+4], eax
    mov dword [rdi+8], GC_FOREGROUND | GC_BACKGROUND
    mov eax, [palette + r14*4]
    mov [rdi+12], eax
    mov eax, [palette + r15*4]
    mov [rdi+16], eax
    lea rsi, [tmp_buf]
    mov rdx, 20
    call x11_buffer
    inc dword [x11_seq]
    pop rcx

    ; ImageText8
    push rcx
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_IMAGE_TEXT8
    mov byte [rdi+1], cl     ; string length
    ; request length = (16 + n + 3) / 4
    mov eax, ecx
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
    ; Copy text from tmp_buf+20 to tmp_buf+16
    pop rcx
    push rcx
    xor edx, edx
.rs_cp_run:
    cmp edx, ecx
    jge .rs_send_run
    movzx eax, byte [tmp_buf + 20 + rdx]
    mov [tmp_buf + 16 + rdx], al
    inc edx
    jmp .rs_cp_run
.rs_send_run:
    pop rcx
    ; Send padded request
    mov eax, ecx
    add eax, 16
    add eax, 3
    and eax, ~3
    mov rdx, rax
    lea rsi, [tmp_buf]
    call x11_buffer
    inc dword [x11_seq]

    ; Advance to next run
    mov r13, rbx
    jmp .rs_run_start

.rs_next_row:
    inc r12
    jmp .rs_row

.rs_cursor:
    ; Draw cursor as inverse block at cursor position
    ; For Phase 1: just a filled rectangle
    lea rdi, [tmp_buf]
    ; Set GC foreground to white for cursor
    mov byte [rdi], X11_CHANGE_GC
    mov byte [rdi+1], 0
    mov word [rdi+2], 4
    mov eax, [gc_id]
    mov [rdi+4], eax
    mov dword [rdi+8], GC_FOREGROUND
    mov eax, [x11_white_pixel]
    mov [rdi+12], eax
    lea rsi, [tmp_buf]
    mov rdx, 16
    call x11_buffer
    inc dword [x11_seq]

    ; PolyFillRectangle
    lea rdi, [tmp_buf]
    mov byte [rdi], X11_POLY_FILL_RECT
    mov byte [rdi+1], 0
    mov word [rdi+2], 5      ; length (3 + 2 per rect)
    mov eax, [win_id]
    mov [rdi+4], eax
    mov eax, [gc_id]
    mov [rdi+8], eax
    ; x = cursor_col * char_width
    mov rax, [cursor_col]
    movzx ecx, word [char_width]
    imul eax, ecx
    mov word [rdi+12], ax
    ; y = cursor_row * char_height + char_height - 2 (underline)
    mov rax, [cursor_row]
    movzx ecx, word [char_height]
    imul eax, ecx
    movzx ecx, word [char_height]
    add eax, ecx
    sub eax, 2
    mov word [rdi+14], ax
    ; width = char_width
    movzx eax, word [char_width]
    mov word [rdi+16], ax
    ; height = 2 (thin underline)
    mov word [rdi+18], 2

    lea rsi, [tmp_buf]
    mov rdx, 20
    call x11_buffer
    inc dword [x11_seq]

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
