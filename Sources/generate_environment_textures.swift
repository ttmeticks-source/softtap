import AppKit
import Foundation

let output = CommandLine.arguments.dropFirst().first ?? "Resources"
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

func writeTexture(_ name: String, draw: (NSRect) -> Void) throws {
    let size = 512
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    draw(NSRect(x: 0, y: 0, width: size, height: size))
    image.unlockFocus()
    guard let data = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: data),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "TextureGenerator", code: 1)
    }
    try png.write(to: URL(fileURLWithPath: output).appendingPathComponent(name + ".png"))
}

func pseudo(_ seed: Int) -> CGFloat {
    let value = (seed &* 1103515245 &+ 12345) & 0x7fffffff
    return CGFloat(value % 10000) / 10000
}

try writeTexture("wall_plaster") { rect in
    NSColor(calibratedRed: 0.57, green: 0.55, blue: 0.51, alpha: 1).setFill()
    rect.fill()
    for i in 0..<2600 {
        let x = pseudo(i * 7 + 3) * 512
        let y = pseudo(i * 13 + 19) * 512
        let d = 0.5 + pseudo(i * 17 + 41) * 2.2
        let alpha = 0.025 + pseudo(i * 23 + 7) * 0.08
        NSColor(calibratedWhite: pseudo(i * 29 + 5) > 0.5 ? 1 : 0, alpha: alpha).setFill()
        NSBezierPath(ovalIn: NSRect(x: x, y: y, width: d, height: d)).fill()
    }
    for row in 0..<18 {
        let y = CGFloat(row) * 30 + 12
        let seam = NSBezierPath()
        seam.move(to: NSPoint(x: 0, y: y))
        seam.line(to: NSPoint(x: 512, y: y + CGFloat(row % 3 - 1) * 1.5))
        seam.lineWidth = 0.6
        NSColor(calibratedWhite: 0.18, alpha: 0.035).setStroke()
        seam.stroke()
    }
}

try writeTexture("carpet_woven") { rect in
    NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.24, alpha: 1).setFill()
    rect.fill()
    for y in stride(from: 0, to: 512, by: 4) {
        for x in stride(from: 0, to: 512, by: 4) {
            let v = pseudo(x * 37 + y * 13)
            NSColor(calibratedRed: 0.16 + v * 0.10, green: 0.17 + v * 0.10, blue: 0.18 + v * 0.11, alpha: 1).setFill()
            NSBezierPath(rect: NSRect(x: CGFloat(x), y: CGFloat(y), width: 2.4, height: 2.4)).fill()
        }
    }
    for y in stride(from: 1, to: 512, by: 4) {
        let thread = NSBezierPath()
        thread.move(to: NSPoint(x: 0, y: y))
        thread.line(to: NSPoint(x: 512, y: y))
        thread.lineWidth = 0.5
        NSColor(calibratedWhite: 0.82, alpha: 0.10).setStroke()
        thread.stroke()
    }
}

try writeTexture("grass_outside") { rect in
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.18, green: 0.34, blue: 0.12, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.27, blue: 0.075, alpha: 1),
        NSColor(calibratedRed: 0.055, green: 0.18, blue: 0.045, alpha: 1)
    ])!
    gradient.draw(in: rect, angle: 90)
    for i in 0..<9000 {
        let x = pseudo(i * 7 + 1) * 512
        let y = pseudo(i * 11 + 29) * 512
        let h = 3 + pseudo(i * 19 + 13) * 22
        let blade = NSBezierPath()
        blade.move(to: NSPoint(x: x, y: y))
        blade.curve(to: NSPoint(x: x + (pseudo(i * 23 + 2) - 0.5) * 8, y: y + h),
                    controlPoint1: NSPoint(x: x - 3, y: y + h * 0.35),
                    controlPoint2: NSPoint(x: x + 4, y: y + h * 0.7))
        blade.lineWidth = 0.5 + pseudo(i * 31 + 9) * 1.4
        NSColor(calibratedRed: 0.13 + pseudo(i * 37 + 4) * 0.20,
                green: 0.25 + pseudo(i * 41 + 8) * 0.30,
                blue: 0.045 + pseudo(i * 43 + 6) * 0.06,
                alpha: 0.42).setStroke()
        blade.stroke()
    }
}
print("Generated wall plaster, woven carpet and grass field textures.")
