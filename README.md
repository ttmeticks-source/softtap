# Smash Simulator

A native macOS 3D destruction sandbox. Smash Simulator models fictional devices in a virtual room — it never interacts with, damages, or modifies your real Mac, desktop, phone, or files.

## Features
- Native AppKit + SceneKit app; no JavaScript, browser wrapper, or Xcode project.
- 3D iPhone, iPad, MacBook, and desktop PC props.
- Studio, garage, concrete, bedroom, and neon lab rooms.
- Hammer, wrecking ball, kick, and drop-test physics.
- Adjustable impact intensity and reset.
- Builds a `.app` bundle and `.icns` icon using the macOS Command Line Tools.

## Build on macOS

Requirements: macOS 13+, Swift compiler and `iconutil` from Apple's standalone Command Line Tools. Xcode is not required.

```sh
git clone https://github.com/ttmeticks-source/softtap.git
cd softtap
chmod +x build.sh
./build.sh
open "dist/Smash Simulator.app"
```

The app bundle is created at `dist/Smash Simulator.app`. The distributable archive is `dist/Smash-Simulator-macOS.zip`.

## Install with curl

After a GitHub Actions build has completed, download the latest packaged app:

```sh
curl -L "https://github.com/ttmeticks-source/softtap/releases/latest/download/Smash-Simulator-macOS.zip" -o Smash-Simulator-macOS.zip
unzip -o Smash-Simulator-macOS.zip
open "Smash Simulator.app"
```

The workflow publishes the zip as a GitHub Actions artifact on each push. A release asset is available after a release is published.

## Safety / scope

All breakage is visual and simulated inside the SceneKit scene. The app does not access hardware controls, send commands to connected devices, alter the macOS desktop, or delete user data. "Desktop PC" is a virtual prop, not a control for the actual desktop.

## License

MIT
