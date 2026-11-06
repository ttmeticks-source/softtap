# Smash Simulator

A native macOS 3D destruction sandbox. All breakage is virtual inside the app; it does not affect real devices, your Mac, your desktop, or your files.

## System support

- **macOS 11 Big Sur or newer**.
- Universal app for both **Intel (x86_64)** and **Apple Silicon (arm64)** Macs.
- The executable and app bundle are both built with macOS 11.0 as the minimum deployment target.

## Install with one curl command

Open Terminal and paste:

```sh
curl -fsSL https://raw.githubusercontent.com/ttmeticks-source/softtap/main/install.sh | bash
```

The installer checks your macOS version, downloads and validates the latest app ZIP, installs **Smash Simulator.app** into /Applications (or ~/Applications if needed), and opens it.

The app is compiled on GitHub's macOS runner. You do not need to clone the repository or compile Swift locally.

## Included

- Native AppKit + SceneKit app.
- Virtual iPhone, iPad, MacBook, and desktop PC models.
- Studio, garage, concrete, bedroom, and neon lab rooms.
- Hammer, wrecking ball, kick, and drop-test simulation.
- Adjustable impact intensity and scene reset.

## Build pipeline

Every push to main queues a macOS build. After the build and compatibility checks succeed, GitHub publishes a release asset named `Smash-Simulator-macOS.zip`; the installer downloads the latest successful release.

## Safety / scope

All effects are visual simulations. The app does not access device hardware, control connected devices, modify the macOS desktop, or delete user data.

## License

MIT
