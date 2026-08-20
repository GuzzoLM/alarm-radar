#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

APP_NAME="AlarmRadar"
VERSION="${1:-$(git describe --tags --always)}"
VERSION="${VERSION#v}"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/alarm-radar-dmg.XXXXXX")"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

echo "Building ${APP_NAME} ${VERSION}..."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

echo "Creating app bundle..."
scripts/package-app.sh "${BIN_DIR}/alarm-radar" "$VERSION" "$STAGING_DIR"
ln -s /Applications "${STAGING_DIR}/Applications"

echo "Creating ${DMG_NAME}..."
rm -f "$DMG_NAME"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME"
shasum -a 256 "$DMG_NAME" > "${DMG_NAME}.sha256"

echo "Created ${DMG_NAME}"
