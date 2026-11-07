import AppKit
import SceneKit
import QuartzCore
import Darwin

final class SmashSceneView: SCNView {
    private var mouseTracking: NSTrackingArea?
    override func updateTrackingAreas() {
        if let mouseTracking { removeTrackingArea(mouseTracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        mouseTracking = area
        super.updateTrackingAreas()
    }
    var onInspect: ((NSPoint) -> Void)?
    var onAim: ((NSPoint) -> Void)?
    var onSwing: ((NSPoint) -> Void)?
    override func mouseMoved(with event: NSEvent) { onAim?(convert(event.locationInWindow, from: nil)) }
    override func mouseDragged(with event: NSEvent) { onAim?(convert(event.locationInWindow, from: nil)) }
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onInspect?(point); onSwing?(point); super.mouseDown(with: event)
    }
}

final class SmashSimulator: NSObject, NSApplicationDelegate, SCNSceneRendererDelegate, SCNPhysicsContactDelegate {
    private var window: NSWindow!
    private var sceneView: SmashSceneView?
    private var sceneContainer: NSView!
    private var scene = SCNScene()
    private var deviceRoot: SCNNode?
    private var selectedTool = "Hammer"
    private var selectedDevice = "iPhone"
    private var cursorTool = SCNNode()
    private var cursorToolPivot = SCNNode()
    private var swingSound: NSSound?
    private var impactSound: NSSound?
    private var glassTapSound: NSSound?
    private var shatterSound: NSSound?
    private var scratchSound: NSSound?
    private var deviceThudSound: NSSound?
    private var woodKnockSound: NSSound?
    private var metalClangSound: NSSound?
    private var plasticClickSound: NSSound?
    private var carpetThumpSound: NSSound?
    private var deviceRattleSound: NSSound?
    private var glassCrackleSound: NSSound?
    private var debrisScatterSound: NSSound?
    private var impactDecals: [SCNNode] = []
    private let maximumImpactDecals = 40
    private let windowBreakThreshold: CGFloat = 0.75
    private var windowIntactGlass: SCNNode?
    private var windowShardGroup: SCNNode?
    private var windowCrackDecals: [SCNNode] = []
    private var windowHasBroken = false
    private var windowHitCount = 0
    private var internalParts: [SCNNode] = []
    private var deviceShellParts: [SCNNode] = []
    private var breakableComponents: [SCNNode] = []
    private var detachedDeviceParts: [SCNNode] = []
    private var roomBreakables: [SCNNode] = []
    private var roomPropDamage: [ObjectIdentifier: CGFloat] = [:]
    private var physicsBlockDamage: [ObjectIdentifier: CGFloat] = [:]
    private var deskBreakablePanels: [SCNNode] = []
    private var deskPanelDamage: [ObjectIdentifier: CGFloat] = [:]
    private var devicePartDamage: [ObjectIdentifier: CGFloat] = [:]
    private var surfaceDamageMarks: [SCNNode] = []
    private var showingInternals = false
    private var damageLevel: Float = 0.72
    private var waterEffects: [SCNNode] = []
    private var activeFireEffects: [SCNNode] = []
    private var roomStyle = "Studio"
    private var statusLabel: NSTextField!
    private var scoreLabel: NSTextField!
    private var damageScore = 0
    private var hitCount = 0
    private var devicePopup: NSPopUpButton!
    private var toolPopup: NSPopUpButton!
    private var roomPopup: NSPopUpButton!
    private var damageSlider: NSSlider!
    private let deskTopY: CGFloat = 1.26
    private let dynamicCategoryMask = 1
    private let staticCategoryMask = 2
    private let cameraBounds = (x: CGFloat(9.20), y: CGFloat(6.35), z: CGFloat(8.15))

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Build the complete scene before exposing the window. This avoids showing
        // a blank view during first-frame setup and removes the blocking startup modal.
        NSApp.setActivationPolicy(.regular)
        buildWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.startDemo() }
    }

    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1360, height: 860),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Smash Simulator — Demo"
        window.center()
        window.minSize = NSSize(width: 1080, height: 700)

        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.067, blue: 0.09, alpha: 1).cgColor
        window.contentView = root

        let sidebar = NSView()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = NSColor(calibratedRed: 0.085, green: 0.10, blue: 0.14, alpha: 1).cgColor
        let sidebarGradient = CAGradientLayer()
        sidebarGradient.colors = [
            NSColor(calibratedRed: 0.075, green: 0.105, blue: 0.15, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.085, alpha: 1).cgColor
        ]
        sidebarGradient.startPoint = CGPoint(x: 0, y: 1)
        sidebarGradient.endPoint = CGPoint(x: 1, y: 0)
        sidebarGradient.frame = NSRect(x: 0, y: 0, width: 278, height: 860)
        sidebarGradient.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        sidebar.layer?.insertSublayer(sidebarGradient, at: 0)
        root.addSubview(sidebar)

        let heading = NSTextField(labelWithString: "SMASH SIMULATOR")
        heading.font = .systemFont(ofSize: 17, weight: .black)
        heading.textColor = .white
        heading.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(heading)

        let subtitle = NSTextField(labelWithString: "LIVE PHYSICS  •  MATERIAL DAMAGE LAB")
        subtitle.font = .systemFont(ofSize: 9, weight: .bold)
        subtitle.textColor = NSColor(calibratedWhite: 0.58, alpha: 1)
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(subtitle)
        let demoBadge = NSTextField(labelWithString: "DEMO")
        demoBadge.font = .systemFont(ofSize: 9, weight: .black)
        demoBadge.textColor = .white
        demoBadge.alignment = .center
        demoBadge.wantsLayer = true
        demoBadge.layer?.backgroundColor = NSColor(calibratedRed: 0.10, green: 0.43, blue: 0.58, alpha: 1).cgColor
        demoBadge.layer?.cornerRadius = 5
        demoBadge.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(demoBadge)

        devicePopup = popup(["iPhone", "MacBook", "Desktop PC", "PC Tower", "Engine", "iPad", "TV", "Smartwatch", "Digital Camera", "Game Console", "Bluetooth Speaker", "Earbuds Case"], selected: selectedDevice)
        toolPopup = popup(["Hammer", "Sledgehammer", "Rubber Mallet", "Crowbar", "Wrench", "Screwdriver", "Drill", "Saw", "Impact Driver", "Plastic Spudger", "Suction Cup", "Fire Simulator", "Water Blaster"], selected: selectedTool)
        roomPopup = popup(["Studio", "Garage", "Concrete", "Bedroom", "Neon Lab"], selected: roomStyle)

        let startDemoButton = makeButton("START 3D DEMO", action: #selector(startDemo))
        sidebar.addSubview(startDemoButton)
        startDemoButton.translatesAutoresizingMaskIntoConstraints = false
        startDemoButton.layer?.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.38, blue: 0.48, alpha: 1).cgColor
        startDemoButton.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 14).isActive = true
        startDemoButton.leadingAnchor.constraint(equalTo: heading.leadingAnchor).isActive = true
        startDemoButton.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -20).isActive = true
        startDemoButton.heightAnchor.constraint(equalToConstant: 34).isActive = true

        addSection("DEVICE", control: devicePopup, to: sidebar, top: startDemoButton, gap: 38)
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
        let internals = makeButton("TOGGLE DEVICE INTERNALS", action: #selector(toggleDeviceInternals))
        let spawn = makeButton("SPAWN CHAOS PROP", action: #selector(spawnChaosProp))
        sidebar.addSubview(hit); sidebar.addSubview(drop); sidebar.addSubview(reset); sidebar.addSubview(internals); sidebar.addSubview(spawn)

        statusLabel = NSTextField(wrappingLabelWithString: "Ready. Choose a device, room and tool.")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = NSColor(calibratedWhite: 0.68, alpha: 1)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.wantsLayer = true
        statusLabel.layer?.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.085, blue: 0.12, alpha: 1).cgColor
        statusLabel.layer?.cornerRadius = 9
        statusLabel.layer?.borderWidth = 1
        statusLabel.layer?.borderColor = NSColor(calibratedRed: 0.16, green: 0.25, blue: 0.31, alpha: 1).cgColor
        sidebar.addSubview(statusLabel)

        // A plain AppKit placeholder is shown at launch. SceneKit (and the GPU
        // renderer) is not created until the user explicitly starts the 3D demo.
        sceneContainer = NSView()
        sceneContainer.translatesAutoresizingMaskIntoConstraints = false
        sceneContainer.wantsLayer = true
        sceneContainer.layer?.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.11, alpha: 1).cgColor
        root.addSubview(sceneContainer)
        let hud = NSTextField(labelWithString: "SCORE 0000  •  HITS 00")
        scoreLabel = hud
        hud.font = .systemFont(ofSize: 10, weight: .bold)
        hud.textColor = NSColor(calibratedRed: 0.76, green: 0.91, blue: 0.96, alpha: 1)
        hud.alignment = .center
        hud.wantsLayer = true
        hud.layer?.backgroundColor = NSColor(calibratedRed: 0.035, green: 0.075, blue: 0.10, alpha: 0.88).cgColor
        hud.layer?.cornerRadius = 8
        hud.layer?.borderWidth = 1
        hud.layer?.borderColor = NSColor(calibratedRed: 0.18, green: 0.42, blue: 0.50, alpha: 1).cgColor
        hud.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(hud)

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: root.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 278),
            sceneContainer.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            sceneContainer.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            sceneContainer.topAnchor.constraint(equalTo: root.topAnchor),
            sceneContainer.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            hud.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            hud.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
            hud.widthAnchor.constraint(equalToConstant: 220),
            hud.heightAnchor.constraint(equalToConstant: 28),
            heading.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 20),
            heading.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 25),
            subtitle.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 4),
            demoBadge.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -20),
            demoBadge.centerYAnchor.constraint(equalTo: heading.centerYAnchor),
            demoBadge.widthAnchor.constraint(equalToConstant: 48),
            demoBadge.heightAnchor.constraint(equalToConstant: 20),
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
            internals.leadingAnchor.constraint(equalTo: hit.leadingAnchor),
            internals.trailingAnchor.constraint(equalTo: hit.trailingAnchor),
            internals.topAnchor.constraint(equalTo: reset.bottomAnchor, constant: 9),
            spawn.leadingAnchor.constraint(equalTo: hit.leadingAnchor),
            spawn.trailingAnchor.constraint(equalTo: hit.trailingAnchor),
            spawn.topAnchor.constraint(equalTo: internals.bottomAnchor, constant: 9),
            statusLabel.topAnchor.constraint(greaterThanOrEqualTo: spawn.bottomAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -18),
            statusLabel.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -22)
        ])

        devicePopup.target = self; devicePopup.action = #selector(deviceChanged(_:))
        toolPopup.target = self; toolPopup.action = #selector(toolChanged(_:))
        roomPopup.target = self; roomPopup.action = #selector(roomChanged(_:))
        window.acceptsMouseMovedEvents = true
    }


    private func inspectObject(at point: NSPoint) {
        guard let sceneView else { statusLabel.stringValue = "Start the 3D demo first."; return }
        let hits = sceneView.hitTest(point, options: nil)
        guard let hit = hits.first else {
            statusLabel.stringValue = "Nothing selected. Click a device or room object to inspect it."
            return
        }

        let objectName = hit.node.name ?? hit.node.geometry?.name ?? "Scene object"
        statusLabel.stringValue = "Selected: \(objectName) — virtual scene inspection."
    }

    private func popup(_ items: [String], selected: String) -> NSPopUpButton {
        let p = NSPopUpButton()
        p.bezelStyle = .rounded
        p.controlSize = .large
        p.font = .systemFont(ofSize: 12, weight: .medium)
        p.wantsLayer = true
        p.layer?.cornerRadius = 7
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
        b.isBordered = false
        b.wantsLayer = true
        b.layer?.backgroundColor = NSColor(calibratedRed: 0.105, green: 0.31, blue: 0.43, alpha: 1).cgColor
        b.layer?.cornerRadius = 8
        b.layer?.borderWidth = 1
        b.layer?.borderColor = NSColor(calibratedRed: 0.23, green: 0.48, blue: 0.59, alpha: 1).cgColor
        b.contentTintColor = NSColor(calibratedRed: 0.91, green: 0.97, blue: 1, alpha: 1)
        let symbol: String
        switch title {
        case "START 3D DEMO": symbol = "play.fill"
        case "STRIKE OBJECT": symbol = "hammer.fill"
        case "DROP FROM HEIGHT": symbol = "arrow.down.to.line"
        case "RESET SCENE": symbol = "arrow.counterclockwise"
        case "TOGGLE DEVICE INTERNALS": symbol = "cpu"
        default: symbol = "circle.fill"
        }
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        b.imagePosition = .imageLeading
        b.font = .systemFont(ofSize: 11, weight: .semibold)
        b.controlSize = .large
        b.translatesAutoresizingMaskIntoConstraints = false
        b.heightAnchor.constraint(equalToConstant: 36).isActive = true
        return b
    }

    @objc private func startDemo() {
        guard sceneView == nil else { return }
        statusLabel.stringValue = "Starting 3D demo in low-load mode…"
        let view = SmashSceneView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.11, alpha: 1)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .none
        view.preferredFramesPerSecond = 30
        view.delegate = self
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.automaticTarget = false
        view.defaultCameraController.inertiaEnabled = false
        view.defaultCameraController.target = SCNVector3(0, 1.30, 0)
        view.defaultCameraController.minimumVerticalAngle = 8
        view.defaultCameraController.maximumVerticalAngle = 40
        view.onInspect = { [weak self] point in self?.inspectObject(at: point) }
        view.onAim = { [weak self] point in self?.aimTool(at: point) }
        view.onSwing = { [weak self] point in self?.swingTool(at: point) }
        sceneContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: sceneContainer.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: sceneContainer.trailingAnchor),
            view.topAnchor.constraint(equalTo: sceneContainer.topAnchor),
            view.bottomAnchor.constraint(equalTo: sceneContainer.bottomAnchor)
        ])
        sceneView = view
        buildScene()
        statusLabel.stringValue = "3D demo active · balanced 30 FPS mode."
    }

    private func buildScene() {
        guard let sceneView else { return }
        scene = SCNScene()
        configurePhysicsWorld()
        sceneView.scene = scene

        let camera = SCNNode()
        camera.camera = SCNCamera()
        // Keep post-processing disabled by default: it can overwhelm integrated GPUs.
        camera.camera?.wantsHDR = false
        camera.camera?.wantsExposureAdaptation = false
        camera.camera?.bloomIntensity = 0
        camera.camera?.vignettingIntensity = 0
        camera.camera?.screenSpaceAmbientOcclusionIntensity = 0
        camera.camera?.screenSpaceAmbientOcclusionRadius = 3.0
        camera.position = SCNVector3(0, 3.8, 7.2)
        camera.look(at: SCNVector3(0, 1.30, 0))
        camera.camera?.zNear = 0.1
        camera.camera?.zFar = 100
        scene.rootNode.addChildNode(camera)
        sceneView.pointOfView = camera

        scene.background.contents = NSColor(calibratedRed: 0.035, green: 0.052, blue: 0.082, alpha: 1)
        scene.fogColor = NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.22, alpha: 1)
        scene.fogStartDistance = 12
        scene.fogEndDistance = 30
        scene.fogDensityExponent = 1.25
        scene.lightingEnvironment.contents = NSColor(calibratedRed: 0.22, green: 0.27, blue: 0.31, alpha: 1)
        scene.lightingEnvironment.intensity = 0.38
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 260
        scene.rootNode.addChildNode(ambient)
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .spot
        key.light?.intensity = 1550
        key.light?.spotInnerAngle = 48
        key.light?.spotOuterAngle = 78
        key.light?.castsShadow = false
        key.light?.shadowRadius = 3
        key.light?.shadowSampleCount = 1
        key.light?.shadowColor = NSColor(calibratedWhite: 0.04, alpha: 0.55)
        key.position = SCNVector3(-3.2, 6.2, 4.6)
        key.look(at: SCNVector3(0, 1.0, 0))
        scene.rootNode.addChildNode(key)
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .omni
        fill.light?.intensity = 420
        fill.light?.color = NSColor(calibratedRed: 0.45, green: 0.66, blue: 1, alpha: 1)
        fill.position = SCNVector3(4.2, 3.1, -3.8)
        scene.rootNode.addChildNode(fill)
        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .spot
        rim.light?.intensity = 680
        rim.light?.color = NSColor(calibratedRed: 0.35, green: 0.72, blue: 0.88, alpha: 1)
        rim.light?.spotInnerAngle = 38
        rim.light?.spotOuterAngle = 66
        rim.position = SCNVector3(0, 4.8, -6.8)
        rim.look(at: SCNVector3(0, 1.3, 0))
        scene.rootNode.addChildNode(rim)

        roomBreakables.removeAll()
        roomPropDamage.removeAll()
        physicsBlockDamage.removeAll()
        waterEffects.forEach { $0.removeFromParentNode() }
        waterEffects.removeAll()
        activeFireEffects.forEach { $0.removeFromParentNode() }
        activeFireEffects.removeAll()
        makeRoom()
        makeRoomDressing()
        makeDesk()
        makeDevice()
        makePhysicsProps()
        makeWindowSetpiece()
        makeCursorTool()
        prepareAudio()
    }

    // Centralized SceneKit world tuning. A smaller fixed simulation step improves
    // stability for the existing dynamic device and props while keeping all physics
    // local to this scene. Contact callbacks are informational only.
    private func configurePhysicsWorld() {
        scene.physicsWorld.gravity = SCNVector3(0, -9.81, 0)
        scene.physicsWorld.speed = 1.0
        // A fixed 120 Hz step reduces tunnelling and jitter for the existing SceneKit bodies.
        scene.physicsWorld.timeStep = 1.0 / 60.0
        scene.physicsWorld.contactDelegate = self
    }

    // SceneKit exposes per-body material response and resting controls, but not public
    // solver-iteration or contact-depth tuning. Keep collision response consistent here.
    private func configureDynamicBody(
        _ body: SCNPhysicsBody,
        mass: CGFloat,
        friction: CGFloat,
        restitution: CGFloat,
        angularDamping: CGFloat
    ) {
        body.mass = mass
        body.friction = friction
        body.restitution = min(0.25, max(0.02, restitution))
        body.angularDamping = angularDamping
        body.damping = 0.08
        body.allowsResting = true
        body.categoryBitMask = dynamicCategoryMask
        body.collisionBitMask = dynamicCategoryMask | staticCategoryMask
        body.contactTestBitMask = dynamicCategoryMask | staticCategoryMask
    }

    private func configureStaticBody(_ body: SCNPhysicsBody, friction: CGFloat, restitution: CGFloat) {
        body.friction = friction
        body.restitution = restitution
        body.categoryBitMask = staticCategoryMask
        body.collisionBitMask = dynamicCategoryMask | staticCategoryMask
        body.contactTestBitMask = dynamicCategoryMask
    }

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        // SceneKit may call its contact delegate on the renderer thread. Snapshot
        // contact data, then perform AppKit/audio/scene mutations on the main queue.
        let impulse = contact.collisionImpulse
        guard impulse > 0.35 else { return }
        let first = contact.nodeA.name ?? "Object"
        let second = contact.nodeB.name ?? "Surface"
        let point = contact.contactPoint
        let normal = contact.contactNormal
        let touchesDevice = impulse > 3.2 && deviceRoot != nil &&
            (deviceRoot.map { isInside(contact.nodeA, root: $0) || isInside(contact.nodeB, root: $0) } ?? false)
        let touchesWindow = contact.nodeA.name == "Breakable window glass" || contact.nodeB.name == "Breakable window glass"
        DispatchQueue.main.async { [weak self] in
            guard let self, self.statusLabel != nil else { return }
            self.statusLabel.stringValue = String(
                format: "Scene contact: %@ ↔ %@  ·  impulse %.1f",
                first, second, impulse
            )
            self.playSurfaceImpact(first: first, second: second, impulse: impulse, position: point)
            if touchesWindow && impulse >= self.windowBreakThreshold {
                self.breakWindow(at: point)
            }
        }
    }

    // Authored one-shot window setpiece: swap visibility, release prebuilt meshes, then clean up.
    private func makeWindowSetpiece() {
        windowHasBroken = false
        windowHitCount = 0
        let center = SCNVector3(0, 2.55, -8.72)
        let frameMaterial = material(NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.19, alpha: 1), roughness: 0.42)
        let frameParts: [(SCNVector3, SCNVector3)] = [
            (SCNVector3(2.62, 0.12, 0.14), SCNVector3(0, 0.86, 0)),
            (SCNVector3(2.62, 0.12, 0.14), SCNVector3(0, -0.86, 0)),
            (SCNVector3(0.12, 1.60, 0.14), SCNVector3(-1.25, 0, 0)),
            (SCNVector3(0.12, 1.60, 0.14), SCNVector3(1.25, 0, 0))
        ]
        for (index, part) in frameParts.enumerated() {
            let geometry = SCNBox(width: CGFloat(part.0.x), height: CGFloat(part.0.y), length: CGFloat(part.0.z), chamferRadius: 0.025)
            geometry.firstMaterial = frameMaterial
            let frame = SCNNode(geometry: geometry)
            frame.name = "Window frame \(index + 1)"
            frame.position = SCNVector3(center.x + part.1.x, center.y + part.1.y, center.z + part.1.z)
            frame.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: geometry, options: nil))
            if let body = frame.physicsBody { configureStaticBody(body, friction: 0.72, restitution: 0.02) }
            scene.rootNode.addChildNode(frame)
        }

        let glassGeometry = SCNBox(width: 2.38, height: 1.58, length: 0.045, chamferRadius: 0.008)
        let glass = SCNNode(geometry: glassGeometry)
        glass.name = "Breakable window glass"
        glass.position = center
        let glassMaterial = SCNMaterial()
        glassMaterial.diffuse.contents = NSColor(calibratedRed: 0.34, green: 0.68, blue: 0.82, alpha: 0.24)
        glassMaterial.emission.contents = NSColor(calibratedRed: 0.035, green: 0.10, blue: 0.14, alpha: 1)
        glassMaterial.transparency = 0.30
        glassMaterial.isDoubleSided = true
        glassMaterial.lightingModel = .physicallyBased
        glassMaterial.roughness.contents = 0.12
        glassMaterial.metalness.contents = 0.08
        glass.geometry?.firstMaterial = glassMaterial
        glass.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: glassGeometry, options: nil))
        if let body = glass.physicsBody {
            configureStaticBody(body, friction: 0.22, restitution: 0.04)
            body.contactTestBitMask = dynamicCategoryMask
        }
        scene.rootNode.addChildNode(glass)
        windowIntactGlass = glass

        let shardGroup = SCNNode()
        shardGroup.name = "Window authored shard set"
        shardGroup.position = center
        guard let assetURL = Bundle.main.url(forResource: "window_shards", withExtension: "scn"),
              let authoredScene = try? SCNScene(url: assetURL, options: nil) else {
            statusLabel?.stringValue = "Window shard asset could not be loaded."
            return
        }
        for authoredShard in authoredScene.rootNode.childNodes {
            let shard = authoredShard.clone()
            shard.isHidden = true
            shard.name = authoredShard.name ?? "Window shard"
            shardGroup.addChildNode(shard)
        }
        shardGroup.isHidden = true
        scene.rootNode.addChildNode(shardGroup)
        windowShardGroup = shardGroup
    }

    private func breakWindow(at impactPoint: SCNVector3) {
        guard !windowHasBroken, let intact = windowIntactGlass,
              let shardGroup = windowShardGroup, !shardGroup.childNodes.isEmpty else { return }
        windowHasBroken = true
        intact.isHidden = true
        intact.physicsBody = nil
        windowCrackDecals.forEach { $0.removeFromParentNode() }
        windowCrackDecals.removeAll()
        shardGroup.isHidden = false
        playSpatial("glass_shatter", at: impactPoint, volume: 1.0)
        playSpatial("debris_scatter", at: impactPoint, volume: 0.82)

        for shard in shardGroup.childNodes {
            shard.isHidden = false
            guard let geometry = shard.geometry else { continue }
            let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: geometry, options: nil))
            configureDynamicBody(body, mass: 0.075, friction: 0.42, restitution: 0.025, angularDamping: 0.48)
            shard.physicsBody = body

            let p = shard.presentation.worldPosition
            var direction = SCNVector3(p.x - impactPoint.x, p.y - impactPoint.y + 0.22, p.z - impactPoint.z)
            let length = max(0.001, sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z))
            direction = SCNVector3(direction.x / length, direction.y / length, direction.z / length)
            let impulse = CGFloat.random(in: 0.28...0.72)
            body.applyForce(SCNVector3(direction.x * impulse, direction.y * impulse, direction.z * impulse), asImpulse: true)
            body.applyTorque(SCNVector4(Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: 0.7...2.2)), asImpulse: true)
            shard.runAction(.sequence([.wait(duration: 3.72), .fadeOut(duration: 0.28), .removeFromParentNode()]))
        }
        statusLabel?.stringValue = "Window setpiece triggered — authored shards scattering."
        shardGroup.runAction(.sequence([.wait(duration: 4.15), .run { [weak self, weak shardGroup] _ in
            shardGroup?.removeFromParentNode()
            self?.windowShardGroup = nil
        }]))
    }

    // Large, staged glass overlays make the first tool strike visibly register before the setpiece swap.
    // Crack art is parented to the glass and positioned in glass-local coordinates.
    private func addWindowCrack(at point: SCNVector3, normal: SCNVector3, stage: Int, on glass: SCNNode) {
        guard let name = (1...8).map({ String(format: "crack_%02d", $0) }).randomElement(),
              let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return }
        let localPoint = glass.convertPosition(point, from: nil)
        var localNormal = glass.convertVector(normal, from: nil)
        let length = max(0.001, sqrt(localNormal.x * localNormal.x + localNormal.y * localNormal.y + localNormal.z * localNormal.z))
        localNormal = SCNVector3(localNormal.x / length, localNormal.y / length, localNormal.z / length)
        let width: CGFloat = stage == 1 ? 0.92 : 1.28
        let plane = SCNPlane(width: width, height: width * 0.92)
        let material = SCNMaterial()
        material.diffuse.contents = image
        material.transparent.contents = image
        material.isDoubleSided = true
        material.lightingModel = .constant
        material.blendMode = .alpha
        plane.firstMaterial = material
        let decal = SCNNode(geometry: plane)
        decal.name = "Window crack overlay"
        decal.position = SCNVector3(localPoint.x + localNormal.x * 0.003,
                                    localPoint.y + localNormal.y * 0.003,
                                    localPoint.z + localNormal.z * 0.003)
        decal.look(at: SCNVector3(localPoint.x + localNormal.x, localPoint.y + localNormal.y, localPoint.z + localNormal.z),
                  up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, 1))
        decal.eulerAngles.z += CGFloat.random(in: 0...(2 * .pi))
        decal.opacity = 1
        glass.addChildNode(decal)
        windowCrackDecals.append(decal)
    }

    private func addStaticBox(
        name: String,
        size: SCNVector3,
        position: SCNVector3,
        surface: SCNMaterial
    ) -> SCNNode {
        let geometry = SCNBox(
            width: size.x,
            height: size.y,
            length: size.z,
            chamferRadius: 0.025
        )
        geometry.firstMaterial = surface
        let node = SCNNode(geometry: geometry)
        node.name = name
        node.position = position

        let shape = SCNPhysicsShape(geometry: geometry, options: nil)
        node.physicsBody = SCNPhysicsBody(type: .static, shape: shape)
        if let body = node.physicsBody {
            configureStaticBody(body, friction: 0.86, restitution: 0.04)
        }

        scene.rootNode.addChildNode(node)
        return node
    }

    private func makeRoom() {
        let floorMaterial = material(roomColor(), roughness: 0.88)
        addStaticBox(
            name: "Room floor",
            size: SCNVector3(20, 0.20, 18),
            position: SCNVector3(0, -0.10, 0),
            surface: floorMaterial
        )

        // Complete the enclosure. All four walls and the ceiling have static collision shapes.
        let wallMaterial = material(wallColor(), roughness: 0.95)
        let wallTexture = Bundle.main.url(forResource: "wall_plaster", withExtension: "png")
        wallMaterial.diffuse.contents = wallTexture.flatMap { NSImage(contentsOf: $0) } ?? wallColor()
        wallMaterial.multiply.contents = wallColor()
        wallMaterial.diffuse.wrapS = .repeat
        wallMaterial.diffuse.wrapT = .repeat
        wallMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(4, 3, 1)
        wallMaterial.roughness.contents = 0.94
        if let normal = Bundle.main.url(forResource: "wall_plaster_normal", withExtension: "png") {
            wallMaterial.normal.contents = NSImage(contentsOf: normal)
            wallMaterial.normal.intensity = 0.42
        }

        // Back wall has a real opening for the window; the grass backdrop sits outside it.
        let boundaries: [(String, SCNVector3, SCNVector3)] = [
            ("Back wall left", SCNVector3(8.69, 7, 0.22), SCNVector3(-5.655, 3.50, -8.90)),
            ("Back wall right", SCNVector3(8.69, 7, 0.22), SCNVector3(5.655, 3.50, -8.90)),
            ("Back wall below window", SCNVector3(2.62, 1.64, 0.22), SCNVector3(0, 0.82, -8.90)),
            ("Back wall above window", SCNVector3(2.62, 3.59, 0.22), SCNVector3(0, 5.205, -8.90)),
            ("Front wall", SCNVector3(20, 7, 0.22), SCNVector3(0, 3.50, 8.90)),
            ("Left wall", SCNVector3(0.22, 7, 18), SCNVector3(-9.90, 3.50, 0)),
            ("Right wall", SCNVector3(0.22, 7, 18), SCNVector3(9.90, 3.50, 0)),
            ("Ceiling", SCNVector3(20, 0.20, 18), SCNVector3(0, 7.10, 0))
        ]

        for (name, size, position) in boundaries {
            addStaticBox(name: name, size: size, position: position, surface: wallMaterial)
        }

        if let carpetURL = Bundle.main.url(forResource: "carpet_woven", withExtension: "png"),
           let carpetImage = NSImage(contentsOf: carpetURL) {
            let carpetMaterial = SCNMaterial()
            carpetMaterial.diffuse.contents = carpetImage
            carpetMaterial.diffuse.wrapS = .repeat
            carpetMaterial.diffuse.wrapT = .repeat
            carpetMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(12, 10, 1)
            carpetMaterial.roughness.contents = 0.98
            if let normal = Bundle.main.url(forResource: "carpet_woven_normal", withExtension: "png") {
                carpetMaterial.normal.contents = NSImage(contentsOf: normal)
                carpetMaterial.normal.intensity = 0.58
            }
            let carpet = SCNNode(geometry: SCNPlane(width: 19.8, height: 17.8))
            carpet.name = "Woven room carpet"
            carpet.geometry?.firstMaterial = carpetMaterial
            carpet.eulerAngles.x = -.pi / 2
            carpet.position = SCNVector3(0, 0.008, 0)
            scene.rootNode.addChildNode(carpet)
        }

        makeGrassField()
    }

    private func makeGrassField() {
        // A textured ground plane gives the same outdoor backdrop without hundreds
        // of separate grass-blade nodes.
        let groundMaterial = material(NSColor(calibratedRed: 0.105, green: 0.25, blue: 0.075, alpha: 1), roughness: 0.98)
        if let texture = Bundle.main.url(forResource: "grass_outside", withExtension: "png") {
            groundMaterial.diffuse.contents = NSImage(contentsOf: texture)
            groundMaterial.diffuse.wrapS = .repeat
            groundMaterial.diffuse.wrapT = .repeat
            groundMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(4, 4, 1)
        }
        let ground = SCNNode(geometry: SCNPlane(width: 28, height: 24))
        ground.name = "Outdoor grass ground"
        ground.geometry?.firstMaterial = groundMaterial
        ground.eulerAngles.x = -.pi / 2
        ground.position = SCNVector3(0, -0.20, -18.5)
        scene.rootNode.addChildNode(ground)
        let moundMaterial = material(NSColor(calibratedRed: 0.16, green: 0.32, blue: 0.08, alpha: 1), roughness: 1)
        for index in 0..<3 {
            let mound = SCNSphere(radius: 1)
            mound.firstMaterial = moundMaterial
            let node = SCNNode(geometry: mound)
            node.name = "Distant grassy mound"
            node.scale = SCNVector3(3.0, 0.20, 0.7)
            node.position = SCNVector3(-7 + CGFloat(index) * 7, -0.18, -27)
            scene.rootNode.addChildNode(node)
        }
    }

    private func makeRoomDressing() {
        let trim = material(NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.14, alpha: 1), roughness: 0.55)
        let cabinet = material(NSColor(calibratedRed: 0.22, green: 0.25, blue: 0.27, alpha: 1), roughness: 0.74)
        let accent = material(NSColor(calibratedRed: 0.12, green: 0.40, blue: 0.48, alpha: 1), roughness: 0.42)
        addStaticBox(name: "Front wall baseboard", size: SCNVector3(19.7, 0.16, 0.10), position: SCNVector3(0, 0.10, 8.76), surface: trim)
        addStaticBox(name: "Left wall baseboard", size: SCNVector3(0.10, 0.16, 17.7), position: SCNVector3(-9.76, 0.10, 0), surface: trim)
        addStaticBox(name: "Right wall baseboard", size: SCNVector3(0.10, 0.16, 17.7), position: SCNVector3(9.76, 0.10, 0), surface: trim)
        let cabinetBody = addStaticBox(name: "Breakable storage cabinet carcass", size: SCNVector3(1.75, 2.10, 0.72), position: SCNVector3(-7.75, 1.05, -5.65), surface: cabinet)
        roomBreakables.append(cabinetBody)
        for x: CGFloat in [-8.18, -7.32] {
            let door = addStaticBox(name: "Breakable cabinet door", size: SCNVector3(0.82, 1.98, 0.045), position: SCNVector3(x, 1.05, -5.265), surface: trim)
            roomBreakables.append(door)
            let knob = SCNNode(geometry: SCNSphere(radius: 0.045))
            knob.name = "Cabinet knob"
            knob.geometry?.firstMaterial = accent
            knob.position = SCNVector3(x + (x < -7.7 ? 0.30 : -0.30), 1.05, -5.21)
            scene.rootNode.addChildNode(knob)
        }
        for level in 0..<2 {
            let shelf = addStaticBox(name: "Breakable wall storage shelf", size: SCNVector3(0.62, 0.12, 4.25),
                                     position: SCNVector3(-9.48, 3.15 + CGFloat(level) * 1.05, -1.65), surface: cabinet)
            roomBreakables.append(shelf)
            for item in 0..<4 {
                let bin = addStaticBox(name: "Breakable storage bin", size: SCNVector3(0.34, 0.26, 0.42),
                                       position: SCNVector3(-9.42, 3.34 + CGFloat(level) * 1.05, -3.15 + CGFloat(item) * 0.98),
                                       surface: storageBinMaterial(item))
                roomBreakables.append(bin)
            }
        }
        let pegboard = addStaticBox(name: "Breakable workshop pegboard", size: SCNVector3(0.08, 2.65, 4.15),
                                    position: SCNVector3(9.72, 3.65, -1.45), surface: cabinet)
        roomBreakables.append(pegboard)
        // Keep the pegboard as one textured panel; hundreds of tiny hole meshes
        // were expensive to render and added no meaningful interaction.
        for index in 0..<5 {
            let hook = SCNNode(geometry: SCNTorus(ringRadius: 0.09, pipeRadius: 0.018))
            hook.name = "Workshop peg hook"
            hook.geometry?.firstMaterial = accent
            hook.position = SCNVector3(9.60, 3.25 + CGFloat(index % 2) * 0.48, -2.75 + CGFloat(index) * 0.70)
            hook.eulerAngles.y = .pi / 2
            scene.rootNode.addChildNode(hook)
        }
        let diffuser = SCNNode(geometry: SCNBox(width: 3.6, height: 0.06, length: 1.25, chamferRadius: 0.08))
        diffuser.name = "Ceiling LED diffuser"
        let diffuserMaterial = material(NSColor(calibratedRed: 0.82, green: 0.88, blue: 0.92, alpha: 1), roughness: 0.18)
        diffuserMaterial.emission.contents = NSColor(calibratedRed: 0.58, green: 0.72, blue: 0.82, alpha: 1)
        diffuser.geometry?.firstMaterial = diffuserMaterial
        diffuser.position = SCNVector3(0, 6.92, 0)
        scene.rootNode.addChildNode(diffuser)
        let practical = SCNNode()
        practical.light = SCNLight()
        practical.light?.type = .area
        practical.light?.intensity = 520
        practical.light?.castsShadow = false
        practical.position = SCNVector3(0, 6.75, 0)
        scene.rootNode.addChildNode(practical)

        // Breakable room props: chair frame, crate stack, lamp and storage speaker.
        let wood = material(NSColor(calibratedRed: 0.31, green: 0.19, blue: 0.11, alpha: 1), roughness: 0.84)
        let chairSeat = addStaticBox(name: "Breakable chair seat", size: SCNVector3(1.05, 0.14, 1.02), position: SCNVector3(-5.9, 0.78, 1.4), surface: wood)
        roomBreakables.append(chairSeat)
        for x: CGFloat in [-6.32, -5.48] {
            for z: CGFloat in [1.02, 1.78] {
                let leg = addStaticBox(name: "Breakable chair leg", size: SCNVector3(0.10, 0.76, 0.10), position: SCNVector3(x, 0.38, z), surface: trim)
                roomBreakables.append(leg)
            }
        }
        let chairBack = addStaticBox(name: "Breakable chair back", size: SCNVector3(1.05, 0.92, 0.12), position: SCNVector3(-5.9, 1.30, 1.88), surface: wood)
        roomBreakables.append(chairBack)
        for index in 0..<3 {
            let crate = addStaticBox(name: "Breakable storage crate \(index + 1)",
                size: SCNVector3(0.82, 0.72, 0.78),
                position: SCNVector3(6.6 + CGFloat(index % 2) * 0.92, 0.36 + CGFloat(index / 2) * 0.74, -5.6),
                surface: storageBinMaterial(index))
            roomBreakables.append(crate)
        }
        let speaker = addStaticBox(name: "Breakable room speaker", size: SCNVector3(0.72, 1.10, 0.54),
                                   position: SCNVector3(7.65, 0.55, 2.1), surface: trim)
        roomBreakables.append(speaker)
        let lampBase = addStaticBox(name: "Breakable floor lamp base", size: SCNVector3(0.62, 0.10, 0.62),
                                    position: SCNVector3(-7.1, 0.05, 2.4), surface: metalMaterial())
        roomBreakables.append(lampBase)
        let lampStem = addStaticBox(name: "Breakable floor lamp stem", size: SCNVector3(0.075, 1.85, 0.075),
                                    position: SCNVector3(-7.1, 1.0, 2.4), surface: trim)
        roomBreakables.append(lampStem)
    }

    private func metalMaterial() -> SCNMaterial {
        material(NSColor(calibratedWhite: 0.48, alpha: 1), roughness: 0.30)
    }

    private func storageBinMaterial(_ index: Int) -> SCNMaterial {
        let colors = [
            NSColor(calibratedRed: 0.28, green: 0.37, blue: 0.42, alpha: 1),
            NSColor(calibratedRed: 0.46, green: 0.32, blue: 0.18, alpha: 1),
            NSColor(calibratedRed: 0.20, green: 0.31, blue: 0.25, alpha: 1),
            NSColor(calibratedRed: 0.38, green: 0.39, blue: 0.42, alpha: 1)
        ]
        return material(colors[index % colors.count], roughness: 0.72)
    }

    private func makeDesk() {
        let wood = material(
            NSColor(calibratedRed: 0.30, green: 0.20, blue: 0.13, alpha: 1),
            roughness: 0.84
        )
        if let texture = Bundle.main.url(forResource: "wood_grain", withExtension: "png"),
           let image = NSImage(contentsOf: texture) {
            wood.diffuse.contents = image
            wood.diffuse.wrapS = .repeat
            wood.diffuse.wrapT = .repeat
            wood.diffuse.contentsTransform = SCNMatrix4MakeScale(3, 2, 1)
        }
        if let normal = Bundle.main.url(forResource: "wood_grain_normal", withExtension: "png") {
            wood.normal.contents = NSImage(contentsOf: normal)
            wood.normal.intensity = 0.32
        }
        let darkMetal = material(
            NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.18, alpha: 1),
            roughness: 0.46
        )
        let brushedMetal = material(
            NSColor(calibratedRed: 0.48, green: 0.53, blue: 0.58, alpha: 1),
            roughness: 0.30
        )

        // Four independent timber panels with visible seams and separate physics bodies.
        deskBreakablePanels.removeAll()
        deskPanelDamage.removeAll()
        for index in 0..<4 {
            let width: CGFloat = 1.885
            let x = -2.8575 + CGFloat(index) * 1.905
            let panel = addStaticBox(
                name: "Workbench tabletop panel \(index + 1)",
                size: SCNVector3(width, 0.22, 4.6),
                position: SCNVector3(x, deskTopY, 0),
                surface: wood
            )
            deskBreakablePanels.append(panel)
        }

        // Four collidable supports, with the top of each leg tucked under the tabletop.
        for x: CGFloat in [-3.35, 3.35] {
            for z: CGFloat in [-1.95, 1.95] {
                addStaticBox(
                    name: "Workbench leg",
                    size: SCNVector3(0.18, 1.26, 0.18),
                    position: SCNVector3(x, 0.63, z),
                    surface: darkMetal
                )
            }
        }

        // Front, rear and side rails tie the frame together.
        addStaticBox(
            name: "Desk front apron",
            size: SCNVector3(6.55, 0.28, 0.14),
            position: SCNVector3(0, 1.02, 2.12),
            surface: darkMetal
        )
        addStaticBox(
            name: "Desk rear apron",
            size: SCNVector3(6.55, 0.28, 0.14),
            position: SCNVector3(0, 1.02, -2.12),
            surface: darkMetal
        )
        for x: CGFloat in [-3.22, 3.22] {
            addStaticBox(
                name: "Desk side apron",
                size: SCNVector3(0.14, 0.28, 3.95),
                position: SCNVector3(x, 1.02, 0),
                surface: darkMetal
            )
        }

        // Two separate drawer boxes and their visible front panels.
        for x: CGFloat in [-1.30, 1.30] {
            addStaticBox(
                name: "Workbench drawer",
                size: SCNVector3(1.48, 0.38, 1.08),
                position: SCNVector3(x, 0.88, 1.12),
                surface: wood
            )
            addStaticBox(
                name: "Drawer front",
                size: SCNVector3(1.48, 0.34, 0.07),
                position: SCNVector3(x, 0.89, 1.69),
                surface: brushedMetal
            )

            let pull = SCNNode(
                geometry: SCNCylinder(radius: 0.035, height: 0.42)
            )
            pull.name = "Drawer pull"
            pull.position = SCNVector3(x, 0.90, 1.75)
            pull.eulerAngles.z = .pi / 2
            pull.geometry?.firstMaterial = brushedMetal
            let pullGeometry = pull.geometry!
            pull.physicsBody = SCNPhysicsBody(
                type: .static,
                shape: SCNPhysicsShape(geometry: pullGeometry, options: nil)
            )
            if let body = pull.physicsBody {
                configureStaticBody(body, friction: 0.78, restitution: 0.03)
            }
            scene.rootNode.addChildNode(pull)
        }

        // Small raised rear lip keeps loose props from sliding off the back.
        addStaticBox(
            name: "Workbench rear lip",
            size: SCNVector3(7.2, 0.18, 0.12),
            position: SCNVector3(0, deskTopY + 0.19, -2.20),
            surface: darkMetal
        )
    }

    // SceneKit's built-in orbit controller remains enabled, but its camera node is clamped
    // every frame to a safe inset of the room volume.
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let camera = renderer.pointOfView else { return }

        let current = camera.position
        let minX: CGFloat = -cameraBounds.x
        let maxX: CGFloat = cameraBounds.x
        let minY: CGFloat = 0.65
        let maxY: CGFloat = cameraBounds.y
        let minZ: CGFloat = -cameraBounds.z
        let maxZ: CGFloat = cameraBounds.z
        let x = Swift.min(maxX, Swift.max(minX, current.x))
        let y = Swift.min(maxY, Swift.max(minY, current.y))
        let z = Swift.min(maxZ, Swift.max(minZ, current.z))
        let clamped = SCNVector3(x, y, z)

        if current.x != clamped.x || current.y != clamped.y || current.z != clamped.z {
            camera.position = clamped
        }
    }

    // A small rigid-body stack makes resting contacts, friction and bounce
    // visible without tying the simulation to tool-driven damage.
    private func makePhysicsProps() {
        let baseY = deskTopY + 0.11
        let blockMaterials: [SCNMaterial] = [
            material(NSColor(calibratedRed: 0.20, green: 0.62, blue: 0.92, alpha: 1), roughness: 0.62),
            material(NSColor(calibratedRed: 0.28, green: 0.78, blue: 0.58, alpha: 1), roughness: 0.70),
            material(NSColor(calibratedRed: 0.92, green: 0.62, blue: 0.24, alpha: 1), roughness: 0.55)
        ]

        for index in 0..<3 {
            let side: CGFloat = 0.48
            let geometry = SCNBox(width: side, height: side, length: side, chamferRadius: 0.035)
            geometry.firstMaterial = blockMaterials[index]
            let block = SCNNode(geometry: geometry)
            block.name = "Physics stack block \(index + 1)"
            block.position = SCNVector3(2.55, baseY + side * (CGFloat(index) + 0.5), -1.05)
            let shape = SCNPhysicsShape(geometry: geometry, options: nil)
            block.physicsBody = SCNPhysicsBody(type: .dynamic, shape: shape)
            if let body = block.physicsBody {
                let profiles: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                    (0.72, 0.88, 0.025, 0.82),
                    (0.86, 0.78, 0.045, 0.76),
                    (1.05, 0.70, 0.075, 0.70)
                ]
                let profile = profiles[index]
                configureDynamicBody(
                    body,
                    mass: profile.0,
                    friction: profile.1,
                    restitution: profile.2,
                    angularDamping: profile.3
                )
            }
            scene.rootNode.addChildNode(block)
        }

        let sphereGeometry = SCNSphere(radius: 0.20)
        sphereGeometry.firstMaterial = material(
            NSColor(calibratedRed: 0.72, green: 0.38, blue: 0.88, alpha: 1),
            roughness: 0.32
        )
        let sphere = SCNNode(geometry: sphereGeometry)
        sphere.name = "Physics rolling sphere"
        sphere.position = SCNVector3(2.55, baseY + 0.24, 0.10)
        sphere.physicsBody = SCNPhysicsBody(
            type: .dynamic,
            shape: SCNPhysicsShape(geometry: sphereGeometry, options: nil)
        )
        if let body = sphere.physicsBody {
            configureDynamicBody(body, mass: 0.34, friction: 0.42, restitution: 0.16, angularDamping: 0.24)
        }
        scene.rootNode.addChildNode(sphere)
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
        m.lightingModel = .physicallyBased
        m.roughness.contents = roughness
        m.metalness.contents = roughness < 0.34 ? 0.28 : 0.045
        return m
    }

    private func makeDevice() {
        deviceRoot?.removeFromParentNode()
        detachedDeviceParts.forEach { $0.removeFromParentNode() }
        detachedDeviceParts.removeAll()
        devicePartDamage.removeAll()
        roomPropDamage.removeAll()
        physicsBlockDamage.removeAll()
        surfaceDamageMarks.forEach { $0.removeFromParentNode() }
        surfaceDamageMarks.removeAll()
        breakableComponents.removeAll()
        internalParts.removeAll()
        deviceShellParts.removeAll()
        let root = SCNNode()
        root.name = "Selected device body"
        let dark = material(NSColor(calibratedWhite: 0.075, alpha: 1), roughness: 0.24)
        let metal = material(NSColor(calibratedWhite: 0.48, alpha: 1), roughness: 0.28)
        let glass = material(NSColor(calibratedRed: 0.025, green: 0.045, blue: 0.075, alpha: 1), roughness: 0.08)

        func box(_ w: CGFloat, _ h: CGFloat, _ d: CGFloat, _ mat: SCNMaterial, _ pos: SCNVector3, _ chamfer: CGFloat = 0.08) -> SCNNode {
            let n = SCNNode(geometry: SCNBox(width: w, height: h, length: d, chamferRadius: chamfer))
            n.geometry?.firstMaterial = mat
            n.position = pos
            return n
        }
        func addShell(_ node: SCNNode) {
            deviceShellParts.append(node)
            root.addChildNode(node)
        }
        func addShellBox(_ name: String, _ size: SCNVector3, _ pos: SCNVector3, _ surface: SCNMaterial, _ chamfer: CGFloat = 0.02) {
            let node = box(size.x, size.y, size.z, surface, pos, chamfer)
            node.name = name
            addShell(node)
        }
        @discardableResult
        func addShellBoxNode(_ name: String, _ size: SCNVector3, _ pos: SCNVector3, _ surface: SCNMaterial, _ chamfer: CGFloat = 0.02) -> SCNNode {
            let node = box(size.x, size.y, size.z, surface, pos, chamfer)
            node.name = name
            addShell(node)
            return node
        }
        func addShellCylinder(_ name: String, radius: CGFloat, height: CGFloat, position: SCNVector3, surface: SCNMaterial) {
            let geometry = SCNCylinder(radius: radius, height: height)
            geometry.firstMaterial = surface
            let node = SCNNode(geometry: geometry)
            node.name = name
            node.position = position
            addShell(node)
        }
        func addShellSphere(_ name: String, radius: CGFloat, position: SCNVector3, surface: SCNMaterial) {
            let geometry = SCNSphere(radius: radius)
            geometry.firstMaterial = surface
            let node = SCNNode(geometry: geometry)
            node.name = name
            node.position = position
            addShell(node)
        }
        func addInternalBox(_ name: String, _ size: SCNVector3, _ pos: SCNVector3, _ color: NSColor, _ roughness: CGFloat = 0.48) {
            let node = box(size.x, size.y, size.z, material(color, roughness: roughness), pos, 0.025)
            node.name = name
            node.isHidden = !showingInternals
            internalParts.append(node)
            root.addChildNode(node)
        }
        func addInternalCylinder(_ name: String, radius: CGFloat, height: CGFloat, position: SCNVector3, color: NSColor) {
            let geometry = SCNCylinder(radius: radius, height: height)
            geometry.firstMaterial = material(color, roughness: 0.38)
            let node = SCNNode(geometry: geometry)
            node.name = name
            node.position = position
            node.isHidden = !showingInternals
            internalParts.append(node)
            root.addChildNode(node)
        }

        switch selectedDevice {
        case "MacBook":
            addShell(box(3.0, 0.16, 2.0, metal, SCNVector3(0, 0.12, 0)))
            root.addChildNode(box(2.88, 0.035, 1.88, dark, SCNVector3(0, 0.215, 0)))
            let display = box(2.85, 1.85, 0.12, metal, SCNVector3(0, 1.12, -0.90))
            display.eulerAngles.x = -0.10
            root.addChildNode(display)
            let screen = box(2.64, 1.62, 0.025, glass, SCNVector3(0, 1.13, -0.825))
            screen.name = "MacBook screen glass"
            screen.eulerAngles.x = -0.10
            root.addChildNode(screen)
            for row in 0..<4 { for col in 0..<12 {
                root.addChildNode(box(0.16, 0.018, 0.12, metal, SCNVector3(-1.25 + Float(col) * 0.23, 0.245, -0.62 + Float(row) * 0.18), 0.025))
            }}
            addShellBox("MacBook display bezel", SCNVector3(2.72, 1.70, 0.018), SCNVector3(0, 1.13, -0.846), dark, 0.035)
            addShellSphere("MacBook camera glass", radius: 0.022, position: SCNVector3(0, 1.98, -0.835), surface: metal)
            addShellBox("MacBook trackpad", SCNVector3(0.92, 0.018, 0.58), SCNVector3(0, 0.245, 0.47), dark, 0.06)
            addShellBox("MacBook palm rest seam", SCNVector3(2.62, 0.008, 0.012), SCNVector3(0, 0.238, 0.04), metal, 0.003)
            addShellBox("MacBook power key", SCNVector3(0.12, 0.018, 0.12), SCNVector3(1.22, 0.245, -0.76), dark, 0.025)
            addShellCylinder("MacBook hinge", radius: 0.052, height: 2.15, position: SCNVector3(0, 0.245, -0.88), surface: metal)
            if let hinge = root.childNodes.last { hinge.eulerAngles.z = .pi / 2 }
            addShellSphere("Display webcam", radius: 0.032, position: SCNVector3(0, 2.01, -0.79), surface: dark)
            for x: CGFloat in [-1.36, 1.36] {
                for i in 0..<10 {
                    addShellBox("Keyboard speaker perforation", SCNVector3(0.018, 0.008, 0.045),
                                SCNVector3(x, 0.235, -0.48 + CGFloat(i) * 0.105), dark, 0.006)
                }
            }
            for x: CGFloat in [-1.48, 1.48] {
                addShellBox("Laptop side port", SCNVector3(0.16, 0.055, 0.035), SCNVector3(x, 0.14, -0.35), dark, 0.012)
            }
        case "Desktop PC":
            let towerX: CGFloat = 2.52
            addShellBox("Desktop monitor rear housing", SCNVector3(3.0, 1.85, 0.16), SCNVector3(0, 1.25, -0.25), metal, 0.055)
            addShellBox("Desktop monitor glass", SCNVector3(2.78, 1.62, 0.035), SCNVector3(0, 1.25, -0.145), glass, 0.035)
            addShellBox("Desktop monitor stand neck", SCNVector3(0.24, 0.85, 0.24), SCNVector3(0, 0.48, -0.25), metal, 0.035)
            addShellBox("Desktop monitor stand foot", SCNVector3(1.25, 0.12, 0.65), SCNVector3(0, 0.12, -0.25), metal, 0.035)
            addShellBox("Monitor lower bezel control strip", SCNVector3(1.20, 0.035, 0.025), SCNVector3(0, 0.43, -0.12), dark, 0.012)
            for index in 0..<5 { addShellSphere("Monitor OSD button", radius: 0.018, position: SCNVector3(0.72 + CGFloat(index) * 0.075, 0.43, -0.105), surface: metal) }
            addShellSphere("Monitor status indicator", radius: 0.012, position: SCNVector3(-0.82, 0.43, -0.105), surface: metal)
            addShellBox("Desktop tower chassis", SCNVector3(0.82, 1.65, 0.8), SCNVector3(towerX, 0.85, 0.1), dark, 0.065)
            addShellBox("Desktop tower side glass", SCNVector3(0.68, 1.48, 0.03), SCNVector3(towerX, 0.85, 0.515), glass, 0.035)
            addShellBox("Desktop tower top panel", SCNVector3(0.76, 0.035, 0.72), SCNVector3(towerX, 1.69, 0.1), metal, 0.018)
            for y: CGFloat in [0.48, 1.12] {
                let fan = SCNNode(geometry: SCNTorus(ringRadius: 0.17, pipeRadius: 0.022))
                fan.name = "Desktop case fan ring"
                fan.geometry?.firstMaterial = metal
                fan.position = SCNVector3(towerX, y, 0.54)
                addShell(fan)
                addShellSphere("Desktop fan hub", radius: 0.055, position: SCNVector3(towerX, y, 0.56), surface: dark)
                for blade in 0..<7 {
                    let angle = CGFloat(blade) * (.pi * 2 / 7)
                    let vane = addShellBoxNode("Desktop fan blade", SCNVector3(0.025, 0.12, 0.012), SCNVector3(towerX + cos(angle) * 0.085, y + sin(angle) * 0.085, 0.555), metal, 0.008)
                    vane.eulerAngles.z = angle
                }
            }
            addShellSphere("Desktop power button", radius: 0.045, position: SCNVector3(2.52, 1.57, 0.55), surface: metal)
            for x: CGFloat in [1.76, 2.34] {
                for z: CGFloat in [-0.20, 0.40] {
                    addShellBox("Desktop case foot", SCNVector3(0.12, 0.08, 0.12), SCNVector3(x, 0.025, z), dark)
                }
            }
        case "PC Tower":
            addShellBox("PC tower chassis", SCNVector3(1.02, 1.82, 1.02), SCNVector3(0, 0.91, 0), dark, 0.075)
            addShellBox("PC tower tempered glass side", SCNVector3(0.92, 1.62, 0.025), SCNVector3(0, 0.91, 0.525), glass, 0.035)
            addShellBox("PC tower top panel", SCNVector3(0.96, 0.045, 0.94), SCNVector3(0, 1.84, 0), metal, 0.025)
            for y: CGFloat in [0.50, 1.20] {
                let fan = SCNNode(geometry: SCNTorus(ringRadius: 0.19, pipeRadius: 0.022))
                fan.name = "PC tower cooling fan ring"
                fan.geometry?.firstMaterial = metal
                fan.position = SCNVector3(0, y, 0.545)
                addShell(fan)
                addShellSphere("PC tower fan hub", radius: 0.052, position: SCNVector3(0, y, 0.56), surface: dark)
            }
            addShellBox("PC tower front I/O panel", SCNVector3(0.34, 0.16, 0.025), SCNVector3(0, 1.62, 0.525), dark, 0.02)
            for x: CGFloat in [-0.10, 0.10] {
                addShellBox("PC tower USB port", SCNVector3(0.055, 0.035, 0.018), SCNVector3(x, 1.62, 0.544), metal, 0.006)
            }
            for x: CGFloat in [-0.38, 0.38] {
                for z: CGFloat in [-0.38, 0.38] {
                    addShellBox("PC tower foot", SCNVector3(0.16, 0.07, 0.16), SCNVector3(x, 0.035, z), dark, 0.02)
                }
            }
        case "Engine":
            addShellBox("Engine crankcase", SCNVector3(1.58, 0.78, 1.10), SCNVector3(0, 0.62, 0), metal, 0.10)
            addShellBox("Engine cylinder head", SCNVector3(1.42, 0.36, 0.92), SCNVector3(0, 1.16, 0), dark, 0.08)
            addShellBox("Engine valve cover", SCNVector3(1.24, 0.18, 0.76), SCNVector3(0, 1.43, 0), metal, 0.07)
            addShellBox("Engine oil pan", SCNVector3(1.24, 0.22, 0.84), SCNVector3(0, 0.16, 0), dark, 0.06)
            addShellBox("Engine intake manifold", SCNVector3(0.92, 0.30, 0.52), SCNVector3(0, 1.48, -0.56), metal, 0.06)
            addShellBox("Engine exhaust manifold", SCNVector3(1.12, 0.22, 0.36), SCNVector3(0, 0.94, 0.60), dark, 0.04)
            for x: CGFloat in [-0.48, -0.16, 0.16, 0.48] {
                addShellCylinder("Engine ignition coil", radius: 0.075, height: 0.24,
                                 position: SCNVector3(x, 1.57, 0.02), surface: dark)
            }
            let pulley = SCNNode(geometry: SCNCylinder(radius: 0.30, height: 0.13))
            pulley.name = "Engine crank pulley"
            pulley.geometry?.firstMaterial = metal
            pulley.position = SCNVector3(0.72, 0.50, 0.58)
            pulley.eulerAngles.x = .pi / 2
            addShell(pulley)
            addShellCylinder("Engine alternator housing", radius: 0.22, height: 0.32,
                             position: SCNVector3(-0.72, 0.72, 0.50), surface: metal)
        case "TV":
            addShellBox("TV rear housing", SCNVector3(3.82, 2.38, 0.20), SCNVector3(0, 1.20, 0), dark, 0.12)
            addShellBox("TV front bezel", SCNVector3(3.84, 2.40, 0.095), SCNVector3(0, 1.20, 0.105), metal, 0.12)
            addShellBox("TV display glass", SCNVector3(3.58, 2.08, 0.035), SCNVector3(0, 1.22, 0.17), glass, 0.025)
            addShellBox("TV lower chin", SCNVector3(3.80, 0.13, 0.10), SCNVector3(0, 0.10, 0.12), dark, 0.025)
            addShellBox("TV stand neck", SCNVector3(0.18, 0.42, 0.22), SCNVector3(0, 0.22, -0.03), metal, 0.035)
            addShellBox("TV stand foot", SCNVector3(1.15, 0.075, 0.55), SCNVector3(0, 0.035, 0.02), dark, 0.035)
            for x: CGFloat in [-1.72, 1.72] {
                for i in 0..<18 {
                    addShellBox("TV speaker grille", SCNVector3(0.018, 0.012, 0.035),
                                SCNVector3(x, 0.105, 0.18 + CGFloat(i) * 0.018), metal, 0.004)
                }
            }
            addShellSphere("TV status LED", radius: 0.018, position: SCNVector3(1.78, 0.11, 0.18), surface: metal)
            for x: CGFloat in [-1.2, -0.8, 0.8, 1.2] {
                addShellBox("TV rear ventilation slot", SCNVector3(0.28, 0.018, 0.035),
                            SCNVector3(x, 2.25, -0.11), metal, 0.006)
            }
            for i in 0..<4 {
                addShellBox("TV input port", SCNVector3(0.12, 0.055, 0.045),
                            SCNVector3(-1.2 + CGFloat(i) * 0.22, 0.28, -0.12), metal, 0.01)
            }
        case "iPad":
            root.addChildNode(box(2.25, 0.12, 3.0, metal, SCNVector3(0, 0.22, 0)))
            let tabletScreen = box(2.08, 0.035, 2.78, glass, SCNVector3(0, 0.30, 0))
            tabletScreen.name = "Tablet screen glass"
            root.addChildNode(tabletScreen)
            addShellSphere("Tablet rear camera lens", radius: 0.055, position: SCNVector3(0.82, 0.33, -1.24), surface: dark)
            addShellBox("Tablet charging port", SCNVector3(0.32, 0.045, 0.035), SCNVector3(0, 0.22, 1.50), dark)
            for i in 0..<8 {
                addShellBox("Tablet speaker perforation", SCNVector3(0.025, 0.012, 0.035),
                            SCNVector3(-0.70 + CGFloat(i) * 0.20, 0.30, 1.46), dark, 0.006)
            }
            addShellBox("Tablet front camera bezel", SCNVector3(0.13, 0.018, 0.045), SCNVector3(0, 0.31, -1.48), dark, 0.02)
            addShellSphere("Tablet front camera lens", radius: 0.025, position: SCNVector3(0.07, 0.32, -1.48), surface: metal)
            for side: CGFloat in [-1, 1] {
                addShellBox("Tablet volume rocker", SCNVector3(0.035, 0.055, 0.32), SCNVector3(side * 1.12, 0.24, -0.75), metal, 0.012)
            }
        case "Smartwatch":
            addShellBox("Smartwatch titanium case", SCNVector3(1.02, 0.24, 1.20), SCNVector3(0, 0.20, 0), metal, 0.16)
            addShellBox("Smartwatch OLED glass", SCNVector3(0.88, 0.035, 1.04), SCNVector3(0, 0.34, 0), glass, 0.13)
            addShellBox("Smartwatch crown", SCNVector3(0.10, 0.18, 0.12), SCNVector3(0.57, 0.22, -0.12), metal, 0.035)
            addShellBox("Smartwatch side button", SCNVector3(0.08, 0.12, 0.09), SCNVector3(0.57, 0.19, 0.18), dark, 0.025)
            let watchBandTop = box(0.62, 0.08, 0.60, dark, SCNVector3(0, 0.08, -0.84), 0.08)
            watchBandTop.name = "Watch upper strap"
            addShell(watchBandTop)
            let watchBandBottom = box(0.62, 0.08, 0.60, dark, SCNVector3(0, 0.08, 0.84), 0.08)
            watchBandBottom.name = "Watch lower strap"
            addShell(watchBandBottom)
            for i in 0..<5 { addShellBox("Watch strap pin", SCNVector3(0.035, 0.025, 0.035), SCNVector3(-0.20 + CGFloat(i) * 0.10, 0.13, 1.02), metal, 0.01) }
        case "Digital Camera":
            addShellBox("Camera magnesium body", SCNVector3(1.72, 1.02, 0.82), SCNVector3(0, 0.55, 0), dark, 0.13)
            addShellBox("Camera grip", SCNVector3(0.42, 0.88, 0.76), SCNVector3(-0.98, 0.55, 0.02), metal, 0.12)
            let lens = SCNNode(geometry: SCNCylinder(radius: 0.39, height: 0.58))
            lens.name = "Camera optical lens barrel"
            lens.geometry?.firstMaterial = metal
            lens.eulerAngles.x = .pi / 2
            lens.position = SCNVector3(0.12, 0.56, 0.56)
            addShell(lens)
            let lensGlass = SCNNode(geometry: SCNCylinder(radius: 0.30, height: 0.035))
            lensGlass.name = "Camera front glass"
            lensGlass.geometry?.firstMaterial = glass
            lensGlass.eulerAngles.x = .pi / 2
            lensGlass.position = SCNVector3(0.12, 0.56, 0.87)
            addShell(lensGlass)
            addShellBox("Camera top hot shoe", SCNVector3(0.48, 0.08, 0.22), SCNVector3(0.12, 1.10, -0.04), metal, 0.02)
            addShellBox("Camera rear LCD", SCNVector3(0.94, 0.56, 0.035), SCNVector3(0.12, 0.58, -0.43), glass, 0.035)
            addShellSphere("Camera shutter button", radius: 0.065, position: SCNVector3(-0.58, 1.08, 0.20), surface: metal)
        case "Game Console":
            addShellBox("Game console chassis", SCNVector3(2.72, 0.52, 2.10), SCNVector3(0, 0.32, 0), dark, 0.18)
            addShellBox("Console top vent panel", SCNVector3(1.70, 0.035, 1.55), SCNVector3(0.24, 0.60, -0.08), metal, 0.12)
            for row in 0..<5 { for col in 0..<12 {
                addShellBox("Console ventilation slot", SCNVector3(0.035, 0.012, 0.20), SCNVector3(-0.48 + CGFloat(col) * 0.13, 0.625, -0.62 + CGFloat(row) * 0.25), dark, 0.008)
            }}
            addShellBox("Console optical drive slot", SCNVector3(0.78, 0.025, 0.035), SCNVector3(0.78, 0.40, 1.055), metal, 0.01)
            addShellSphere("Console power button", radius: 0.055, position: SCNVector3(-1.12, 0.42, 1.06), surface: metal)
            addShellBox("Console front USB port", SCNVector3(0.18, 0.08, 0.025), SCNVector3(-0.78, 0.37, 1.065), metal, 0.01)
        case "Bluetooth Speaker":
            addShellCylinder("Speaker acoustic enclosure", radius: 0.58, height: 2.15, position: SCNVector3(0, 0.58, 0), surface: dark)
            addShellCylinder("Speaker end cap", radius: 0.55, height: 0.10, position: SCNVector3(0, 0.58, 1.08), surface: metal)
            for i in 0..<7 {
                let driver = SCNNode(geometry: SCNTorus(ringRadius: 0.12 + CGFloat(i % 3) * 0.055, pipeRadius: 0.012))
                driver.name = "Speaker driver trim"
                driver.geometry?.firstMaterial = metal
                driver.position = SCNVector3(-0.30 + CGFloat(i % 3) * 0.30, 0.58 + CGFloat(i / 3 - 1) * 0.25, 1.14)
                addShell(driver)
            }
            addShellBox("Speaker control strip", SCNVector3(0.52, 0.07, 0.035), SCNVector3(0, 1.17, 1.12), metal, 0.025)
        case "Earbuds Case":
            addShellBox("Earbuds charging case lower shell", SCNVector3(1.18, 0.42, 0.88), SCNVector3(0, 0.24, 0), dark, 0.18)
            addShellBox("Earbuds case lid", SCNVector3(1.16, 0.15, 0.84), SCNVector3(0, 0.53, -0.015), metal, 0.15)
            addShellBox("Earbuds case hinge", SCNVector3(0.82, 0.09, 0.12), SCNVector3(0, 0.45, -0.40), dark, 0.04)
            addShellSphere("Case status LED", radius: 0.025, position: SCNVector3(0, 0.24, 0.45), surface: metal)
            for x: CGFloat in [-0.28, 0.28] {
                addShellCylinder("Earbud stem", radius: 0.055, height: 0.34, position: SCNVector3(x, 0.70, 0.04), surface: metal)
                addShellSphere("Earbud head", radius: 0.12, position: SCNVector3(x, 0.83, 0.04), surface: dark)
            }
        default:
            root.addChildNode(box(1.25, 0.16, 2.45, metal, SCNVector3(0, 0.18, 0), 0.14))
            let phoneScreen = box(1.12, 0.035, 2.28, glass, SCNVector3(0, 0.28, 0), 0.12)
            phoneScreen.name = "Phone screen glass"
            root.addChildNode(phoneScreen)
            let speaker = SCNNode(geometry: SCNCylinder(radius: 0.045, height: 0.012))
            speaker.geometry?.firstMaterial = metal
            speaker.position = SCNVector3(0, 0.305, 1.02)
            root.addChildNode(speaker)
            addShellSphere("Phone rear camera lens one", radius: 0.060, position: SCNVector3(0.40, 0.105, -0.96), surface: dark)
            addShellSphere("Phone rear camera lens two", radius: 0.052, position: SCNVector3(0.25, 0.105, -0.82), surface: dark)
            addShellSphere("Phone flash", radius: 0.025, position: SCNVector3(0.51, 0.105, -0.80), surface: metal)
            let cameraRingA = SCNNode(geometry: SCNTorus(ringRadius: 0.070, pipeRadius: 0.010))
            cameraRingA.name = "Phone camera lens metal ring"
            cameraRingA.geometry?.firstMaterial = metal
            cameraRingA.position = SCNVector3(0.40, 0.105, -0.96)
            addShell(cameraRingA)
            let cameraRingB = SCNNode(geometry: SCNTorus(ringRadius: 0.061, pipeRadius: 0.008))
            cameraRingB.name = "Phone second camera lens ring"
            cameraRingB.geometry?.firstMaterial = metal
            cameraRingB.position = SCNVector3(0.25, 0.105, -0.82)
            addShell(cameraRingB)
            addShellBox("Phone earpiece grille", SCNVector3(0.22, 0.012, 0.025), SCNVector3(0, 0.305, -1.12), dark, 0.01)
            addShellSphere("Phone front camera", radius: 0.025, position: SCNVector3(0.22, 0.305, -1.12), surface: dark)
            addShellBox("Phone charging port", SCNVector3(0.26, 0.035, 0.025), SCNVector3(0, 0.18, 1.23), dark, 0.01)
            for side: CGFloat in [-1, 1] {
                addShellBox("Phone side button", SCNVector3(0.035, 0.07, 0.22), SCNVector3(side * 0.635, 0.20, -0.30), metal, 0.012)
            }
            for i in 0..<8 {
                addShellBox("Phone speaker perforation", SCNVector3(0.025, 0.010, 0.035),
                            SCNVector3(-0.14 + CGFloat(i) * 0.04, 0.305, 1.02), dark, 0.005)
            }
        }
        deviceShellParts = root.childNodes
        deviceShellParts.forEach { $0.isHidden = showingInternals }

        // Layered, stylized internal assemblies are separate scene nodes so the
        // casing can be hidden for an inspection view without changing the body physics.
        let board = NSColor(calibratedRed: 0.035, green: 0.20, blue: 0.16, alpha: 1)
        let copper = NSColor(calibratedRed: 0.72, green: 0.39, blue: 0.16, alpha: 1)
        let graphite = NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.17, alpha: 1)
        let silver = NSColor(calibratedWhite: 0.68, alpha: 1)
        switch selectedDevice {
        case "MacBook":
            addInternalBox("MacBook logic board", SCNVector3(1.42, 0.045, 0.48), SCNVector3(0, 0.34, -0.55), board)
            addInternalBox("MacBook battery pack", SCNVector3(2.18, 0.055, 0.62), SCNVector3(0, 0.34, 0.48), graphite)
            addInternalBox("MacBook SSD module", SCNVector3(0.72, 0.035, 0.20), SCNVector3(0.42, 0.39, -0.72), silver)
            for x: CGFloat in [-0.48, 0.48] {
                addInternalCylinder("Cooling fan", radius: 0.22, height: 0.07, position: SCNVector3(x, 0.39, -0.50), color: graphite)
                addInternalBox("Heat pipe", SCNVector3(0.10, 0.035, 0.62), SCNVector3(x * 0.55, 0.41, -0.12), copper)
            }
            for i in 0..<6 {
                addInternalBox("Memory and power component", SCNVector3(0.12, 0.04, 0.08), SCNVector3(-0.55 + CGFloat(i) * 0.22, 0.40, -0.70), copper)
            }
        case "Desktop PC":
            let towerX: CGFloat = 2.52
            addInternalBox("PC motherboard", SCNVector3(0.62, 1.25, 0.045), SCNVector3(towerX, 0.86, 0.02), board)
            addInternalBox("Graphics card", SCNVector3(0.56, 0.20, 0.66), SCNVector3(towerX, 0.55, 0.12), graphite)
            addInternalBox("CPU heatsink", SCNVector3(0.30, 0.20, 0.30), SCNVector3(towerX, 1.03, 0.12), silver)
            addInternalBox("Power supply", SCNVector3(0.60, 0.30, 0.62), SCNVector3(towerX, 0.28, 0.10), graphite)
            for i in 0..<4 {
                addInternalBox("RAM module", SCNVector3(0.07, 0.48, 0.045), SCNVector3(towerX - 0.40 + CGFloat(i) * 0.12, 0.90, 0.06), copper)
            }
            for y: CGFloat in [0.48, 1.10] {
                addInternalCylinder("Case fan", radius: 0.25, height: 0.06, position: SCNVector3(towerX, y, 0.32), color: graphite)
            }
        case "PC Tower":
            addInternalBox("PC tower motherboard", SCNVector3(0.72, 1.34, 0.05), SCNVector3(0, 0.94, 0.18), board)
            addInternalBox("PC tower graphics card", SCNVector3(0.68, 0.18, 0.72), SCNVector3(0, 0.58, -0.12), graphite)
            addInternalBox("PC tower power supply", SCNVector3(0.78, 0.28, 0.72), SCNVector3(0, 0.24, -0.08), graphite)
            addInternalBox("PC tower CPU heatsink", SCNVector3(0.34, 0.18, 0.34), SCNVector3(0.10, 1.20, 0.12), silver)
            for i in 0..<4 {
                addInternalBox("PC tower RAM module", SCNVector3(0.075, 0.52, 0.045),
                               SCNVector3(-0.34 + CGFloat(i) * 0.12, 1.00, 0.22), copper)
            }
            addInternalCylinder("PC tower cooling fan", radius: 0.24, height: 0.07,
                                position: SCNVector3(0, 1.35, 0.36), color: graphite)
        case "Engine":
            addInternalBox("Engine block inner casting", SCNVector3(1.30, 0.62, 0.88), SCNVector3(0, 0.65, 0), graphite)
            addInternalBox("Engine cylinder bank", SCNVector3(1.18, 0.34, 0.74), SCNVector3(0, 1.12, 0), silver)
            addInternalBox("Engine crankshaft assembly", SCNVector3(1.18, 0.12, 0.16), SCNVector3(0, 0.56, 0.05), copper)
            addInternalBox("Engine timing assembly", SCNVector3(0.22, 0.62, 0.10), SCNVector3(0.72, 0.70, 0.42), graphite)
            addInternalBox("Engine oil pump", SCNVector3(0.30, 0.20, 0.24), SCNVector3(-0.48, 0.28, 0.30), silver)
            addInternalBox("Engine coolant pump", SCNVector3(0.26, 0.22, 0.20), SCNVector3(-0.70, 0.78, 0.48), copper)
            for x: CGFloat in [-0.48, -0.16, 0.16, 0.48] {
                addInternalCylinder("Engine piston", radius: 0.105, height: 0.20,
                                    position: SCNVector3(x, 1.02, 0.02), color: silver)
                addInternalCylinder("Engine valve spring", radius: 0.035, height: 0.12,
                                    position: SCNVector3(x, 1.36, 0.10), color: copper)
            }
            addInternalBox("Engine accessory drive", SCNVector3(0.16, 0.54, 0.08), SCNVector3(-0.78, 0.80, 0.40), graphite)
        case "TV":
            addInternalBox("TV main logic board", SCNVector3(1.12, 0.055, 0.52), SCNVector3(0.82, 0.72, -0.02), board)
            addInternalBox("TV power supply board", SCNVector3(0.72, 0.045, 0.58), SCNVector3(-0.98, 0.64, -0.02), board)
            addInternalBox("TV backlight driver", SCNVector3(0.42, 0.035, 0.30), SCNVector3(-1.45, 0.90, -0.02), copper)
            addInternalBox("TV speaker left", SCNVector3(0.22, 0.12, 0.38), SCNVector3(-1.62, 0.35, -0.01), graphite)
            addInternalBox("TV speaker right", SCNVector3(0.22, 0.12, 0.38), SCNVector3(1.62, 0.35, -0.01), graphite)
            addInternalBox("TV LCD panel stack", SCNVector3(3.48, 1.98, 0.045), SCNVector3(0, 1.22, 0.06), silver)
            for i in 0..<8 {
                addInternalBox("TV LED backlight strip", SCNVector3(0.025, 1.78, 0.035),
                               SCNVector3(-1.48 + CGFloat(i) * 0.42, 1.22, -0.01), copper)
            }
            addInternalBox("TV ribbon cable", SCNVector3(0.055, 0.48, 0.025), SCNVector3(0.30, 0.70, 0.04), silver)
        case "iPad":
            addInternalBox("Tablet logic board", SCNVector3(0.38, 0.045, 1.42), SCNVector3(0.62, 0.38, 0), board)
            addInternalBox("Tablet battery", SCNVector3(1.22, 0.05, 1.55), SCNVector3(-0.36, 0.37, 0), graphite)
            addInternalBox("Tablet camera module", SCNVector3(0.22, 0.06, 0.24), SCNVector3(0.82, 0.42, -1.12), copper)
            for i in 0..<5 {
                addInternalBox("Tablet connector", SCNVector3(0.10, 0.035, 0.22), SCNVector3(0.50, 0.42, -0.65 + CGFloat(i) * 0.28), silver)
            }
        case "Smartwatch":
            addInternalBox("Watch logic board", SCNVector3(0.46, 0.045, 0.55), SCNVector3(0, 0.30, 0), board)
            addInternalBox("Watch OLED display stack", SCNVector3(0.72, 0.035, 0.82), SCNVector3(0, 0.37, 0), silver)
            addInternalBox("Watch battery cell", SCNVector3(0.52, 0.045, 0.48), SCNVector3(0, 0.26, 0.25), graphite)
            addInternalCylinder("Watch haptic motor", radius: 0.10, height: 0.08, position: SCNVector3(0.22, 0.33, -0.22), color: copper)
        case "Digital Camera":
            addInternalBox("Camera main PCB", SCNVector3(0.92, 0.06, 0.46), SCNVector3(-0.10, 0.54, -0.10), board)
            addInternalBox("Camera image sensor", SCNVector3(0.38, 0.12, 0.34), SCNVector3(0.12, 0.56, 0.30), silver)
            addInternalBox("Camera battery", SCNVector3(0.42, 0.48, 0.28), SCNVector3(-0.88, 0.52, -0.12), graphite)
            addInternalBox("Camera image processor", SCNVector3(0.22, 0.08, 0.22), SCNVector3(0.48, 0.56, -0.12), copper)
        case "Game Console":
            addInternalBox("Console motherboard", SCNVector3(1.92, 0.06, 1.28), SCNVector3(0, 0.34, 0), board)
            addInternalBox("Console APU heatsink", SCNVector3(0.62, 0.18, 0.62), SCNVector3(0.25, 0.47, -0.10), silver)
            addInternalBox("Console power supply", SCNVector3(0.58, 0.22, 0.88), SCNVector3(-0.85, 0.34, 0.12), graphite)
            addInternalCylinder("Console cooling fan", radius: 0.38, height: 0.08, position: SCNVector3(0.78, 0.47, -0.28), color: graphite)
            addInternalBox("Console optical drive", SCNVector3(0.88, 0.12, 0.55), SCNVector3(0.70, 0.32, 0.55), silver)
        case "Bluetooth Speaker":
            addInternalBox("Speaker amplifier PCB", SCNVector3(0.22, 0.06, 0.82), SCNVector3(-0.32, 0.58, 0), board)
            addInternalBox("Speaker lithium battery", SCNVector3(0.52, 0.22, 0.66), SCNVector3(0.22, 0.58, -0.12), graphite)
            for x: CGFloat in [-0.30, 0.30] {
                addInternalCylinder("Speaker driver magnet", radius: 0.18, height: 0.12, position: SCNVector3(x, 0.58, 0.40), color: silver)
            }
        case "Earbuds Case":
            addInternalBox("Earbuds case charging PCB", SCNVector3(0.68, 0.035, 0.24), SCNVector3(0, 0.36, 0.12), board)
            addInternalBox("Earbuds case battery", SCNVector3(0.56, 0.12, 0.42), SCNVector3(0, 0.28, -0.12), graphite)
            for x: CGFloat in [-0.28, 0.28] {
                addInternalCylinder("Earbud driver", radius: 0.07, height: 0.05, position: SCNVector3(x, 0.72, 0), color: silver)
            }
        default:
            addInternalBox("Phone logic board", SCNVector3(0.34, 0.045, 0.92), SCNVector3(0.40, 0.37, -0.52), board)
            addInternalBox("Phone battery", SCNVector3(0.60, 0.05, 1.18), SCNVector3(-0.22, 0.36, 0.08), graphite)
            addInternalBox("Phone camera module", SCNVector3(0.34, 0.07, 0.42), SCNVector3(0.39, 0.41, -0.91), copper)
            addInternalCylinder("Phone speaker", radius: 0.075, height: 0.05, position: SCNVector3(0, 0.39, 1.02), color: silver)
            for i in 0..<5 {
                addInternalBox("Phone ribbon connector", SCNVector3(0.055, 0.025, 0.28), SCNVector3(-0.42 + CGFloat(i) * 0.19, 0.41, -0.55 + CGFloat(i % 2) * 0.52), copper)
            }
        }

        // Extra inspection-only board components, fasteners and cable blocks give each
        // device a denser, layered interior when the shell is toggled off.
        switch selectedDevice {
        case "MacBook":
            for i in 0..<12 {
                addInternalBox("MacBook SMD component", SCNVector3(0.055, 0.024, 0.060),
                               SCNVector3(-0.56 + CGFloat(i) * 0.10, 0.425, -0.68), copper, 0.32)
            }
            for i in 0..<5 {
                addInternalBox("MacBook battery cell seam", SCNVector3(0.018, 0.014, 0.48),
                               SCNVector3(-0.82 + CGFloat(i) * 0.41, 0.385, 0.48), silver, 0.38)
            }
            for x: CGFloat in [-0.48, 0.48] {
                addInternalCylinder("Cooling fan center hub", radius: 0.065, height: 0.085,
                                    position: SCNVector3(x, 0.43, -0.50), color: silver)
            }
        case "Desktop PC":
            let towerX: CGFloat = 2.52
            for i in 0..<8 {
                addInternalCylinder("Motherboard capacitor", radius: 0.035, height: 0.11,
                                    position: SCNVector3(towerX - 0.28 + CGFloat(i % 4) * 0.15, 0.82, -0.08 + CGFloat(i / 4) * 0.18),
                                    color: silver)
            }
            for i in 0..<6 {
                addInternalBox("GPU memory chip", SCNVector3(0.10, 0.055, 0.10),
                               SCNVector3(towerX - 0.30 + CGFloat(i) * 0.11, 0.62, 0.22), copper, 0.32)
            }
            addInternalBox("Motherboard power connector", SCNVector3(0.10, 0.12, 0.16), SCNVector3(towerX + 0.29, 1.18, 0.12), silver)
        case "PC Tower":
            for i in 0..<10 {
                addInternalCylinder("PC tower motherboard capacitor", radius: 0.035, height: 0.12,
                                    position: SCNVector3(-0.30 + CGFloat(i % 5) * 0.14, 0.82 + CGFloat(i / 5) * 0.20, 0.22), color: silver)
            }
            for i in 0..<8 {
                addInternalBox("PC tower GPU memory chip", SCNVector3(0.09, 0.045, 0.09),
                               SCNVector3(-0.30 + CGFloat(i) * 0.085, 0.66, -0.02), copper, 0.30)
            }
            addInternalBox("PC tower front panel connector", SCNVector3(0.12, 0.08, 0.12), SCNVector3(0, 1.54, 0.36), silver)
        case "Engine":
            for x: CGFloat in [-0.48, -0.16, 0.16, 0.48] {
                addInternalCylinder("Engine connecting rod", radius: 0.045, height: 0.34,
                                    position: SCNVector3(x, 0.80, 0.06), color: copper)
            }
            for i in 0..<8 {
                addInternalBox("Engine sensor and wiring connector", SCNVector3(0.07, 0.045, 0.08),
                               SCNVector3(-0.48 + CGFloat(i) * 0.14, 1.48, -0.24), silver, 0.25)
            }
            addInternalBox("Engine oil filter", SCNVector3(0.20, 0.32, 0.20), SCNVector3(0.78, 0.42, 0.42), graphite)
        case "TV":
            for i in 0..<14 {
                addInternalBox("TV board microcomponent", SCNVector3(0.07, 0.028, 0.075),
                               SCNVector3(0.38 + CGFloat(i % 7) * 0.13, 0.78, -0.25 + CGFloat(i / 7) * 0.18), copper, 0.30)
            }
            for x: CGFloat in [-1.62, 1.62] {
                addInternalCylinder("TV speaker driver", radius: 0.075, height: 0.08,
                                    position: SCNVector3(x, 0.36, 0.02), color: silver)
            }
            addInternalBox("TV main ribbon connector", SCNVector3(0.42, 0.025, 0.055), SCNVector3(0.18, 0.69, 0.04), silver, 0.24)
        case "iPad":
            for i in 0..<10 {
                addInternalBox("Tablet board component", SCNVector3(0.07, 0.024, 0.08),
                               SCNVector3(0.40 + CGFloat(i % 5) * 0.12, 0.425, -0.54 + CGFloat(i / 5) * 0.28), copper, 0.30)
            }
            addInternalBox("Tablet ribbon cable", SCNVector3(0.045, 0.018, 0.72), SCNVector3(0.20, 0.43, 0.48), silver, 0.18)
        default:
            for i in 0..<12 {
                addInternalBox("Phone board microchip", SCNVector3(0.065, 0.024, 0.075),
                               SCNVector3(0.20 + CGFloat(i % 4) * 0.11, 0.425, -0.72 + CGFloat(i / 4) * 0.22), copper, 0.30)
            }
            addInternalBox("Phone charging daughterboard", SCNVector3(0.40, 0.035, 0.12), SCNVector3(0, 0.40, 1.00), board)
            addInternalBox("Phone antenna flex", SCNVector3(0.045, 0.018, 0.68), SCNVector3(-0.48, 0.42, 0.10), silver, 0.22)
        }
        let collisionSize: SCNVector3
        switch selectedDevice {
        case "MacBook": collisionSize = SCNVector3(3.0, 1.94, 2.0)
        case "Desktop PC": collisionSize = SCNVector3(5.9, 2.15, 1.0)
        case "PC Tower": collisionSize = SCNVector3(1.12, 1.95, 1.12)
        case "Engine": collisionSize = SCNVector3(1.95, 1.72, 1.48)
        case "iPad": collisionSize = SCNVector3(2.3, 0.16, 3.0)
        case "TV": collisionSize = SCNVector3(3.84, 2.40, 0.34)
        case "Smartwatch": collisionSize = SCNVector3(1.15, 0.30, 1.30)
        case "Digital Camera": collisionSize = SCNVector3(2.15, 1.25, 1.05)
        case "Game Console": collisionSize = SCNVector3(2.9, 0.65, 2.25)
        case "Bluetooth Speaker": collisionSize = SCNVector3(1.30, 1.30, 2.35)
        case "Earbuds Case": collisionSize = SCNVector3(1.35, 0.95, 1.10)
        default: collisionSize = SCNVector3(1.3, 0.205, 2.5)
        }
        let modelCenterY: CGFloat
        switch selectedDevice {
        case "MacBook": modelCenterY = 1.0825
        case "Desktop PC": modelCenterY = 1.10
        case "PC Tower": modelCenterY = 0.94
        case "Engine": modelCenterY = 0.86
        case "iPad": modelCenterY = 0.23
        case "TV": modelCenterY = 1.20
        case "Smartwatch": modelCenterY = 0.32
        case "Digital Camera": modelCenterY = 0.55
        case "Game Console": modelCenterY = 0.32
        case "Bluetooth Speaker": modelCenterY = 0.58
        case "Earbuds Case": modelCenterY = 0.48
        default: modelCenterY = 0.2025
        }
        for child in root.childNodes {
            child.position.y -= modelCenterY
        }
        let deskSurfaceY = deskTopY + 0.11
        root.position = SCNVector3(0, deskSurfaceY + collisionSize.y / 2 + 0.015, 0)
        let collisionGeometry = SCNBox(width: CGFloat(collisionSize.x), height: CGFloat(collisionSize.y), length: CGFloat(collisionSize.z), chamferRadius: 0.05)
        root.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: collisionGeometry, options: nil))
        if let body = root.physicsBody {
            let profile: (mass: CGFloat, friction: CGFloat, restitution: CGFloat, angular: CGFloat)
            switch selectedDevice {
            case "Desktop PC": profile = (9.0, 0.88, 0.035, 0.68)
            case "PC Tower": profile = (11.5, 0.88, 0.025, 0.62)
            case "Engine": profile = (32.0, 0.86, 0.025, 0.72)
            case "TV": profile = (7.2, 0.80, 0.04, 0.64)
            case "MacBook": profile = (3.4, 0.82, 0.045, 0.62)
            case "iPad": profile = (1.1, 0.76, 0.055, 0.58)
            case "Digital Camera": profile = (1.25, 0.74, 0.045, 0.52)
            case "Game Console": profile = (2.8, 0.82, 0.035, 0.66)
            case "Bluetooth Speaker": profile = (1.1, 0.78, 0.05, 0.48)
            case "Smartwatch": profile = (0.28, 0.68, 0.06, 0.45)
            case "Earbuds Case": profile = (0.22, 0.62, 0.07, 0.42)
            default: profile = (0.42, 0.72, 0.065, 0.54)
            }
            configureDynamicBody(
                body,
                mass: profile.mass,
                friction: profile.friction,
                restitution: profile.restitution,
                angularDamping: profile.angular
            )
        }
        let excludedPartWords = ["perforation", "grille", "port", "button", "led", "lens", "speaker", "fan hub", "case foot", "webcam"]
        breakableComponents = root.childNodes.filter { node in
            guard node.geometry != nil, !internalParts.contains(where: { $0 === node }) else { return false }
            let name = (node.name ?? "").lowercased()
            if excludedPartWords.contains(where: { name.contains($0) }) { return false }
            let bounds = node.boundingBox
            let dx = abs(bounds.max.x - bounds.min.x)
            let dy = abs(bounds.max.y - bounds.min.y)
            let dz = abs(bounds.max.z - bounds.min.z)
            return dx * dy * dz > 0.008
        }
        scene.rootNode.addChildNode(root)
        deviceRoot = root
    }

    private func detachNearestDevicePart(at impactPoint: SCNVector3) {
        let candidates = showingInternals ? internalParts : breakableComponents
        guard let part = candidates.min(by: { a, b in
            let pa = a.presentation.worldPosition
            let pb = b.presentation.worldPosition
            let da = (pa.x - impactPoint.x) * (pa.x - impactPoint.x) +
                     (pa.y - impactPoint.y) * (pa.y - impactPoint.y) +
                     (pa.z - impactPoint.z) * (pa.z - impactPoint.z)
            let db = (pb.x - impactPoint.x) * (pb.x - impactPoint.x) +
                     (pb.y - impactPoint.y) * (pb.y - impactPoint.y) +
                     (pb.z - impactPoint.z) * (pb.z - impactPoint.z)
            return da < db
        }), let geometry = part.geometry else { return }
        let worldPosition = part.presentation.worldPosition
        let worldRotation = part.presentation.eulerAngles
        part.removeFromParentNode()
        scene.rootNode.addChildNode(part)
        part.position = worldPosition
        part.eulerAngles = worldRotation
        part.isHidden = false
        let bounds = geometry.boundingBox
        let dx = abs(bounds.max.x - bounds.min.x)
        let dy = abs(bounds.max.y - bounds.min.y)
        let dz = abs(bounds.max.z - bounds.min.z)
        let partMass = min(1.8, max(0.06, dx * dy * dz * 2.4))
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: geometry, options: nil))
        configureDynamicBody(body, mass: partMass, friction: 0.58, restitution: 0.075, angularDamping: 0.32)
        part.physicsBody = body
        var direction = SCNVector3(worldPosition.x - impactPoint.x,
                                   max(0.25, worldPosition.y - impactPoint.y + 0.35),
                                   worldPosition.z - impactPoint.z)
        let length = max(0.001, sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z))
        direction = SCNVector3(direction.x / length, direction.y / length, direction.z / length)
        let impulse = CGFloat(1.2 + damageLevel * 3.8)
        body.applyForce(SCNVector3(direction.x * impulse, direction.y * impulse, direction.z * impulse), asImpulse: true)
        body.applyTorque(SCNVector4(Float.random(in: -1...1), Float.random(in: -1...1),
                                    Float.random(in: -1...1), Float.random(in: 0.5...1.8)), asImpulse: true)
        if showingInternals {
            internalParts.removeAll { $0 === part }
        } else {
            breakableComponents.removeAll { $0 === part }
        }
        deviceShellParts.removeAll { $0 === part }
        detachedDeviceParts.append(part)
        play(deviceRattleSound)
        part.runAction(.sequence([.wait(duration: 11.5), .fadeOut(duration: 0.5), .removeFromParentNode()]))
        DispatchQueue.main.asyncAfter(deadline: .now() + 12.2) { [weak self, weak part] in
            guard let self, let part else { return }
            self.detachedDeviceParts.removeAll { $0 === part }
        }
    }

    // Brief, local flex at the struck component. The mesh returns to its original
    // transform, avoiding the unstable part-detachment behavior from earlier builds.
    private func bendDevicePart(_ part: SCNNode, intensity: CGFloat) {
        let originalScale = part.scale
        let originalRotation = part.eulerAngles
        let amount = min(0.085, max(0.025, intensity * 0.085))
        part.removeAction(forKey: "device-flex")
        let flex = SCNAction.customAction(duration: 0.42) { node, elapsed in
            let progress = min(1, max(0, elapsed / 0.42))
            let bend = sin(progress * .pi)
            node.scale = SCNVector3(
                originalScale.x * (1 - amount * bend),
                originalScale.y * (1 + amount * 0.45 * bend),
                originalScale.z * (1 - amount * bend)
            )
            node.eulerAngles = SCNVector3(
                originalRotation.x + amount * 0.55 * bend,
                originalRotation.y,
                originalRotation.z + amount * bend
            )
        }
        part.runAction(flex, forKey: "device-flex")
    }

    // Marks are attached to the struck component, not left behind in world space.
    private func addSurfaceDamage(at point: SCNVector3, normal: SCNVector3, scratch: Bool, on surface: SCNNode) {
        let prefix = scratch ? "scratch" : "dent"
        let names = (1...6).map { String(format: "%@_%02d", prefix, $0) }
        guard let name = names.randomElement(),
              let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return }
        if surfaceDamageMarks.count >= 48 { surfaceDamageMarks.removeFirst().removeFromParentNode() }
        let localPoint = surface.convertPosition(point, from: nil)
        var localNormal = surface.convertVector(normal, from: nil)
        let length = max(0.001, sqrt(localNormal.x * localNormal.x + localNormal.y * localNormal.y + localNormal.z * localNormal.z))
        localNormal = SCNVector3(localNormal.x / length, localNormal.y / length, localNormal.z / length)
        let size = scratch ? CGFloat.random(in: 0.18...0.38) : CGFloat.random(in: 0.14...0.27)
        let plane = SCNPlane(width: size, height: size * CGFloat.random(in: 0.55...1.25))
        let mat = SCNMaterial()
        mat.diffuse.contents = image
        mat.transparent.contents = image
        mat.isDoubleSided = true
        mat.lightingModel = .constant
        mat.blendMode = .alpha
        plane.firstMaterial = mat
        let mark = SCNNode(geometry: plane)
        mark.name = "Surface damage mark"
        mark.position = SCNVector3(localPoint.x + localNormal.x * 0.0025, localPoint.y + localNormal.y * 0.0025, localPoint.z + localNormal.z * 0.0025)
        mark.look(at: SCNVector3(localPoint.x + localNormal.x, localPoint.y + localNormal.y, localPoint.z + localNormal.z),
                  up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, 1))
        mark.eulerAngles.z += CGFloat.random(in: 0...(2 * .pi))
        mark.opacity = 0.94
        surface.addChildNode(mark)
        surfaceDamageMarks.append(mark)
    }

    // Subdivide a struck box and indent the vertices around the impact point.
    // This is actual vertex displacement; the rest of the component keeps its dimensions.
    private func deformImpactMesh(_ part: SCNNode, worldPoint: SCNVector3, worldNormal: SCNVector3, intensity: CGFloat) {
        guard var geometry = part.geometry else { return }
        if let box = geometry as? SCNBox {
            let dense = SCNBox(width: box.width, height: box.height, length: box.length, chamferRadius: min(box.chamferRadius, 0.012))
            dense.widthSegmentCount = 18
            dense.heightSegmentCount = 18
            dense.lengthSegmentCount = 18
            dense.materials = geometry.materials
            geometry = dense
        }
        guard let source = geometry.sources(for: .vertex).first,
              source.usesFloatComponents, source.bytesPerComponent == 4,
              source.componentsPerVector >= 3, source.vectorCount >= 80 else { return }
        let localPoint = part.convertPosition(worldPoint, from: nil)
        var normal = part.convertVector(worldNormal, from: nil)
        let nl = max(0.001, sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z))
        normal = SCNVector3(normal.x / nl, normal.y / nl, normal.z / nl)
        let bounds = geometry.boundingBox
        let center = SCNVector3((bounds.min.x + bounds.max.x) * 0.5, (bounds.min.y + bounds.max.y) * 0.5, (bounds.min.z + bounds.max.z) * 0.5)
        let sx = bounds.max.x - bounds.min.x, sy = bounds.max.y - bounds.min.y, sz = bounds.max.z - bounds.min.z
        let tangent = max(0.10, min(sx, max(sy, sz)))
        let radius = max(0.11, tangent * 0.38)
        let depth = min(0.14, max(0.022, tangent * 0.085)) * min(1.8, max(0.55, intensity))
        var vertices = [SCNVector3]()
        vertices.reserveCapacity(source.vectorCount)
        source.data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            for index in 0..<source.vectorCount {
                let offset = source.dataOffset + index * source.dataStride
                var x: Float = 0, y: Float = 0, z: Float = 0
                memcpy(&x, base.advanced(by: offset), 4)
                memcpy(&y, base.advanced(by: offset + 4), 4)
                memcpy(&z, base.advanced(by: offset + 8), 4)
                vertices.append(SCNVector3(CGFloat(x), CGFloat(y), CGFloat(z)))
            }
        }
        var changed = false
        for i in vertices.indices {
            let v = vertices[i]
            let facing = (v.x - center.x) * normal.x + (v.y - center.y) * normal.y + (v.z - center.z) * normal.z
            let dx = v.x - localPoint.x, dy = v.y - localPoint.y, dz = v.z - localPoint.z
            let along = dx * normal.x + dy * normal.y + dz * normal.z
            let rx = dx - normal.x * along, ry = dy - normal.y * along, rz = dz - normal.z * along
            let radial = sqrt(rx * rx + ry * ry + rz * rz)
            if facing > 0 && radial < radius * 2.2 {
                let bowl = exp(-pow(radial / radius, 2) * 2.1)
                let lip = exp(-pow((radial - radius * 1.12) / (radius * 0.22), 2)) * 0.20
                let push = depth * (bowl - lip)
                vertices[i] = SCNVector3(v.x - normal.x * push, v.y - normal.y * push, v.z - normal.z * push)
                changed = true
            }
        }
        guard changed else { return }
        // Rebuild normals from the deformed triangles so dents catch light as
        // concave surfaces rather than remaining visually flat.
        var normals = Array(repeating: SCNVector3(0, 0, 0), count: vertices.count)
        for element in geometry.elements where element.primitiveType == .triangles {
            let triangleIndexCount = element.primitiveCount * 3
            element.data.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                func vertexIndex(_ index: Int) -> Int {
                    let offset = index * element.bytesPerIndex
                    if element.bytesPerIndex == 2 {
                        var value: UInt16 = 0
                        memcpy(&value, base.advanced(by: offset), 2)
                        return Int(value)
                    }
                    var value: UInt32 = 0
                    memcpy(&value, base.advanced(by: offset), 4)
                    return Int(value)
                }
                for triangle in stride(from: 0, to: triangleIndexCount, by: 3) {
                    let ia = vertexIndex(triangle), ib = vertexIndex(triangle + 1), ic = vertexIndex(triangle + 2)
                    guard ia < vertices.count, ib < vertices.count, ic < vertices.count else { continue }
                    let a = vertices[ia], b = vertices[ib], c = vertices[ic]
                    let ab = SCNVector3(b.x - a.x, b.y - a.y, b.z - a.z)
                    let ac = SCNVector3(c.x - a.x, c.y - a.y, c.z - a.z)
                    let face = SCNVector3(ab.y * ac.z - ab.z * ac.y,
                                          ab.z * ac.x - ab.x * ac.z,
                                          ab.x * ac.y - ab.y * ac.x)
                    for index in [ia, ib, ic] {
                        normals[index] = SCNVector3(normals[index].x + face.x,
                                                    normals[index].y + face.y,
                                                    normals[index].z + face.z)
                    }
                }
            }
        }
        for index in normals.indices {
            let n = normals[index]
            let length = max(0.0001, sqrt(n.x * n.x + n.y * n.y + n.z * n.z))
            normals[index] = SCNVector3(n.x / length, n.y / length, n.z / length)
        }
        let dented = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals)],
                                 elements: geometry.elements)
        dented.materials = geometry.materials
        part.geometry = dented
    }

    private func damageDevicePart(_ part: SCNNode, at point: SCNVector3, normal: SCNVector3, intensity: CGFloat) {
        guard part.geometry != nil, part !== deviceRoot else { return }
        let key = ObjectIdentifier(part)
        let accumulated = (devicePartDamage[key] ?? 0) + max(0.06, intensity * 0.30)
        devicePartDamage[key] = accumulated
        deformImpactMesh(part, worldPoint: point, worldNormal: normal, intensity: intensity)
        // Permanent progressive flex: the shell visibly kinks and stays bent between hits.
        let bend = min(0.045, intensity * 0.0045)
        part.eulerAngles.x += normal.z * bend
        part.eulerAngles.z += normal.x * bend * CGFloat.random(in: 0.7...1.3)
        addSurfaceDamage(at: point, normal: normal, scratch: accumulated < 1.2, on: part)
        // Structural failure is delayed: components deform and loosen over many hits first.
        if accumulated >= 5.2, part.parent === deviceRoot, let geometry = part.geometry {
            let world = part.presentation.worldPosition
            let rotation = part.presentation.eulerAngles
            part.removeFromParentNode()
            scene.rootNode.addChildNode(part)
            part.position = world
            part.eulerAngles = rotation
            let bounds = geometry.boundingBox
            let volume = abs(bounds.max.x - bounds.min.x) * abs(bounds.max.y - bounds.min.y) * abs(bounds.max.z - bounds.min.z)
            let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: geometry, options: nil))
            configureDynamicBody(body, mass: min(0.55, max(0.08, volume * 1.8)),
                                 friction: 0.62, restitution: 0.035, angularDamping: 0.68)
            part.physicsBody = body
            let kick = CGFloat.random(in: 0.22...0.48)
            body.applyForce(SCNVector3(normal.x * kick, max(0.08, normal.y * kick), normal.z * kick), asImpulse: true)
            detachedDeviceParts.append(part)
            deviceShellParts.removeAll { $0 === part }
            breakableComponents.removeAll { $0 === part }
            playSpatial("device_rattle", at: world, volume: 0.72)
            statusLabel.stringValue = "A damaged casing component has come loose."
        }
    }

    private func damageRoomProp(_ part: SCNNode, at point: SCNVector3, normal: SCNVector3, intensity: CGFloat) {
        guard part.geometry != nil, part.physicsBody?.type == .static else { return }
        let key = ObjectIdentifier(part)
        let accumulated = (roomPropDamage[key] ?? 0) + intensity * 0.34
        roomPropDamage[key] = accumulated
        deformImpactMesh(part, worldPoint: point, worldNormal: normal, intensity: intensity * 0.9)
        let bend = min(0.055, intensity * 0.005)
        part.eulerAngles.x += normal.z * bend
        part.eulerAngles.z += normal.x * bend
        addSurfaceDamage(at: point, normal: normal, scratch: accumulated < 1.1, on: part)
        guard accumulated >= 4.8, let geometry = part.geometry else { return }
        let world = part.presentation.worldPosition
        let rotation = part.presentation.eulerAngles
        part.removeFromParentNode()
        scene.rootNode.addChildNode(part)
        part.position = world
        part.eulerAngles = rotation
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: geometry, options: nil))
        configureDynamicBody(body, mass: 0.75, friction: 0.72, restitution: 0.045, angularDamping: 0.52)
        part.physicsBody = body
        let kick = min(1.1, 0.22 + intensity * 0.12)
        body.applyForce(SCNVector3(normal.x * kick, max(0.08, normal.y * kick), normal.z * kick), asImpulse: true)
        roomBreakables.removeAll { $0 === part }
        statusLabel.stringValue = "Room prop finally gave way after repeated damage."
        playSpatial("wood_knock", at: world, volume: 0.86)
    }

    private func darkGripMaterial() -> SCNMaterial {
        material(NSColor(calibratedRed: 0.055, green: 0.07, blue: 0.085, alpha: 1), roughness: 0.86)
    }

    private var toolPower: CGFloat {
        switch selectedTool {
        case "Sledgehammer": return 2.25
        case "Crowbar": return 1.55
        case "Drill": return 1.25
        case "Saw": return 1.65
        case "Impact Driver": return 1.35
        case "Rubber Mallet": return 0.78
        case "Plastic Spudger", "Suction Cup", "Flashlight": return 0.35
        default: return 1.0
        }
    }

    private func emitFire(on target: SCNNode, worldPoint: SCNVector3) {
        let fireParent: SCNNode
        if let deviceRoot, isInside(target, root: deviceRoot) {
            fireParent = deviceRoot
        } else if let prop = roomBreakables.first(where: { isInside(target, root: $0) }) {
            fireParent = prop
        } else if let panel = deskBreakablePanels.first(where: { isInside(target, root: $0) }) {
            fireParent = panel
        } else {
            fireParent = target
        }
        if fireParent.childNodes.contains(where: { $0.name == "Virtual fire effect" }) { return }
        let fire = SCNNode()
        fire.name = "Virtual fire effect"
        fire.position = fireParent.convertPosition(worldPoint, from: nil)
        let flame = SCNParticleSystem()
        flame.birthRate = 95
        flame.particleLifeSpan = 0.72
        flame.particleLifeSpanVariation = 0.22
        flame.particleSize = 0.12
        flame.particleSizeVariation = 0.07
        flame.particleColor = NSColor(calibratedRed: 1.0, green: 0.30, blue: 0.045, alpha: 0.92)
        flame.particleColorVariation = SCNVector4(0.08, 0.20, 0.02, 0.08)
        flame.particleVelocity = 0.42
        flame.particleVelocityVariation = 0.28
        flame.acceleration = SCNVector3(0, 0.72, 0)
        flame.spreadingAngle = 28
        flame.isAffectedByGravity = false
        flame.emissionDuration = 7
        flame.loops = false
        let smoke = SCNParticleSystem()
        smoke.birthRate = 18
        smoke.particleLifeSpan = 1.8
        smoke.particleSize = 0.19
        smoke.particleSizeVariation = 0.12
        smoke.particleColor = NSColor(calibratedWhite: 0.20, alpha: 0.30)
        smoke.particleVelocity = 0.25
        smoke.acceleration = SCNVector3(0, 0.38, 0)
        smoke.spreadingAngle = 38
        smoke.isAffectedByGravity = false
        smoke.emissionDuration = 6
        smoke.loops = false
        fire.addParticleSystem(flame)
        fire.addParticleSystem(smoke)
        fireParent.addChildNode(fire)
        activeFireEffects.append(fire)
        fire.runAction(.sequence([.wait(duration: 8), .removeFromParentNode()]))
        statusLabel.stringValue = "Virtual fire effect active — switch to Water Blaster to put it out."
    }

    private func sprayWater(at point: SCNVector3, hitNode: SCNNode) {
        var ancestor: SCNNode? = hitNode
        var extinguished = false
        while let current = ancestor {
            for child in current.childNodes where child.name == "Virtual fire effect" {
                child.removeFromParentNode()
                activeFireEffects.removeAll { $0 === child }
                extinguished = true
            }
            ancestor = current.parent
        }
        let spray = SCNNode()
        spray.name = "Water spray effect"
        let droplets = SCNParticleSystem()
        droplets.birthRate = 260
        droplets.particleLifeSpan = 0.48
        droplets.particleSize = 0.035
        droplets.particleSizeVariation = 0.02
        droplets.particleColor = NSColor(calibratedRed: 0.35, green: 0.72, blue: 1, alpha: 0.72)
        droplets.particleVelocity = 2.4
        droplets.particleVelocityVariation = 0.9
        droplets.spreadingAngle = 24
        droplets.acceleration = SCNVector3(0, -3.2, 0)
        droplets.isAffectedByGravity = true
        droplets.emissionDuration = 0.18
        droplets.loops = false
        spray.addParticleSystem(droplets)
        spray.position = point
        scene.rootNode.addChildNode(spray)
        waterEffects.append(spray)
        spray.runAction(.sequence([.wait(duration: 1.4), .removeFromParentNode()]))
        if extinguished {
            statusLabel.stringValue = "Extinguished! The virtual flame is out."
            playSpatial("steam_hiss", at: point, volume: 0.82)
        } else {
            statusLabel.stringValue = "Water burst — aim at a virtual flame to extinguish it."
        }
    }

    private func damageDeskPanel(_ panel: SCNNode, at point: SCNVector3, normal: SCNVector3, intensity: CGFloat) {
        let key = ObjectIdentifier(panel)
        let accumulated = (deskPanelDamage[key] ?? 0) + intensity * 0.55
        deskPanelDamage[key] = accumulated
        deformImpactMesh(panel, worldPoint: point, worldNormal: normal, intensity: intensity * 0.72)
        addSurfaceDamage(at: point, normal: normal, scratch: accumulated < 1.2, on: panel)
        guard accumulated >= 2.8, panel.physicsBody?.type == .static, let geometry = panel.geometry else { return }
        let world = panel.presentation.worldPosition
        let rotation = panel.presentation.eulerAngles
        panel.removeFromParentNode()
        scene.rootNode.addChildNode(panel)
        panel.position = world
        panel.eulerAngles = rotation
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: geometry, options: nil))
        configureDynamicBody(body, mass: 1.8, friction: 0.78, restitution: 0.025, angularDamping: 0.72)
        panel.physicsBody = body
        let kick = CGFloat(0.25 + intensity * 0.25)
        body.applyForce(SCNVector3(-normal.x * kick, -normal.y * kick, -normal.z * kick), asImpulse: true)
        statusLabel.stringValue = "A workbench panel has broken free."
    }

    @objc private func toggleDeviceInternals() {
        showingInternals.toggle()
        deviceShellParts.forEach { $0.isHidden = showingInternals }
        internalParts.forEach { $0.isHidden = !showingInternals }
        statusLabel.stringValue = showingInternals
            ? "Inspection view: internal boards, batteries, cooling and connectors."
            : "Exterior casing view restored."
    }

    @objc private func deviceChanged(_ sender: NSPopUpButton) {
        selectedDevice = sender.titleOfSelectedItem ?? "iPhone"
        makeDevice()
        statusLabel.stringValue = "Loaded virtual \(selectedDevice)."
    }

    @objc private func toolChanged(_ sender: NSPopUpButton) {
        selectedTool = sender.titleOfSelectedItem ?? "Hammer"
        rebuildCursorTool()
        statusLabel.stringValue = "Cursor tool selected. Move over the scene and click to swing."
    }

    @objc private func roomChanged(_ sender: NSPopUpButton) {
        roomStyle = sender.titleOfSelectedItem ?? "Studio"
        buildScene()
        statusLabel.stringValue = "Room changed to \(roomStyle)."
    }

    @objc private func damageChanged(_ sender: NSSlider) { damageLevel = Float(sender.floatValue) }

    private func playSpatial(_ name: String, at position: SCNVector3, volume: Float = 1.0) {
        let alternate = name + "_alt"
        let chosenName = Bool.random() && Bundle.main.url(forResource: alternate, withExtension: "wav") != nil ? alternate : name
        guard let url = Bundle.main.url(forResource: chosenName, withExtension: "wav"),
              let source = SCNAudioSource(url: url) else { return }
        source.isPositional = true
        source.shouldStream = false
        source.volume = volume * Float.random(in: 0.84...1.0)
        source.reverbBlend = Float.random(in: 0.10...0.30)
        source.load()
        let emitter = SCNNode()
        emitter.position = position
        emitter.addAudioPlayer(SCNAudioPlayer(source: source))
        scene.rootNode.addChildNode(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak emitter] in
            emitter?.removeFromParentNode()
        }
    }

    private func isScreenSurface(_ node: SCNNode) -> Bool {
        var current: SCNNode? = node
        while let candidate = current {
            let name = (candidate.name ?? "").lowercased()
            if name.contains("screen") || name.contains("display") || name.contains("oled") || name.contains("lcd") {
                return true
            }
            current = candidate.parent
        }
        return false
    }

    private func addScreenCrack(at worldPoint: SCNVector3, normal worldNormal: SCNVector3, on hitNode: SCNNode) {
        var screen: SCNNode? = hitNode
        while let candidate = screen {
            let name = (candidate.name ?? "").lowercased()
            if name.contains("screen") || name.contains("display") || name.contains("oled") || name.contains("lcd") { break }
            screen = candidate.parent
        }
        guard let surface = screen, let geometry = surface.geometry else { return }
        let localPoint = surface.convertPosition(worldPoint, from: nil)
        var normal = surface.convertVector(worldNormal, from: nil)
        let length = max(0.001, sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z))
        normal = SCNVector3(normal.x / length, normal.y / length, normal.z / length)
        let bounds = geometry.boundingBox
        let width = max(0.30, min(1.65, (bounds.max.x - bounds.min.x) * 0.88))
        let heightAxis = abs(normal.y) > 0.65 ? (bounds.max.z - bounds.min.z) : (bounds.max.y - bounds.min.y)
        let height = max(0.30, min(1.55, heightAxis * 0.88))
        let image = NSImage(size: NSSize(width: 512, height: 512))
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: 512, height: 512).fill()
        let center = NSPoint(x: CGFloat.random(in: 180...330), y: CGFloat.random(in: 180...330))
        for ray in 0..<16 {
            let angle = CGFloat(ray) * (.pi * 2 / 16) + CGFloat.random(in: -0.12...0.12)
            let reach = CGFloat.random(in: 125...245)
            let end = NSPoint(x: center.x + cos(angle) * reach, y: center.y + sin(angle) * reach)
            let crack = NSBezierPath()
            crack.lineWidth = CGFloat.random(in: 1.0...2.3)
            crack.move(to: center)
            let mid = NSPoint(x: center.x + cos(angle) * reach * 0.55 + CGFloat.random(in: -15...15),
                              y: center.y + sin(angle) * reach * 0.55 + CGFloat.random(in: -15...15))
            crack.line(to: mid)
            crack.line(to: end)
            NSColor(calibratedWhite: 0.96, alpha: 0.92).setStroke()
            crack.stroke()
            if ray % 2 == 0 {
                let branch = NSBezierPath()
                branch.lineWidth = 1.0
                branch.move(to: mid)
                branch.line(to: NSPoint(x: mid.x + CGFloat.random(in: -48...48), y: mid.y + CGFloat.random(in: -48...48)))
                branch.stroke()
            }
        }
        // Simulated LCD/OLED damage: narrow colour-separated streaks beneath the cracks.
        for index in 0..<7 {
            let x = center.x + CGFloat(index - 3) * CGFloat.random(in: 5...11)
            let band = NSBezierPath()
            band.lineWidth = CGFloat.random(in: 2...7)
            band.move(to: NSPoint(x: x, y: center.y - 150))
            band.line(to: NSPoint(x: x + CGFloat.random(in: -10...10), y: center.y + 150))
            let colors: [NSColor] = [.systemRed, .systemGreen, .systemBlue, .systemCyan, .magenta]
            colors[index % colors.count].withAlphaComponent(0.70).setStroke()
            band.stroke()
        }
        image.unlockFocus()
        let plane = SCNPlane(width: width, height: height)
        let decalMaterial = SCNMaterial()
        decalMaterial.diffuse.contents = image
        decalMaterial.transparent.contents = image
        decalMaterial.lightingModel = .constant
        decalMaterial.blendMode = .alpha
        decalMaterial.isDoubleSided = true
        plane.firstMaterial = decalMaterial
        let decal = SCNNode(geometry: plane)
        decal.name = "Screen crack overlay"
        decal.position = SCNVector3(localPoint.x + normal.x * 0.004,
                                     localPoint.y + normal.y * 0.004,
                                     localPoint.z + normal.z * 0.004)
        let up = abs(normal.y) > 0.85 ? SCNVector3(0, 0, 1) : SCNVector3(0, 1, 0)
        decal.look(at: SCNVector3(localPoint.x + normal.x, localPoint.y + normal.y, localPoint.z + normal.z),
                   up: up, localFront: SCNVector3(0, 0, 1))
        surface.addChildNode(decal)
    }

    private func playSurfaceImpact(first: String, second: String, impulse: CGFloat, position: SCNVector3) {
        let contactNames = (first + " " + second).lowercased()
        let touchesDevice = contactNames.contains("device") || contactNames.contains("phone") ||
            contactNames.contains("tablet") || contactNames.contains("laptop")
        let touchesWood = contactNames.contains("wood") || contactNames.contains("desk") ||
            contactNames.contains("drawer") || contactNames.contains("workbench") || contactNames.contains("tabletop")
        let touchesMetal = contactNames.contains("metal") || contactNames.contains("frame") ||
            contactNames.contains("pull") || contactNames.contains("hinge")
        let touchesFloor = contactNames.contains("floor") || contactNames.contains("carpet")
        let touchesCeramic = contactNames.contains("ceramic") || contactNames.contains("porcelain") || contactNames.contains("tile")
        let touchesRubber = contactNames.contains("rubber") || contactNames.contains("tyre") || contactNames.contains("tire")
        let touchesFabric = contactNames.contains("fabric") || contactNames.contains("cloth") || contactNames.contains("upholstery")
        let touchesAluminum = contactNames.contains("aluminum") || contactNames.contains("aluminium")
        let touchesSteel = contactNames.contains("steel") || contactNames.contains("stainless")
        let touchesPlastic = contactNames.contains("plastic") || contactNames.contains("polymer") || contactNames.contains("acrylic")

        if contactNames.contains("glass") || contactNames.contains("window") || contactNames.contains("screen") || contactNames.contains("display") {
            playSpatial("glass_tap", at: position, volume: 0.9)
            if impulse > 1.0 { playSpatial("glass_crackle", at: position, volume: 0.82) }
        } else if touchesCeramic {
            playSpatial("ceramic_clink", at: position, volume: 0.88)
        } else if touchesSteel {
            playSpatial("steel_ring", at: position, volume: 0.92)
        } else if touchesAluminum || touchesMetal {
            playSpatial("aluminum_ting", at: position, volume: 0.88)
        } else if touchesWood {
            playSpatial("wood_knock", at: position, volume: 0.86)
        } else if touchesRubber {
            playSpatial("rubber_thud", at: position, volume: 0.82)
        } else if touchesFabric || touchesFloor {
            playSpatial("fabric_rustle", at: position, volume: 0.72)
        } else if touchesPlastic || touchesDevice {
            playSpatial("plastic_click", at: position, volume: 0.82)
            if impulse > 1.8 { playSpatial("device_rattle", at: position, volume: 0.62) }
        } else {
            playSpatial("device_thud", at: position, volume: 0.78)
        }
    }

    private func prepareAudio() {
        func load(_ name: String) -> NSSound? {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
            return NSSound(contentsOf: url, byReference: false)
        }
        swingSound = load("tool_swing")
        impactSound = load("device_tap")
        glassTapSound = load("glass_tap")
        shatterSound = load("glass_shatter")
        scratchSound = load("surface_scratch")
        deviceThudSound = load("device_thud")
        woodKnockSound = load("wood_knock")
        metalClangSound = load("metal_clang")
        plasticClickSound = load("plastic_click")
        carpetThumpSound = load("carpet_thump")
        deviceRattleSound = load("device_rattle")
        glassCrackleSound = load("glass_crackle")
        debrisScatterSound = load("debris_scatter")
    }
    private func play(_ sound: NSSound?) { sound?.stop(); sound?.play() }
    private func makeCursorTool() {
        cursorTool = SCNNode()
        cursorTool.name = "Cursor tool"
        cursorToolPivot = SCNNode()
        cursorToolPivot.name = "Swing pivot"
        cursorTool.addChildNode(cursorToolPivot)
        rebuildCursorTool()
        scene.rootNode.addChildNode(cursorTool)
    }
    private func rebuildCursorTool() {
        cursorToolPivot.childNodes.forEach { $0.removeFromParentNode() }
        let metal = material(NSColor(calibratedWhite: 0.68, alpha: 1), roughness: 0.3)
        let handle = SCNNode(geometry: SCNCylinder(radius: 0.045, height: 0.72))
        handle.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.32, green: 0.18, blue: 0.10, alpha: 1), roughness: 0.6)
        handle.position = SCNVector3(0, -0.27, 0)
        cursorToolPivot.addChildNode(handle)
        // Molded rubber grip ribs and a metal ferrule add small manufactured details.
        for index in 0..<5 {
            let rib = SCNNode(geometry: SCNCylinder(radius: 0.050, height: 0.035))
            rib.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.075, green: 0.085, blue: 0.095, alpha: 1), roughness: 0.92)
            rib.position = SCNVector3(0, -0.49 + CGFloat(index) * 0.085, 0)
            cursorToolPivot.addChildNode(rib)
        }
        let ferrule = SCNNode(geometry: SCNCylinder(radius: 0.052, height: 0.055))
        ferrule.geometry?.firstMaterial = metal
        ferrule.position = SCNVector3(0, 0.075, 0)
        cursorToolPivot.addChildNode(ferrule)
        for side: CGFloat in [-1, 1] {
            let fastener = SCNNode(geometry: SCNSphere(radius: 0.012))
            fastener.geometry?.firstMaterial = metal
            fastener.position = SCNVector3(side * 0.046, -0.02, 0)
            cursorToolPivot.addChildNode(fastener)
        }
        let head: SCNNode
        switch selectedTool {
        case "Rubber Mallet":
            head = SCNNode(geometry: SCNCylinder(radius: 0.14, height: 0.42))
            head.eulerAngles.z = .pi / 2
            head.geometry?.firstMaterial = material(NSColor.darkGray, roughness: 0.8)
        case "Wrench":
            head = SCNNode(geometry: SCNTorus(ringRadius: 0.12, pipeRadius: 0.035))
            head.geometry?.firstMaterial = metal
        case "Screwdriver":
            head = SCNNode(geometry: SCNBox(width: 0.075, height: 0.30, length: 0.075, chamferRadius: 0.02))
            head.geometry?.firstMaterial = metal
        case "Flashlight":
            head = SCNNode(geometry: SCNCylinder(radius: 0.13, height: 0.30))
            head.geometry?.firstMaterial = metal
        case "Impact Driver":
            head = SCNNode(geometry: SCNBox(width: 0.24, height: 0.34, length: 0.18, chamferRadius: 0.045))
            head.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.16, green: 0.42, blue: 0.52, alpha: 1), roughness: 0.38)
            let chuck = SCNNode(geometry: SCNCylinder(radius: 0.045, height: 0.22))
            chuck.geometry?.firstMaterial = metal
            chuck.position = SCNVector3(0, 0.12, -0.18)
            head.addChildNode(chuck)
        case "Plastic Spudger":
            head = SCNNode(geometry: SCNBox(width: 0.075, height: 0.40, length: 0.045, chamferRadius: 0.025))
            head.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.18, green: 0.62, blue: 0.82, alpha: 1), roughness: 0.7)
        case "Sledgehammer":
            head = SCNNode(geometry: SCNBox(width: 0.62, height: 0.28, length: 0.24, chamferRadius: 0.055))
            head.geometry?.firstMaterial = material(NSColor(calibratedWhite: 0.30, alpha: 1), roughness: 0.72)
            for side: CGFloat in [-1, 1] {
                let cap = SCNNode(geometry: SCNCylinder(radius: 0.13, height: 0.035))
                cap.geometry?.firstMaterial = metal
                cap.position = SCNVector3(side * 0.31, 0, 0)
                cap.eulerAngles.z = .pi / 2
                head.addChildNode(cap)
            }
        case "Crowbar":
            head = SCNNode(geometry: SCNCylinder(radius: 0.045, height: 0.72))
            head.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.76, green: 0.18, blue: 0.10, alpha: 1), roughness: 0.32)
            head.eulerAngles.z = .pi / 2
            let claw = SCNNode(geometry: SCNCylinder(radius: 0.035, height: 0.28))
            claw.geometry?.firstMaterial = metal
            claw.position = SCNVector3(0.30, 0.11, 0)
            claw.eulerAngles.z = 0.62
            head.addChildNode(claw)
        case "Drill":
            head = SCNNode(geometry: SCNBox(width: 0.30, height: 0.38, length: 0.34, chamferRadius: 0.07))
            head.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.12, green: 0.46, blue: 0.30, alpha: 1), roughness: 0.42)
            let chuck = SCNNode(geometry: SCNCylinder(radius: 0.055, height: 0.30))
            chuck.geometry?.firstMaterial = metal
            chuck.position = SCNVector3(0, 0.04, -0.28)
            chuck.eulerAngles.x = .pi / 2
            head.addChildNode(chuck)
            let grip = SCNNode(geometry: SCNBox(width: 0.12, height: 0.30, length: 0.13, chamferRadius: 0.035))
            grip.geometry?.firstMaterial = darkGripMaterial()
            grip.position = SCNVector3(0, -0.30, 0.02)
            head.addChildNode(grip)
        case "Saw":
            head = SCNNode(geometry: SCNCylinder(radius: 0.19, height: 0.055))
            head.geometry?.firstMaterial = metal
            head.eulerAngles.z = .pi / 2
            for tooth in 0..<12 {
                let angle = CGFloat(tooth) * (.pi * 2 / 12)
                let spike = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.035, height: 0.075))
                spike.geometry?.firstMaterial = metal
                spike.position = SCNVector3(cos(angle) * 0.19, sin(angle) * 0.19, 0)
                head.addChildNode(spike)
            }
        case "Fire Simulator":
            head = SCNNode(geometry: SCNBox(width: 0.22, height: 0.30, length: 0.25, chamferRadius: 0.045))
            head.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.80, green: 0.22, blue: 0.06, alpha: 1), roughness: 0.38)
            let nozzle = SCNNode(geometry: SCNCylinder(radius: 0.07, height: 0.22))
            nozzle.geometry?.firstMaterial = metal
            nozzle.position = SCNVector3(0, 0.04, -0.22)
            nozzle.eulerAngles.x = .pi / 2
            head.addChildNode(nozzle)
        case "Water Blaster":
            head = SCNNode(geometry: SCNBox(width: 0.25, height: 0.34, length: 0.30, chamferRadius: 0.06))
            head.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.08, green: 0.48, blue: 0.86, alpha: 1), roughness: 0.32)
            let barrel = SCNNode(geometry: SCNCylinder(radius: 0.075, height: 0.34))
            barrel.geometry?.firstMaterial = metal
            barrel.position = SCNVector3(0, 0.10, -0.29)
            barrel.eulerAngles.x = .pi / 2
            head.addChildNode(barrel)
            let tank = SCNNode(geometry: SCNBox(width: 0.20, height: 0.26, length: 0.18, chamferRadius: 0.04))
            tank.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.20, green: 0.66, blue: 0.92, alpha: 0.8), roughness: 0.22)
            tank.position = SCNVector3(0, -0.24, 0.08)
            head.addChildNode(tank)
        case "Suction Cup":
            head = SCNNode(geometry: SCNTorus(ringRadius: 0.12, pipeRadius: 0.035))
            head.geometry?.firstMaterial = material(NSColor(calibratedRed: 0.18, green: 0.25, blue: 0.28, alpha: 1), roughness: 0.28)
        default:
            head = SCNNode(geometry: SCNBox(width: 0.42, height: 0.18, length: 0.18, chamferRadius: 0.04))
            head.geometry?.firstMaterial = metal
        }
        head.position = SCNVector3(0, 0.13, 0)
        cursorToolPivot.addChildNode(head)
        cursorTool.isHidden = true
    }
    private func hasAncestor(named name: String, startingAt node: SCNNode) -> Bool {
        var current: SCNNode? = node
        while let candidate = current {
            if candidate.name == name { return true }
            current = candidate.parent
        }
        return false
    }

    private func isInside(_ node: SCNNode, root: SCNNode) -> Bool {
        var current: SCNNode? = node
        while let candidate = current {
            if candidate === root { return true }
            current = candidate.parent
        }
        return false
    }

    private func interactiveHit(at point: NSPoint) -> SCNHitTestResult? {
        guard let sceneView else { return nil }
        let hits = sceneView.hitTest(point, options: nil).filter { hit in
            var node: SCNNode? = hit.node
            while let current = node {
                if current.name == "Window crack overlay" || current.name == "Screen crack overlay" || current.name == "Surface damage mark" ||
                    current.name == "Cursor tool" || current.name == "Swing pivot" {
                    return false
                }
                node = current.parent
            }
            return true
        }
        // Prefer the actual window/device geometry over the grass backdrop or workbench
        // when the ray crosses more than one visible surface.
        if !windowHasBroken, let glass = hits.first(where: {
            hasAncestor(named: "Breakable window glass", startingAt: $0.node) ||
            $0.node.name?.hasPrefix("Window frame") == true
        }) {
            return glass
        }
        if let device = deviceRoot, let deviceHit = hits.first(where: { isInside($0.node, root: device) }) {
            return deviceHit
        }
        return hits.first
    }

    private func aimTool(at point: NSPoint) {
        guard let hit = interactiveHit(at: point) else { cursorTool.isHidden = true; return }
        cursorTool.isHidden = false
        cursorTool.position = hit.worldCoordinates
        cursorTool.position.y += 0.48
        cursorTool.eulerAngles = SCNVector3(-0.62, 0.35, 0.30)
    }
    private func swingTool(at point: NSPoint) {
        aimTool(at: point)
        guard !cursorTool.isHidden else { return }
        if let hit = interactiveHit(at: point) {
            damageScore += max(1, Int(CGFloat(damageLevel) * toolPower * 10))
            hitCount += 1
            scoreLabel?.stringValue = String(format: "SCORE %04d  •  HITS %02d", damageScore, hitCount)
            if selectedTool == "Fire Simulator" {
                emitFire(on: hit.node, worldPoint: hit.worldCoordinates)
                playSpatial("fire_roar", at: hit.worldCoordinates, volume: 0.72)
            } else if selectedTool == "Water Blaster" {
                sprayWater(at: hit.worldCoordinates, hitNode: hit.node)
                playSpatial("water_spray", at: hit.worldCoordinates, volume: 0.82)
            } else {
                let impact = CGFloat(damageLevel) * toolPower
                switch selectedTool {
                case "Sledgehammer": playSpatial("sledgehammer_impact", at: hit.worldCoordinates, volume: 0.95)
                case "Crowbar": playSpatial("crowbar_creak", at: hit.worldCoordinates, volume: 0.82)
                case "Drill": playSpatial("drill_whirr", at: hit.worldCoordinates, volume: 0.72)
                case "Saw": playSpatial("saw_whine", at: hit.worldCoordinates, volume: 0.78)
                default: break
                }
                let touchesGlass = hasAncestor(named: "Breakable window glass", startingAt: hit.node)
                let touchesFrame = hit.node.name?.hasPrefix("Window frame") == true
                if !windowHasBroken && (touchesGlass || touchesFrame) {
                    windowHitCount += toolPower > 1.8 ? 2 : 1
                    if touchesGlass, let glass = windowIntactGlass {
                        addWindowCrack(at: hit.worldCoordinates, normal: hit.worldNormal, stage: min(2, windowHitCount), on: glass)
                    }
                    playSpatial("glass_tap", at: hit.worldCoordinates, volume: 0.9)
                    if windowHitCount >= 2 {
                        breakWindow(at: hit.worldCoordinates)
                    } else {
                        statusLabel.stringValue = "Visible glass crack — another hit will scatter the shards."
                    }
                } else if let device = deviceRoot, isInside(hit.node, root: device) {
                    if isScreenSurface(hit.node) {
                        addScreenCrack(at: hit.worldCoordinates, normal: hit.worldNormal, on: hit.node)
                        playSpatial("glass_tap", at: hit.worldCoordinates, volume: 0.92)
                        if impact > 0.55 { playSpatial("glass_crackle", at: hit.worldCoordinates, volume: 0.86) }
                    } else {
                        playSpatial(impact > 0.9 ? "surface_scratch" : "device_thud", at: hit.worldCoordinates, volume: 0.92)
                    }
                    damageDevicePart(hit.node, at: hit.worldCoordinates, normal: hit.worldNormal, intensity: impact)
                    if impact > 0.45 { playSpatial("device_rattle", at: hit.worldCoordinates, volume: 0.58) }
                    let normal = hit.worldNormal
                    let impulse = CGFloat(0.12) + impact * 0.16
                    device.physicsBody?.applyForce(SCNVector3(-normal.x * impulse, -normal.y * impulse, -normal.z * impulse), asImpulse: true)
                } else if let panel = deskBreakablePanels.first(where: { isInside(hit.node, root: $0) }) {
                    damageDeskPanel(panel, at: hit.worldCoordinates, normal: hit.worldNormal, intensity: impact)
                    playSpatial("wood_knock", at: hit.worldCoordinates, volume: 0.86)
                } else if let prop = roomBreakables.first(where: { isInside(hit.node, root: $0) }) {
                    damageRoomProp(prop, at: hit.worldCoordinates, normal: hit.worldNormal, intensity: impact)
                } else if hit.node.name?.hasPrefix("Physics stack block") == true {
                    let key = ObjectIdentifier(hit.node)
                    let accumulated = (physicsBlockDamage[key] ?? 0) + impact * 0.30
                    physicsBlockDamage[key] = accumulated
                    addSurfaceDamage(at: hit.worldCoordinates, normal: hit.worldNormal, scratch: accumulated < 1.0, on: hit.node)
                    deformImpactMesh(hit.node, worldPoint: hit.worldCoordinates, worldNormal: hit.worldNormal, intensity: impact)
                    if accumulated >= 3.2 { breakPhysicsBlock(hit.node, at: hit.worldCoordinates, normal: hit.worldNormal) }
                }
            }
        }
        cursorToolPivot.removeAllActions()
        cursorToolPivot.eulerAngles = SCNVector3(-0.75, 0, -0.72)
        let down = SCNAction.rotateTo(x: 0.92, y: 0, z: 0.58, duration: 0.16, usesShortestUnitArc: true)
        down.timingMode = .easeOut
        let up = SCNAction.rotateTo(x: -0.75, y: 0, z: -0.72, duration: 0.22, usesShortestUnitArc: true)
        up.timingMode = .easeInEaseOut
        cursorToolPivot.runAction(.sequence([down, up]))
        play(swingSound)
        statusLabel.stringValue = selectedTool == "Fire Simulator" ? "Virtual flame deployed." :
            (selectedTool == "Water Blaster" ? "Water spray deployed." : "Swing: " + selectedTool + " · virtual prop damage.")
    }

    private func breakPhysicsBlock(_ block: SCNNode, at point: SCNVector3, normal: SCNVector3) {
        guard block.parent != nil, let geometry = block.geometry else { return }
        let world = block.presentation.worldPosition
        let bounds = geometry.boundingBox
        let size = SCNVector3(bounds.max.x - bounds.min.x, bounds.max.y - bounds.min.y, bounds.max.z - bounds.min.z)
        let fragmentMaterial = geometry.firstMaterial ?? self.material(.gray, roughness: 0.72)
        block.removeFromParentNode()
        let fragmentSize = SCNVector3(size.x * 0.48, size.y * 0.48, size.z * 0.48)
        for index in 0..<4 {
            let fragment = SCNNode(geometry: SCNBox(width: fragmentSize.x, height: fragmentSize.y, length: fragmentSize.z, chamferRadius: 0.012))
            fragment.name = "Physics block fragment"
            fragment.geometry?.firstMaterial = fragmentMaterial
            fragment.position = SCNVector3(world.x + (CGFloat(index % 2) - 0.5) * size.x * 0.50,
                                           world.y + (index < 2 ? -1 : 1) * size.y * 0.20,
                                           world.z + (CGFloat(index / 2) - 0.5) * size.z * 0.50)
            let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: fragment.geometry!, options: nil))
            configureDynamicBody(body, mass: 0.16, friction: 0.68, restitution: 0.08, angularDamping: 0.34)
            fragment.physicsBody = body
            scene.rootNode.addChildNode(fragment)
            let impulse = CGFloat.random(in: 0.20...0.48)
            body.applyForce(SCNVector3(normal.x * impulse, max(0.10, normal.y * impulse), normal.z * impulse), asImpulse: true)
            fragment.runAction(.sequence([.wait(duration: 12), .fadeOut(duration: 0.5), .removeFromParentNode()]))
        }
        physicsBlockDamage.removeValue(forKey: ObjectIdentifier(block))
        playSpatial("device_thud", at: point, volume: 0.9)
        statusLabel.stringValue = "Block fractured into four loose pieces."
    }

    @objc private func spawnChaosProp() {
        guard sceneView != nil else { statusLabel.stringValue = "Start the 3D demo first."; return }
        let colors = [
            NSColor(calibratedRed: 0.78, green: 0.34, blue: 0.22, alpha: 1),
            NSColor(calibratedRed: 0.24, green: 0.55, blue: 0.78, alpha: 1),
            NSColor(calibratedRed: 0.72, green: 0.62, blue: 0.28, alpha: 1)
        ]
        let side = CGFloat.random(in: 0.38...0.72)
        let geometry = SCNBox(width: side, height: side, length: side, chamferRadius: 0.035)
        geometry.firstMaterial = material(colors.randomElement() ?? .systemOrange, roughness: 0.64)
        let prop = SCNNode(geometry: geometry)
        prop.name = "Physics stack block spawned"
        prop.position = SCNVector3(CGFloat.random(in: -2.4...2.4), 3.8, CGFloat.random(in: -1.8...1.8))
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: geometry, options: nil))
        configureDynamicBody(body, mass: 0.65, friction: 0.70, restitution: 0.10, angularDamping: 0.38)
        prop.physicsBody = body
        scene.rootNode.addChildNode(prop)
        statusLabel.stringValue = "A fresh breakable prop dropped into the room."
    }

    @objc private func strike() {
        guard let sceneView else { statusLabel.stringValue = "Start the 3D demo first."; return }
        swingTool(at: NSPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY))
    }

    @objc private func dropObject() {
        guard let target = deviceRoot else { return }
        target.position = SCNVector3(0, 5.2, 0)
        target.physicsBody?.velocity = SCNVector3Zero
        target.physicsBody?.angularVelocity = SCNVector4Zero
        // Gravity and the collision surface determine the fall; no random sideways impulse.
        statusLabel.stringValue = "Drop test started. The object will fall onto the room floor."
    }

    @objc private func resetScene() {
        buildScene()
        damageScore = 0
        hitCount = 0
        scoreLabel?.stringValue = "SCORE 0000  •  HITS 00"
        statusLabel.stringValue = "Scene reset. All simulated damage and props cleared."
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = SmashSimulator()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
