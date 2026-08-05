#!/usr/bin/env bash
# Package a built Storefront.app into a styled drag-to-Applications DMG.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKGROUND="$ROOT/packaging/dmg/background.png"
OUT_DIR="${OUT_DIR:-$ROOT/dist}"
OUT_DMG="${OUT_DMG:-$OUT_DIR/Storefront.dmg}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [path/to/Storefront.app]

Creates a DMG with a Finder background that guides users to drag
Storefront.app into Applications.

Environment:
  OUT_DIR   Output directory (default: dist/)
  OUT_DMG   Full output path (default: \$OUT_DIR/Storefront.dmg)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "error: create-dmg is not installed. Install it with:" >&2
  echo "  brew install create-dmg" >&2
  exit 1
fi

if [[ ! -f "$BACKGROUND" ]]; then
  echo "error: missing background image at $BACKGROUND" >&2
  exit 1
fi

APP_PATH="${1:-}"
if [[ -z "$APP_PATH" ]]; then
  echo "error: path to Storefront.app is required" >&2
  echo >&2
  usage >&2
  exit 1
fi

# Resolve and validate .app bundle
APP_PATH="$(cd "$(dirname "$APP_PATH")" && pwd)/$(basename "$APP_PATH")"
if [[ ! -d "$APP_PATH" || ! -f "$APP_PATH/Contents/Info.plist" ]]; then
  echo "error: not a valid app bundle: $APP_PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT_DMG")"
rm -f "$OUT_DMG"

# Stage a clean folder containing only the app (create-dmg copies folder contents)
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/storefront-dmg.XXXXXX")"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

cp -R "$APP_PATH" "$STAGE/Storefront.app"

echo "Packaging $APP_PATH -> $OUT_DMG"

# Window 660x400; icons aligned to packaging/dmg/background.png arrow endpoints.
# Applications (left) at 180,170; Storefront.app (right) at 480,170.
# ULMO (lzma) instead of create-dmg's default UDZO (zlib) — noticeably smaller for the
# same content. ULMO needs macOS 10.15+ to mount; the app itself requires 14.0.
create-dmg \
  --volname "Storefront" \
  --background "$BACKGROUND" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 128 \
  --icon "Storefront.app" 480 170 \
  --hide-extension "Storefront.app" \
  --app-drop-link 180 170 \
  --format ULMO \
  "$OUT_DMG" \
  "$STAGE"

echo "Created $OUT_DMG"
