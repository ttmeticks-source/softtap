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
    NSColor(calibratedRed: 0.62, green: 0.59, blue: 0.53, alpha: 1).setFill()
    rect.fill()
    for i in 0..<6200 {
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
    NSColor(calibratedRed: 0.22, green: 0.17, blue: 0.15, alpha: 1).setFill()
    rect.fill()
    for y in stride(from: 0, to: 512, by: 3) {
        for x in stride(from: 0, to: 512, by: 3) {
            let v = pseudo(x * 37 + y * 13)
            let warm = pseudo(x * 17 + y * 31)
            NSColor(calibratedRed: 0.19 + v * 0.13,
                    green: 0.145 + warm * 0.105,
                    blue: 0.13 + v * 0.085, alpha: 1).setFill()
            NSBezierPath(rect: NSRect(x: CGFloat(x), y: CGFloat(y), width: 2.2, height: 2.2)).fill()
        }
    }
    for y in stride(from: 1, to: 512, by: 3) {
        let thread = NSBezierPath()
        thread.move(to: NSPoint(x: 0, y: y))
        thread.line(to: NSPoint(x: 512, y: y))
        thread.lineWidth = 0.75
        NSColor(calibratedRed: 0.72, green: 0.57, blue: 0.43, alpha: 0.16).setStroke()
        thread.stroke()
    }
    for x in stride(from: 2, to: 512, by: 6) {
        let thread = NSBezierPath()
        thread.move(to: NSPoint(x: x, y: 0))
        thread.line(to: NSPoint(x: x + 12, y: 512))
        thread.lineWidth = 0.55
        NSColor(calibratedWhite: 0.92, alpha: 0.07).setStroke()
        thread.stroke()
    }
}

try writeTexture("wall_plaster_normal") { rect in
    NSColor(calibratedRed: 0.50, green: 0.50, blue: 0.98, alpha: 1).setFill()
    rect.fill()
    for i in 0..<2200 {
        let x = pseudo(i * 7 + 51) * 512
        let y = pseudo(i * 13 + 17) * 512
        let length = 4 + pseudo(i * 19 + 33) * 28
        let stroke = NSBezierPath()
        stroke.move(to: NSPoint(x: x, y: y))
        stroke.line(to: NSPoint(x: x + length, y: y + (pseudo(i * 23 + 5) - 0.5) * 3))
        stroke.lineWidth = 0.7 + pseudo(i * 29 + 9) * 1.5
        NSColor(calibratedRed: 0.50 + (pseudo(i * 31 + 3) - 0.5) * 0.10,
                green: 0.50 + (pseudo(i * 37 + 7) - 0.5) * 0.10,
                blue: 0.94 + pseudo(i * 41 + 11) * 0.06, alpha: 0.8).setStroke()
        stroke.stroke()
    }
}

try writeTexture("carpet_woven_normal") { rect in
    NSColor(calibratedRed: 0.50, green: 0.50, blue: 1.0, alpha: 1).setFill()
    rect.fill()
    for y in stride(from: 0, to: 512, by: 3) {
        let thread = NSBezierPath()
        thread.move(to: NSPoint(x: 0, y: y))
        thread.line(to: NSPoint(x: 512, y: y))
        thread.lineWidth = 1.4
        NSColor(calibratedRed: 0.58, green: 0.48, blue: 0.98, alpha: 1).setStroke()
        thread.stroke()
    }
    for x in stride(from: 0, to: 512, by: 3) {
        let thread = NSBezierPath()
        thread.move(to: NSPoint(x: x, y: 0))
        thread.line(to: NSPoint(x: x, y: 512))
        thread.lineWidth = 1.1
        NSColor(calibratedRed: 0.43, green: 0.55, blue: 0.98, alpha: 1).setStroke()
        thread.stroke()
    }
}

try writeTexture("wood_grain") { rect in
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.30, green: 0.18, blue: 0.10, alpha: 1),
        NSColor(calibratedRed: 0.43, green: 0.27, blue: 0.15, alpha: 1),
        NSColor(calibratedRed: 0.25, green: 0.14, blue: 0.08, alpha: 1)
    ])!
    gradient.draw(in: rect, angle: 0)
    for i in 0..<95 {
        let y = pseudo(i * 29 + 5) * 512
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: y))
        path.curve(to: NSPoint(x: 512, y: y + (pseudo(i * 31 + 9) - 0.5) * 24),
                   controlPoint1: NSPoint(x: 150, y: y + (pseudo(i * 37 + 2) - 0.5) * 15),
                   controlPoint2: NSPoint(x: 340, y: y + (pseudo(i * 41 + 7) - 0.5) * 18))
        path.lineWidth = 0.8 + pseudo(i * 43 + 3) * 2.8
        NSColor(calibratedRed: 0.12, green: 0.065, blue: 0.035,
                alpha: 0.12 + pseudo(i * 47 + 1) * 0.22).setStroke()
        path.stroke()
    }
    for i in 0..<8 {
        let x = 45 + pseudo(i * 13 + 8) * 420
        let y = 45 + pseudo(i * 17 + 3) * 420
        let knot = NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 10 + pseudo(i * 19 + 4) * 15, height: 4 + pseudo(i * 23 + 6) * 7))
        knot.lineWidth = 1.5
        NSColor(calibratedRed: 0.16, green: 0.085, blue: 0.04, alpha: 0.32).setStroke()
        knot.stroke()
    }
}

try writeTexture("wood_grain_normal") { rect in
    NSColor(calibratedRed: 0.50, green: 0.50, blue: 0.98, alpha: 1).setFill()
    rect.fill()
    for i in 0..<1500 {
        let y = pseudo(i * 17 + 5) * 512
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: y))
        path.curve(to: NSPoint(x: 512, y: y + (pseudo(i * 23 + 1) - 0.5) * 9),
                   controlPoint1: NSPoint(x: 150, y: y + 2),
                   controlPoint2: NSPoint(x: 350, y: y - 2))
        path.lineWidth = 0.5 + pseudo(i * 29 + 7) * 1.4
        NSColor(calibratedRed: 0.50 + (pseudo(i * 31 + 9) - 0.5) * 0.13,
                green: 0.50 + (pseudo(i * 37 + 3) - 0.5) * 0.07,
                blue: 0.94 + pseudo(i * 41 + 2) * 0.06, alpha: 0.75).setStroke()
        path.stroke()
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
