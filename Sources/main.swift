import AppKit
import SceneKit
import QuartzCore
import AVFoundation

final class SmashSceneView: SCNView {
    var onPointerMove: ((NSPoint) -> Void)?
    var onPointerClick: ((NSPoint, TimeInterval) -> Void)?
    var onOrbit: ((CGFloat, CGFloat) -> Void)?
    var onZoom: ((CGFloat) -> Void)?

    private var tracking: NSTrackingArea?
    private var pressStartedAt: TimeInterval = 0
    private var orbitPoint = NSPoint.zero

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseDragged, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
        super.updateTrackingAreas()
    }

    private func localPoint(_ event: NSEvent) -> NSPoint {
        convert(event.locationInWindow, from: nil)
    }

    override func mouseMoved(with event: NSEvent) {
        onPointerMove?(localPoint(event))
        super.mouseMoved(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        pressStartedAt = CACurrentMediaTime()
        onPointerMove?(localPoint(event))
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        let held = max(0, CACurrentMediaTime() - pressStartedAt)
        onPointerClick?(localPoint(event), held)
        super.mouseUp(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        onPointerMove?(localPoint(event))
        super.mouseDragged(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        orbitPoint = localPoint(event)
    }

    override func rightMouseDragged(with event: NSEvent) {
        let current = localPoint(event)
        onOrbit?(current.x - orbitPoint.x, current.y - orbitPoint.y)
        orbitPoint = current
    }

    override func scrollWheel(with event: NSEvent) {
        onZoom?(event.scrollingDeltaY)
        super.scrollWheel(with: event)
    }
}

final class SmashSimulator: NSObject, NSApplicationDelegate, SCNSceneRendererDelegate, SCNPhysicsContactDelegate {
    private var window: NSWindow!
    private var sceneView: SmashSceneView!
    private var scene = SCNScene()
    private var deviceRoot: SCNNode?
    private var selectedTool = "Hammer"
    private var selectedDevice = "iPhone"
    private var damageLevel: Float = 0.72
    private var roomStyle = "Studio"
    private var statusLabel: NSTextField!
    private var devicePopup: NSPopUpButton!
    private var toolPopup: NSPopUpButton!
    private var roomPopup: NSPopUpButton!
    private var damageSlider: NSSlider!
    private var cursorToolNode: SCNNode?
    private var cameraNode: SCNNode?
    private var cameraYaw: Float = 0
    private var cameraPitch: Float = 0.27
    private var cameraDistance: Float = 9.2
    private var lastImpactSoundTime: TimeInterval = 0
    private var debrisCount = 0
    private let deskTopY: Float = 1.28
    private let toolPower: [String: Float] = [
        "Soft Tap": 0.38,
        "Rubber Mallet": 0.62,
        "Precision Hammer": 1.0,
        "Heavy Hammer": 1.42,
        "Wrench": 0.82,
        "Impact Driver": 1.18,
        "Energy Pulse": 1.62
    ]
    private let audioEngine = AVAudioEngine()
    private let impactPlayer = AVAudioPlayerNode()
    private var audioFormat: AVAudioFormat?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        guard showAgeNotice() else {
            NSApp.terminate(nil)
            return
        }
        setupImpactAudio()
        buildWindow()
        buildScene()
    }

    private func showAgeNotice() -> Bool {
        let notice = NSAlert()
        notice.alertStyle = .warning
        notice.messageText = "16+ VIRTUAL SIMULATION NOTICE"
        notice.informativeText = "Smash Simulator is intended for users aged 16 and older. All effects are fictional simulations inside this app. Do not try to reproduce them on real devices or property. This is a self-confirmation prompt, not identity or age verification."
        notice.addButton(withTitle: "I confirm I am 16 or older")
        notice.addButton(withTitle: "Quit")
        return notice.runModal() == .alertFirstButtonReturn
    }

    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Smash Simulator"
        window.center()
        window.minSize = NSSize(width: 980, height: 660)
        window.acceptsMouseMovedEvents = true

        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.067, blue: 0.09, alpha: 1).cgColor
        window.contentView = root

        let sidebar = NSView()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = NSColor(calibratedRed: 0.085, green: 0.10, blue: 0.14, alpha: 1).cgColor
        root.addSubview(sidebar)

        let heading = NSTextField(labelWithString: "SMASH SIMULATOR")
        heading.font = .systemFont(ofSize: 17, weight: .black)
        heading.textColor = .white
        heading.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(heading)

        let subtitle = NSTextField(labelWithString: "VIRTUAL DESTRUCTION LAB")
        subtitle.font = .systemFont(ofSize: 9, weight: .bold)
        subtitle.textColor = NSColor(calibratedWhite: 0.58, alpha: 1)
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(subtitle)


        devicePopup = popup(["iPhone", "MacBook", "Desktop PC", "iPad"], selected: selectedDevice)
        toolPopup = popup(["Soft Tap", "Rubber Mallet", "Precision Hammer", "Heavy Hammer", "Wrench", "Impact Driver", "Energy Pulse"], selected: selectedTool)
        roomPopup = popup(["Studio", "Garage", "Concrete", "Bedroom", "Neon Lab"], selected: roomStyle)

        addSection("DEVICE", control: devicePopup, to: sidebar, top: subtitle, gap: 28)
        addSection("TOOL", control: toolPopup, to: sidebar, top: devicePopup, gap: 38)
        addSection("ROOM", control: roomPopup, to: sidebar, top: toolPopup, gap: 38)

        let damageTitle = NSTextField(labelWithString: "DAMAGE INTENSITY")
        damageTitle.font = .systemFont(ofSize: 10, weight: .bold)
        damageTitle.textColor = NSColor(calibratedWhite: 0.72, alpha: 1)
        damageTitle.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(damageTitle)
        damageSlider = NSSlider(value: Double(damageLevel), minValue: 0.1, maxValue: 1.0, target: self, action: #selector(damageChanged(_:)))
        damageSlider.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(damageSlider)

        let hit = makeButton("CENTER TEST HIT", action: #selector(strike))
        let drop = makeButton("DROP TEST", action: #selector(dropObject))
        let reset = makeButton("RESET SCENE", action: #selector(resetScene))
        sidebar.addSubview(hit); sidebar.addSubview(drop); sidebar.addSubview(reset)

        statusLabel = NSTextField(wrappingLabelWithString: "Move the mouse to aim the selected 3D tool. Click briefly or hold for a stronger arcade hit.")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = NSColor(calibratedWhite: 0.68, alpha: 1)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(statusLabel)

        sceneView = SmashSceneView()
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.scene = scene
        sceneView.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.20, alpha: 1)
        sceneView.allowsCameraControl = false
        sceneView.autoenablesDefaultLighting = false
        sceneView.antialiasingMode = .multisampling4X
        sceneView.preferredFramesPerSecond = 60
        sceneView.rendersContinuously = true
        sceneView.delegate = self
        sceneView.onPointerMove = { [weak self] point in self?.moveCursorTool(to: point) }
        sceneView.onPointerClick = { [weak self] point, held in self?.applyTool(at: point, heldFor: held) }
        sceneView.onOrbit = { [weak self] dx, dy in self?.orbitCamera(dx: dx, dy: dy) }
        sceneView.onZoom = { [weak self] delta in self?.zoomCamera(delta: delta) }
        root.addSubview(sceneView)

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: root.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 250),
            sceneView.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            sceneView.topAnchor.constraint(equalTo: root.topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            heading.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 20),
            heading.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 25),
            subtitle.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 4),
            damageTitle.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            damageTitle.topAnchor.constraint(equalTo: roomPopup.bottomAnchor, constant: 27),
            damageSlider.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            damageSlider.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -20),
            damageSlider.topAnchor.constraint(equalTo: damageTitle.bottomAnchor, constant: 8),
            hit.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            hit.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -20),
            hit.topAnchor.constraint(equalTo: damageSlider.bottomAnchor, constant: 22),
            drop.leadingAnchor.constraint(equalTo: hit.leadingAnchor),
            drop.trailingAnchor.constraint(equalTo: hit.trailingAnchor),
            drop.topAnchor.constraint(equalTo: hit.bottomAnchor, constant: 9),
            reset.leadingAnchor.constraint(equalTo: hit.leadingAnchor),
            reset.trailingAnchor.constraint(equalTo: hit.trailingAnchor),
            reset.topAnchor.constraint(equalTo: drop.bottomAnchor, constant: 9),
            statusLabel.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -18),
            statusLabel.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -22)
        ])

        devicePopup.target = self; devicePopup.action = #selector(deviceChanged(_:))
        toolPopup.target = self; toolPopup.action = #selector(toolChanged(_:))
        roomPopup.target = self; roomPopup.action = #selector(roomChanged(_:))
        window.makeKeyAndOrderFront(nil)
    }


    private func inspectObject(at point: NSPoint) {
        let hits = sceneView.hitTest(point, options: nil)
        guard let hit = hits.first else {
            statusLabel.stringValue = "Nothing selected. Click a device or room object to inspect it."
            return
        }

        let objectName = hit.node.name ?? hit.node.geometry?.name ?? "Scene object"
        statusLabel.stringValue = "Selected: \(objectName) — virtual scene inspection."
        let marker = SCNNode(geometry: SCNSphere(radius: 0.055))
        marker.name = "Selection marker"
        marker.geometry?.firstMaterial = SCNMaterial()
        let selectionColor = NSColor(calibratedRed: 0.12, green: 0.78, blue: 0.96, alpha: 1)
        marker.geometry?.firstMaterial?.diffuse.contents = selectionColor
        marker.geometry?.firstMaterial?.emission.contents = selectionColor
        marker.position = hit.worldCoordinates
        scene.rootNode.addChildNode(marker)
        marker.runAction(.sequence([
            .scale(to: 1.8, duration: 0.12),
            .wait(duration: 0.28),
            .fadeOut(duration: 0.16),
            .removeFromParentNode()
        ]))
    }

    private func buildCursorTool() {
        cursorToolNode?.removeFromParentNode()
        let tool = SCNNode()
        tool.name = "Cursor Tool — \(selectedTool)"
        let steel = material(NSColor(calibratedRed: 0.62, green: 0.68, blue: 0.74, alpha: 1), roughness: 0.24, metalness: 0.82)
        let grip = material(NSColor(calibratedRed: 0.13, green: 0.15, blue: 0.18, alpha: 1), roughness: 0.84)

        let handle = SCNNode(geometry: SCNCylinder(radius: 0.05, height: 0.62))
        handle.name = "Cursor Tool handle"
        handle.geometry?.firstMaterial = grip
        handle.position = SCNVector3(0, 0.23, 0)
        tool.addChildNode(handle)

        switch selectedTool {
        case "Wrench":
            let head = SCNNode(geometry: SCNTorus(ringRadius: 0.15, pipeRadius: 0.045))
            head.name = "Cursor Tool wrench head"
            head.geometry?.firstMaterial = steel
            head.position = SCNVector3(0, 0.55, 0)
            tool.addChildNode(head)
        case "Impact Driver":
            let body = SCNNode(geometry: SCNCylinder(radius: 0.105, height: 0.34))
            body.geometry?.firstMaterial = grip
            body.position = SCNVector3(0, 0.56, 0)
            tool.addChildNode(body)
            let bit = SCNNode(geometry: SCNCylinder(radius: 0.025, height: 0.22))
            bit.geometry?.firstMaterial = steel
            bit.position = SCNVector3(0, 0.83, 0)
            tool.addChildNode(bit)
        case "Energy Pulse":
            let orb = SCNNode(geometry: SCNSphere(radius: 0.18))
            orb.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.12, green: 0.72, blue: 0.98, alpha: 1), roughness: 0.12)
            orb.geometry?.firstMaterial?.emission.contents = NSColor(calibratedRed: 0.08, green: 0.32, blue: 0.9, alpha: 1)
            tool.addChildNode(orb)
        case "Rubber Mallet", "Soft Tap":
            let head = SCNNode(geometry: SCNBox(width: 0.48, height: 0.18, length: 0.18, chamferRadius: 0.06))
            head.geometry?.firstMaterial = selectedTool == "Soft Tap" ? grip : material(NSColor(calibratedRed: 0.18, green: 0.21, blue: 0.24, alpha: 1), roughness: 0.92)
            head.position = SCNVector3(0, 0.55, 0)
            tool.addChildNode(head)
        default:
            let head = SCNNode(geometry: SCNBox(width: selectedTool == "Heavy Hammer" ? 0.62 : 0.45,
                                                height: 0.20, length: 0.18, chamferRadius: 0.04))
            head.geometry?.firstMaterial = steel
            head.position = SCNVector3(0, 0.55, 0)
            tool.addChildNode(head)
        }

        tool.scale = SCNVector3(0.72, 0.72, 0.72)
        tool.position = SCNVector3(0, deskTopY + 1.2, 0)
        scene.rootNode.addChildNode(tool)
        cursorToolNode = tool
    }

    private func damageableOwner(for node: SCNNode) -> SCNNode? {
        var current: SCNNode? = node
        while let candidate = current {
            if candidate.userData?["damageKind"] as? String != nil { return candidate }
            current = candidate.parent
        }
        return nil
    }

    private func moveCursorTool(to point: NSPoint) {
        guard let cursorToolNode else { return }
        let hits = sceneView.hitTest(point, options: nil)
        if let hit = hits.first(where: { !($0.node.name ?? "").hasPrefix("Cursor Tool") }) {
            let normal = hit.worldNormal
            cursorToolNode.position = SCNVector3(
                hit.worldCoordinates.x + normal.x * 0.30,
                hit.worldCoordinates.y + normal.y * 0.30,
                hit.worldCoordinates.z + normal.z * 0.30
            )
        } else {
            let near = sceneView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
            let far = sceneView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
            let direction = SCNVector3(far.x - near.x, far.y - near.y, far.z - near.z)
            if abs(direction.y) > 0.0001 {
                let planeY = deskTopY + 0.85
                let t = (planeY - near.y) / direction.y
                if t >= 0 {
                    cursorToolNode.position = SCNVector3(
                        min(8.0, max(-8.0, near.x + direction.x * t)),
                        planeY,
                        min(7.6, max(-7.6, near.z + direction.z * t))
                    )
                }
            }
        }
    }

    private func animateToolImpact(intensity: Float) {
        guard let cursorToolNode else { return }
        cursorToolNode.removeAllActions()
        let wobble = min(0.42, 0.10 + Double(intensity) * 0.14)
        cursorToolNode.runAction(.sequence([
            .group([
                .moveBy(x: 0, y: -CGFloat(0.12 + intensity * 0.08), z: 0, duration: 0.045),
                .rotateBy(x: 0, y: 0, z: wobble, duration: 0.055)
            ]),
            .group([
                .moveBy(x: 0, y: CGFloat(0.12 + intensity * 0.08), z: 0, duration: 0.09),
                .rotateBy(x: 0, y: 0, z: -wobble * 0.78, duration: 0.10)
            ])
        ]))
    }

    private func applySelectedTool(at point: NSPoint, heldFor: TimeInterval) {
        let hits = sceneView.hitTest(point, options: nil)
        guard let hit = hits.first(where: { !($0.node.name ?? "").hasPrefix("Cursor Tool") }),
              let target = damageableOwner(for: hit.node),
              let kind = target.userData?["damageKind"] as? String else {
            statusLabel.stringValue = "Aim at the desk, device or a room prop and click."
            return
        }

        moveCursorTool(to: point)
        // Assumption: hold duration controls the arcade intensity; pointer velocity is ignored.
        let holdFactor = Float(min(1.0, max(0.0, heldFor / 0.85)))
        let clickIntensity = 0.38 + holdFactor * 0.82
        let intensity = (toolPower[selectedTool] ?? 1.0) * damageLevel * clickIntensity
        animateToolImpact(intensity: intensity)

        let worldPoint = hit.worldCoordinates
        let localPoint = hit.localCoordinates
        let localNormal = hit.localNormal
        let worldNormal = hit.worldNormal

        deformMesh(hit.node, around: localPoint, normal: localNormal,
                   radius: CGFloat(0.20 + intensity * 0.18),
                   depth: CGFloat(0.035 + intensity * 0.09))

        if let dynamicBody = nearestDynamicBody(from: hit.node) {
            let applicationPoint = dynamicBody.convertPosition(worldPoint, from: nil)
            let impulse = SCNVector3(
                worldNormal.x * intensity * 3.2,
                worldNormal.y * intensity * 3.2 + intensity * 0.45,
                worldNormal.z * intensity * 3.2
            )
            dynamicBody.physicsBody?.applyForce(impulse, at: applicationPoint, asImpulse: true)
        }

        addImpactFlash(at: worldPoint, normal: worldNormal, intensity: intensity)
        spawnArcadeDebris(at: worldPoint, normal: worldNormal, intensity: intensity, color: materialColor(of: hit.node))
        playImpactSound(intensity: intensity)

        if intensity > 1.02 {
            switch kind {
            case "devicePart":
                detachPart(hit.node, at: worldPoint, normal: worldNormal, intensity: intensity)
            case "desk":
                if intensity > 1.25 {
                    breakDesk(at: worldPoint, normal: worldNormal, intensity: intensity)
                }
            case "prop":
                if intensity > 1.38 {
                    detachPart(target, at: worldPoint, normal: worldNormal, intensity: intensity)
                }
            default:
                break
            }
        }

        let holdText = String(format: "%.2f", heldFor)
        let amountText = String(format: "%.2f", intensity)
        statusLabel.stringValue = "\(selectedTool) • \(kind) • hold \(holdText)s • arcade power \(amountText)"
    }

    private func nearestDynamicBody(from node: SCNNode) -> SCNNode? {
        var current: SCNNode? = node
        while let candidate = current {
            if candidate.physicsBody?.type == .dynamic { return candidate }
            current = candidate.parent
        }
        return nil
    }

    private func materialColor(of node: SCNNode) -> NSColor {
        if let color = node.geometry?.firstMaterial?.diffuse.contents as? NSColor { return color }
        return NSColor(calibratedRed: 0.34, green: 0.40, blue: 0.48, alpha: 1)
    }

    private func deformMesh(_ node: SCNNode, around point: SCNVector3, normal: SCNVector3,
                            radius: CGFloat, depth: CGFloat) {
        guard let geometry = node.geometry,
              let source = geometry.sources(for: .vertex).first,
              source.usesFloatComponents,
              source.bytesPerComponent == MemoryLayout<Float>.size,
              source.componentsPerVector >= 3 else { return }

        var data = source.data
        let stride = source.dataStride
        let offset = source.dataOffset
        data.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            let values = base.assumingMemoryBound(to: Float.self)
            for index in 0..<source.vectorCount {
                let start = (offset + index * stride) / MemoryLayout<Float>.size
                let dx = CGFloat(values[start] - point.x)
                let dy = CGFloat(values[start + 1] - point.y)
                let dz = CGFloat(values[start + 2] - point.z)
                let distance = sqrt(dx * dx + dy * dy + dz * dz)
                guard distance < radius else { continue }
                let falloff = 1.0 - distance / radius
                let centerWeight = falloff * falloff
                let amount = Float(depth * centerWeight)
                values[start] -= normal.x * amount
                values[start + 1] -= normal.y * amount
                values[start + 2] -= normal.z * amount
            }
        }

        let replacement = SCNGeometrySource(
            data: data,
            semantic: .vertex,
            vectorCount: source.vectorCount,
            usesFloatComponents: source.usesFloatComponents,
            componentsPerVector: source.componentsPerVector,
            bytesPerComponent: source.bytesPerComponent,
            dataOffset: source.dataOffset,
            dataStride: source.dataStride
        )
        let updatedSources = geometry.sources.map { $0 === source ? replacement : $0 }
        let updated = SCNGeometry(sources: updatedSources, elements: geometry.elements)
        updated.materials = geometry.materials
        node.geometry = updated
    }

    private func addImpactFlash(at point: SCNVector3, normal: SCNVector3, intensity: Float) {
        let marker = SCNNode(geometry: SCNSphere(radius: CGFloat(0.055 + intensity * 0.025)))
        marker.name = "Arcade impact flash"
        let flashColor = NSColor(calibratedRed: 1.0, green: 0.48 + CGFloat(min(0.4, intensity * 0.1)), blue: 0.16, alpha: 1)
        marker.geometry?.firstMaterial = material(flashColor, roughness: 0.25)
        marker.geometry?.firstMaterial?.emission.contents = flashColor
        marker.position = SCNVector3(point.x + normal.x * 0.045, point.y + normal.y * 0.045, point.z + normal.z * 0.045)
        scene.rootNode.addChildNode(marker)
        marker.runAction(.sequence([
            .scale(to: 1.9, duration: 0.07),
            .fadeOut(duration: 0.18),
            .removeFromParentNode()
        ]))
    }

    private func spawnArcadeDebris(at point: SCNVector3, normal: SCNVector3, intensity: Float, color: NSColor) {
        let count = min(8, max(2, Int(intensity * 3.5)))
        for _ in 0..<count {
            let size = CGFloat.random(in: 0.035...0.10)
            let chip = SCNNode(geometry: SCNBox(width: size, height: size * 0.55, length: size * 1.7, chamferRadius: 0.008))
            chip.name = "Arcade debris"
            chip.geometry?.firstMaterial = material(color.blended(withFraction: 0.25, of: .white) ?? color, roughness: 0.48)
            chip.position = point
            configureDebris(chip, mass: 0.025 + CGFloat(intensity) * 0.012)
            scene.rootNode.addChildNode(chip)
            let random = SCNVector3(Float.random(in: -1...1), Float.random(in: 0.2...1.2), Float.random(in: -1...1))
            chip.physicsBody?.applyForce(SCNVector3(
                (normal.x * 0.65 + random.x * 0.8) * intensity * 2.0,
                (normal.y * 0.65 + random.y * 0.8) * intensity * 2.0,
                (normal.z * 0.65 + random.z * 0.8) * intensity * 2.0
            ), asImpulse: true)
            chip.physicsBody?.applyTorque(SCNVector4(random.x, random.y, random.z, Float.random(in: 0.8...2.8)), asImpulse: true)
        }
    }

    private func detachPart(_ node: SCNNode, at point: SCNVector3, normal: SCNVector3, intensity: Float) {
        guard node.parent != nil, node.geometry != nil else { return }
        let bounds = node.boundingBox
        let span = SCNVector3(max(0.12, bounds.max.x - bounds.min.x),
                              max(0.12, bounds.max.y - bounds.min.y),
                              max(0.12, bounds.max.z - bounds.min.z))
        let color = materialColor(of: node)
        node.removeFromParentNode()

        // The clicked point anchors the fragment cluster; the count scales with arcade power.
        let columns = 2
        let rows = 2
        for column in 0..<columns {
            for row in 0..<rows {
                let shard = SCNNode(geometry: SCNBox(
                    width: CGFloat(span.x / 2.2 * Float.random(in: 0.72...1.10)),
                    height: CGFloat(span.y / 2.0 * Float.random(in: 0.72...1.10)),
                    length: CGFloat(span.z / 2.2 * Float.random(in: 0.72...1.10)),
                    chamferRadius: 0.012
                ))
                shard.name = "Detached arcade fragment"
                shard.geometry?.firstMaterial = material(color, roughness: 0.55, metalness: 0.35)
                shard.position = SCNVector3(
                    point.x + (Float(column) - 0.5) * span.x * 0.22 + Float.random(in: -0.05...0.05),
                    point.y + (Float(row) - 0.5) * span.y * 0.22 + Float.random(in: -0.05...0.05),
                    point.z + Float.random(in: -0.07...0.07)
                )
                configureDebris(shard, mass: 0.10 + CGFloat(intensity) * 0.025)
                scene.rootNode.addChildNode(shard)
                let random = SCNVector3(Float.random(in: -1...1), Float.random(in: 0.25...1.2), Float.random(in: -1...1))
                shard.physicsBody?.applyForce(SCNVector3(
                    (normal.x + random.x * 0.75) * intensity * 2.8,
                    (normal.y + random.y * 0.8) * intensity * 2.8,
                    (normal.z + random.z * 0.75) * intensity * 2.8
                ), asImpulse: true)
                shard.physicsBody?.applyTorque(SCNVector4(random.x, random.y, random.z, Float.random(in: 1.0...3.5)), asImpulse: true)
            }
        }
    }

    private func breakDesk(at point: SCNVector3, normal: SCNVector3, intensity: Float) {
        guard let desk = scene.rootNode.childNodes.first(where: { $0.name == "Workbench desk top" }) else { return }
        let origin = desk.presentation.worldPosition
        desk.removeFromParentNode()
        for row in 0..<3 {
            for column in 0..<4 {
                let plank = SCNNode(geometry: SCNBox(width: 1.85, height: 0.20, length: 1.47, chamferRadius: 0.025))
                plank.name = "Detached workbench plank"
                plank.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.31, green: 0.20, blue: 0.13, alpha: 1), roughness: 0.82)
                plank.position = SCNVector3(origin.x + (Float(column) - 1.5) * 1.9,
                                             origin.y + Float.random(in: -0.03...0.06),
                                             origin.z + (Float(row) - 1) * 1.50)
                configureDebris(plank, mass: 0.65)
                scene.rootNode.addChildNode(plank)
                let away = SCNVector3(plank.position.x - point.x, 0, plank.position.z - point.z)
                plank.physicsBody?.applyForce(SCNVector3(
                    away.x * 0.8 + normal.x * intensity,
                    intensity * 0.75,
                    away.z * 0.8 + normal.z * intensity
                ), asImpulse: true)
                plank.physicsBody?.applyTorque(SCNVector4(Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: -1...1), 2.2), asImpulse: true)
            }
        }
    }

    private func configureDebris(_ node: SCNNode, mass: CGFloat) {
        guard let geometry = node.geometry else { return }
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: geometry, options: nil))
        node.physicsBody?.mass = mass
        node.physicsBody?.friction = 0.68
        node.physicsBody?.restitution = 0.28
        node.physicsBody?.linearDamping = 0.05
        node.physicsBody?.angularDamping = 0.12
        node.physicsBody?.collisionBitMask = -1
        node.physicsBody?.contactTestBitMask = -1
        if node.userData == nil { node.userData = NSMutableDictionary() }
        node.userData?["debrisBorn"] = CACurrentMediaTime()
        debrisCount += 1
    }

    private func orbitCamera(dx: CGFloat, dy: CGFloat) {
        cameraYaw = min(0.78, max(-0.78, cameraYaw - Float(dx) * 0.004))
        cameraPitch = min(0.52, max(0.10, cameraPitch + Float(dy) * 0.003))
        updateCamera()
    }

    private func zoomCamera(delta: CGFloat) {
        cameraDistance = min(12.2, max(7.6, cameraDistance - Float(delta) * 0.012))
        updateCamera()
    }

    private func updateCamera() {
        guard let cameraNode else { return }
        let target = SCNVector3(0, 1.38, 0)
        let horizontal = cameraDistance * cos(cameraPitch)
        cameraNode.position = SCNVector3(sin(cameraYaw) * horizontal,
                                         target.y + sin(cameraPitch) * cameraDistance,
                                         cos(cameraYaw) * horizontal)
        cameraNode.look(at: target)
    }

    private func setupImpactAudio() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        audioFormat = format
        audioEngine.attach(impactPlayer)
        audioEngine.connect(impactPlayer, to: audioEngine.mainMixerNode, format: format)
        do {
            try audioEngine.start()
            impactPlayer.play()
        } catch {
            // If audio is unavailable, all visual gameplay still works.
        }
    }

    private func playImpactSound(intensity: Float) {
        guard let format = audioFormat,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8820),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = 8820
        let level = min(1.6, max(0.18, Double(intensity)))
        let frequency = 88.0 + level * 62.0
        for index in 0..<Int(buffer.frameLength) {
            let time = Double(index) / format.sampleRate
            let envelope = exp(-time * (13.0 - min(3.0, level)))
            let fundamental = sin(2.0 * Double.pi * frequency * time)
            let overtone = sin(2.0 * Double.pi * frequency * 2.45 * time) * 0.23
            let noise = Double.random(in: -1.0...1.0) * 0.10
            channel[index] = Float((fundamental * 0.68 + overtone + noise) * envelope * (0.16 + level * 0.18))
        }
        impactPlayer.scheduleBuffer(buffer, completionHandler: nil)
    }

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let now = CACurrentMediaTime()
        guard now - lastImpactSoundTime > 0.10, contact.collisionImpulse > 0.45 else { return }
        lastImpactSoundTime = now
        playImpactSound(intensity: Float(min(1.8, contact.collisionImpulse / 7.0)))
    }

    func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
        let now = CACurrentMediaTime()
        let expired = scene.rootNode.childNodes.filter { node in
            guard let born = node.userData?["debrisBorn"] as? Double else { return false }
            return now - born > 11 || node.presentation.worldPosition.y < -2
        }
        for node in expired {
            node.removeFromParentNode()
            debrisCount = max(0, debrisCount - 1)
        }
    }

    private func popup(_ items: [String], selected: String) -> NSPopUpButton {
        let p = NSPopUpButton()
        p.addItems(withTitles: items)
        p.selectItem(withTitle: selected)
        p.translatesAutoresizingMaskIntoConstraints = false
        return p
    }

    private func addSection(_ title: String, control: NSPopUpButton, to parent: NSView, top: NSView, gap: CGFloat) {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = NSColor(calibratedWhite: 0.72, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(label)
        parent.addSubview(control)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: 20),
            label.topAnchor.constraint(equalTo: top.bottomAnchor, constant: gap),
            control.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            control.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -20),
            control.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 7)
        ])
    }

    private func makeButton(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.font = .systemFont(ofSize: 11, weight: .bold)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return b
    }

    private func buildScene() {
        scene = SCNScene()
        scene.physicsWorld.gravity = SCNVector3(0, -9.8, 0)
        scene.physicsWorld.contactDelegate = self
        sceneView.scene = scene

        let camera = SCNNode()
        camera.camera = SCNCamera()
        cameraNode = camera
        scene.rootNode.addChildNode(camera)
        updateCamera()
        sceneView.pointOfView = camera

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 480
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .omni
        key.light?.intensity = 1100
        key.position = SCNVector3(-3, 6, 5)
        scene.rootNode.addChildNode(key)

        makeRoom()
        makeDesk()
        makeDevice()
        buildCursorTool()
    }

    private func tag(_ node: SCNNode, kind: String) {
        if node.userData == nil { node.userData = NSMutableDictionary() }
        node.userData?["damageKind"] = kind
    }

    private func tagSubtree(_ node: SCNNode, kind: String) {
        tag(node, kind: kind)
        for child in node.childNodes { tagSubtree(child, kind: kind) }
    }

    private func makeRoom() {
        let floorGeometry = SCNBox(width: 20, height: 0.22, length: 18, chamferRadius: 0)
        floorGeometry.widthSegmentCount = 12
        floorGeometry.lengthSegmentCount = 12
        floorGeometry.firstMaterial = material(roomColor(), roughness: 0.88)
        let floor = SCNNode(geometry: floorGeometry)
        floor.name = "Room floor"
        floor.position = SCNVector3(0, -0.14, 0)
        floor.physicsBody = SCNPhysicsBody.static()
        tag(floor, kind: "floor")
        scene.rootNode.addChildNode(floor)

        // All four walls and the ceiling are solid static colliders.
        let wallMaterial = material(wallColor(), roughness: 0.94)
        let bounds: [(String, SCNVector3, SCNVector3)] = [
            ("Back wall", SCNVector3(0, 3.4, -8.9), SCNVector3(20, 7, 0.22)),
            ("Front wall", SCNVector3(0, 3.4, 8.9), SCNVector3(20, 7, 0.22)),
            ("Left wall", SCNVector3(-9.9, 3.4, 0), SCNVector3(0.22, 7, 18)),
            ("Right wall", SCNVector3(9.9, 3.4, 0), SCNVector3(0.22, 7, 18)),
            ("Ceiling", SCNVector3(0, 6.95, 0), SCNVector3(20, 0.18, 18))
        ]
        for (name, position, size) in bounds {
            let geometry = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: 0)
            geometry.firstMaterial = wallMaterial
            let wall = SCNNode(geometry: geometry)
            wall.name = name
            wall.position = position
            wall.physicsBody = SCNPhysicsBody.static()
            tag(wall, kind: "wall")
            scene.rootNode.addChildNode(wall)
        }

        // Ribbed acoustic panels and ceiling strips make the room read as an enclosed workshop.
        for index in 0..<8 {
            let panel = SCNNode(geometry: SCNBox(width: 1.8, height: 1.15, length: 0.07, chamferRadius: 0.035))
            panel.name = "Acoustic wall panel"
            panel.position = SCNVector3(-6.3 + Float(index) * 1.8, 3.65, -8.75)
            panel.geometry?.firstMaterial = material(NSColor(calibratedWhite: 0.13 + CGFloat(index % 3) * 0.035, alpha: 1), roughness: 0.93)
            panel.physicsBody = SCNPhysicsBody.static()
            scene.rootNode.addChildNode(panel)
        }

        let accent = NSColor(calibratedRed: 0.10, green: 0.70, blue: 0.98, alpha: 1)
        for y: Float in [5.85, 6.15] {
            let strip = SCNNode(geometry: SCNBox(width: 14.5, height: 0.035, length: 0.05, chamferRadius: 0))
            strip.name = "Room LED strip"
            strip.position = SCNVector3(0, y, -8.72)
            strip.geometry?.firstMaterial = material(accent, roughness: 0.28)
            strip.geometry?.firstMaterial?.emission.contents = accent
            strip.physicsBody = nil
            scene.rootNode.addChildNode(strip)
        }

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .omni
        key.light?.intensity = 1050
        key.position = SCNVector3(-3.5, 5.7, 4)
        scene.rootNode.addChildNode(key)
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .omni
        fill.light?.intensity = 560
        fill.position = SCNVector3(4, 4.8, -4)
        scene.rootNode.addChildNode(fill)
    }

    private func makeDesk() {
        let wood = NSColor(calibratedRed: 0.30, green: 0.20, blue: 0.13, alpha: 1)
        let steel = NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.18, alpha: 1)

        let topGeometry = SCNBox(width: 7.6, height: 0.22, length: 4.5, chamferRadius: 0.065)
        topGeometry.widthSegmentCount = 12
        topGeometry.heightSegmentCount = 5
        topGeometry.lengthSegmentCount = 10
        topGeometry.firstMaterial = material(wood, roughness: 0.84)
        let top = SCNNode(geometry: topGeometry)
        top.name = "Workbench desk top"
        top.position = SCNVector3(0, deskTopY, 0)
        top.physicsBody = SCNPhysicsBody.static()
        tag(top, kind: "desk")
        scene.rootNode.addChildNode(top)

        for x: Float in [-3.35, 3.35] {
            for z: Float in [-1.88, 1.88] {
                let leg = SCNNode(geometry: SCNBox(width: 0.18, height: 1.25, length: 0.18, chamferRadius: 0.025))
                leg.name = "Workbench leg"
                leg.position = SCNVector3(x, 0.61, z)
                leg.geometry?.firstMaterial = material(steel, roughness: 0.46, metalness: 0.62)
                leg.physicsBody = SCNPhysicsBody.static()
                tag(leg, kind: "prop")
                scene.rootNode.addChildNode(leg)
            }
        }

        let apron = SCNNode(geometry: SCNBox(width: 6.8, height: 0.28, length: 0.14, chamferRadius: 0.025))
        apron.name = "Desk apron"
        apron.position = SCNVector3(0, 0.98, 1.9)
        apron.geometry?.firstMaterial = material(steel, roughness: 0.52, metalness: 0.5)
        apron.physicsBody = SCNPhysicsBody.static()
        tag(apron, kind: "prop")
        scene.rootNode.addChildNode(apron)

        let drawer = SCNNode(geometry: SCNBox(width: 2.0, height: 0.34, length: 1.15, chamferRadius: 0.035))
        drawer.name = "Desk drawer"
        drawer.position = SCNVector3(0, 1.02, -0.45)
        drawer.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.19, green: 0.13, blue: 0.09, alpha: 1), roughness: 0.78)
        drawer.physicsBody = SCNPhysicsBody.static()
        tag(drawer, kind: "prop")
        scene.rootNode.addChildNode(drawer)

        let pull = SCNNode(geometry: SCNCylinder(radius: 0.035, height: 0.42))
        pull.name = "Drawer handle"
        pull.position = SCNVector3(0, 1.03, 0.14)
        pull.eulerAngles.z = .pi / 2
        pull.geometry?.firstMaterial = material(NSColor(calibratedWhite: 0.64, alpha: 1), roughness: 0.25, metalness: 0.82)
        scene.rootNode.addChildNode(pull)

        let tray = SCNNode(geometry: SCNBox(width: 1.4, height: 0.10, length: 0.85, chamferRadius: 0.025))
        tray.name = "Metal parts tray"
        tray.position = SCNVector3(2.75, deskTopY + 0.16, -1.42)
        tray.geometry?.firstMaterial = material(NSColor(calibratedWhite: 0.26, alpha: 1), roughness: 0.34, metalness: 0.72)
        tray.physicsBody = SCNPhysicsBody.static()
        tag(tray, kind: "prop")
        scene.rootNode.addChildNode(tray)

        let organizer = SCNNode(geometry: SCNBox(width: 0.85, height: 0.28, length: 0.55, chamferRadius: 0.04))
        organizer.name = "Parts organizer"
        organizer.position = SCNVector3(-2.85, deskTopY + 0.22, -1.50)
        organizer.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.20, alpha: 1), roughness: 0.62)
        organizer.physicsBody = SCNPhysicsBody.static()
        tag(organizer, kind: "prop")
        scene.rootNode.addChildNode(organizer)

        let riser = SCNNode(geometry: SCNBox(width: 6.9, height: 0.10, length: 0.35, chamferRadius: 0.025))
        riser.name = "Workbench rear riser"
        riser.position = SCNVector3(0, deskTopY + 0.36, -2.03)
        riser.geometry?.firstMaterial = material(steel, roughness: 0.55, metalness: 0.42)
        riser.physicsBody = SCNPhysicsBody.static()
        scene.rootNode.addChildNode(riser)
    }

    private func roomColor() -> NSColor {
        switch roomStyle {
        case "Garage": return NSColor(calibratedRed: 0.25, green: 0.27, blue: 0.29, alpha: 1)
        case "Concrete": return NSColor(calibratedRed: 0.38, green: 0.39, blue: 0.40, alpha: 1)
        case "Bedroom": return NSColor(calibratedRed: 0.30, green: 0.24, blue: 0.29, alpha: 1)
        case "Neon Lab": return NSColor(calibratedRed: 0.07, green: 0.10, blue: 0.18, alpha: 1)
        default: return NSColor(calibratedRed: 0.20, green: 0.23, blue: 0.27, alpha: 1)
        }
    }

    private func wallColor() -> NSColor {
        roomStyle == "Neon Lab" ? NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.25, alpha: 1) : roomColor().blended(withFraction: 0.25, of: .black) ?? roomColor()
    }

    private func material(_ color: NSColor, roughness: CGFloat, metalness: CGFloat = 0.12) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.roughness.contents = roughness
        m.metalness.contents = metalness
        return m
    }

    private func makeDevice() {
        deviceRoot?.removeFromParentNode()
        let root = SCNNode()
        let dark = material(NSColor(calibratedWhite: 0.075, alpha: 1), roughness: 0.24)
        let metal = material(NSColor(calibratedWhite: 0.48, alpha: 1), roughness: 0.28)
        let glass = material(NSColor(calibratedRed: 0.025, green: 0.045, blue: 0.075, alpha: 1), roughness: 0.08)

        func box(_ w: CGFloat, _ h: CGFloat, _ d: CGFloat, _ mat: SCNMaterial, _ pos: SCNVector3, _ chamfer: CGFloat = 0.08) -> SCNNode {
            let n = SCNNode(geometry: SCNBox(width: w, height: h, length: d, chamferRadius: chamfer))
            n.geometry?.firstMaterial = mat
            n.position = pos
            return n
        }

        switch selectedDevice {
        case "MacBook":
            root.addChildNode(box(3.0, 0.16, 2.0, metal, SCNVector3(0, 0.12, 0)))
            root.addChildNode(box(2.88, 0.035, 1.88, dark, SCNVector3(0, 0.215, 0)))
            let display = box(2.85, 1.85, 0.12, metal, SCNVector3(0, 1.12, -0.90))
            display.eulerAngles.x = -0.10
            root.addChildNode(display)
            let screen = box(2.64, 1.62, 0.025, glass, SCNVector3(0, 1.13, -0.825))
            screen.eulerAngles.x = -0.10
            root.addChildNode(screen)
            for row in 0..<4 { for col in 0..<12 {
                root.addChildNode(box(0.16, 0.018, 0.12, metal, SCNVector3(-1.25 + Float(col) * 0.23, 0.245, -0.62 + Float(row) * 0.18), 0.025))
            }}
        case "Desktop PC":
            root.addChildNode(box(3.0, 1.85, 0.16, metal, SCNVector3(0, 1.25, -0.25)))
            root.addChildNode(box(2.78, 1.62, 0.035, glass, SCNVector3(0, 1.25, -0.145)))
            root.addChildNode(box(0.24, 0.85, 0.24, metal, SCNVector3(0, 0.48, -0.25)))
            root.addChildNode(box(1.25, 0.12, 0.65, metal, SCNVector3(0, 0.12, -0.25)))
            root.addChildNode(box(0.82, 1.65, 0.8, dark, SCNVector3(2.05, 0.85, 0.1)))
            root.addChildNode(box(0.68, 1.48, 0.03, glass, SCNVector3(2.05, 0.85, 0.515)))
        case "iPad":
            root.addChildNode(box(2.25, 0.12, 3.0, metal, SCNVector3(0, 0.22, 0)))
            root.addChildNode(box(2.08, 0.035, 2.78, glass, SCNVector3(0, 0.30, 0)))
        default:
            root.addChildNode(box(1.25, 0.16, 2.45, metal, SCNVector3(0, 0.18, 0), 0.14))
            root.addChildNode(box(1.12, 0.035, 2.28, glass, SCNVector3(0, 0.28, 0), 0.12))
            let speaker = SCNNode(geometry: SCNCylinder(radius: 0.045, height: 0.012))
            speaker.geometry?.firstMaterial = metal
            speaker.position = SCNVector3(0, 0.305, 1.02)
            root.addChildNode(speaker)
        }

        for child in root.childNodes {
            tagSubtree(child, kind: "devicePart")
        }
        root.position = SCNVector3(0, deskTopY + 0.18, 0)
        root.name = selectedDevice
        let collisionSize: SCNVector3 = selectedDevice == "MacBook" ? SCNVector3(3.0, 2.0, 2.0) : (selectedDevice == "Desktop PC" ? SCNVector3(3.0, 2.0, 1.0) : (selectedDevice == "iPad" ? SCNVector3(2.3, 0.35, 3.0) : SCNVector3(1.3, 0.45, 2.5)))
        let collisionGeometry = SCNBox(width: CGFloat(collisionSize.x), height: CGFloat(collisionSize.y), length: CGFloat(collisionSize.z), chamferRadius: 0.05)
        root.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: collisionGeometry, options: nil))
        root.physicsBody?.mass = selectedDevice == "Desktop PC" ? 9 : 2.2
        root.physicsBody?.friction = 0.78
        root.physicsBody?.restitution = 0.12
        root.physicsBody?.angularDamping = 0.42
        root.physicsBody?.categoryBitMask = 1
        root.physicsBody?.collisionBitMask = -1
        root.physicsBody?.contactTestBitMask = -1
        scene.rootNode.addChildNode(root)
        deviceRoot = root
    }

    @objc private func deviceChanged(_ sender: NSPopUpButton) {
        selectedDevice = sender.titleOfSelectedItem ?? "iPhone"
        makeDevice()
        statusLabel.stringValue = "Loaded virtual \(selectedDevice)."
    }

    @objc private func toolChanged(_ sender: NSPopUpButton) {
        selectedTool = sender.titleOfSelectedItem ?? "Precision Hammer"
        buildCursorTool()
        statusLabel.stringValue = "Selected \(selectedTool). Move the mouse and click; longer holds make stronger arcade hits."
    }

    @objc private func roomChanged(_ sender: NSPopUpButton) {
        roomStyle = sender.titleOfSelectedItem ?? "Studio"
        buildScene()
        statusLabel.stringValue = "Room changed to \(roomStyle)."
    }

    @objc private func damageChanged(_ sender: NSSlider) { damageLevel = Float(sender.floatValue) }

    @objc private func strike() {
        guard let target = deviceRoot, let body = target.physicsBody else { return }
        let force = CGFloat(18 + 72 * damageLevel)
        switch selectedTool {
        case "Wrecking Ball":
            let ball = SCNNode(geometry: SCNSphere(radius: 0.48))
            ball.geometry?.firstMaterial = material(NSColor(calibratedWhite: 0.22, alpha: 1), roughness: 0.22)
            ball.position = SCNVector3(-2.8, 2.5, 1.4)
            ball.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
            ball.physicsBody?.mass = 12
            scene.rootNode.addChildNode(ball)
            ball.physicsBody?.applyForce(SCNVector3(28, -7, -12), asImpulse: true)
        case "Drop Test":
            target.position = SCNVector3(0, 4.5, 0)
            body.velocity = SCNVector3Zero
            body.angularVelocity = SCNVector4Zero
        case "Kick":
            body.applyForce(SCNVector3(0, 2, -Float(force)), asImpulse: true)
            body.applyTorque(SCNVector4(7, 2, 1, 5), asImpulse: true)
        default:
            body.applyForce(SCNVector3(0, Float(force) * 0.48, -Float(force)), asImpulse: true)
            body.applyTorque(SCNVector4(2, 1, 0, CGFloat(force) * 0.035), asImpulse: true)
        }
        addImpactMark()
        statusLabel.stringValue = "\(selectedTool) applied — simulated physics and cosmetic impact effects."
    }

    private func addImpactMark() {
        guard let target = deviceRoot else { return }
        let crack = SCNNode(geometry: SCNCylinder(radius: CGFloat(0.025 + damageLevel * 0.055), height: 0.012))
        crack.geometry?.firstMaterial = material(NSColor(calibratedWhite: 0.78, alpha: 1), roughness: 0.2)
        crack.position = SCNVector3(Float.random(in: -0.35...0.35), 0.36, 0.12)
        crack.eulerAngles.x = .pi / 2
        target.addChildNode(crack)
    }

    @objc private func dropObject() {
        guard let target = deviceRoot else { return }
        target.position = SCNVector3(0, deskTopY + 4.0, 0)
        target.physicsBody?.velocity = SCNVector3Zero
        target.physicsBody?.angularVelocity = SCNVector4Zero
        target.physicsBody?.applyForce(SCNVector3(Float.random(in: -3...3), 0, Float.random(in: -2...2)), asImpulse: true)
        statusLabel.stringValue = "Drop test started. The object will fall onto the room floor."
    }

    @objc private func resetScene() {
        buildScene()
        statusLabel.stringValue = "Scene reset. The workbench, room and device have been restored."
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = SmashSimulator()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
