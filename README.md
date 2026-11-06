# Smash Simulator

A native macOS SceneKit sandbox for experimenting with virtual devices and simple physics effects. Everything happens inside the app and never affects real devices, your Mac, or your files.

## Requirements

- macOS 11 Big Sur or newer.
- Universal app for Intel (x86_64) and Apple Silicon (arm64).
- Native AppKit + SceneKit. No Xcode project is required.

## Install with one curl command

Open Terminal and paste:

```sh
curl -fsSL https://raw.githubusercontent.com/ttmeticks-source/softtap/main/install.sh | bash
```

The installer displays download progress, validates the ZIP, checks the macOS 11 minimum and both CPU architectures, installs the app in Applications, and opens it.

## Controls

- Choose a virtual device, effect, and room from the sidebar.
- Use the app's buttons to apply simple in-scene effects and reset the scene.
- Drag the scene to orbit the camera.

## Scope

This is a lightweight virtual sandbox, not a real-world damage guide or a reproduction of BeamNG's soft-body solver. Its visual effects and physics stay inside the SceneKit scene.

## License

MIT
