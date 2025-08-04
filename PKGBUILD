# Maintainer: Tawsif <awtawsif@gmail.com>

pkgname=passman
pkgver=1.0.0
pkgrel=1
pkgdesc="A robust and user-friendly command-line password manager."
arch=('any')
url="https://github.com/awtawsif/passman"
license=('MIT')
depends=('bash' 'jq' 'openssl')
install=passman.install
source=("$pkgname-$pkgver.tar.gz")
sha256sums=('SKIP')

prepare() {
    cd "$srcdir"
    tar -xzf "$pkgname-$pkgver.tar.gz"
}

build() {
    # No build steps needed for a shell script application
    echo "Skipping build step..."
}

package() {
    cd "$srcdir"
    # Create directories
    install -d "$pkgdir/usr/bin"
    install -d "$pkgdir/usr/lib/passman"

    # Install the main script
    install -Dm755 "passman.sh" "$pkgdir/usr/bin/passman"

    # Install the library files
    install -Dm644 "lib"/* "$pkgdir/usr/lib/passman/"

    # Install the install file
    install -Dm644 "passman.install" "$pkgdir/usr/share/pacman/hooks/passman.install"
}
