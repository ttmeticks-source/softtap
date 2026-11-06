# Smash Simulator

A native macOS 3D destruction sandbox with a detailed desk scene, pointer-controlled tools, glitch displays, scratches and rigid debris.

## Requirements

- macOS 11 Big Sur or newer.
- Universal app: Intel (x86_64) and Apple Silicon (arm64).
- Native AppKit + SceneKit. No browser wrapper or Xcode project.

## Install with one curl command

```sh
curl -fsSL https://raw.githubusercontent.com/ttmeticks-source/softtap/main/install.sh | bash
```

The installer shows download progress, validates the ZIP, checks the app's macOS 11 minimum and both CPU architectures, installs it in Applications, and opens it.

## Controls

- Move the mouse to move the selected 3D tool.
- Click or drag on a device, desk, floor panel or room prop to interact.
- Choose the device, tool, room and impact strength from the left panel.
- Orbit the scene and zoom with SceneKit camera controls.
- Use Drop Object to run a virtual drop test and Reset Room to restore the scene.

## Simulation

Devices have separate chassis, display, keyboard, camera, speaker and port details. Their displays show an original locally generated glitch/test feed with the text **Made by C0oled**; no downloaded third-party video or copyrighted footage is included.

Damage is represented by scratches and separate rigid fragments with collision, not rubber-like stretching. SceneKit provides rigid-body dynamics and collision handling; this is a lightweight fracture approximation, not BeamNG's full node-and-beam soft-body solver. Debris clears itself after a short time to keep the scene responsive.

The desk, its supports, floor panels and room props have collision bodies. Strong virtual hits can break selected surfaces into individual pieces. The simulation never damages or controls real devices or files.

## License

MIT
