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
    let s = CGFloat(size)
    let bounds = NSRect(x:0,y:0,width:s,height:s)
    NSColor(calibratedRed:0.018,green:0.028,blue:0.055,alpha:1).setFill()
    NSBezierPath(roundedRect:bounds,xRadius:s*0.22,yRadius:s*0.22).fill()
    let glow = NSGradient(colors:[
        NSColor(calibratedRed:0.035,green:0.16,blue:0.25,alpha:1),
        NSColor(calibratedRed:0.12,green:0.035,blue:0.19,alpha:1)
    ])!
    glow.draw(in:bounds,angle:42)
    let phone = NSRect(x:s*0.24,y:s*0.09,width:s*0.52,height:s*0.82)
    let body = NSBezierPath(roundedRect:phone,xRadius:s*0.085,yRadius:s*0.085)
    NSColor(calibratedRed:0.58,green:0.68,blue:0.76,alpha:1).setFill()
    body.fill()
    let screen = phone.insetBy(dx:s*0.025,dy:s*0.035)
    let glass = NSBezierPath(roundedRect:screen,xRadius:s*0.065,yRadius:s*0.065)
    NSColor(calibratedRed:0.008,green:0.014,blue:0.03,alpha:1).setFill()
    glass.fill()
    for band in 0..<9 {
        let y = screen.minY + CGFloat(band) * screen.height / 9
        let stripe = NSBezierPath()
        stripe.lineWidth = s * (0.012 + CGFloat(band % 3) * 0.006)
        stripe.move(to:NSPoint(x:screen.minX+s*0.015,y:y))
        stripe.line(to:NSPoint(x:screen.maxX-s*0.015,y:y+CGFloat((band%2)*2-1)*s*0.012))
        let colors = [
            NSColor(calibratedRed:1,green:0.025,blue:0.18,alpha:0.95),
            NSColor(calibratedRed:0.02,green:0.78,blue:1,alpha:0.95),
            NSColor(calibratedRed:0.68,green:0.06,blue:1,alpha:0.95)
        ]
        colors[band%3].setStroke()
        stripe.stroke()
    }
    let crack = NSBezierPath()
    crack.lineCapStyle = .round
    crack.lineJoinStyle = .round
    crack.lineWidth = s*0.018
    crack.move(to:NSPoint(x:s*0.50,y:s*0.53))
    crack.line(to:NSPoint(x:s*0.42,y:s*0.62))
    crack.line(to:NSPoint(x:s*0.56,y:s*0.70))
    crack.line(to:NSPoint(x:s*0.46,y:s*0.82))
    crack.move(to:NSPoint(x:s*0.43,y:s*0.62))
    crack.line(to:NSPoint(x:s*0.31,y:s*0.57))
    crack.move(to:NSPoint(x:s*0.56,y:s*0.70))
    crack.line(to:NSPoint(x:s*0.68,y:s*0.65))
    NSColor.white.setStroke()
    crack.stroke()
    for index in 0..<7 {
        let x = s * (0.18 + CGFloat(index) * 0.105)
        let shard = NSBezierPath()
        shard.move(to:NSPoint(x:x,y:s*0.18))
        shard.line(to:NSPoint(x:x+CGFloat(index%2 == 0 ? 0.035 : -0.025)*s,y:s*0.11))
        shard.line(to:NSPoint(x:x+CGFloat(index%2 == 0 ? 0.06 : -0.05)*s,y:s*0.20))
        shard.close()
        [NSColor.systemCyan,NSColor.systemPink,NSColor.systemPurple][index%3].withAlphaComponent(0.9).setFill()
        shard.fill()
    }
    image.unlockFocus()
    let rep = NSBitmapImageRep(data:image.tiffRepresentation!)!
    let png = rep.representation(using:.png,properties:[:])!
    try png.write(to:URL(fileURLWithPath:"dist/Smash.iconset/icon_\(size)x\(size).png"))
}
SWIFTT

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
