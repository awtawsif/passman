#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Function to check for a command's existence
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for dependencies
echo "Checking for dependencies..."
dependencies=("jq" "openssl" "xclip" "makepkg")
missing_deps=()

for dep in "${dependencies[@]}"; do
    if ! command_exists "$dep"; then
        missing_deps+=("$dep")
    fi
done

if [ ${#missing_deps[@]} -ne 0 ]; then
    echo "Error: The following dependencies are missing: ${missing_deps[*]}."
    if command_exists "pacman"; then
        echo "You can install them on Arch Linux using:"
        echo "sudo pacman -Syu --needed ${missing_deps[*]}"
    fi
    exit 1
fi

echo "All dependencies are satisfied."

# Create the source tarball
echo "Creating the source tarball..."
TARBALL_NAME="passman-1.0.0.tar.gz"
tar -czf "$TARBALL_NAME" \
    passman.sh \
    PKGBUILD \
    passman.install \
    README.md \
    .SRCINFO \
    lib

# Build and install the package

echo "Building and installing the package..."
makepkg -si

echo "Installation complete. You can now run 'passman' from your terminal."
