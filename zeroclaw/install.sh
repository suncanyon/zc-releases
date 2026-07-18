#!/bin/bash
set -e

ZC_INSTALL_DIR="$HOME/.local/bin"
ZC_BINARY="$ZC_INSTALL_DIR/zeroclaw"
RELEASE_URL="https://raw.githubusercontent.com/suncanyon/zc-releases/main/zeroclaw"

echo "Installing zeroclaw CLI..."
mkdir -p "$ZC_INSTALL_DIR"
echo "Downloading latest release..."
curl -fsSL "${RELEASE_URL}/zeroclaw-linux-x86_64-latest" -o "$ZC_BINARY"
chmod +x "$ZC_BINARY"

if ! grep -q "$ZC_INSTALL_DIR" "$HOME/.bashrc" 2>/dev/null; then
    echo "" >> "$HOME/.bashrc"
    echo '# zeroclaw CLI' >> "$HOME/.bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "Added $ZC_INSTALL_DIR to PATH (reload shell with: source ~/.bashrc)"
fi

echo "Verifying installation..."
"$ZC_BINARY" --version

echo ""
echo "zeroclaw installed successfully to $ZC_BINARY"
echo "Run 'zeroclaw --help' to get started
