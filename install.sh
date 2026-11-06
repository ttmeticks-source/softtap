#!/bin/bash
set -euo pipefail

RELEASE_URL="https://github.com/ttmeticks-source/softtap/releases/latest/download/Smash-Simulator-macOS.zip"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/smash-simulator.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

ARCHIVE="$WORK_DIR/Smash-Simulator-macOS.zip"
APP_SOURCE="$WORK_DIR/Smash Simulator.app"

echo "Downloading the latest Smash Simulator build..."
if ! curl --fail --location --silent --show-error --retry 3 "$RELEASE_URL" --output "$ARCHIVE"; then
  echo "Download failed. The latest GitHub macOS build may not have finished yet." >&2
  echo "Build status: https://github.com/ttmeticks-source/softtap/actions" >&2
  exit 1
fi

if ! /usr/bin/unzip -tq "$ARCHIVE" >/dev/null; then
  echo "The downloaded file is not a valid app ZIP. The release build may be incomplete." >&2
  exit 1
fi

/usr/bin/unzip -q "$ARCHIVE" -d "$WORK_DIR"
if [[ ! -d "$APP_SOURCE" ]]; then
  echo "The archive did not contain Smash Simulator.app." >&2
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

echo "Installed: $INSTALL_DIR/Smash Simulator.app"
open "$INSTALL_DIR/Smash Simulator.app"
