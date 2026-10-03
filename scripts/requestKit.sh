#!/usr/bin/env bash
set -euo pipefail

# Per-user installer. Rerun with a newer download URL to update.
DRY_RUN=false
usage() { printf 'Usage: %s [--dry-run]\n' "${0##*/}"; }

if (( $# > 1 )); then
    usage >&2
    exit 1
fi

case "${1:-}" in
    "") ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
esac

LOGO_URL="https://webrequestkit.com/logo.png"
BIN_DIR="$HOME/.local/bin"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
ICON_DIR="$DATA_DIR/icons"
APP_DIR="$DATA_DIR/applications"

BIN="$BIN_DIR/webrequestkit"
ICON="$ICON_DIR/webrequestkit.png"
DESKTOP_FILE="$APP_DIR/webrequestkit.desktop"

read -r -p "Direct download URL (.AppImage.zip): " URL
if [[ "$URL" != https://* ]]; then
    printf 'Error: Enter a direct HTTPS download URL.\n' >&2
    exit 1
fi

if "$DRY_RUN"; then
    printf '[DRY] Download ZIP: %s\n' "$URL"
    printf '[DRY] Extract the AppImage into a temporary directory\n'
    printf '[DRY] Download PNG icon: %s\n' "$LOGO_URL"
    printf '[DRY] Create directories: %s, %s, %s\n' "$BIN_DIR" "$ICON_DIR" "$APP_DIR"
    printf '[DRY] Install executable: %s\n' "$BIN"
    printf '[DRY] Install icon: %s\n' "$ICON"
    printf '[DRY] Create desktop entry: %s\n' "$DESKTOP_FILE"
    exit 0
fi

for cmd in curl unzip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf 'Error: Missing %s. Install dependencies with:\n' "$cmd" >&2
        printf '  sudo pacman -S --needed curl unzip\n' >&2
        exit 1
    fi
done

TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

download() {
    curl --fail --location --show-error --retry 3 \
        --proto '=https' --proto-redir '=https' \
        --output "$2" "$1"
}

printf 'Downloading WebRequestKit...\n'
download "$URL" "$TMP_DIR/webrequestkit.zip"

printf 'Extracting AppImage...\n'
mkdir -p "$TMP_DIR/extracted"
unzip -q "$TMP_DIR/webrequestkit.zip" -d "$TMP_DIR/extracted"

# Discover the AppImage, rather than hard-coding its versioned filename.
# Ignore macOS ZIP metadata, including AppleDouble resource-fork files.
mapfile -d '' -t APPIMAGES < <(
    find "$TMP_DIR/extracted" -type f -iname '*.AppImage' \
        ! -path '*/__MACOSX/*' ! -name '._*' -print0
)
if (( ${#APPIMAGES[@]} != 1 )); then
    printf 'Error: Expected exactly one AppImage in the ZIP; found %s.\n' \
        "${#APPIMAGES[@]}" >&2
    exit 1
fi

printf 'Downloading icon...\n'
download "$LOGO_URL" "$TMP_DIR/webrequestkit.png"

# Stage all downloads before replacing an existing installation.
cat > "$TMP_DIR/webrequestkit.desktop" <<EOF
[Desktop Entry]
Name=WebRequestKit
Comment=WebRequestKit API Client
Exec="$BIN"
Icon=$ICON
Terminal=false
Type=Application
Categories=Development;Network;
StartupNotify=true
EOF

mkdir -p "$BIN_DIR" "$ICON_DIR" "$APP_DIR"
install -m 0755 "${APPIMAGES[0]}" "$BIN"
install -m 0644 "$TMP_DIR/webrequestkit.png" "$ICON"
install -m 0644 "$TMP_DIR/webrequestkit.desktop" "$DESKTOP_FILE"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APP_DIR" || true
fi

printf '\nInstalled successfully! Launch WebRequestKit from your application menu.\n'
printf 'Or run: "%s"\n' "$BIN"
