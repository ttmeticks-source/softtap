# Smash Simulator

A native macOS SceneKit sandbox for virtual devices, simple physics effects and display interference. Everything happens in the app and never affects real devices, your Mac, or your files.

## Requirements

- macOS 11 Big Sur or newer.
- Universal app for Intel (x86_64) and Apple Silicon (arm64).
- Native AppKit + SceneKit. No Xcode project is required.

## Install with one curl command

```sh
curl -fsSL https://raw.githubusercontent.com/ttmeticks-source/softtap/main/install.sh | bash
```

The installer correctly reads versions such as 11.7, 12.7.6 and 14.8.9, shows download progress, validates the ZIP, checks the macOS 11 app minimum and both CPU architectures, installs the app in Applications, and opens it.

## Safety notice

All effects are virtual. Do not try to reproduce them on real devices, furniture or other property. The app does not access the camera, scan faces, verify identity, control connected devices, or modify user files.

## Store publishing notes

This repository currently distributes a macOS app from GitHub; it is not a Google Play Android package. Google Play submissions require an Android build and an accurate target-audience/content-rating questionnaire in Play Console. macOS App Store distribution follows Apple's separate Mac App Store requirements, including sandboxing, app-bundle packaging and its own submission process. A warning label does not guarantee store approval or replace the platform's age/content rating process.

## License

MIT
