import AppKit
import SceneKit
import QuartzCore

final class SmashSceneView: SCNView {
    var pointerMoved: ((NSPoint) -> Void)?
    var pointerPressed: ((NSPoint) -> Void)?
    var pointerDragged: ((NSPoint) -> Void)?
    private var pointerTracking: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        if let pointerTracking { removeTrackingArea(pointerTracking) }
        let tracking = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseDragged, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(tracking)
        pointerTracking = tracking
        super.updateTrackingAreas()
    }

    private func localPoint(_ event: NSEvent) -> NSPoint {
        convert(event.locationInWindow, from: nil)
    }

    override func mouseMoved(with event: NSEvent) {
        pointerMoved?(localPoint(event))
        super.mouseMoved(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        pointerPressed?(localPoint(event))
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        pointerMoved?(localPoint(event))
        pointerDragged?(localPoint(event))
        super.mouseDragged(with: event)
    }
}

final class SmashSimulator: NSObject, NSApplicationDelegate, SCNSceneRendererDelegate {
    private var window: NSWindow!
    private var sceneView: SmashSceneView!
    private var scene = SCNScene()
    private var deviceRoot: SCNNode?
    private var cursorTool: SCNNode?
    private var selectedTool = "Precision Hammer"
    private var selectedDevice = "iPhone 16 Pro"
    private var roomStyle = "Creator Studio"
    private var impactPower: Float = 0.72
    private var screenMaterials: [SCNMaterial] = []
    private var statusLabel: NSTextField!
    private var devicePopup: NSPopUpButton!
    private var toolPopup: NSPopUpButton!
    private var roomPopup: NSPopUpButton!
    private var impactSlider: NSSlider!
    private var lastDragStrike = 0.0
    private var debrisCount = 0

    private let deskHeight: Float = 1.55
    private let toolPlaneHeight: Float = 2.02

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        buildScene()
        Timer.scheduledTimer(withTimeInterval: 0.22, repeats: true) { [weak self] _ in
            self?.refreshScreenTextures()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Smash Simulator — C0oled Lab"
        window.center()
        window.minSize = NSSize(width: 1100, height: 720)
        window.acceptsMouseMovedEvents = true

        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedRed: 0.035, green: 0.045, blue: 0.065, alpha: 1).cgColor
        window.contentView = root

        let sidebar = NSView()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.07, blue: 0.095, alpha: 1).cgColor
        root.addSubview(sidebar)

        let heading = NSTextField(labelWithString: "SMASH / LAB")
        heading.font = .systemFont(ofSize: 22, weight: .black)
        heading.textColor = NSColor(calibratedWhite: 0.96, alpha: 1)
        heading.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(heading)

        let subtitle = NSTextField(labelWithString: "COOLED INTERACTIVE DAMAGE SANDBOX")
        subtitle.font = .monospacedSystemFont(ofSize: 8, weight: .bold)
        subtitle.textColor = NSColor(calibratedRed: 0.35, green: 0.78, blue: 0.98, alpha: 1)
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(subtitle)

        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor(calibratedWhite: 0.24, alpha: 1).cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(divider)

        devicePopup = makePopup([
            "iPhone 16 Pro", "iPhone 16 Pro Max", "iPad Pro", "MacBook Pro 16",
            "MacBook Air", "Gaming PC", "Desktop Tower + Monitor"
        ])
        toolPopup = makePopup([
            "Precision Hammer", "Rubber Mallet", "Heavy Hammer", "Wrench",
            "Screwdriver", "Hydraulic Press", "Impact Pulse", "Drop Test"
        ])
        roomPopup = makePopup([
            "Creator Studio", "Workshop", "Night Lab", "Concrete Room", "Bedroom"
        ])

        let deviceSection = makeSection("OBJECT / DEVICE", control: devicePopup)
        let toolSection = makeSection("ACTIVE TOOL", control: toolPopup)
        let roomSection = makeSection("ENVIRONMENT", control: roomPopup)

        let impactTitle = NSTextField(labelWithString: "IMPACT STRENGTH")
        impactTitle.font = .systemFont(ofSize: 10, weight: .bold)
        impactTitle.textColor = NSColor(calibratedWhite: 0.73, alpha: 1)
        impactTitle.translatesAutoresizingMaskIntoConstraints = false
        impactSlider = NSSlider(value: Double(impactPower), minValue: 0.15, maxValue: 1.0, target: self, action: #selector(impactChanged(_:)))
        impactSlider.translatesAutoresizingMaskIntoConstraints = false
        impactSlider.controlSize = .regular
        sidebar.addSubview(impactTitle)
        sidebar.addSubview(impactSlider)

        let actionRow = NSStackView()
        actionRow.orientation = .horizontal
        actionRow.distribution = .fillEqually
        actionRow.spacing = 8
        actionRow.translatesAutoresizingMaskIntoConstraints = false
        actionRow.addArrangedSubview(makeButton("RESET ROOM", action: #selector(resetScene)))
        actionRow.addArrangedSubview(makeButton("DROP OBJECT", action: #selector(dropObject)))
        sidebar.addSubview(actionRow)

        let hint = NSTextField(wrappingLabelWithString: "MOVE YOUR MOUSE OVER THE BENCH. CLICK OR DRAG TO USE THE SELECTED TOOL. ORBIT AND ZOOM WITH SCENEKIT CAMERA CONTROLS.")
        hint.font = .monospacedSystemFont(ofSize: 9, weight: .medium)
        hint.textColor = NSColor(calibratedWhite: 0.62, alpha: 1)
        hint.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(hint)

        let madeBy = NSTextField(labelWithString: "MADE BY C0OLED  •  BUILD 1.2")
        madeBy.font = .monospacedSystemFont(ofSize: 9, weight: .bold)
        madeBy.textColor = NSColor(calibratedRed: 0.35, green: 0.78, blue: 0.98, alpha: 1)
        madeBy.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(madeBy)

        statusLabel = NSTextField(wrappingLabelWithString: "Ready. The pointer is your tool.")
        statusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = NSColor(calibratedWhite: 0.84, alpha: 1)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(statusLabel)

        sceneView = SmashSceneView()
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.backgroundColor = NSColor(calibratedRed: 0.075, green: 0.095, blue: 0.13, alpha: 1)
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = false
        sceneView.antialiasingMode = .multisampling4X
        sceneView.preferredFramesPerSecond = 60
        sceneView.rendersContinuously = true
        sceneView.delegate = self
        sceneView.pointerMoved = { [weak self] point in self?.moveCursorTool(to: point) }
        sceneView.pointerPressed = { [weak self] point in self?.useSelectedTool(at: point) }
        sceneView.pointerDragged = { [weak self] point in self?.dragTool(at: point) }
        root.addSubview(sceneView)

        let hud = NSTextField(labelWithString: "LIVE BENCH  /  RIGID-BODY PHYSICS  /  SCREEN SIGNAL ACTIVE")
        hud.font = .monospacedSystemFont(ofSize: 10, weight: .bold)
        hud.textColor = NSColor(calibratedWhite: 0.92, alpha: 1)
        hud.backgroundColor = NSColor(calibratedRed: 0.03, green: 0.045, blue: 0.07, alpha: 0.82)
        hud.drawsBackground = true
        hud.wantsLayer = true
        hud.layer?.cornerRadius = 7
        hud.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(hud)

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: root.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 292),
            sceneView.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            sceneView.topAnchor.constraint(equalTo: root.topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            heading.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 22),
            heading.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -18),
            heading.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 27),
            subtitle.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 5),
            divider.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -20),
            divider.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 21),
            divider.heightAnchor.constraint(equalToConstant: 1),
            deviceSection.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            deviceSection.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -20),
            deviceSection.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 21),
            toolSection.leadingAnchor.constraint(equalTo: deviceSection.leadingAnchor),
            toolSection.trailingAnchor.constraint(equalTo: deviceSection.trailingAnchor),
            toolSection.topAnchor.constraint(equalTo: deviceSection.bottomAnchor, constant: 17),
            roomSection.leadingAnchor.constraint(equalTo: deviceSection.leadingAnchor),
            roomSection.trailingAnchor.constraint(equalTo: deviceSection.trailingAnchor),
            roomSection.topAnchor.constraint(equalTo: toolSection.bottomAnchor, constant: 17),
            impactTitle.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            impactTitle.topAnchor.constraint(equalTo: roomSection.bottomAnchor, constant: 24),
            impactSlider.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            impactSlider.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -22),
            impactSlider.topAnchor.constraint(equalTo: impactTitle.bottomAnchor, constant: 7),
            actionRow.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            actionRow.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -20),
            actionRow.topAnchor.constraint(equalTo: impactSlider.bottomAnchor, constant: 20),
            actionRow.heightAnchor.constraint(equalToConstant: 36),
            hint.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            hint.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -20),
            hint.topAnchor.constraint(equalTo: actionRow.bottomAnchor, constant: 22),
            statusLabel.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -20),
            statusLabel.bottomAnchor.constraint(equalTo: madeBy.topAnchor, constant: -14),
            madeBy.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            madeBy.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -20),
            hud.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -22),
            hud.topAnchor.constraint(equalTo: root.topAnchor, constant: 18)
        ])

        devicePopup.target = self
        devicePopup.action = #selector(deviceChanged(_:))
        toolPopup.target = self
        toolPopup.action = #selector(toolChanged(_:))
        roomPopup.target = self
        roomPopup.action = #selector(roomChanged(_:))

        window.contentView = root
        window.makeKeyAndOrderFront(nil)
    }

    private func makePopup(_ values: [String]) -> NSPopUpButton {
        let popup = NSPopUpButton()
        popup.addItems(withTitles: values)
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.controlSize = .large
        popup.font = .systemFont(ofSize: 11, weight: .medium)
        return popup
    }

    private func makeSection(_ title: String, control: NSView) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        let label = NSTextField(labelWithString: title)
        label.font = .monospacedSystemFont(ofSize: 9, weight: .bold)
        label.textColor = NSColor(calibratedWhite: 0.65, alpha: 1)
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(control)
        control.widthAnchor.constraint(equalToConstant: 248).isActive = true
        return stack
    }

    private func makeButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 10, weight: .bold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    private func material(_ color: NSColor, roughness: CGFloat = 0.62, metalness: CGFloat = 0.0) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.roughness.contents = roughness
        m.metalness.contents = metalness
        return m
    }

    private func tag(_ node: SCNNode, as kind: String) {
        if node.userData == nil { node.userData = NSMutableDictionary() }
        node.userData?["breakable"] = kind
    }

    private func makeBox(
        _ name: String,
        size: SCNVector3,
        position: SCNVector3,
        color: NSColor,
        chamfer: CGFloat = 0.035,
        bodyType: SCNPhysicsBodyType? = .static,
        breakable: String? = nil
    ) -> SCNNode {
        let geometry = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: chamfer)
        geometry.materials = [material(color, roughness: 0.48, metalness: 0.14)]
        let node = SCNNode(geometry: geometry)
        node.name = name
        node.position = position
        if let bodyType {
            node.physicsBody = SCNPhysicsBody(type: bodyType, shape: SCNPhysicsShape(geometry: geometry, options: nil))
            node.physicsBody?.friction = 0.76
            node.physicsBody?.restitution = 0.12
        }
        if let breakable { tag(node, as: breakable) }
        return node
    }

    private func makeCylinder(
        _ name: String,
        radius: CGFloat,
        height: CGFloat,
        position: SCNVector3,
        color: NSColor,
        bodyType: SCNPhysicsBodyType? = .static,
        breakable: String? = nil
    ) -> SCNNode {
        let geometry = SCNCylinder(radius: radius, height: height)
        geometry.firstMaterial = material(color, roughness: 0.4, metalness: 0.35)
        let node = SCNNode(geometry: geometry)
        node.name = name
        node.position = position
        if let bodyType {
            node.physicsBody = SCNPhysicsBody(type: bodyType, shape: SCNPhysicsShape(geometry: geometry, options: nil))
            node.physicsBody?.friction = 0.7
        }
        if let breakable { tag(node, as: breakable) }
        return node
    }

    private func buildScene() {
        screenMaterials.removeAll()
        scene = SCNScene()
        scene.physicsWorld.gravity = SCNVector3(0, -9.8, 0)
        scene.physicsWorld.speed = 1
        sceneView.scene = scene

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 48
        camera.position = SCNVector3(0.0, 7.1, 10.8)
        camera.look(at: SCNVector3(0, 1.4, -0.1))
        scene.rootNode.addChildNode(camera)
        sceneView.pointOfView = camera

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = roomStyle == "Night Lab" ? 260 : 430
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .area
        key.light?.intensity = roomStyle == "Night Lab" ? 850 : 1250
        key.light?.areaSize = CGSize(width: 8, height: 6)
        key.position = SCNVector3(-3, 7, 5)
        scene.rootNode.addChildNode(key)

        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .omni
        rim.light?.intensity = 650
        rim.position = SCNVector3(4, 4, -4)
        scene.rootNode.addChildNode(rim)

        buildRoom()
        buildDesk()
        buildDevice()
        buildCursorTool()
    }

    private func roomPalette() -> (floor: NSColor, wall: NSColor, accent: NSColor) {
        switch roomStyle {
        case "Workshop":
            return (NSColor(calibratedRed: 0.22, green: 0.24, blue: 0.25, alpha: 1), NSColor(calibratedRed: 0.15, green: 0.17, blue: 0.19, alpha: 1), NSColor(calibratedRed: 0.98, green: 0.43, blue: 0.12, alpha: 1))
        case "Night Lab":
            return (NSColor(calibratedRed: 0.055, green: 0.07, blue: 0.13, alpha: 1), NSColor(calibratedRed: 0.035, green: 0.05, blue: 0.10, alpha: 1), NSColor(calibratedRed: 0.13, green: 0.75, blue: 0.98, alpha: 1))
        case "Concrete Room":
            return (NSColor(calibratedRed: 0.34, green: 0.35, blue: 0.36, alpha: 1), NSColor(calibratedRed: 0.27, green: 0.28, blue: 0.29, alpha: 1), NSColor(calibratedRed: 0.94, green: 0.78, blue: 0.35, alpha: 1))
        case "Bedroom":
            return (NSColor(calibratedRed: 0.22, green: 0.17, blue: 0.22, alpha: 1), NSColor(calibratedRed: 0.18, green: 0.13, blue: 0.19, alpha: 1), NSColor(calibratedRed: 0.85, green: 0.42, blue: 0.65, alpha: 1))
        default:
            return (NSColor(calibratedRed: 0.13, green: 0.16, blue: 0.19, alpha: 1), NSColor(calibratedRed: 0.085, green: 0.11, blue: 0.15, alpha: 1), NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.98, alpha: 1))
        }
    }

    private func buildRoom() {
        let palette = roomPalette()
        for x in -2...2 {
            for z in -2...2 {
                let tile = makeBox(
                    "Floor panel",
                    size: SCNVector3(4.0, 0.16, 4.0),
                    position: SCNVector3(Float(x) * 4, -0.12, Float(z) * 4),
                    color: palette.floor,
                    chamfer: 0,
                    breakable: "floor"
                )
                scene.rootNode.addChildNode(tile)
            }
        }
        let foundation = makeBox("Floor foundation", size: SCNVector3(24, 0.25, 24), position: SCNVector3(0, -0.34, 0), color: palette.wall, chamfer: 0)
        scene.rootNode.addChildNode(foundation)

        let backWall = makeBox("Back wall", size: SCNVector3(22, 8, 0.22), position: SCNVector3(0, 3.8, -8.5), color: palette.wall, chamfer: 0, breakable: "wall")
        scene.rootNode.addChildNode(backWall)
        let leftWall = makeBox("Left wall", size: SCNVector3(0.22, 8, 18), position: SCNVector3(-10.8, 3.8, 0), color: palette.wall, chamfer: 0, breakable: "wall")
        scene.rootNode.addChildNode(leftWall)

        for i in 0..<8 {
            let panel = makeBox(
                "Wall acoustic panel",
                size: SCNVector3(1.7, 1.15, 0.06),
                position: SCNVector3(-6.5 + Float(i) * 1.85, 3.0, -8.34),
                color: NSColor(calibratedWhite: 0.12 + CGFloat(i % 3) * 0.035, alpha: 1),
                chamfer: 0.04,
                breakable: "wall"
            )
            scene.rootNode.addChildNode(panel)
        }

        let accent = makeBox("Wall light strip", size: SCNVector3(15, 0.035, 0.04), position: SCNVector3(0, 6.3, -8.22), color: palette.accent, chamfer: 0)
        accent.geometry?.firstMaterial?.emission.contents = palette.accent
        accent.physicsBody = nil
        scene.rootNode.addChildNode(accent)

        for side: Float in [-1, 1] {
            let x = side * 8.7
            let shelf = makeBox("Storage shelf", size: SCNVector3(1.7, 0.12, 5.0), position: SCNVector3(x, 2.05, -2.8), color: NSColor(calibratedWhite: 0.16, alpha: 1), breakable: "prop")
            scene.rootNode.addChildNode(shelf)
            for y: Float in [0.95, 3.15] {
                let support = makeBox("Shelf support", size: SCNVector3(0.12, 2.2, 0.12), position: SCNVector3(x, y, -2.8), color: NSColor(calibratedWhite: 0.22, alpha: 1), breakable: "prop")
                scene.rootNode.addChildNode(support)
            }
            for i in 0..<3 {
                let storage = makeBox("Storage case", size: SCNVector3(0.42, 0.35, 0.65), position: SCNVector3(x, 2.35, -4.2 + Float(i) * 1.25), color: NSColor(calibratedRed: 0.18, green: 0.23, blue: 0.29, alpha: 1), breakable: "prop")
                scene.rootNode.addChildNode(storage)
            }
        }

        let mat = makeBox("Rubber floor mat", size: SCNVector3(7.5, 0.035, 4.2), position: SCNVector3(0, 0.0, 0.2), color: NSColor(calibratedRed: 0.075, green: 0.085, blue: 0.10, alpha: 1), chamfer: 0.03)
        scene.rootNode.addChildNode(mat)

        for i in 0..<7 {
            let line = makeBox("Mat groove", size: SCNVector3(0.018, 0.012, 3.7), position: SCNVector3(-3.1 + Float(i) * 1.03, 0.022, 0.2), color: NSColor(calibratedWhite: 0.19, alpha: 1), chamfer: 0)
            line.physicsBody = nil
            scene.rootNode.addChildNode(line)
        }

        addRoomLamp(at: SCNVector3(-7.2, 3.6, 2.2), accent: palette.accent)
        addRoomLamp(at: SCNVector3(7.2, 3.6, -5.6), accent: palette.accent)
    }

    private func addRoomLamp(at position: SCNVector3, accent: NSColor) {
        let stem = makeCylinder("Room lamp stem", radius: 0.045, height: 2.0, position: SCNVector3(position.x, position.y - 0.7, position.z), color: NSColor(calibratedWhite: 0.25, alpha: 1))
        scene.rootNode.addChildNode(stem)

        let shade = SCNNode(geometry: SCNCone(topRadius: 0.08, bottomRadius: 0.42, height: 0.52))
        shade.position = position
        shade.geometry?.firstMaterial = material(NSColor(calibratedWhite: 0.2, alpha: 1), roughness: 0.4, metalness: 0.3)
        shade.physicsBody = SCNPhysicsBody.static()
        tag(shade, as: "prop")
        scene.rootNode.addChildNode(shade)

        let bulb = SCNNode(geometry: SCNSphere(radius: 0.12))
        bulb.position = SCNVector3(position.x, position.y - 0.28, position.z)
        bulb.geometry?.firstMaterial = material(accent)
        bulb.geometry?.firstMaterial?.emission.contents = accent
        bulb.physicsBody = nil
        scene.rootNode.addChildNode(bulb)
    }

    private func buildDesk() {
        let wood = NSColor(calibratedRed: 0.25, green: 0.18, blue: 0.13, alpha: 1)
        let edge = NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.15, alpha: 1)

        let top = makeBox("Desk tabletop", size: SCNVector3(5.7, 0.18, 3.1), position: SCNVector3(0, deskHeight, -0.15), color: wood, chamfer: 0.07, breakable: "desk")
        top.geometry?.firstMaterial?.roughness.contents = 0.82
        scene.rootNode.addChildNode(top)

        let frontTrim = makeBox("Desk front trim", size: SCNVector3(5.65, 0.09, 0.10), position: SCNVector3(0, deskHeight - 0.025, 1.43), color: edge)
        scene.rootNode.addChildNode(frontTrim)

        for x: Float in [-2.48, 2.48] {
            for z: Float in [-1.38, 1.20] {
                let leg = makeBox("Desk leg", size: SCNVector3(0.16, 1.48, 0.16), position: SCNVector3(x, 0.75, z), color: edge, chamfer: 0.025, breakable: "deskLeg")
                scene.rootNode.addChildNode(leg)
            }
        }

        let drawer = makeBox("Desk drawer", size: SCNVector3(1.75, 0.42, 1.2), position: SCNVector3(0, 1.23, -0.55), color: NSColor(calibratedRed: 0.17, green: 0.13, blue: 0.11, alpha: 1), breakable: "prop")
        scene.rootNode.addChildNode(drawer)

        let drawerHandle = makeBox("Drawer handle", size: SCNVector3(0.48, 0.045, 0.06), position: SCNVector3(0, 1.22, 0.07), color: NSColor(calibratedWhite: 0.55, alpha: 1))
        scene.rootNode.addChildNode(drawerHandle)

        let organizer = makeBox("Desk organizer", size: SCNVector3(0.75, 0.28, 0.48), position: SCNVector3(-2.15, 1.79, -0.8), color: NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.14, alpha: 1), breakable: "prop")
        scene.rootNode.addChildNode(organizer)

        for x: Float in [-2.0, 2.0] {
            let speaker = makeBox("Desk speaker", size: SCNVector3(0.46, 0.75, 0.42), position: SCNVector3(x, 1.99, -1.0), color: NSColor(calibratedRed: 0.075, green: 0.085, blue: 0.10, alpha: 1), breakable: "prop")
            scene.rootNode.addChildNode(speaker)
            let cone = makeCylinder("Speaker cone", radius: 0.14, height: 0.025, position: SCNVector3(x, 2.02, -0.775), color: NSColor(calibratedWhite: 0.32, alpha: 1))
            cone.eulerAngles.x = .pi / 2
            scene.rootNode.addChildNode(cone)
        }

        let monitorStand = makeBox("Monitor stand foot", size: SCNVector3(1.45, 0.07, 0.7), position: SCNVector3(0, 1.70, -1.15), color: edge, breakable: "prop")
        scene.rootNode.addChildNode(monitorStand)
    }

    private func makeScreenMaterial() -> SCNMaterial {
        let screen = SCNMaterial()
        screen.diffuse.contents = createScreenTexture()
        screen.emission.contents = NSColor(calibratedWhite: 0.10, alpha: 1)
        screen.lightingModel = .constant
        screen.isDoubleSided = true
        screenMaterials.append(screen)
        return screen
    }

    private func createScreenTexture() -> NSImage {
        let size = NSSize(width: 640, height: 360)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor(calibratedRed: 0.018, green: 0.027, blue: 0.045, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSColor(calibratedRed: 0.07, green: 0.085, blue: 0.12, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 316, width: 640, height: 44)).fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 19, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        ("YOUTUBE  /  SIMULATED FEED" as NSString).draw(at: NSPoint(x: 22, y: 329), withAttributes: attrs)

        NSColor(calibratedRed: 0.08, green: 0.42, blue: 0.68, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 28, y: 75, width: 584, height: 218), xRadius: 10, yRadius: 10).fill()

        let bandColors: [NSColor] = [
            NSColor(calibratedRed: 0.02, green: 0.82, blue: 0.95, alpha: 1),
            NSColor(calibratedRed: 0.82, green: 0.08, blue: 0.34, alpha: 1),
            NSColor(calibratedRed: 0.98, green: 0.55, blue: 0.12, alpha: 1),
            NSColor(calibratedRed: 0.47, green: 0.20, blue: 0.88, alpha: 1)
        ]
        for i in 0..<10 {
            let y = CGFloat(90 + i * 19)
            bandColors[i % bandColors.count].withAlphaComponent(i % 2 == 0 ? 0.72 : 0.36).setFill()
            NSBezierPath(rect: NSRect(x: 34, y: y, width: CGFloat(Int.random(in: 110...565)), height: CGFloat(Int.random(in: 4...13)))).fill()
        }

        NSColor(calibratedWhite: 0.02, alpha: 0.82).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 640, height: 60)).fill()
        let maker: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 31, weight: .black),
            .foregroundColor: NSColor(calibratedRed: 0.96, green: 0.97, blue: 1, alpha: 1)
        ]
        ("Made by C0oled" as NSString).draw(at: NSPoint(x: 28, y: 22), withAttributes: maker)

        let sub: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.8, alpha: 1)
        ]
        ("ORIGINAL TEST SIGNAL  •  NO THIRD-PARTY VIDEO" as NSString).draw(at: NSPoint(x: 370, y: 25), withAttributes: sub)

        NSColor.white.withAlphaComponent(0.10).setFill()
        for y in stride(from: 2, through: 358, by: 5) {
            NSBezierPath(rect: NSRect(x: 0, y: CGFloat(y), width: 640, height: 1)).fill()
        }
        if Int.random(in: 0...3) == 0 {
            NSColor(calibratedRed: 1, green: 0.13, blue: 0.22, alpha: 0.6).setFill()
            NSBezierPath(rect: NSRect(x: 0, y: CGFloat(Int.random(in: 90...280)), width: 640, height: CGFloat(Int.random(in: 3...18)))).fill()
        }

        image.unlockFocus()
        return image
    }

    private func refreshScreenTextures() {
        guard !screenMaterials.isEmpty else { return }
        let texture = createScreenTexture()
        for material in screenMaterials { material.diffuse.contents = texture }
    }

    private func addScreen(to parent: SCNNode, width: CGFloat, height: CGFloat, position: SCNVector3, horizontal: Bool) {
        let plane = SCNPlane(width: width, height: height)
        plane.firstMaterial = makeScreenMaterial()
        let node = SCNNode(geometry: plane)
        node.position = position
        if horizontal { node.eulerAngles.x = -.pi / 2 }
        node.name = "Glitch display — Made by C0oled"
        parent.addChildNode(node)
    }

    private func buildDevice() {
        deviceRoot?.removeFromParentNode()
        let root = SCNNode()
        root.name = selectedDevice
        tag(root, as: "device")

        let titanium = material(NSColor(calibratedRed: 0.36, green: 0.39, blue: 0.43, alpha: 1), roughness: 0.25, metalness: 0.82)
        let blackGlass = material(NSColor(calibratedRed: 0.012, green: 0.02, blue: 0.035, alpha: 1), roughness: 0.09, metalness: 0.08)
        let keyboard = material(NSColor(calibratedRed: 0.055, green: 0.065, blue: 0.08, alpha: 1), roughness: 0.34)
        let lens = material(NSColor(calibratedRed: 0.018, green: 0.025, blue: 0.04, alpha: 1), roughness: 0.12, metalness: 0.35)

        func part(_ name: String, _ size: SCNVector3, _ position: SCNVector3, _ material: SCNMaterial, _ chamfer: CGFloat = 0.04) -> SCNNode {
            let geometry = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: chamfer)
            geometry.materials = [material]
            let node = SCNNode(geometry: geometry)
            node.name = name
            node.position = position
            return node
        }

        switch selectedDevice {
        case "MacBook Pro 16", "MacBook Air":
            let isAir = selectedDevice == "MacBook Air"
            let width: Float = isAir ? 2.75 : 3.0
            let depth: Float = isAir ? 1.92 : 2.05
            root.addChildNode(part("Aluminium keyboard deck", SCNVector3(width, 0.12, depth), SCNVector3(0, 0.12, 0), titanium, 0.09))
            root.addChildNode(part("Trackpad", SCNVector3(0.84, 0.018, 0.55), SCNVector3(0, 0.19, 0.55), material(NSColor(calibratedWhite: 0.23, alpha: 1), roughness: 0.3), 0.045))
            for row in 0..<5 {
                for col in 0..<13 {
                    root.addChildNode(part("Keyboard key", SCNVector3(0.145, 0.018, 0.115), SCNVector3(-1.23 + Float(col) * 0.205, 0.195, -0.76 + Float(row) * 0.17), keyboard, 0.018))
                }
            }
            root.addChildNode(makeBox("Laptop hinge", size: SCNVector3(width * 0.78, 0.09, 0.10), position: SCNVector3(0, 0.24, -0.91), color: NSColor(calibratedWhite: 0.22, alpha: 1), chamfer: 0.03, bodyType: nil))
            root.addChildNode(part("Display lid", SCNVector3(width, 1.85, 0.10), SCNVector3(0, 1.16, -0.94), titanium, 0.08))
            addScreen(to: root, width: CGFloat(width - 0.22), height: 1.62, position: SCNVector3(0, 1.16, -0.875), horizontal: false)
            root.addChildNode(makeCylinder("Webcam", radius: 0.035, height: 0.012, position: SCNVector3(0, 2.01, -0.87), color: lens, bodyType: nil))
            for x: Float in [-1.05, 1.05] {
                root.addChildNode(makeBox("USB-C port", size: SCNVector3(0.12, 0.035, 0.035), position: SCNVector3(x, 0.11, 0.05), color: lens, chamfer: 0.012, bodyType: nil))
            }

        case "Gaming PC", "Desktop Tower + Monitor":
            let screenWidth: Float = 2.55
            root.addChildNode(part("Monitor housing", SCNVector3(screenWidth, 1.68, 0.14), SCNVector3(-0.55, 1.02, -0.62), titanium, 0.08))
            addScreen(to: root, width: 2.35, height: 1.48, position: SCNVector3(-0.55, 1.02, -0.535), horizontal: false)
            root.addChildNode(part("Monitor chin", SCNVector3(screenWidth, 0.13, 0.05), SCNVector3(-0.55, 0.24, -0.52), keyboard, 0.02))
            root.addChildNode(part("Monitor neck", SCNVector3(0.22, 0.60, 0.22), SCNVector3(-0.55, 0.28, -0.62), titanium))
            root.addChildNode(part("Monitor base", SCNVector3(1.15, 0.08, 0.55), SCNVector3(-0.55, 0.045, -0.50), titanium))
            root.addChildNode(part("PC tower shell", SCNVector3(1.12, 1.7, 1.1), SCNVector3(2.0, 0.87, -0.30), keyboard, 0.08))
            root.addChildNode(part("Tempered glass side", SCNVector3(0.025, 1.48, 0.84), SCNVector3(2.57, 0.9, -0.30), blackGlass, 0.018))
            for i in 0..<3 {
                let colors = [NSColor.systemCyan, NSColor.systemPurple, NSColor.systemPink]
                let fan = makeCylinder("RGB fan", radius: 0.23, height: 0.035, position: SCNVector3(2.57, 0.43 + Float(i) * 0.48, -0.30), color: colors[i], bodyType: nil)
                fan.eulerAngles.z = .pi / 2
                fan.geometry?.firstMaterial?.emission.contents = colors[i]
                root.addChildNode(fan)
            }
            root.addChildNode(part("Mechanical keyboard", SCNVector3(2.15, 0.10, 0.72), SCNVector3(-0.5, 0.08, 1.0), keyboard))
            for row in 0..<4 {
                for col in 0..<14 {
                    root.addChildNode(part("RGB key", SCNVector3(0.115, 0.025, 0.12), SCNVector3(-1.48 + Float(col) * 0.15, 0.15, 0.73 + Float(row) * 0.16), titanium, 0.012))
                }
            }

        case "iPad Pro":
            root.addChildNode(part("iPad aluminium chassis", SCNVector3(2.05, 0.13, 2.8), SCNVector3(0, 0.11, 0), titanium, 0.12))
            addScreen(to: root, width: 1.87, height: 2.60, position: SCNVector3(0, 0.182, 0), horizontal: true)
            for x: Float in [-0.78, 0.78] {
                let camera = makeCylinder("iPad camera", radius: 0.075, height: 0.024, position: SCNVector3(x, 0.19, -1.22), color: lens, bodyType: nil)
                camera.eulerAngles.x = .pi / 2
                root.addChildNode(camera)
            }
            let pencil = makeCylinder("Stylus", radius: 0.035, height: 2.2, position: SCNVector3(1.17, 0.17, 0), color: titanium, bodyType: nil)
            pencil.eulerAngles.x = .pi / 2
            root.addChildNode(pencil)

        default:
            let isMax = selectedDevice == "iPhone 16 Pro Max"
            let width: Float = isMax ? 1.18 : 1.08
            let depth: Float = isMax ? 2.30 : 2.12
            root.addChildNode(part("Titanium phone frame", SCNVector3(width, 0.14, depth), SCNVector3(0, 0.12, 0), titanium, 0.15))
            addScreen(to: root, width: CGFloat(width - 0.13), height: CGFloat(depth - 0.15), position: SCNVector3(0, 0.198, 0), horizontal: true)
            for x: Float in [-0.35, 0.0, 0.35] {
                let cameraX = x - 0.22
                let camera = makeCylinder("Rear camera lens", radius: 0.115, height: 0.035, position: SCNVector3(cameraX, 0.20, -0.76), color: lens, bodyType: nil)
                camera.eulerAngles.x = .pi / 2
                root.addChildNode(camera)
                let ring = makeCylinder("Camera lens ring", radius: 0.145, height: 0.022, position: SCNVector3(cameraX, 0.19, -0.76), color: titanium, bodyType: nil)
                ring.eulerAngles.x = .pi / 2
                root.addChildNode(ring)
            }
            let flash = makeCylinder("Camera flash", radius: 0.055, height: 0.02, position: SCNVector3(0.34, 0.20, -0.75), color: NSColor(calibratedRed: 0.85, green: 0.78, blue: 0.55, alpha: 1), bodyType: nil)
            flash.eulerAngles.x = .pi / 2
            root.addChildNode(flash)
            for x: Float in [-0.28, 0.28] {
                root.addChildNode(makeBox("Speaker perforation", size: SCNVector3(0.035, 0.012, 0.12), position: SCNVector3(x, 0.20, 0.92), color: lens, chamfer: 0.01, bodyType: nil))
            }
            root.addChildNode(makeBox("Side button", size: SCNVector3(0.035, 0.055, 0.35), position: SCNVector3(width / 2 + 0.012, 0.12, -0.12), color: titanium, chamfer: 0.012, bodyType: nil))
        }

        root.position = SCNVector3(0, deskHeight + 0.14, 0.05)
        let footprint: SCNVector3
        switch selectedDevice {
        case "MacBook Pro 16": footprint = SCNVector3(3.1, 2.1, 2.2)
        case "MacBook Air": footprint = SCNVector3(2.9, 2.1, 2.1)
        case "Gaming PC", "Desktop Tower + Monitor": footprint = SCNVector3(4.0, 2.2, 2.3)
        case "iPad Pro": footprint = SCNVector3(2.2, 0.35, 2.95)
        case "iPhone 16 Pro Max": footprint = SCNVector3(1.3, 0.35, 2.4)
        default: footprint = SCNVector3(1.2, 0.35, 2.25)
        }
        let collision = SCNBox(width: CGFloat(footprint.x), height: CGFloat(footprint.y), length: CGFloat(footprint.z), chamferRadius: 0.06)
        root.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: collision, options: nil))
        root.physicsBody?.mass = selectedDevice.contains("PC") || selectedDevice.contains("Tower") ? 11 : (selectedDevice.contains("MacBook") ? 3.2 : 1.4)
        root.physicsBody?.friction = 0.72
        root.physicsBody?.restitution = 0.10
        root.physicsBody?.angularDamping = 0.55
        root.physicsBody?.linearDamping = 0.12
        scene.rootNode.addChildNode(root)
        deviceRoot = root
    }

    private func buildCursorTool() {
        cursorTool?.removeFromParentNode()
        let root = SCNNode()
        root.name = "Mouse-controlled tool"
        let steel = material(NSColor(calibratedWhite: 0.58, alpha: 1), roughness: 0.23, metalness: 0.86)
        let grip = material(NSColor(calibratedRed: 0.15, green: 0.17, blue: 0.20, alpha: 1), roughness: 0.82)
        let handle = SCNNode(geometry: SCNCylinder(radius: 0.065, height: 0.85))
        handle.geometry?.firstMaterial = grip
        handle.position = SCNVector3(0, 0.36, 0)
        root.addChildNode(handle)

        switch selectedTool {
        case "Rubber Mallet":
            let head = SCNNode(geometry: SCNBox(width: 0.62, height: 0.22, length: 0.22, chamferRadius: 0.08))
            head.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.18, green: 0.20, blue: 0.24, alpha: 1), roughness: 0.9)
            head.position = SCNVector3(0, 0.82, 0)
            root.addChildNode(head)
        case "Wrench":
            let head = SCNNode(geometry: SCNTorus(ringRadius: 0.19, pipeRadius: 0.055))
            head.geometry?.firstMaterial = steel
            head.position = SCNVector3(0, 0.86, 0)
            root.addChildNode(head)
        case "Screwdriver":
            let tip = SCNNode(geometry: SCNCylinder(radius: 0.025, height: 0.42))
            tip.geometry?.firstMaterial = steel
            tip.position = SCNVector3(0, 0.82, 0)
            root.addChildNode(tip)
            let cap = SCNNode(geometry: SCNSphere(radius: 0.12))
            cap.geometry?.firstMaterial = grip
            cap.position = SCNVector3(0, 1.08, 0)
            root.addChildNode(cap)
        case "Hydraulic Press":
            let plate = SCNNode(geometry: SCNBox(width: 1.1, height: 0.20, length: 0.9, chamferRadius: 0.06))
            plate.geometry?.firstMaterial = steel
            plate.position = SCNVector3(0, 0.72, 0)
            root.addChildNode(plate)
            let piston = SCNNode(geometry: SCNCylinder(radius: 0.12, height: 0.72))
            piston.geometry?.firstMaterial = steel
            piston.position = SCNVector3(0, 1.15, 0)
            root.addChildNode(piston)
        case "Impact Pulse":
            let orb = SCNNode(geometry: SCNSphere(radius: 0.27))
            orb.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.15, green: 0.68, blue: 0.98, alpha: 1), roughness: 0.12, metalness: 0.65)
            orb.geometry?.firstMaterial?.emission.contents = NSColor(calibratedRed: 0.08, green: 0.35, blue: 0.95, alpha: 1)
            root.addChildNode(orb)
        default:
            let head = SCNNode(geometry: SCNBox(width: selectedTool == "Heavy Hammer" ? 0.78 : 0.55, height: 0.25, length: 0.24, chamferRadius: 0.045))
            head.geometry?.firstMaterial = steel
            head.position = SCNVector3(0, 0.82, 0)
            root.addChildNode(head)
        }

        root.scale = SCNVector3(0.62, 0.62, 0.62)
        root.position = SCNVector3(0, toolPlaneHeight, 0)
        scene.rootNode.addChildNode(root)
        cursorTool = root
    }

    private func moveCursorTool(to point: NSPoint) {
        guard let cursorTool else { return }
        let near = sceneView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
        let far = sceneView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
        let direction = SCNVector3(far.x - near.x, far.y - near.y, far.z - near.z)
        guard abs(direction.y) > 0.0001 else { return }
        let t = (toolPlaneHeight - near.y) / direction.y
        guard t >= 0 else { return }
        cursorTool.position = SCNVector3(near.x + direction.x * t, toolPlaneHeight, near.z + direction.z * t)
    }

    private func dragTool(at point: NSPoint) {
        let now = CACurrentMediaTime()
        guard now - lastDragStrike > 0.16 else { return }
        lastDragStrike = now
        useSelectedTool(at: point, fromDrag: true)
    }

    private func ownerNode(for node: SCNNode) -> SCNNode? {
        var current: SCNNode? = node
        while let item = current {
            if item.userData?["breakable"] as? String != nil { return item }
            current = item.parent
        }
        return nil
    }

    private func useSelectedTool(at point: NSPoint, fromDrag: Bool = false) {
        moveCursorTool(to: point)
        let hits = sceneView.hitTest(point, options: nil)
        guard let hit = hits.first(where: { ownerNode(for: $0.node) != nil }),
              let target = ownerNode(for: hit.node),
              let kind = target.userData?["breakable"] as? String else {
            statusLabel.stringValue = "Move the pointer onto the device, desk, floor or a room prop."
            return
        }

        let worldHit = hit.worldCoordinates
        let localHit = target.convertPosition(worldHit, from: nil)
        let power = toolStrength() * impactPower
        let impulse = SCNVector3(Float.random(in: -1...1) * power * 5, power * 4, -power * 7)
        animateToolTap()

        switch kind {
        case "device":
            if power > 1.26 {
                fractureDevice(target, at: worldHit, power: power)
            } else {
                addScratch(to: target, at: localHit, amount: power)
                target.physicsBody?.applyForce(impulse, at: localHit, asImpulse: true)
                statusLabel.stringValue = "Impact registered. Scratches and display interference added."
            }
        case "desk":
            if power > 1.35 {
                fractureDeskTop(target, at: worldHit, power: power)
            } else {
                addScratch(to: target, at: localHit, amount: power)
                statusLabel.stringValue = "Desk surface marked. Stronger simulated impacts can split the top."
            }
        case "deskLeg":
            if power > 1.55 {
                fractureSimpleNode(target, at: worldHit, power: power, count: 5)
                statusLabel.stringValue = "Desk support separated into collidable pieces."
            } else {
                target.physicsBody?.applyForce(impulse, asImpulse: true)
                statusLabel.stringValue = "Desk support jolted."
            }
        case "floor":
            if power > 2.0 {
                fractureFloorTile(target, at: worldHit, power: power)
                statusLabel.stringValue = "Floor panel fractured. Debris collides and clears itself."
            } else {
                addScratch(to: target, at: localHit, amount: power)
                statusLabel.stringValue = "Floor tile scratched."
            }
        default:
            if power > 1.8 {
                fractureSimpleNode(target, at: worldHit, power: power, count: 6)
                statusLabel.stringValue = "Room prop broke into rigid debris."
            } else {
                target.physicsBody?.applyForce(impulse, at: localHit, asImpulse: true)
                statusLabel.stringValue = "Prop hit. It remains collidable."
            }
        }

        if fromDrag { statusLabel.stringValue = "Tool drag impact: \(selectedTool)." }
    }

    private func toolStrength() -> Float {
        switch selectedTool {
        case "Rubber Mallet": return 0.72
        case "Precision Hammer": return 1.25
        case "Heavy Hammer": return 1.9
        case "Wrench": return 0.92
        case "Screwdriver": return 0.48
        case "Hydraulic Press": return 3.1
        case "Impact Pulse": return 2.25
        case "Drop Test": return 2.0
        default: return 1.0
        }
    }

    private func animateToolTap() {
        guard let cursorTool else { return }
        cursorTool.removeAllActions()
        cursorTool.runAction(.sequence([
            .moveBy(x: 0, y: -0.22, z: 0, duration: 0.055),
            .moveBy(x: 0, y: 0.22, z: 0, duration: 0.12)
        ]))
    }

    private func addScratch(to target: SCNNode, at point: SCNVector3, amount: Float) {
        let count = Int.random(in: 2...5)
        let scratchMaterial = material(NSColor(calibratedWhite: CGFloat.random(in: 0.48...0.86), alpha: 1), roughness: 0.25, metalness: 0.55)
        for _ in 0..<count {
            let length = CGFloat.random(in: 0.12...0.42) * CGFloat(max(0.45, amount))
            let line = SCNBox(width: length, height: 0.009, length: 0.018, chamferRadius: 0.004)
            line.firstMaterial = scratchMaterial
            let scratch = SCNNode(geometry: line)
            scratch.position = SCNVector3(point.x + Float.random(in: -0.24...0.24), point.y + 0.075, point.z + Float.random(in: -0.24...0.24))
            scratch.eulerAngles.y = Float.random(in: -1.0...1.0)
            target.addChildNode(scratch)
        }
        addImpactSparks(at: target.convertPosition(point, to: nil), count: max(3, Int(amount * 9)))
    }

    private func addImpactSparks(at position: SCNVector3, count: Int) {
        for _ in 0..<count {
            let spark = SCNNode(geometry: SCNSphere(radius: CGFloat.random(in: 0.012...0.028)))
            spark.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.65, green: 0.84, blue: 0.98, alpha: 1), roughness: 0.25, metalness: 0.5)
            spark.position = position
            spark.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
            spark.physicsBody?.mass = 0.015
            spark.physicsBody?.linearDamping = 0.08
            tag(spark, as: "temporary")
            scene.rootNode.addChildNode(spark)
            spark.physicsBody?.applyForce(SCNVector3(Float.random(in: -3...3), Float.random(in: 1...4), Float.random(in: -3...3)), asImpulse: true)
            spark.runAction(.sequence([.wait(duration: 1.4), .removeFromParentNode()]))
        }
    }

    private func fractureDevice(_ target: SCNNode, at point: SCNVector3, power: Float) {
        let origin = target.presentation.worldPosition
        let rotation = target.presentation.eulerAngles
        let dimensions: (Float, Float, Float)
        switch selectedDevice {
        case "MacBook Pro 16": dimensions = (3.0, 0.13, 2.05)
        case "MacBook Air": dimensions = (2.75, 0.13, 1.92)
        case "Gaming PC", "Desktop Tower + Monitor": dimensions = (2.55, 0.14, 1.68)
        case "iPad Pro": dimensions = (2.05, 0.14, 2.8)
        case "iPhone 16 Pro Max": dimensions = (1.18, 0.14, 2.3)
        default: dimensions = (1.08, 0.14, 2.12)
        }

        target.removeFromParentNode()
        if deviceRoot === target { deviceRoot = nil }

        let columns = 4
        let rows = 4
        let cellW = dimensions.0 / Float(columns)
        let cellD = dimensions.2 / Float(rows)
        let glass = material(NSColor(calibratedRed: 0.055, green: 0.12, blue: 0.18, alpha: 1), roughness: 0.13, metalness: 0.22)
        let edge = material(NSColor(calibratedRed: 0.34, green: 0.38, blue: 0.42, alpha: 1), roughness: 0.3, metalness: 0.8)

        for col in 0..<columns {
            for row in 0..<rows {
                let shardGeometry = SCNBox(width: CGFloat(cellW * Float.random(in: 0.86...0.98)), height: CGFloat(dimensions.1), length: CGFloat(cellD * Float.random(in: 0.86...0.98)), chamferRadius: 0.025)
                shardGeometry.materials = [glass, edge, edge, edge, edge, edge]
                let shard = SCNNode(geometry: shardGeometry)
                shard.name = "Detached device panel"
                shard.position = SCNVector3(origin.x + (Float(col) - 1.5) * cellW, origin.y + Float.random(in: -0.025...0.035), origin.z + (Float(row) - 1.5) * cellD)
                shard.eulerAngles = rotation
                configureDebris(shard, mass: 0.24)
                scene.rootNode.addChildNode(shard)
                let dx = shard.position.x - point.x
                let dz = shard.position.z - point.z
                let distance = max(0.18, sqrt(dx * dx + dz * dz))
                shard.physicsBody?.applyForce(SCNVector3(dx / distance * power * 3.0, power * 1.8, dz / distance * power * 3.0), asImpulse: true)
            }
        }

        if selectedDevice.contains("MacBook") || selectedDevice.contains("PC") || selectedDevice.contains("Tower") {
            for col in 0..<4 {
                for row in 0..<3 {
                    let shard = SCNNode(geometry: SCNBox(width: CGFloat(dimensions.0 / 4.2), height: 0.50, length: 0.10, chamferRadius: 0.018))
                    shard.geometry?.firstMaterial = glass
                    shard.position = SCNVector3(origin.x + (Float(col) - 1.5) * dimensions.0 / 4.2, origin.y + 0.42 + Float(row) * 0.51, origin.z - 0.9)
                    configureDebris(shard, mass: 0.18)
                    scene.rootNode.addChildNode(shard)
                    shard.physicsBody?.applyForce(SCNVector3(Float.random(in: -1...1) * power * 3, power * 1.5, -power * 3), asImpulse: true)
                }
            }
        }

        addImpactSparks(at: point, count: 24)
        statusLabel.stringValue = "FRACTURE: the shell split into separate rigid pieces. No rubbery stretching."
    }

    private func fractureDeskTop(_ target: SCNNode, at point: SCNVector3, power: Float) {
        let origin = target.presentation.worldPosition
        target.removeFromParentNode()
        for col in 0..<5 {
            for row in 0..<3 {
                let shard = SCNNode(geometry: SCNBox(width: 1.08, height: 0.18, length: 1.0, chamferRadius: 0.035))
                shard.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.22, green: 0.15, blue: 0.10, alpha: 1), roughness: 0.86)
                shard.position = SCNVector3(origin.x + (Float(col) - 2) * 1.1, origin.y + Float.random(in: -0.02...0.05), origin.z + (Float(row) - 1) * 1.02)
                configureDebris(shard, mass: 1.2)
                scene.rootNode.addChildNode(shard)
                let dx = shard.position.x - point.x
                let dz = shard.position.z - point.z
                let distance = max(0.2, sqrt(dx * dx + dz * dz))
                shard.physicsBody?.applyForce(SCNVector3(dx / distance * power * 3.8, power * 1.4, dz / distance * power * 3.8), asImpulse: true)
            }
        }
        addImpactSparks(at: point, count: 18)
    }

    private func fractureFloorTile(_ target: SCNNode, at point: SCNVector3, power: Float) {
        let origin = target.presentation.worldPosition
        target.removeFromParentNode()
        for x in 0..<3 {
            for z in 0..<3 {
                let shard = SCNNode(geometry: SCNBox(width: 1.28, height: 0.16, length: 1.28, chamferRadius: 0.018))
                shard.geometry?.firstMaterial = material(NSColor(calibratedWhite: 0.29, alpha: 1), roughness: 0.94)
                shard.position = SCNVector3(origin.x + (Float(x) - 1) * 1.32, origin.y, origin.z + (Float(z) - 1) * 1.32)
                configureDebris(shard, mass: 0.85)
                scene.rootNode.addChildNode(shard)
                let dx = shard.position.x - point.x
                let dz = shard.position.z - point.z
                let distance = max(0.2, sqrt(dx * dx + dz * dz))
                shard.physicsBody?.applyForce(SCNVector3(dx / distance * power * 2.8, power * 1.8, dz / distance * power * 2.8), asImpulse: true)
            }
        }
    }

    private func fractureSimpleNode(_ target: SCNNode, at point: SCNVector3, power: Float, count: Int) {
        let origin = target.presentation.worldPosition
        let box = target.boundingBox
        let width = max(0.22, box.max.x - box.min.x)
        let height = max(0.12, box.max.y - box.min.y)
        let depth = max(0.22, box.max.z - box.min.z)
        target.removeFromParentNode()

        for _ in 0..<max(4, count) {
            let shard = SCNNode(geometry: SCNBox(
                width: CGFloat(width / 2.2 * Float.random(in: 0.65...1.05)),
                height: CGFloat(height / 2.0 * Float.random(in: 0.65...1.05)),
                length: CGFloat(depth / 2.2 * Float.random(in: 0.65...1.05)),
                chamferRadius: 0.025
            ))
            shard.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.27, green: 0.30, blue: 0.33, alpha: 1), roughness: 0.55, metalness: 0.45)
            shard.position = SCNVector3(origin.x + Float.random(in: -width / 2...width / 2), origin.y + Float.random(in: -height / 2...height / 2), origin.z + Float.random(in: -depth / 2...depth / 2))
            configureDebris(shard, mass: 0.32)
            scene.rootNode.addChildNode(shard)
            let dx = shard.position.x - point.x
            let dz = shard.position.z - point.z
            let distance = max(0.2, sqrt(dx * dx + dz * dz))
            shard.physicsBody?.applyForce(SCNVector3(dx / distance * power * 2.6, power * 1.5, dz / distance * power * 2.6), asImpulse: true)
        }
    }

    private func configureDebris(_ node: SCNNode, mass: CGFloat) {
        guard let geometry = node.geometry else { return }
        let shape = SCNPhysicsShape(geometry: geometry, options: nil)
        let body = SCNPhysicsBody(type: .dynamic, shape: shape)
        body.mass = mass
        body.friction = 0.68
        body.restitution = 0.14
        body.linearDamping = 0.08
        body.angularDamping = 0.22
        node.physicsBody = body
        if node.userData == nil { node.userData = NSMutableDictionary() }
        node.userData?["debrisBorn"] = CACurrentMediaTime()
        debrisCount += 1
    }

    func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
        let now = CACurrentMediaTime()
        let debris = scene.rootNode.childNodes.filter { node in
            guard let born = node.userData?["debrisBorn"] as? Double else { return false }
            return now - born > 14 || node.presentation.worldPosition.y < -1.8
        }
        for node in debris {
            node.removeFromParentNode()
            debrisCount = max(0, debrisCount - 1)
        }
    }

    @objc private func deviceChanged(_ sender: NSPopUpButton) {
        selectedDevice = sender.titleOfSelectedItem ?? "iPhone 16 Pro"
        buildDevice()
        statusLabel.stringValue = "Loaded \(selectedDevice). Move the pointer onto it to interact."
    }

    @objc private func toolChanged(_ sender: NSPopUpButton) {
        selectedTool = sender.titleOfSelectedItem ?? "Precision Hammer"
        buildCursorTool()
        statusLabel.stringValue = "Mouse tool changed to \(selectedTool)."
    }

    @objc private func roomChanged(_ sender: NSPopUpButton) {
        roomStyle = sender.titleOfSelectedItem ?? "Creator Studio"
        buildScene()
        statusLabel.stringValue = "Environment loaded: \(roomStyle)."
    }

    @objc private func impactChanged(_ sender: NSSlider) {
        impactPower = Float(sender.floatValue)
    }

    @objc private func resetScene() {
        debrisCount = 0
        buildScene()
        statusLabel.stringValue = "Room reset. Desk, floor, device and props restored."
    }

    @objc private func dropObject() {
        guard let target = deviceRoot, let body = target.physicsBody else { return }
        target.position = SCNVector3(0, 5.7, 0)
        body.velocity = SCNVector3Zero
        body.angularVelocity = SCNVector4Zero
        body.applyForce(SCNVector3(Float.random(in: -1.2...1.2), 0, Float.random(in: -1.2...1.2)), asImpulse: true)
        statusLabel.stringValue = "Drop test started. The device will collide with the desk and floor."
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = SmashSimulator()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
