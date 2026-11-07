import AppKit
import Foundation

let output = CommandLine.arguments.dropFirst().first ?? "Resources"
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

func render(_ name: String, scratch: Bool, seed: Int) throws {
    let size = 512
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSColor.clear.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
    let path = NSBezierPath()
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.lineWidth = scratch ? CGFloat(2 + seed % 3) : CGFloat(2 + seed % 2)
    let center = CGFloat(256 + (seed * 17 % 60) - 30)
    if scratch {
        for strand in 0..<5 {
            let y = CGFloat(90 + strand * 75 + seed % 21)
            path.move(to: NSPoint(x: 35, y: y))
            path.curve(to: NSPoint(x: 475, y: y + CGFloat((strand % 2 == 0) ? 24 : -19)),
                       controlPoint1: NSPoint(x: 160, y: y - 18),
                       controlPoint2: NSPoint(x: 320, y: y + 25))
        }
    } else {
        let spokes = 7 + seed % 5
        for spoke in 0..<spokes {
            let angle = Double(spoke) * 2 * Double.pi / Double(spokes) + Double(seed) * 0.13
            let radius = CGFloat(185 + (spoke * 23 + seed * 7) % 75)
            let end = NSPoint(x: center + cos(angle) * radius, y: center + sin(angle) * radius)
            path.move(to: NSPoint(x: center, y: center))
            path.line(to: end)
            let branch = NSPoint(x: center + cos(angle + 0.34) * radius * 0.62,
                                 y: center + sin(angle + 0.34) * radius * 0.62)
            path.move(to: NSPoint(x: center + cos(angle) * radius * 0.58,
                                  y: center + sin(angle) * radius * 0.58))
            path.line(to: branch)
        }
        let ring = NSBezierPath(ovalIn: NSRect(x: center - 20, y: center - 20, width: 40, height: 40))
        ring.lineWidth = 2
        ring.stroke()
    }
    NSColor(calibratedWhite: 0.86, alpha: scratch ? 0.68 : 0.78).setStroke()
    path.stroke()
    image.unlockFocus()
    guard let data = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: data),
          let png = bitmap.representation(using: .png, properties: [:]) else { return }
    try png.write(to: URL(fileURLWithPath: output).appendingPathComponent(name + ".png"))
}

for index in 1...8 { try render(String(format: "crack_%02d", index), scratch: false, seed: index) }
for index in 1...6 { try render(String(format: "scratch_%02d", index), scratch: true, seed: index) }
