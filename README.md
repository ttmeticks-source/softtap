# Smash Simulator

A native macOS 3D destruction sandbox. All breakage is virtual inside the app; it does not affect real devices, your Mac, your desktop, or your files.

## Install with one curl command

Open Terminal and paste:

```sh
curl -fsSL https://raw.githubusercontent.com/ttmeticks-source/softtap/main/install.sh | bash
```

The installer downloads the latest macOS app ZIP from GitHub Releases, checks that it is a valid ZIP, installs **Smash Simulator.app** into /Applications (or ~/Applications if needed), and opens it.

The app is built by GitHub Actions on a hosted macOS runner. You do not need to clone the repository, compile Swift locally, or install Xcode.

## Included

- Native AppKit + SceneKit app.
- Virtual iPhone, iPad, MacBook, and desktop PC models.
- Studio, garage, concrete, bedroom, and neon lab rooms.
- Hammer, wrecking ball, kick, and drop-test simulation.
- Adjustable impact intensity and scene reset.

## Build pipeline

Every push to main queues a macOS build. After the build succeeds, GitHub publishes a release asset named `Smash-Simulator-macOS.zip`; the installer always downloads the latest successful release.

## Safety / scope

All effects are visual simulations. The app does not access device hardware, control connected devices, modify the macOS desktop, or delete user data.

## License

MIT
