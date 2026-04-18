# glass - Pure Assembly Terminal Emulator

<img src="img/glass.svg" align="left" width="150" height="150">

![Version](https://img.shields.io/badge/version-0.1.3-blue) ![Assembly](https://img.shields.io/badge/language-x86__64%20Assembly-purple) ![License](https://img.shields.io/badge/license-Unlicense-green) ![Platform](https://img.shields.io/badge/platform-Linux%20x86__64-blue) ![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen) ![Binary](https://img.shields.io/badge/binary-~58KB-orange) ![X11](https://img.shields.io/badge/protocol-X11%20wire-ff6600) ![Stay Amazing](https://img.shields.io/badge/Stay-Amazing-important)

Terminal emulator written in x86_64 Linux assembly. No libc, no runtime, pure syscalls. Speaks X11 wire protocol directly via Unix socket. Single static binary, 58KB.

No toolkit, no rendering library, no font engine. Just your keystrokes, the X11 server, and the kernel.

Part of the **CHasm** (CHange to ASM) suite: [bare](https://github.com/isene/bare) (shell), [show](https://github.com/isene/show) (file viewer), glass (terminal emulator).

<br clear="left"/>

## Install

### From source (requires nasm and ld)

```bash
git clone https://github.com/isene/glass.git
cd glass
make
sudo make install
```

## Configuration

Create `~/.glassrc` for custom colors:

```
bg = #1a1b26
fg = #c0caf5
cursor = #f7768e
font_size = 13
opacity = 80
```

Available font sizes: 10, 13, 15, 18, 20. Colors are hex RGB.
`opacity` is a 0..100 percentage (100 = opaque, default). Values
below 100 prefer a 32-bit ARGB visual when a compositor (picom,
compton, KWin, Mutter, etc.) is detected via `_NET_WM_CM_S0` —
that gives true per-pixel see-through. With no compositor, glass
falls back to a wallpaper-tint: it samples the desktop wallpaper
behind the window, averages it, blends with the configured `bg`,
and uses that as the cell background. The result color-matches
the wallpaper area but is a solid tint (not actually see-through).
Without a configured `opacity`, none of this code runs.

## Features

### Rendering
- X11 wire protocol over Unix domain socket (no Xlib/XCB)
- Xauthority cookie authentication (MIT-MAGIC-COOKIE-1)
- Unicode BMP rendering via ImageText16 with iso10646-1 font
- UTF-8 decoding state machine (2/3/4-byte sequences)
- Per-color-run rendering (each color segment drawn separately)
- 256-color palette with truecolor (24-bit) SGR mapping
- Inverse video (SGR 7) for status bars
- Configurable background, foreground, and cursor colors
- Visual selection rendering (inverted cells during drag)
- Visual bell on BEL (0x07)
- No-flicker rendering (omits ClearArea since cells fully repaint)

### Terminal Emulation
- VT100/xterm escape sequence parser
- Alternate screen buffer (CSI ?1049h/l) for vim, less, man, htop
- Scroll regions (DECSTBM) for vim splits
- DECSET/DECRST modes: cursor visibility, autowrap, mouse tracking, bracketed paste
- Cursor shapes: block, underline, bar (CSI q)
- Insert/delete lines and characters (CSI L/M/@/P/X)
- SGR: bold, underline, inverse, 8/16/256/truecolor (24-bit mapped to 256-color cube)
- OSC 0/2: dynamic window title
- CSI private prefixes: ?, >, =
- Reply-aware event parsing (variable-size replies don't misalign event stream)

### Input
- Proper X11 keyboard mapping (GetKeyboardMapping from server)
- AltGr (Mod5) support for international keyboard layouts (e.g., Norwegian AltGr+4 → $)
- Latin-1 keysyms (0x00A0-0x00FF) sent as UTF-8 (e.g., AltGr+3 → £)
- Arrow keys, Home/End, Page Up/Down, Delete, function keys
- Ctrl and Shift modifiers
- Mouse reporting (SGR mode 1006) for vim, tmux
- Bracketed paste mode (CSI ?2004h/l)
- Ctrl+Shift+V pastes CLIPBOARD selection
- Shift+Insert pastes PRIMARY selection (X11 tradition)
- Ctrl+D properly exits glass when bare exits (POLLHUP detection)

### Interaction
- Scrollback buffer (1000 lines, Shift+PageUp/Down)
- Text selection (click and drag, visible inverted highlight)
- Double-click to select word (alnum + `_-./~+@:%=`)
- Triple-click to select whole line
- Selection populates X11 PRIMARY for paste in other apps
- Glass responds to SelectionRequest (TARGETS, UTF8_STRING, STRING)
- URL detection (http/https), Ctrl+click to open with xdg-open
- PTY resize on window resize with SIGWINCH
- Initial PTY size from screen dimensions (no 80×24 default)
- TERM=xterm-256color set in child environment

### Architecture
- Pure x86_64 Linux syscalls (no libc)
- Single `.asm` source file (~6500 lines)
- Static binary (~58KB, zero dependencies)
- PTY management (posix_openpt, setsid, TIOCSCTTY)
- X11 request batching (single write per frame)
- 8-byte grid cells (UCS-2 char + fg + bg + attrs)
- Circular scrollback buffer
- Drains large QueryFont replies (~786KB for Unicode font) to keep socket aligned

## How It Works

glass connects to the X11 server via a Unix domain socket (`/tmp/.X11-unix/X0`), authenticates with the Xauthority cookie, and speaks raw X11 wire protocol. No Xlib, no XCB, no toolkit.

It opens a PTY, forks a child shell ([bare](https://github.com/isene/bare) by default), and enters an event loop polling both the X11 socket and the PTY master. Keyboard events are translated to terminal input via the server's keymap. PTY output is parsed through a VT100 state machine and rendered to an internal grid. The grid is drawn to the X11 window using batched ImageText16 requests with per-color-run optimization.

Selection works via the X11 PRIMARY mechanism: drag-select to claim ownership, other apps' middle-click or Shift+Insert sends a ConvertSelection request to glass which responds with the selection text via ChangeProperty + SelectionNotify.

## Key Bindings

| Key | Action |
|-----|--------|
| Shift+PageUp | Scroll back |
| Shift+PageDown | Scroll forward |
| Ctrl+Shift+V | Paste from CLIPBOARD |
| Shift+Insert | Paste from PRIMARY (selected text) |
| Ctrl+Click | Open URL under cursor |
| Ctrl+D | Exit (when shell line is empty) |

## Roadmap

- [ ] True emoji rendering (Xrender extension)
- [ ] Tab/split support (multiple PTYs)
- [ ] Font ligatures
- [ ] Image protocol (Sixel or kitty graphics)
- [ ] Opacity/transparency
- [ ] WM_CLASS for window manager integration
- [ ] Configurable key bindings
- [ ] Cursor blink
- [ ] OSC 8 hyperlinks
- [ ] OSC 52 clipboard (program-initiated copy)

## The CHasm Suite

| Tool | Purpose | Binary | Lines |
|------|---------|--------|-------|
| [bare](https://github.com/isene/bare) | Interactive shell | ~150KB | ~16K |
| [show](https://github.com/isene/show) | File viewer | ~40KB | ~3.4K |
| glass | Terminal emulator | ~58KB | ~6.5K |

All three: pure x86_64 assembly, no libc, no dependencies, direct syscalls.

## License

[Unlicense](https://unlicense.org/) (public domain)
