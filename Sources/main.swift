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
    private var showingInternals = false
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
        // Build the complete scene before exposing the window. This avoids showing
        // a blank view during first-frame setup and removes the blocking startup modal.
        NSApp.setActivationPolicy(.regular)
        buildWindow()
        buildScene()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Smash Simulator — Demo"
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

        let subtitle = NSTextField(labelWithString: "PLAYABLE DEMO  •  PHYSICS SANDBOX")
        subtitle.font = .systemFont(ofSize: 9, weight: .bold)
        subtitle.textColor = NSColor(calibratedWhite: 0.58, alpha: 1)
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(subtitle)


        devicePopup = popup(["iPhone", "MacBook", "Desktop PC", "iPad", "TV"], selected: selectedDevice)
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
        let internals = makeButton("TOGGLE DEVICE INTERNALS", action: #selector(toggleDeviceInternals))
        sidebar.addSubview(hit); sidebar.addSubview(drop); sidebar.addSubview(reset); sidebar.addSubview(internals)

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
        sceneView.autoenablesDefaultLighting = false
        sceneView.antialiasingMode = .multisampling4X
        sceneView.preferredFramesPerSecond = 60
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
            internals.leadingAnchor.constraint(equalTo: hit.leadingAnchor),
            internals.trailingAnchor.constraint(equalTo: hit.trailingAnchor),
            internals.topAnchor.constraint(equalTo: reset.bottomAnchor, constant: 9),
            statusLabel.topAnchor.constraint(greaterThanOrEqualTo: internals.bottomAnchor, constant: 10),
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
        b.bezelColor = NSColor(calibratedRed: 0.10, green: 0.34, blue: 0.48, alpha: 1)
        b.contentTintColor = .white
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
        camera.camera?.wantsHDR = true
        camera.camera?.wantsExposureAdaptation = true
        camera.camera?.bloomIntensity = 0.10
        camera.camera?.bloomThreshold = 1.25
        camera.camera?.vignettingIntensity = 0.22
        camera.camera?.screenSpaceAmbientOcclusionIntensity = 0.62
        camera.camera?.screenSpaceAmbientOcclusionRadius = 7.0
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
        key.light?.castsShadow = true
        key.light?.shadowRadius = 7
        key.light?.shadowSampleCount = 16
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
        playSurfaceImpact(first: first, second: second, impulse: impulse)
        addImpactDecal(at: contact.contactPoint, normal: contact.contactNormal, impulse: impulse, surfaceName: first + " " + second)
        let touchesWindow = contact.nodeA.name == "Breakable window glass" || contact.nodeB.name == "Breakable window glass"
        if touchesWindow && impulse >= windowBreakThreshold {
            breakWindow(at: contact.contactPoint)
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
        play(shatterSound)
        play(debrisScatterSound)

        for shard in shardGroup.childNodes {
            shard.isHidden = false
            guard let geometry = shard.geometry else { continue }
            let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: geometry, options: nil))
            configureDynamicBody(body, mass: 0.075, friction: 0.34, restitution: 0.08, angularDamping: 0.18)
            shard.physicsBody = body

            let p = shard.presentation.worldPosition
            var direction = SCNVector3(p.x - impactPoint.x, p.y - impactPoint.y + 0.22, p.z - impactPoint.z)
            let length = max(0.001, sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z))
            direction = SCNVector3(direction.x / length, direction.y / length, direction.z / length)
            let impulse = CGFloat.random(in: 0.75...1.65)
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
    private func addWindowCrack(at point: SCNVector3, normal: SCNVector3, stage: Int) {
        guard let name = (1...8).map({ String(format: "crack_%02d", $0) }).randomElement(),
              let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return }
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
        decal.position = SCNVector3(point.x + normal.x * 0.032,
                                    point.y + normal.y * 0.032,
                                    point.z + normal.z * 0.032)
        let target = SCNVector3(point.x + normal.x, point.y + normal.y, point.z + normal.z)
        decal.look(at: target, up: scene.rootNode.worldUp, localFront: SCNVector3(0, 0, 1))
        decal.eulerAngles.z += CGFloat.random(in: 0...(2 * .pi))
        decal.opacity = 1
        scene.rootNode.addChildNode(decal)
        windowCrackDecals.append(decal)
    }

    // Cosmetic texture-plane overlays only; no material damage model is used.
    private func addImpactDecal(at point: SCNVector3, normal: SCNVector3, impulse: CGFloat, surfaceName: String) {
        let surface = surfaceName.lowercased()
        let isGlass = surface.contains("glass") || surface.contains("window") || surface.contains("screen") || surface.contains("display")
        let isSoft = surface.contains("floor") || surface.contains("carpet")
        let isScratch = !isGlass && !isSoft &&
            (impulse > 4.2 || surface.contains("wood") || surface.contains("desk") ||
             surface.contains("workbench") || surface.contains("metal") || surface.contains("frame"))
        let names: [String]
        if isGlass {
            names = (1...8).map { String(format: "crack_%02d", $0) }
        } else if isSoft {
            names = (1...4).map { String(format: "scuff_%02d", $0) }
        } else if isScratch {
            names = (1...6).map { String(format: "scratch_%02d", $0) }
        } else {
            names = (1...8).map { String(format: "crack_%02d", $0) }
        }
        guard let name = names.randomElement(),
              let url = Bundle.main.url(forResource: name, withExtension: "png") else { return }
        if impactDecals.count >= maximumImpactDecals {
            let oldest = impactDecals.removeFirst()
            oldest.removeFromParentNode()
        }
        let width = CGFloat.random(in: 0.28...0.52) * (1 + min(0.55, impulse / 30))
        let plane = SCNPlane(width: width, height: width * CGFloat.random(in: 0.72...1.28))
        let material = SCNMaterial()
        material.diffuse.contents = NSImage(contentsOf: url)
        material.transparent.contents = NSImage(contentsOf: url)
        material.isDoubleSided = true
        material.lightingModel = .constant
        material.blendMode = .alpha
        plane.firstMaterial = material
        let decal = SCNNode(geometry: plane)
        decal.name = "Impact VFX decal"
        decal.position = SCNVector3(point.x + normal.x * 0.006,
                                    point.y + normal.y * 0.006,
                                    point.z + normal.z * 0.006)
        let target = SCNVector3(point.x + normal.x, point.y + normal.y, point.z + normal.z)
        decal.look(at: target, up: scene.rootNode.worldUp, localFront: SCNVector3(0, 0, 1))
        decal.eulerAngles.z += CGFloat.random(in: 0...(2 * .pi))
        decal.opacity = 0.92
        scene.rootNode.addChildNode(decal)
        impactDecals.append(decal)
        decal.runAction(.sequence([.wait(duration: 14.0), .fadeOut(duration: 1.0), .removeFromParentNode()]))
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.2) { [weak self, weak decal] in
            guard let self, let decal else { return }
            self.impactDecals.removeAll { $0 === decal }
        }
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
        let colors = [
            NSColor(calibratedRed: 0.12, green: 0.34, blue: 0.075, alpha: 1),
            NSColor(calibratedRed: 0.19, green: 0.43, blue: 0.09, alpha: 1),
            NSColor(calibratedRed: 0.25, green: 0.39, blue: 0.08, alpha: 1),
            NSColor(calibratedRed: 0.10, green: 0.27, blue: 0.055, alpha: 1)
        ]
        let blades = colors.map { color -> SCNGeometry in
            let cone = SCNCone(topRadius: 0.0015, bottomRadius: 0.012, height: 0.28)
            cone.radialSegmentCount = 4
            cone.firstMaterial = material(color, roughness: 0.98)
            return cone
        }
        func sample(_ index: Int) -> CGFloat {
            let value = (index &* 1664525 &+ 1013904223) & 0x7fffffff
            return CGFloat(value % 10000) / 10000
        }
        for tuft in 0..<160 {
            let x = -10.0 + sample(tuft * 7 + 3) * 20.0
            let z = -10.0 - sample(tuft * 11 + 5) * 17.0
            let count = 2 + Int(sample(tuft * 13 + 9) * 2)
            for bladeIndex in 0..<count {
                let blade = SCNNode(geometry: blades[(tuft + bladeIndex) % blades.count])
                let height = 0.16 + sample(tuft * 19 + bladeIndex * 23 + 1) * 0.26
                blade.scale = SCNVector3(1, height / 0.28, 1)
                blade.position = SCNVector3(x + (sample(tuft * 29 + bladeIndex) - 0.5) * 0.12,
                                            height * 0.5 - 0.19,
                                            z + (sample(tuft * 31 + bladeIndex * 3) - 0.5) * 0.12)
                blade.eulerAngles = SCNVector3(0, sample(tuft * 37 + bladeIndex) * .pi,
                                               (sample(tuft * 41 + bladeIndex) - 0.5) * 0.55)
                scene.rootNode.addChildNode(blade)
            }
        }
        for index in 0..<5 {
            let mound = SCNSphere(radius: 1)
            mound.firstMaterial = material(colors[index % colors.count], roughness: 1)
            let node = SCNNode(geometry: mound)
            node.name = "Distant grassy mound"
            node.scale = SCNVector3(2.6 + CGFloat(index % 2), 0.22, 0.65)
            node.position = SCNVector3(-8 + CGFloat(index) * 4, -0.18, -27 + CGFloat(index % 2) * 1.2)
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
        addStaticBox(name: "Storage cabinet carcass", size: SCNVector3(1.75, 2.10, 0.72), position: SCNVector3(-7.75, 1.05, -5.65), surface: cabinet)
        for x: CGFloat in [-8.18, -7.32] {
            addStaticBox(name: "Storage cabinet door", size: SCNVector3(0.82, 1.98, 0.045), position: SCNVector3(x, 1.05, -5.265), surface: trim)
            let knob = SCNNode(geometry: SCNSphere(radius: 0.045))
            knob.name = "Cabinet knob"
            knob.geometry?.firstMaterial = accent
            knob.position = SCNVector3(x + (x < -7.7 ? 0.30 : -0.30), 1.05, -5.21)
            scene.rootNode.addChildNode(knob)
        }
        for level in 0..<2 {
            addStaticBox(name: "Wall storage shelf", size: SCNVector3(0.62, 0.12, 4.25),
                         position: SCNVector3(-9.48, 3.15 + CGFloat(level) * 1.05, -1.65), surface: cabinet)
            for item in 0..<4 {
                let bin = SCNNode(geometry: SCNBox(width: 0.34, height: 0.26, length: 0.42, chamferRadius: 0.025))
                bin.name = "Storage bin"
                bin.geometry?.firstMaterial = storageBinMaterial(item)
                bin.position = SCNVector3(-9.42, 3.34 + CGFloat(level) * 1.05, -3.15 + CGFloat(item) * 0.98)
                scene.rootNode.addChildNode(bin)
            }
        }
        addStaticBox(name: "Workshop pegboard", size: SCNVector3(0.08, 2.65, 4.15),
                     position: SCNVector3(9.72, 3.65, -1.45), surface: cabinet)
        for row in 0..<10 {
            for col in 0..<13 {
                let hole = SCNNode(geometry: SCNSphere(radius: 0.018))
                hole.geometry?.firstMaterial = trim
                hole.position = SCNVector3(9.665, 2.55 + CGFloat(row) * 0.23, -3.35 + CGFloat(col) * 0.32)
                scene.rootNode.addChildNode(hole)
            }
        }
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
        m.lightingModel = .physicallyBased
        m.roughness.contents = roughness
        m.metalness.contents = roughness < 0.34 ? 0.28 : 0.045
        return m
    }

    private func makeDevice() {
        deviceRoot?.removeFromParentNode()
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
            screen.eulerAngles.x = -0.10
            root.addChildNode(screen)
            for row in 0..<4 { for col in 0..<12 {
                root.addChildNode(box(0.16, 0.018, 0.12, metal, SCNVector3(-1.25 + Float(col) * 0.23, 0.245, -0.62 + Float(row) * 0.18), 0.025))
            }}
            addShellBox("MacBook trackpad", SCNVector3(0.92, 0.018, 0.58), SCNVector3(0, 0.245, 0.47), dark, 0.06)
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
            root.addChildNode(box(3.0, 1.85, 0.16, metal, SCNVector3(0, 1.25, -0.25)))
            root.addChildNode(box(2.78, 1.62, 0.035, glass, SCNVector3(0, 1.25, -0.145)))
            root.addChildNode(box(0.24, 0.85, 0.24, metal, SCNVector3(0, 0.48, -0.25)))
            root.addChildNode(box(1.25, 0.12, 0.65, metal, SCNVector3(0, 0.12, -0.25)))
            root.addChildNode(box(0.82, 1.65, 0.8, dark, SCNVector3(2.05, 0.85, 0.1)))
            root.addChildNode(box(0.68, 1.48, 0.03, glass, SCNVector3(2.05, 0.85, 0.515)))
            for y: CGFloat in [0.48, 1.12] {
                let fan = SCNNode(geometry: SCNTorus(ringRadius: 0.17, pipeRadius: 0.022))
                fan.name = "Desktop case fan ring"
                fan.geometry?.firstMaterial = metal
                fan.position = SCNVector3(2.05, y, 0.54)
                addShell(fan)
                addShellSphere("Desktop fan hub", radius: 0.055, position: SCNVector3(2.05, y, 0.56), surface: dark)
            }
            addShellSphere("Desktop power button", radius: 0.045, position: SCNVector3(2.05, 1.57, 0.55), surface: metal)
            for x: CGFloat in [1.76, 2.34] {
                for z: CGFloat in [-0.20, 0.40] {
                    addShellBox("Desktop case foot", SCNVector3(0.12, 0.08, 0.12), SCNVector3(x, 0.025, z), dark)
                }
            }
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
            root.addChildNode(box(2.08, 0.035, 2.78, glass, SCNVector3(0, 0.30, 0)))
            addShellSphere("Tablet rear camera lens", radius: 0.055, position: SCNVector3(0.82, 0.33, -1.24), surface: dark)
            addShellBox("Tablet charging port", SCNVector3(0.32, 0.045, 0.035), SCNVector3(0, 0.22, 1.50), dark)
            for i in 0..<8 {
                addShellBox("Tablet speaker perforation", SCNVector3(0.025, 0.012, 0.035),
                            SCNVector3(-0.70 + CGFloat(i) * 0.20, 0.30, 1.46), dark, 0.006)
            }
        default:
            root.addChildNode(box(1.25, 0.16, 2.45, metal, SCNVector3(0, 0.18, 0), 0.14))
            root.addChildNode(box(1.12, 0.035, 2.28, glass, SCNVector3(0, 0.28, 0), 0.12))
            let speaker = SCNNode(geometry: SCNCylinder(radius: 0.045, height: 0.012))
            speaker.geometry?.firstMaterial = metal
            speaker.position = SCNVector3(0, 0.305, 1.02)
            root.addChildNode(speaker)
            addShellSphere("Phone rear camera lens one", radius: 0.060, position: SCNVector3(0.40, 0.105, -0.96), surface: dark)
            addShellSphere("Phone rear camera lens two", radius: 0.052, position: SCNVector3(0.25, 0.105, -0.82), surface: dark)
            addShellSphere("Phone flash", radius: 0.025, position: SCNVector3(0.51, 0.105, -0.80), surface: metal)
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
            addInternalBox("PC motherboard", SCNVector3(0.62, 1.25, 0.045), SCNVector3(2.05, 0.86, 0.02), board)
            addInternalBox("Graphics card", SCNVector3(0.56, 0.20, 0.66), SCNVector3(2.05, 0.55, 0.12), graphite)
            addInternalBox("CPU heatsink", SCNVector3(0.30, 0.20, 0.30), SCNVector3(2.05, 1.03, 0.12), silver)
            addInternalBox("Power supply", SCNVector3(0.60, 0.30, 0.62), SCNVector3(2.05, 0.28, 0.10), graphite)
            for i in 0..<4 {
                addInternalBox("RAM module", SCNVector3(0.07, 0.48, 0.045), SCNVector3(1.65 + CGFloat(i) * 0.12, 0.90, 0.06), copper)
            }
            for y: CGFloat in [0.48, 1.10] {
                addInternalCylinder("Case fan", radius: 0.25, height: 0.06, position: SCNVector3(2.05, y, 0.32), color: graphite)
            }
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
            for i in 0..<8 {
                addInternalCylinder("Motherboard capacitor", radius: 0.035, height: 0.11,
                                    position: SCNVector3(1.77 + CGFloat(i % 4) * 0.15, 0.82, -0.08 + CGFloat(i / 4) * 0.18),
                                    color: silver)
            }
            for i in 0..<6 {
                addInternalBox("GPU memory chip", SCNVector3(0.10, 0.055, 0.10),
                               SCNVector3(1.72 + CGFloat(i) * 0.11, 0.62, 0.22), copper, 0.32)
            }
            addInternalBox("Motherboard power connector", SCNVector3(0.10, 0.12, 0.16), SCNVector3(2.34, 1.18, 0.12), silver)
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
        let collisionSize: SCNVector3 = selectedDevice == "MacBook" ? SCNVector3(3.0, 1.94, 2.0) : (selectedDevice == "Desktop PC" ? SCNVector3(3.0, 2.15, 1.0) : (selectedDevice == "iPad" ? SCNVector3(2.3, 0.16, 3.0) : (selectedDevice == "TV" ? SCNVector3(3.84, 2.40, 0.34) : SCNVector3(1.3, 0.205, 2.5))))
        let modelCenterY: CGFloat
        switch selectedDevice {
        case "MacBook": modelCenterY = 1.0825
        case "Desktop PC": modelCenterY = 1.10
        case "iPad": modelCenterY = 0.23
        case "TV": modelCenterY = 1.20
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
            case "TV": profile = (7.2, 0.80, 0.04, 0.64)
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

    private func playSurfaceImpact(first: String, second: String, impulse: CGFloat) {
        let contactNames = (first + " " + second).lowercased()
        let touchesDevice = contactNames.contains("device") || contactNames.contains("phone") ||
            contactNames.contains("tablet") || contactNames.contains("laptop")
        let touchesWood = contactNames.contains("wood") || contactNames.contains("desk") ||
            contactNames.contains("drawer") || contactNames.contains("workbench") || contactNames.contains("tabletop")
        let touchesMetal = contactNames.contains("metal") || contactNames.contains("frame") ||
            contactNames.contains("pull") || contactNames.contains("hinge")
        let touchesFloor = contactNames.contains("floor") || contactNames.contains("carpet")

        if contactNames.contains("glass") || contactNames.contains("window") || contactNames.contains("screen") || contactNames.contains("display") {
            play(glassTapSound)
            if impulse > 1.0 { play(glassCrackleSound) }
            if touchesDevice { play(deviceRattleSound) }
        } else if touchesMetal {
            play(metalClangSound)
            if touchesDevice { play(deviceRattleSound) }
        } else if touchesWood {
            play(woodKnockSound)
            if touchesDevice { play(deviceRattleSound) }
        } else if touchesFloor {
            play(carpetThumpSound)
            if touchesDevice { play(deviceRattleSound) }
        } else if touchesDevice {
            if impulse > 4.2 { play(scratchSound) } else { play(deviceThudSound) }
            if impulse > 1.8 { play(deviceRattleSound) }
        } else {
            play(plasticClickSound ?? impactSound)
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
        let hits = sceneView.hitTest(point, options: nil).filter { hit in
            var node: SCNNode? = hit.node
            while let current = node {
                if current.name == "Selection marker" || current.name == "Impact VFX decal" ||
                    current.name == "Window crack overlay" || current.name == "Cursor tool" ||
                    current.name == "Swing pivot" {
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
            let touchesGlass = hasAncestor(named: "Breakable window glass", startingAt: hit.node)
            let touchesFrame = hit.node.name?.hasPrefix("Window frame") == true
            if !windowHasBroken && (touchesGlass || touchesFrame) {
                windowHitCount += 1
                addWindowCrack(at: hit.worldCoordinates, normal: hit.worldNormal, stage: windowHitCount)
                play(glassTapSound)
                if windowHitCount == 1 { play(glassCrackleSound) }
                if windowHitCount >= 2 {
                    breakWindow(at: hit.worldCoordinates)
                } else {
                    statusLabel.stringValue = "Visible glass crack — one more hit to scatter the shards."
                }
            } else if let device = deviceRoot, isInside(hit.node, root: device) {
                let power = CGFloat(5 + damageLevel * 18)
                addImpactDecal(at: hit.worldCoordinates, normal: hit.worldNormal, impulse: CGFloat(damageLevel) * 5, surfaceName: hit.node.name ?? "Device")
                let strikeImpulse = CGFloat(damageLevel) * 5
                if strikeImpulse > 4.2 { play(scratchSound) } else { play(deviceThudSound) }
                if damageLevel > 0.45 { play(deviceRattleSound) }
                device.physicsBody?.applyForce(SCNVector3(0, power * 0.07, power), asImpulse: true)
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
