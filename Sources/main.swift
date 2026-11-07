import AppKit
import SceneKit
import QuartzCore

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
    private var sceneView: SmashSceneView!
    private var scene = SCNScene()
    private var deviceRoot: SCNNode?
    private var selectedTool = "Hammer"
    private var selectedDevice = "iPhone"
    private var cursorTool = SCNNode()
    private var cursorToolPivot = SCNNode()
    private var swingSound: NSSound?
    private var impactSound: NSSound?
    private var damageLevel: Float = 0.72
    private var roomStyle = "Studio"
    private var statusLabel: NSTextField!
    private var devicePopup: NSPopUpButton!
    private var toolPopup: NSPopUpButton!
    private var roomPopup: NSPopUpButton!
    private var damageSlider: NSSlider!
    private let deskTopY: CGFloat = 1.26
    private let dynamicCategoryMask = 1
    private let staticCategoryMask = 2
    private let cameraBounds = (x: CGFloat(9.20), y: CGFloat(6.35), z: CGFloat(8.15))

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
        toolPopup = popup(["Hammer", "Rubber Mallet", "Wrench", "Screwdriver", "Flashlight"], selected: selectedTool)
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
        sceneView.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.11, alpha: 1)
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.antialiasingMode = .multisampling4X
        sceneView.delegate = self
        sceneView.defaultCameraController.interactionMode = .orbitTurntable
        sceneView.defaultCameraController.automaticTarget = false
        sceneView.defaultCameraController.inertiaEnabled = true
        sceneView.defaultCameraController.target = SCNVector3(0, 1.30, 0)
        sceneView.defaultCameraController.minimumVerticalAngle = 8
        sceneView.defaultCameraController.maximumVerticalAngle = 40
        sceneView.onInspect = { [weak self] point in self?.inspectObject(at: point) }
        sceneView.onAim = { [weak self] point in self?.aimTool(at: point) }
        sceneView.onSwing = { [weak self] point in self?.swingTool(at: point) }
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
        window.acceptsMouseMovedEvents = true
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
        configurePhysicsWorld()
        sceneView.scene = scene

        let camera = SCNNode()
        camera.camera = SCNCamera()
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
        key.light?.castsShadow = true
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

        makeRoom()
        makeDesk()
        makeDevice()
        makePhysicsProps()
        makeCursorTool()
        prepareAudio()
    }

    // Centralized SceneKit world tuning. A smaller fixed simulation step improves
    // stability for the existing dynamic device and props while keeping all physics
    // local to this scene. Contact callbacks are informational only.
    private func configurePhysicsWorld() {
        scene.physicsWorld.gravity = SCNVector3(0, -9.8, 0)
        scene.physicsWorld.speed = 1.0
        // A fixed 120 Hz step reduces tunnelling and jitter for the existing SceneKit bodies.
        scene.physicsWorld.timeStep = 1.0 / 120.0
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
        guard statusLabel != nil else { return }
        let impulse = contact.collisionImpulse
        guard impulse > 0.35 else { return }
        let first = contact.nodeA.name ?? "Object"
        let second = contact.nodeB.name ?? "Surface"
        statusLabel.stringValue = String(
            format: "Scene contact: %@ ↔ %@  ·  impulse %.1f",
            first, second, impulse
        )
        play(impactSound)
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
        let boundaries: [(String, SCNVector3, SCNVector3)] = [
            ("Back wall", SCNVector3(20, 7, 0.22), SCNVector3(0, 3.50, -8.90)),
            ("Front wall", SCNVector3(20, 7, 0.22), SCNVector3(0, 3.50, 8.90)),
            ("Left wall", SCNVector3(0.22, 7, 18), SCNVector3(-9.90, 3.50, 0)),
            ("Right wall", SCNVector3(0.22, 7, 18), SCNVector3(9.90, 3.50, 0)),
            ("Ceiling", SCNVector3(20, 0.20, 18), SCNVector3(0, 7.10, 0))
        ]

        for (name, size, position) in boundaries {
            addStaticBox(name: name, size: size, position: position, surface: wallMaterial)
        }
    }

    private func makeDesk() {
        let wood = material(
            NSColor(calibratedRed: 0.30, green: 0.20, blue: 0.13, alpha: 1),
            roughness: 0.84
        )
        let darkMetal = material(
            NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.18, alpha: 1),
            roughness: 0.46
        )
        let brushedMetal = material(
            NSColor(calibratedRed: 0.48, green: 0.53, blue: 0.58, alpha: 1),
            roughness: 0.30
        )

        // One-piece tabletop.
        addStaticBox(
            name: "Workbench tabletop",
            size: SCNVector3(7.6, 0.22, 4.6),
            position: SCNVector3(0, deskTopY, 0),
            surface: wood
        )

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

        let collisionSize: SCNVector3 = selectedDevice == "MacBook" ? SCNVector3(3.0, 1.94, 2.0) : (selectedDevice == "Desktop PC" ? SCNVector3(3.0, 2.15, 1.0) : (selectedDevice == "iPad" ? SCNVector3(2.3, 0.16, 3.0) : SCNVector3(1.3, 0.205, 2.5)))
        let modelCenterY: CGFloat
        switch selectedDevice {
        case "MacBook": modelCenterY = 1.0825
        case "Desktop PC": modelCenterY = 1.10
        case "iPad": modelCenterY = 0.23
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
            case "MacBook": profile = (3.4, 0.82, 0.045, 0.62)
            case "iPad": profile = (1.1, 0.76, 0.055, 0.58)
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
        rebuildCursorTool()
        statusLabel.stringValue = "Cursor tool selected. Move over the scene and click to swing."
    }

    @objc private func roomChanged(_ sender: NSPopUpButton) {
        roomStyle = sender.titleOfSelectedItem ?? "Studio"
        buildScene()
        statusLabel.stringValue = "Room changed to \(roomStyle)."
    }

    @objc private func damageChanged(_ sender: NSSlider) { damageLevel = Float(sender.floatValue) }

    private func prepareAudio() {
        swingSound = NSSound(contentsOfFile: "/System/Library/Sounds/Pop.aiff", byReference: true)
        impactSound = NSSound(contentsOfFile: "/System/Library/Sounds/Glass.aiff", byReference: true)
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
        default:
            head = SCNNode(geometry: SCNBox(width: 0.42, height: 0.18, length: 0.18, chamferRadius: 0.04))
            head.geometry?.firstMaterial = metal
        }
        head.position = SCNVector3(0, 0.13, 0)
        cursorToolPivot.addChildNode(head)
        cursorTool.isHidden = true
    }
    private func aimTool(at point: NSPoint) {
        guard let hit = sceneView.hitTest(point, options: nil).first else { cursorTool.isHidden = true; return }
        cursorTool.isHidden = false
        cursorTool.position = hit.worldCoordinates
        cursorTool.position.y += 0.48
        cursorTool.eulerAngles = SCNVector3(-0.62, 0.35, 0.30)
    }
    private func swingTool(at point: NSPoint) {
        aimTool(at: point)
        guard !cursorTool.isHidden else { return }
        cursorToolPivot.removeAllActions()
        cursorToolPivot.eulerAngles = SCNVector3(-0.75, 0, -0.72)
        let down = SCNAction.rotateTo(x: 0.92, y: 0, z: 0.58, duration: 0.16, usesShortestUnitArc: true)
        down.timingMode = .easeOut
        let up = SCNAction.rotateTo(x: -0.75, y: 0, z: -0.72, duration: 0.22, usesShortestUnitArc: true)
        up.timingMode = .easeInEaseOut
        cursorToolPivot.runAction(.sequence([down, up]))
        play(swingSound)
        statusLabel.stringValue = "Swing animation: " + selectedTool + " · virtual prop only."
    }
    @objc private func strike() {
        swingTool(at: NSPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY))
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
