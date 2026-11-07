# Smash Simulator

A native macOS SceneKit sandbox for virtual devices and room scenes.

## Requirements

- macOS 11 Big Sur or newer.
- Universal app for Intel (x86_64) and Apple Silicon (arm64).
- Native AppKit + SceneKit. No Xcode project is required.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/ttmeticks-source/softtap/main/install.sh | bash
```

The installer shows download progress, checks the macOS 11 minimum and both CPU architectures, validates the ZIP, installs the app in Applications, and opens it.

## Startup notice and controls

At launch, the app shows one 16+ self-confirmation notice. Choosing Quit exits. The prompt is an age declaration only; it does not scan faces or independently verify identity or age.

The scene includes a full collidable room enclosure (floor, four walls and ceiling) and a workbench with a collidable tabletop, four legs, frame rails, two drawers and drawer pulls. The selected virtual device is positioned on the workbench. SceneKit camera orbit remains enabled, with the camera position clamped inside the room volume. Click objects in the 3D view to inspect them. A brief selection marker and status text identify the selected scene node. Use the sidebar to choose a virtual device, tool preset, room and impact setting.

## Simulation scope

SceneKit provides the app's built-in rigid-body physics. The current simulator remains a lightweight virtual sandbox; it does not claim to reproduce BeamNG's soft-body solver or provide real-world damage instructions. All effects stay inside the app and do not affect real devices or files.

## Distribution

This repository builds a macOS app for GitHub Releases. It is not an Android app and a macOS GitHub release does not represent Google Play approval. Store submissions require the correct platform build, content declarations and review process.

## License

MIT
