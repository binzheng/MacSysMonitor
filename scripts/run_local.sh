#!/usr/bin/env bash
set -euo pipefail

# Build and launch MacSysMonitor locally (no DMG needed).
# - Builds Release into ./build
# - Copies the app to /Applications (overwrites existing copy)
# - Launches the app with `open`

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/MacSysMonitor.xcodeproj"
SCHEME="MacSysMonitor"
DERIVED_DATA="$ROOT/build"
APP_SRC="$DERIVED_DATA/Build/Products/Release/MacSysMonitor.app"
APP_DST="/Applications/MacSysMonitor.app"

echo "==> Building Release..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" >/tmp/macsysmonitor_build.log

if [[ ! -d "$APP_SRC" ]]; then
  echo "Build failed: $APP_SRC not found" >&2
  exit 1
fi

echo "==> Installing to $APP_DST"
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

echo "==> Launching MacSysMonitor"
open "$APP_DST"
echo "Done. Check the menu bar for the MacSysMonitor icon."
