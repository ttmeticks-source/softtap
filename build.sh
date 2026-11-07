#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="dist/Smash Simulator.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"
rm -rf "dist"
mkdir -p "$MACOS" "$RES" "dist/Smash.iconset"
swift Sources/generate_vfx_textures.swift "$RES"
swift Sources/generate_window_shards.swift "$RES/window_shards.scn"
swift Sources/generate_environment_textures.swift "$RES"
swift Sources/generate_audio.swift "$RES"
# Optional real recordings override the synthesized placeholders when supplied.
if [ -d "Assets/Audio" ]; then
    find "Assets/Audio" -maxdepth 1 -type f -name "*.wav" -exec cp {} "$RES/" \;
fi

cat > "dist/make_icon.swift" <<'SWIFT'
import AppKit
let sizes = [16,32,64,128,256,512,1024]
for size in sizes {
    let image = NSImage(size: NSSize(width:size,height:size))
    image.lockFocus()
    let bounds = NSRect(x:0,y:0,width:size,height:size)
    NSColor(calibratedRed:0.035,green:0.025,blue:0.075,alpha:1).setFill()
    NSBezierPath(roundedRect:bounds,xRadius:Double(size)*0.22,yRadius:Double(size)*0.22).fill()
    let inset = Double(size)*0.045
    let background = NSBezierPath(roundedRect:NSRect(x:inset,y:inset,width:Double(size)-2*inset,height:Double(size)-2*inset),xRadius:Double(size)*0.22,yRadius:Double(size)*0.22)
    let gradient = NSGradient(colors:[
        NSColor(calibratedRed:0.13,green:0.07,blue:0.22,alpha:1),
        NSColor(calibratedRed:0.30,green:0.12,blue:0.34,alpha:1)
    ])!
    gradient.draw(in:background,angle:135)
    let ring = NSBezierPath(ovalIn:NSRect(x:Double(size)*0.13,y:Double(size)*0.13,width:Double(size)*0.74,height:Double(size)*0.74))
    NSColor(calibratedRed:0.98,green:0.56,blue:0.20,alpha:0.35).setStroke()
    ring.lineWidth = max(1,Double(size)*0.018)
    ring.stroke()
    let screen = NSBezierPath(roundedRect:NSRect(x:Double(size)*0.20,y:Double(size)*0.20,width:Double(size)*0.60,height:Double(size)*0.48),xRadius:Double(size)*0.055,yRadius:Double(size)*0.055)
    NSColor(calibratedRed:0.025,green:0.045,blue:0.065,alpha:1).setFill()
    screen.fill()
    screen.lineWidth = max(1,Double(size)*0.025)
    NSColor(calibratedRed:0.96,green:0.74,blue:0.42,alpha:1).setStroke()
    screen.stroke()
    let crack = NSBezierPath()
    crack.move(to:NSPoint(x:Double(size)*0.50,y:Double(size)*0.62))
    crack.line(to:NSPoint(x:Double(size)*0.43,y:Double(size)*0.49))
    crack.line(to:NSPoint(x:Double(size)*0.54,y:Double(size)*0.40))
    crack.line(to:NSPoint(x:Double(size)*0.47,y:Double(size)*0.27))
    crack.lineCapStyle = .round
    crack.lineJoinStyle = .round
    crack.lineWidth = max(1,Double(size)*0.025)
    NSColor(calibratedRed:1.0,green:0.64,blue:0.24,alpha:1).setStroke()
    crack.stroke()
    let stand = NSBezierPath()
    stand.move(to:NSPoint(x:Double(size)*0.50,y:Double(size)*0.20))
    stand.line(to:NSPoint(x:Double(size)*0.50,y:Double(size)*0.12))
    stand.line(to:NSPoint(x:Double(size)*0.37,y:Double(size)*0.12))
    stand.line(to:NSPoint(x:Double(size)*0.63,y:Double(size)*0.12))
    stand.lineWidth = max(2,Double(size)*0.045)
    NSColor(calibratedRed:0.72,green:0.78,blue:0.84,alpha:1).setStroke()
    stand.stroke()
    let head = NSBezierPath(roundedRect:NSRect(x:Double(size)*0.23,y:Double(size)*0.59,width:Double(size)*0.48,height:Double(size)*0.19),xRadius:Double(size)*0.055,yRadius:Double(size)*0.055)
    NSColor(calibratedRed:0.98,green:0.70,blue:0.20,alpha:1).setFill()
    head.fill()
    let highlight = NSBezierPath()
    highlight.move(to:NSPoint(x:Double(size)*0.29,y:Double(size)*0.70))
    highlight.line(to:NSPoint(x:Double(size)*0.62,y:Double(size)*0.70))
    highlight.lineWidth = max(1,Double(size)*0.018)
    NSColor(calibratedWhite:1,alpha:0.72).setStroke()
    highlight.stroke()
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
        -framework AppKit -framework SceneKit -framework QuartzCore \
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
<key>CFBundleName</key><string>Smash Simulator Demo</string>
<key>CFBundleDisplayName</key><string>Smash Simulator Demo</string>
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
