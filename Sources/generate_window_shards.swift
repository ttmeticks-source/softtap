import AppKit
import Foundation
import SceneKit

let outputPath = CommandLine.arguments.dropFirst().first ?? "Resources/window_shards.scn"
let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let scene = SCNScene()
let glassMaterial = SCNMaterial()
glassMaterial.diffuse.contents = NSColor(calibratedRed: 0.40, green: 0.76, blue: 0.88, alpha: 0.72)
glassMaterial.transparency = 0.72
glassMaterial.isDoubleSided = true
glassMaterial.lightingModel = .physicallyBased
glassMaterial.roughness.contents = 0.16
glassMaterial.metalness.contents = 0.04

for row in 0..<4 {
    for column in 0..<4 {
        let index = row * 4 + column
        let cellWidth: CGFloat = 2.38 / 4
        let cellHeight: CGFloat = 1.58 / 4
        let width = cellWidth * CGFloat.random(in: 0.78...0.96)
        let height = cellHeight * CGFloat.random(in: 0.78...0.96)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: -width * 0.50, y: -height * 0.44))
        path.line(to: NSPoint(x: width * CGFloat.random(in: 0.28...0.50), y: -height * 0.50))
        path.line(to: NSPoint(x: width * 0.50, y: height * CGFloat.random(in: 0.25...0.48)))
        path.line(to: NSPoint(x: -width * CGFloat.random(in: 0.28...0.48), y: height * 0.50))
        path.close()
        let shape = SCNShape(path: path, extrusionDepth: 0.028)
        shape.chamferRadius = 0.003
        shape.firstMaterial = glassMaterial
        let shard = SCNNode(geometry: shape)
        shard.name = String(format: "WindowShard_%02d", index + 1)
        shard.position = SCNVector3((CGFloat(column) - 1.5) * cellWidth,
                                    (1.5 - CGFloat(row)) * cellHeight, 0)
        scene.rootNode.addChildNode(shard)
    }
}
guard scene.write(to: outputURL, options: nil, delegate: nil, progressHandler: nil) else {
    fatalError("Could not write authored window shard scene to \(outputPath)")
}
print("Generated 16 authored window shard meshes: \(outputPath)")
