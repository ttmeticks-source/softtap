#!/bin/bash
set -euo pipefail

OS_VERSION="$(/usr/bin/sw_vers -productVersion)"
OS_MAJOR="${OS_VERSION%%.*}"
if [[ ! "$OS_MAJOR" =~ ^[0-9]+$ ]] || (( OS_MAJOR < 11 )); then
  echo "Smash Simulator requires macOS 11 Big Sur or newer. This Mac is running macOS $OS_VERSION." >&2
  exit 1
fi

RELEASE_URL="https://github.com/ttmeticks-source/softtap/releases/latest/download/Smash-Simulator-macOS.zip"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/smash-simulator.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

ARCHIVE="$WORK_DIR/Smash-Simulator-macOS.zip"
APP_SOURCE="$WORK_DIR/Smash Simulator.app"

echo "Downloading Smash Simulator for macOS $OS_VERSION..."
if ! curl --fail --location --silent --show-error --retry 3 "$RELEASE_URL" --output "$ARCHIVE"; then
  echo "Download failed. Check the latest build at https://github.com/ttmeticks-source/softtap/actions" >&2
  exit 1
fi

if ! /usr/bin/unzip -tq "$ARCHIVE" >/dev/null; then
  echo "The downloaded file is not a valid app ZIP." >&2
  exit 1
fi

/usr/bin/unzip -q "$ARCHIVE" -d "$WORK_DIR"
if [[ ! -d "$APP_SOURCE" ]]; then
  echo "The archive did not contain Smash Simulator.app." >&2
  exit 1
fi

APP_EXECUTABLE="$APP_SOURCE/Contents/MacOS/SmashSimulator"
MINIMUM_OS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP_SOURCE/Contents/Info.plist")"
if [[ "$MINIMUM_OS" != "11.0" ]]; then
  echo "Downloaded app has an unexpected minimum OS version: $MINIMUM_OS" >&2
  exit 1
fi
ARCHS="$(/usr/bin/lipo -archs "$APP_EXECUTABLE")"
if [[ " $ARCHS " != *" arm64 "* || " $ARCHS " != *" x86_64 "* ]]; then
  echo "Downloaded app is missing an Intel or Apple Silicon build slice: $ARCHS" >&2
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
