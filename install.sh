#!/usr/bin/env sh
# Picobot CLI installer
# Usage: curl -fsSL https://raw.githubusercontent.com/suncanyon/zc-releases/main/install.sh | sh
#
# Installs the `pb` binary to /usr/local/bin (or ~/bin if not writable).

set -eu

REPO="suncanyon/zc-releases"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="pb"
TMPDIR="${TMPDIR:-/tmp}"

# ---------------------------------------------------------------------------
# Detect OS and architecture
# ---------------------------------------------------------------------------

detect_target() {
    OS=$(uname -s)
    ARCH=$(uname -m)

    case "$OS" in
        Linux)
            case "$ARCH" in
                x86_64)  echo "x86_64-unknown-linux-gnu" ;;
                aarch64) echo "aarch64-unknown-linux-gnu" ;;
                arm64)   echo "aarch64-unknown-linux-gnu" ;;
                *)
                    echo "Unsupported architecture: $ARCH" >&2
                    exit 1
                    ;;
            esac
            ;;
        Darwin)
            case "$ARCH" in
                x86_64) echo "x86_64-apple-darwin" ;;
                arm64)  echo "aarch64-apple-darwin" ;;
                *)
                    echo "Unsupported architecture: $ARCH" >&2
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo "Unsupported OS: $OS" >&2
            exit 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Fetch latest version tag from GitHub (includes prereleases)
# ---------------------------------------------------------------------------

latest_version() {
    # Try /releases/latest first (stable), fall back to first entry in /releases
    TAG=""
    if command -v curl >/dev/null 2>&1; then
        TAG=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null \
            | grep '"tag_name"' \
            | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' || true)
        if [ -z "$TAG" ]; then
            TAG=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases?per_page=1" \
                | grep '"tag_name"' \
                | head -1 \
                | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
        fi
    elif command -v wget >/dev/null 2>&1; then
        TAG=$(wget -qO- "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null \
            | grep '"tag_name"' \
            | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' || true)
        if [ -z "$TAG" ]; then
            TAG=$(wget -qO- "https://api.github.com/repos/${REPO}/releases?per_page=1" \
                | grep '"tag_name"' \
                | head -1 \
                | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
        fi
    else
        echo "curl or wget is required" >&2
        exit 1
    fi

    if [ -z "$TAG" ]; then
        echo "Could not determine latest version" >&2
        exit 1
    fi
    echo "$TAG"
}

download() {
    URL="$1"
    DEST="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$URL" -o "$DEST"
    else
        wget -qO "$DEST" "$URL"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

TARGET=$(detect_target)
VERSION="${PB_VERSION:-$(latest_version)}"
VERSION_NUM="${VERSION#v}"

ARCHIVE="pb-${VERSION_NUM}-${TARGET}.tar.gz"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ARCHIVE}"

TMP_DIR=$(mktemp -d "${TMPDIR}/picobot-install.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Installing picobot ${VERSION} (${TARGET})..."

# Download archive
download "$DOWNLOAD_URL" "${TMP_DIR}/${ARCHIVE}"

# Verify checksum if sha256sum / shasum available
SHA_URL="${DOWNLOAD_URL}.sha256"
if command -v sha256sum >/dev/null 2>&1; then
    download "$SHA_URL" "${TMP_DIR}/${ARCHIVE}.sha256"
    EXPECTED=$(cat "${TMP_DIR}/${ARCHIVE}.sha256" | cut -d' ' -f1)
    ACTUAL=$(sha256sum "${TMP_DIR}/${ARCHIVE}" | cut -d' ' -f1)
    if [ "$EXPECTED" != "$ACTUAL" ]; then
        echo "Checksum mismatch!" >&2
        echo "  Expected: $EXPECTED" >&2
        echo "  Got:      $ACTUAL" >&2
        exit 1
    fi
elif command -v shasum >/dev/null 2>&1; then
    download "$SHA_URL" "${TMP_DIR}/${ARCHIVE}.sha256"
    EXPECTED=$(cat "${TMP_DIR}/${ARCHIVE}.sha256" | cut -d' ' -f1)
    ACTUAL=$(shasum -a 256 "${TMP_DIR}/${ARCHIVE}" | cut -d' ' -f1)
    if [ "$EXPECTED" != "$ACTUAL" ]; then
        echo "Checksum mismatch!" >&2
        exit 1
    fi
fi

# Extract
tar -xzf "${TMP_DIR}/${ARCHIVE}" -C "${TMP_DIR}"

# Install — unlink first so upgrades are safe even if the binary is running.
install_binary() {
    TARGET_DIR="$1"
    USE_SUDO="$2"

    if [ "$USE_SUDO" = "yes" ]; then
        sudo rm -f "${TARGET_DIR}/${BINARY_NAME}"
        sudo cp "${TMP_DIR}/${BINARY_NAME}" "${TARGET_DIR}/${BINARY_NAME}"
        sudo chmod +x "${TARGET_DIR}/${BINARY_NAME}"
    else
        rm -f "${TARGET_DIR}/${BINARY_NAME}"
        cp "${TMP_DIR}/${BINARY_NAME}" "${TARGET_DIR}/${BINARY_NAME}"
        chmod +x "${TARGET_DIR}/${BINARY_NAME}"
    fi
}

if [ -w "$INSTALL_DIR" ]; then
    install_binary "$INSTALL_DIR" no
    INSTALLED_TO="${INSTALL_DIR}/${BINARY_NAME}"
elif command -v sudo >/dev/null 2>&1; then
    install_binary "$INSTALL_DIR" yes
    INSTALLED_TO="${INSTALL_DIR}/${BINARY_NAME}"
else
    mkdir -p "$HOME/bin"
    install_binary "$HOME/bin" no
    INSTALLED_TO="$HOME/bin/${BINARY_NAME}"
    echo ""
    echo "Installed to ~/bin — make sure ~/bin is in your PATH:"
    echo '  export PATH="$HOME/bin:$PATH"'
fi

echo ""
echo "picobot ${VERSION} installed to ${INSTALLED_TO}"
echo ""
echo "Get started:"
echo "  pb --help"
