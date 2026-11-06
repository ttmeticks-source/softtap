import AppKit
import SceneKit
import QuartzCore

final class SmashSceneView: SCNView {
    var onInspect: ((NSPoint) -> Void)?
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onInspect?(point)
        super.mouseDown(with: event)
    }
}

final class SmashSimulator: NSObject, NSApplicationDelegate {
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        guard showAgeNotice() else {
            NSApp.terminate(nil)
            return
        }
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
        window.minSize = NSSize(width: 900, height: 620)

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
        toolPopup = popup(["Hammer", "Wrecking Ball", "Drop Test", "Kick"], selected: selectedTool)
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

        let hit = makeButton("STRIKE OBJECT", action: #selector(strike))
        let drop = makeButton("DROP FROM HEIGHT", action: #selector(dropObject))
        let reset = makeButton("RESET SCENE", action: #selector(resetScene))
        sidebar.addSubview(hit); sidebar.addSubview(drop); sidebar.addSubview(reset)

        statusLabel = NSTextField(wrappingLabelWithString: "Ready. Choose a device, room and tool.")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = NSColor(calibratedWhite: 0.68, alpha: 1)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(statusLabel)

        sceneView = SmashSceneView()
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.scene = scene
        sceneView.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.20, alpha: 1)
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.antialiasingMode = .multisampling4X
        sceneView.onInspect = { [weak self] point in self?.inspectObject(at: point) }
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
        sceneView.scene = scene

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(0, 3.6, 8.5)
        camera.eulerAngles = SCNVector3(-0.22, 0, 0)
        scene.rootNode.addChildNode(camera)
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
        makeDevice()
    }

    private func makeRoom() {
        let floor = SCNNode(geometry: SCNBox(width: 14, height: 0.18, length: 14, chamferRadius: 0))
        floor.position = SCNVector3(0, -0.12, 0)
        floor.geometry?.firstMaterial = material(roomColor(), roughness: 0.82)
        floor.physicsBody = SCNPhysicsBody.static()
        scene.rootNode.addChildNode(floor)

        let back = SCNNode(geometry: SCNBox(width: 14, height: 7, length: 0.12, chamferRadius: 0))
        back.position = SCNVector3(0, 3.35, -5)
        back.geometry?.firstMaterial = material(wallColor(), roughness: 0.95)
        scene.rootNode.addChildNode(back)

        let left = SCNNode(geometry: SCNBox(width: 0.12, height: 7, length: 10, chamferRadius: 0))
        left.position = SCNVector3(-7, 3.35, 0)
        left.geometry?.firstMaterial = material(wallColor(), roughness: 0.95)
        scene.rootNode.addChildNode(left)
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

    private func material(_ color: NSColor, roughness: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.roughness.contents = roughness
        m.metalness.contents = 0.12
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

        root.position = SCNVector3(0, 0.02, 0)
        let collisionSize: SCNVector3 = selectedDevice == "MacBook" ? SCNVector3(3.0, 2.0, 2.0) : (selectedDevice == "Desktop PC" ? SCNVector3(3.0, 2.0, 1.0) : (selectedDevice == "iPad" ? SCNVector3(2.3, 0.35, 3.0) : SCNVector3(1.3, 0.45, 2.5)))
        let collisionGeometry = SCNBox(width: CGFloat(collisionSize.x), height: CGFloat(collisionSize.y), length: CGFloat(collisionSize.z), chamferRadius: 0.05)
        root.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: collisionGeometry, options: nil))
        root.physicsBody?.mass = selectedDevice == "Desktop PC" ? 9 : 2.2
        root.physicsBody?.friction = 0.78
        root.physicsBody?.restitution = 0.12
        root.physicsBody?.angularDamping = 0.42
        root.physicsBody?.categoryBitMask = 1
        scene.rootNode.addChildNode(root)
        deviceRoot = root
    }

    @objc private func deviceChanged(_ sender: NSPopUpButton) {
        selectedDevice = sender.titleOfSelectedItem ?? "iPhone"
        makeDevice()
        statusLabel.stringValue = "Loaded virtual \(selectedDevice)."
    }

    @objc private func toolChanged(_ sender: NSPopUpButton) {
        selectedTool = sender.titleOfSelectedItem ?? "Hammer"
        statusLabel.stringValue = "Tool selected: \(selectedTool)."
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
        target.position = SCNVector3(0, 5.2, 0)
        target.physicsBody?.velocity = SCNVector3Zero
        target.physicsBody?.angularVelocity = SCNVector4Zero
        target.physicsBody?.applyForce(SCNVector3(Float.random(in: -3...3), 0, Float.random(in: -2...2)), asImpulse: true)
        statusLabel.stringValue = "Drop test started. The object will fall onto the room floor."
    }

    @objc private func resetScene() {
        buildScene()
        statusLabel.stringValue = "Scene reset. All simulated damage and props cleared."
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = SmashSimulator()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
