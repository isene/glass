# glass - Pure Assembly Terminal Emulator

<img src="img/glass.svg" align="left" width="150" height="150">

![Version](https://img.shields.io/badge/version-0.1.0-blue) ![Assembly](https://img.shields.io/badge/language-x86__64%20Assembly-purple) ![License](https://img.shields.io/badge/license-Unlicense-green) ![Platform](https://img.shields.io/badge/platform-Linux%20x86__64-blue) ![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen) ![Binary](https://img.shields.io/badge/binary-~56KB-orange) ![X11](https://img.shields.io/badge/protocol-X11%20wire-ff6600) ![Stay Amazing](https://img.shields.io/badge/Stay-Amazing-important)

Terminal emulator written in x86_64 Linux assembly. No libc, no runtime, pure syscalls. Speaks X11 wire protocol directly via Unix socket. Single static binary, 56KB.

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
```

Available font sizes: 10, 13, 15, 18, 20. Colors are hex RGB.

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

### Terminal Emulation
- VT100/xterm escape sequence parser
- Alternate screen buffer (CSI ?1049h/l) for vim, less, man, htop
- Scroll regions (DECSTBM) for vim splits
- DECSET/DECRST modes: cursor visibility, autowrap, mouse tracking
- Cursor shapes: block, underline, bar (CSI q)
- Insert/delete lines and characters (CSI L/M/@/P/X)
- SGR: bold, underline, inverse, 8/16/256/truecolor
- OSC 0/2: dynamic window title
- CSI private prefixes: ?, >, =

### Input
- Proper X11 keyboard mapping (GetKeyboardMapping from server)
- Arrow keys, Home/End, Page Up/Down, Delete, function keys
- Ctrl and Shift modifiers
- Mouse reporting (SGR mode 1006) for vim, tmux
- Bracketed paste mode (CSI ?2004h/l)
- Ctrl+Shift+V and Shift+Insert paste from clipboard

### Interaction
- Scrollback buffer (1000 lines, Shift+PageUp/Down)
- Text selection (click and drag, X11 PRIMARY selection)
- URL detection (http/https), Ctrl+click to open with xdg-open
- PTY resize on window resize with SIGWINCH

### Architecture
- Pure x86_64 Linux syscalls (no libc)
- Single `.asm` source file (~6000 lines)
- Static binary (~56KB, zero dependencies)
- PTY management (posix_openpt, setsid, TIOCSCTTY)
- X11 request batching (single write per frame)
- 8-byte grid cells (UCS-2 char + fg + bg + attrs)
- Circular scrollback buffer

## How It Works

glass connects to the X11 server via a Unix domain socket (`/tmp/.X11-unix/X0`), authenticates with the Xauthority cookie, and speaks raw X11 wire protocol. No Xlib, no XCB, no toolkit.

It opens a PTY, forks a child shell ([bare](https://github.com/isene/bare) by default), and enters an event loop polling both the X11 socket and the PTY master. Keyboard events are translated to terminal input via the server's keymap. PTY output is parsed through a VT100 state machine and rendered to an internal grid. The grid is drawn to the X11 window using batched ImageText16 requests with per-color-run optimization.

## Key Bindings

| Key | Action |
|-----|--------|
| Shift+PageUp | Scroll back |
| Shift+PageDown | Scroll forward |
| Ctrl+Shift+V | Paste from clipboard |
| Shift+Insert | Paste from clipboard |
| Ctrl+Click | Open URL under cursor |

## Roadmap

- [ ] True emoji rendering (Xrender extension)
- [ ] Tab/split support (multiple PTYs)
- [ ] Font ligatures
- [ ] Image protocol (Sixel or kitty graphics)
- [ ] Opacity/transparency
- [ ] WM_CLASS for window manager integration
- [ ] Configurable key bindings

## The CHasm Suite

| Tool | Purpose | Binary | Lines |
|------|---------|--------|-------|
| [bare](https://github.com/isene/bare) | Interactive shell | ~150KB | ~16K |
| [show](https://github.com/isene/show) | File viewer | ~40KB | ~3.4K |
| glass | Terminal emulator | ~56KB | ~6K |

All three: pure x86_64 assembly, no libc, no dependencies, direct syscalls.

## License

[Unlicense](https://unlicense.org/) (public domain)
