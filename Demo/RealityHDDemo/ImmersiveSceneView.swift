import SwiftUI
import RealityKit
import RealCore
import RealKit
import RealLibrary

/// Full-immersion scene: sky dome + IBL + sun, the composed scene placed so its camera hint sits at
/// the viewer's feet facing -Z, and head-tracked LOD. Rebuilds in place when `model.rebuildToken`
/// moves (build-time performance settings changed).
struct ImmersiveSceneView: View {
    let config: SpaceConfig
    @Environment(DemoModel.self) private var model
    /// Holds the environment and the scene anchor; emptied on rebuild.
    @State private var root = Entity()
    /// Scene root. Capture args `-pan <deg/s>` and `-dolly <m/s>` move it for camera-motion footage.
    @State private var anchor = Entity()
    /// Teleport destinations of the built scene.
    @State private var spots: [RealScene.Spot] = []

    var body: some View {
        RealityView { content, attachments in
            content.add(root)
            if let hud = attachments.entity(for: "hud") {
                let head = AnchorEntity(.head)
                head.anchoring.trackingMode = .continuous
                hud.position = SIMD3(0, -0.24, -0.8)
                head.addChild(hud)
                content.add(head)
            }
        } update: { _, attachments in
            attachments.entity(for: "hud")?.isEnabled = model.showHUD
        } attachments: {
            Attachment(id: "hud") { StatsHUD() }
        }
        // Tap a door, drawer, lid or lamp to toggle it; tap the floor to move there.
        .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { value in
            if value.entity.name == Self.floorName {
                guard model.tapTeleport else { return }
                let p = value.convert(value.location3D, from: .local, to: .scene)
                teleport(toScenePoint: p)
            } else {
                value.entity.realToggle()
            }
        })
        .task(id: model.rebuildToken) { await build() }
        .onChange(of: model.teleportTo) { _, name in
            guard let name else { return }
            model.teleportTo = nil
            if let s = spots.first(where: { $0.name == name }) { teleport(to: s) }
        }
        .onChange(of: model.resetGrabsToken) { resetGrabs(anchor) }
        .onDisappear { model.spots = [] }
        .task { await RealViewerTracker.shared.start() }
        .task { await captureMotion() }
        .onDisappear { RealViewerTracker.shared.stop() }
    }

    private func build() async {
        model.loading = true
        model.status = "building \(config.scene.rawValue)…"
        let t0 = Date()
        let perf = RealityHD.performance
        do {
            let id = config.scene.rawValue, seed = config.seed
            guard let scene = await Task.detached(priority: .userInitiated, operation: { SceneCatalog.build(id, seed: seed) }).value else {
                model.status = "unknown scene \(id)"; model.loading = false; return
            }
            // Scene lighting hints (interior probe, fog off, its own sun) unless the menu sky applies.
            let env = try RealityHD.environment(for: scene, sky: config.scene.usesSceneLighting ? nil : config.sky.sunSky)
            let world = try await scene.entity()
            root.children.removeAll()
            anchor.children.removeAll()
            anchor.addChild(world)
            anchor.addChild(Self.teleportFloor())
            spots = scene.spots
            if spots.isEmpty, let cam = scene.camera { spots = [.init("start", eye: cam.eye, target: cam.target)] }
            model.spots = spots.map(\.name)
            if let cam = scene.camera { anchor.transform = Self.viewerTransform(eye: cam.eye, target: cam.target, extraYaw: config.yaw) }
            env.illuminate(world)
            root.addChild(env.root)
            root.addChild(anchor)
            model.builtWith = perf
            let cost = scene.estimate(settings: perf)
            model.status = "\(id) seed \(seed) \(config.sky.rawValue) \(perf.tier?.rawValue ?? "custom"): "
                + "\(Int(Date().timeIntervalSince(t0) * 1000)) ms, est \(cost.triangles / 1000)k tris \(cost.drawCalls) draws"
        } catch {
            model.status = "error: \(error)"
        }
        model.loading = false
    }

    static let floorName = "teleport-floor"

    /// Invisible tap target at floor level under the whole scene (props and parts above it win the hit).
    static func teleportFloor(size: Float = 160) -> Entity {
        let e = Entity()
        e.name = floorName
        let shape = ShapeResource.generateBox(size: SIMD3(size, 0.02, size)).offsetBy(translation: SIMD3(0, -0.01, 0))
        e.components.set(CollisionComponent(shapes: [shape], mode: .trigger, filter: .default))
        e.components.set(InputTargetComponent())
        return e
    }

    /// Viewer's feet in scene space (head pose from `RealViewerTracker`, origin without tracking).
    private var feet: SIMD3<Float> {
        let h = RealViewer.position
        return SIMD3(h.x, 0, h.z)
    }

    /// Moves the scene so the tapped floor point lands under the viewer, keeping the heading.
    private func teleport(toScenePoint p: SIMD3<Float>) {
        var local = anchor.convert(position: p, from: nil)
        local.y = 0
        let rot = anchor.transform.rotation
        move(to: Transform(scale: .one, rotation: rot, translation: feet - rot.act(local)))
    }

    /// Moves the scene so the spot's eye stands at the viewer's feet, its target ahead along -Z.
    private func teleport(to spot: RealScene.Spot) {
        var t = Self.viewerTransform(eye: spot.eye, target: spot.target)
        t.translation += feet
        move(to: t)
    }

    private func move(to t: Transform) {
        anchor.move(to: t, relativeTo: anchor.parent, duration: 0.35, timingFunction: .easeInOut)
    }

    private func resetGrabs(_ e: Entity) {
        if e.components.has(RealGrabComponent.self) { e.resetGrab(); return }
        for c in e.children { resetGrabs(c) }
    }

    /// Slow pan (yaw about the viewer) and dolly (forward along -Z) from launch args, for capture.
    private func captureMotion() async {
        let d = UserDefaults.standard
        let pan = d.float(forKey: "pan"), dolly = d.float(forKey: "dolly")
        guard pan != 0 || dolly != 0 else { return }
        while model.loading || anchor.children.isEmpty { try? await Task.sleep(for: .milliseconds(50)) }
        let base = anchor.transform.matrix
        let t0 = Date()
        while !Task.isCancelled {
            let t = Float(Date().timeIntervalSince(t0))
            let rot = simd_quatf(angle: -pan * t * .pi / 180, axis: SIMD3(0, 1, 0))
            let move = Transform(scale: .one, rotation: rot, translation: rot.act(SIMD3(0, 0, dolly * t)))
            anchor.transform = Transform(matrix: move.matrix * base)
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    /// Moves the scene so `eye` (minus standing height) lands at the origin and `target` lies along -Z.
    static func viewerTransform(eye: V3, target: V3, extraYaw: Float = 0, standingHeight: Float = 1.6) -> Transform {
        let d = target - eye
        let yaw = atan2(d.x, -d.z) + extraYaw * .pi / 180                       // heading of the look direction, clockwise from -Z
        let rot = simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0))   // rotating by +yaw (CCW) brings it back to -Z
        let feet = SIMD3(eye.x, eye.y - standingHeight, eye.z)
        return Transform(scale: .one, rotation: rot, translation: -rot.act(feet))
    }
}
