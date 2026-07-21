PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
EMOJI_CACHE_DIR = $(PREFIX)/share/glass/emoji

glass: glass.asm
	nasm -f elf64 glass.asm -o glass.o
	ld glass.o -o glass
	rm -f glass.o

install: glass install-emoji
	install -Dm755 glass $(DESTDIR)$(BINDIR)/glass
	@echo "Installed glass to $(BINDIR)/glass"

# Install bundled emoji cache (skipped silently if cache/ is empty —
# build it first with `make emoji-cache` if you want this step to do
# anything).
install-emoji:
	@if [ -d cache ] && [ "$$(ls cache 2>/dev/null | head -1)" ]; then \
	  install -d $(DESTDIR)$(EMOJI_CACHE_DIR); \
	  install -m644 cache/*.rgba $(DESTDIR)$(EMOJI_CACHE_DIR)/; \
	  echo "Installed $$(ls cache | wc -l) emoji rasters to $(EMOJI_CACHE_DIR)"; \
	else \
	  echo "(no bundled emoji cache; run 'make emoji-cache' to build it)"; \
	fi

# Pre-render the bundled emoji cache for the default 13pt font cell
# size (12x13). Pass W=N H=M to override.
W ?= 12
H ?= 13
emoji-cache:
	./tools/build-emoji-cache.sh $(W) $(H)

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/glass
	rm -rf $(DESTDIR)$(EMOJI_CACHE_DIR)

clean:
	rm -f glass glass.o

.PHONY: install install-emoji emoji-cache uninstall clean deb

# ── Debian package ─────────────────────────────────────────────────────
# Version comes from the README badge (the repo's single version marker).
VERSION := $(shell grep -oP 'version-\K[0-9.]+(?=-blue)' README.md)

deb: glass
	rm -rf pkgroot
	$(MAKE) install DESTDIR=$(CURDIR)/pkgroot PREFIX=/usr
	install -Dm644 LICENSE pkgroot/usr/share/doc/glass/copyright
	install -d pkgroot/DEBIAN
	printf 'Package: glass\nVersion: $(VERSION)\nArchitecture: amd64\nMaintainer: Geir Isene <g@isene.com>\nSection: x11\nPriority: optional\nHomepage: https://github.com/isene/glass\nDescription: Terminal emulator in x86_64 assembly\n Speaks the X11 wire protocol directly, no libc, no toolkit. Embedded\n TrueType rasterizer, kitty graphics, color emoji, pseudo-transparency.\n Single static binary.\n' > pkgroot/DEBIAN/control
	dpkg-deb --build --root-owner-group pkgroot glass_$(VERSION)_amd64.deb
	rm -rf pkgroot
