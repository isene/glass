# Maintainer: Geir Isene <g@isene.com>
pkgname=glass
pkgver=0.3.47
pkgrel=1
pkgdesc="Terminal emulator in x86_64 assembly. X11 wire protocol, no libc. Embedded TTF rasterizer, kitty graphics, color emoji."
arch=('x86_64')
url="https://github.com/isene/glass"
license=('Unlicense')
makedepends=('binutils' 'nasm')
source=("$pkgname-$pkgver.tar.gz::https://github.com/isene/glass/archive/refs/tags/v$pkgver.tar.gz"
        "glyph-0.5.0.tar.gz::https://github.com/isene/glyph/archive/refs/tags/v0.5.0.tar.gz")
sha256sums=('SKIP' 'SKIP')

prepare() {
    # glass %includes the glyph rasterizer from a sibling dir named glyph.
    ln -sfn "glyph-0.5.0" glyph
}

build() {
    cd "glass-$pkgver"
    make
    strip glass
}

package() {
    cd "glass-$pkgver"
    make PREFIX=/usr DESTDIR="$pkgdir" install
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
