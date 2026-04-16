PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin

glass: glass.asm
	nasm -f elf64 glass.asm -o glass.o
	ld glass.o -o glass
	rm -f glass.o

install: glass
	install -Dm755 glass $(DESTDIR)$(BINDIR)/glass
	@echo "Installed glass to $(BINDIR)/glass"

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/glass

clean:
	rm -f glass glass.o

.PHONY: install uninstall clean
