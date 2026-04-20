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

.PHONY: install install-emoji emoji-cache uninstall clean
