#!/bin/bash
set -euo pipefail

OS_VERSION="$(/usr/bin/sw_vers -productVersion)"
OS_MAJOR="\${OS_VERSION%%.*}"
if [[ ! "$OS_MAJOR" =~ ^[0-9]+$ ]] || (( OS_MAJOR < 11 )); then
  echo "Smash Simulator requires macOS 11 Big Sur or newer. This Mac is running macOS $OS_VERSION." >&2
  exit 1
fi

RELEASE_URL="https://github.com/ttmeticks-source/softtap/releases/latest/download/Smash-Simulator-macOS.zip"
WORK_DIR="$(mktemp -d "\${TMPDIR:-/tmp}/smash-simulator.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
ARCHIVE="$WORK_DIR/Smash-Simulator-macOS.zip"
APP_SOURCE="$WORK_DIR/Smash Simulator.app"

echo "Downloading Smash Simulator for macOS $OS_VERSION..."
curl --fail --location --show-error --retry 3 --progress-bar "$RELEASE_URL" --output "$ARCHIVE"

if ! /usr/bin/unzip -tq "$ARCHIVE" >/dev/null; then
  echo "Download finished, but the ZIP did not pass integrity checking." >&2
  exit 1
fi

/usr/bin/unzip -q "$ARCHIVE" -d "$WORK_DIR"
if [[ ! -d "$APP_SOURCE" ]]; then
  echo "The archive did not contain Smash Simulator.app." >&2
  exit 1
fi

MINIMUM_OS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP_SOURCE/Contents/Info.plist")"
if [[ "$MINIMUM_OS" != "11.0" ]]; then
  echo "The downloaded app reports an unexpected minimum macOS version: $MINIMUM_OS" >&2
  exit 1
fi

ARCHS="$(/usr/bin/lipo -archs "$APP_SOURCE/Contents/MacOS/SmashSimulator")"
if [[ " $ARCHS " != *" arm64 "* || " $ARCHS " != *" x86_64 "* ]]; then
  echo "The app is not universal. Found architectures: $ARCHS" >&2
  exit 1
fi

if [[ -w /Applications ]]; then
  INSTALL_DIR="/Applications"
else
  INSTALL_DIR="$HOME/Applications"
  mkdir -p "$INSTALL_DIR"
fi

rm -rf "$INSTALL_DIR/Smash Simulator.app"
/usr/bin/ditto "$APP_SOURCE" "$INSTALL_DIR/Smash Simulator.app"
echo "Installed for macOS 11+ ($ARCHS): $INSTALL_DIR/Smash Simulator.app"
open "$INSTALL_DIR/Smash Simulator.app"
