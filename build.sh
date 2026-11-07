#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="dist/Smash Simulator.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"
rm -rf "dist"
mkdir -p "$MACOS" "$RES" "dist/Smash.iconset"

cat > "dist/make_icon.swift" <<'SWIFT'
import AppKit
let sizes = [16,32,64,128,256,512,1024]
for size in sizes {
    let image = NSImage(size: NSSize(width:size,height:size))
    image.lockFocus()
    let bounds = NSRect(x:0,y:0,width:size,height:size)
    NSColor(calibratedRed:0.07,green:0.10,blue:0.16,alpha:1).setFill()
    NSBezierPath(roundedRect:bounds,xRadius:Double(size)*0.22,yRadius:Double(size)*0.22).fill()
    let device = NSBezierPath(roundedRect:NSRect(x:Double(size)*0.28,y:Double(size)*0.12,width:Double(size)*0.44,height:Double(size)*0.76),xRadius:Double(size)*0.07,yRadius:Double(size)*0.07)
    NSColor(calibratedWhite:0.72,alpha:1).setFill(); device.fill()
    let screen = NSBezierPath(roundedRect:NSRect(x:Double(size)*0.315,y:Double(size)*0.22,width:Double(size)*0.37,height:Double(size)*0.56),xRadius:Double(size)*0.025,yRadius:Double(size)*0.025)
    NSColor(calibratedRed:0.02,green:0.035,blue:0.06,alpha:1).setFill(); screen.fill()
    let slash = NSBezierPath()
    slash.lineWidth = max(2,Double(size)*0.035)
    slash.move(to:NSPoint(x:Double(size)*0.40,y:Double(size)*0.68))
    slash.line(to:NSPoint(x:Double(size)*0.60,y:Double(size)*0.43))
    NSColor(calibratedRed:1,green:0.35,blue:0.18,alpha:1).setStroke(); slash.stroke()
    image.unlockFocus()
    let tiff = image.tiffRepresentation!
    let rep = NSBitmapImageRep(data:tiff)!
    let png = rep.representation(using:.png,properties:[:])!
    try png.write(to:URL(fileURLWithPath:"dist/Smash.iconset/icon_\(size)x\(size).png"))
}
SWIFT

swift "dist/make_icon.swift"
cp "dist/Smash.iconset/icon_16x16.png" "dist/Smash.iconset/icon_16x16@1x.png"
cp "dist/Smash.iconset/icon_32x32.png" "dist/Smash.iconset/icon_16x16@2x.png"
cp "dist/Smash.iconset/icon_32x32.png" "dist/Smash.iconset/icon_32x32@1x.png"
cp "dist/Smash.iconset/icon_64x64.png" "dist/Smash.iconset/icon_32x32@2x.png"
cp "dist/Smash.iconset/icon_128x128.png" "dist/Smash.iconset/icon_128x128@1x.png"
cp "dist/Smash.iconset/icon_256x256.png" "dist/Smash.iconset/icon_128x128@2x.png"
cp "dist/Smash.iconset/icon_256x256.png" "dist/Smash.iconset/icon_256x256@1x.png"
cp "dist/Smash.iconset/icon_512x512.png" "dist/Smash.iconset/icon_256x256@2x.png"
cp "dist/Smash.iconset/icon_512x512.png" "dist/Smash.iconset/icon_512x512@1x.png"
cp "dist/Smash.iconset/icon_1024x1024.png" "dist/Smash.iconset/icon_512x512@2x.png"
rm -f "dist/Smash.iconset/icon_64x64.png" "dist/Smash.iconset/icon_1024x1024.png"
iconutil -c icns "dist/Smash.iconset" -o "$RES/Smash.icns"

# Build both supported Mac CPU architectures with macOS 11.0 as the true minimum.
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
for ARCH in arm64 x86_64; do
    echo "Compiling for ${ARCH}, minimum macOS 11.0..."
    xcrun --sdk macosx swiftc -O -sdk "$SDK_PATH" \
        -target "${ARCH}-apple-macos11.0" \
        -framework AppKit -framework SceneKit -framework QuartzCore -framework AVFoundation \
        Sources/main.swift -o "$MACOS/SmashSimulator-${ARCH}"
done
xcrun lipo -create \
    "$MACOS/SmashSimulator-arm64" \
    "$MACOS/SmashSimulator-x86_64" \
    -output "$MACOS/SmashSimulator"
rm "$MACOS/SmashSimulator-arm64" "$MACOS/SmashSimulator-x86_64"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Smash Simulator</string>
<key>CFBundleDisplayName</key><string>Smash Simulator</string>
<key>CFBundleIdentifier</key><string>com.ttmeticks.smashsimulator</string>
<key>CFBundleVersion</key><string>1.1.0</string>
<key>CFBundleShortVersionString</key><string>1.1.0</string>
<key>CFBundleExecutable</key><string>SmashSimulator</string>
<key>CFBundleIconFile</key><string>Smash</string>
<key>LSMinimumSystemVersion</key><string>11.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST

/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$CONTENTS/Info.plist" >/dev/null
codesign --force --deep --sign - "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/Smash-Simulator-macOS.zip"
echo "Built universal app for macOS 11.0+: $APP"
echo "Archive: dist/Smash-Simulator-macOS.zip"
