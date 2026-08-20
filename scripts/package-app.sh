#!/bin/bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <binary> <version> <output-directory>"
    exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BINARY="$1"
VERSION="${2#v}"
OUTPUT_DIR="$3"
APP_NAME="AlarmRadar"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"

if [[ ! -f "$BINARY" ]]; then
    echo "Binary not found: ${BINARY}"
    exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"
cp "$BINARY" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod 755 "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "$ROOT_DIR/scripts/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist"

# Ad-hoc signing keeps the local bundle internally consistent. This can be
# replaced by Developer ID signing and notarization later.
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Created $APP_BUNDLE"
