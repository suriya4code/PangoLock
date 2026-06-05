#!/usr/bin/env bash
#
# Build a release PangoLock.app and package it as a .zip.
#
# By default this produces an UNSIGNED build (no Apple Developer account needed),
# suitable for local testing. To produce a SIGNED + NOTARIZED artifact for
# distribution, set the env vars below and pass --sign. See docs/RELEASING.md.
#
# Usage:
#   scripts/build-release.sh                # unsigned local build + zip
#   DEVELOPMENT_TEAM=XXXXXXXXXX \
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" \
#   scripts/build-release.sh --sign         # signed (then notarize separately)

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="PangoLock"
PROJECT="PangoLock.xcodeproj"
BUILD_DIR="build"
EXPORT_DIR="dist"
APP="$EXPORT_DIR/$SCHEME.app"
VERSION="$(/usr/bin/awk -F' = ' '/MARKETING_VERSION/ {gsub(/;/,"",$2); print $2; exit}' "$PROJECT/project.pbxproj")"

SIGN=0
[[ "${1:-}" == "--sign" ]] && SIGN=1

rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

echo "==> Building $SCHEME $VERSION (Release)…"
if [[ "$SIGN" -eq 1 ]]; then
  : "${DEVELOPMENT_TEAM:?set DEVELOPMENT_TEAM for a signed build}"
  : "${SIGN_IDENTITY:?set SIGN_IDENTITY for a signed build}"
  xcodebuild build \
    -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'platform=macOS' -derivedDataPath "$BUILD_DIR" \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY"
else
  xcodebuild build \
    -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'platform=macOS' -derivedDataPath "$BUILD_DIR" \
    CODE_SIGNING_ALLOWED=NO
fi

cp -R "$BUILD_DIR/Build/Products/Release/$SCHEME.app" "$APP"

ZIP="$EXPORT_DIR/$SCHEME-$VERSION.zip"
echo "==> Zipping -> $ZIP"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Done: $ZIP"
if [[ "$SIGN" -eq 0 ]]; then
  echo "    (UNSIGNED — for distribution, sign + notarize: see docs/RELEASING.md)"
fi
