#!/bin/bash

set -e

DRY=true

URL="https://get.requestly.com/linux-api-client"
LOGO_URL="https://requestly.com/favicon.ico"


BIN_DIR="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons"
APP_DIR="$HOME/.local/share/applications"

BIN="$BIN_DIR/requestly"
ICON="$ICON_DIR/requestly-logo.svg"
DESKTOP_FILE="$APP_DIR/requestly.desktop"

if $DRY; then
    echo "[DRY] mkdir -p $BIN_DIR $ICON_DIR $APP_DIR"
    echo "[DRY] curl -L -o $BIN $URL"
    echo "[DRY] curl -L -o $ICON $LOGO_URL"
    echo "[DRY] chmod +x $BIN"
    echo "[DRY] create $DESKTOP_FILE"
    exit 0
fi

mkdir -p "$BIN_DIR" "$ICON_DIR" "$APP_DIR"

echo "Downloading Requestly..."
curl -L -o "$BIN" "$URL"

echo "Downloading logo..."
curl -L -o "$ICON" "$LOGO_URL"

chmod +x "$BIN"

echo "Creating desktop entry..."

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Requestly
Comment=Requestly API Client
Exec=$BIN
Icon=$ICON
Terminal=false
Type=Application
Categories=Development;Network;
StartupNotify=true
EOF

chmod +x "$DESKTOP_FILE"

echo "Installed successfully!"
