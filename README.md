# Smash Simulator

Native macOS SceneKit arcade sandbox with a workbench, collidable room, cursor-controlled tools and exaggerated game-feel damage.

## Requirements

- macOS 11 Big Sur or newer.
- Universal app for Intel (x86_64) and Apple Silicon (arm64).
- Native AppKit + SceneKit + AVFoundation. No Xcode project is required.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/ttmeticks-source/softtap/main/install.sh | bash
```

The installer displays download progress, checks macOS 11+ and both CPU architectures, validates the ZIP, installs the app in Applications, and opens it.

## Controls

- Move the mouse over the 3D scene: the selected tool model follows the pointer.
- Click to make an impact. Holding the mouse button longer increases the arcade hit intensity (capped at 0.85 seconds).
- The tool's power stat and the damage slider also scale the effect.
- Right-drag to orbit the camera within the room; scroll to zoom within its bounds.
- Choose Soft Tap, Rubber Mallet, Precision Hammer, Heavy Hammer, Wrench, Impact Driver or Energy Pulse.
- The center test-hit button performs a demo hit; Drop Test sends the selected device toward the workbench.
- Reset Scene rebuilds the desk, room, device and effects.

## Arcade simulation

SceneKit provides rigid-body gravity, collisions and contact callbacks for fragments and props. Subdivided meshes receive localized cartoon dents around the click point. High-power impacts can detach stylized chunks with spin and gravity. The workbench tabletop, legs, drawer and room props are part of the scene; the floor, all four walls and ceiling are colliders. The camera is constrained to the room.

Impact and collision sounds are synthesized locally. No external media assets are required.

Deformation and breakage are exaggerated visual gameplay effects, not material-science simulation or real-world damage instructions.

## Age notice

One 16+ self-confirmation is shown at startup. It is a self-declaration, not independent identity or age verification.

## License

MIT
