import SwiftUI
import RealityKit
import RealCore
import RealKit
import RealLibrary

/// Full-immersion scene: sky dome + IBL + sun, the composed scene placed so its camera hint sits at
/// the viewer's feet facing -Z, and head-tracked LOD.
struct ImmersiveSceneView: View {
    let config: SpaceConfig
    @Environment(DemoModel.self) private var model
    /// Scene root. Capture args `-pan <deg/s>` and `-dolly <m/s>` move it for camera-motion footage.
    @State private var anchor = Entity()

    var body: some View {
        RealityView { content in
            model.loading = true
            model.status = "building \(config.scene.rawValue)…"
            let t0 = Date()
            do {
                let id = config.scene.rawValue, seed = config.seed
                guard let scene = await Task.detached(priority: .userInitiated, operation: { SceneCatalog.build(id, seed: seed) }).value else {
                    model.status = "unknown scene \(id)"; model.loading = false; return
                }
                // Scene lighting hints (interior probe, fog off, its own sun) unless the menu sky applies.
                let env = try RealityHD.environment(for: scene, sky: config.scene.usesSceneLighting ? nil : config.sky.sunSky)
                let world = try await scene.entity()
                anchor.addChild(world)
                if let cam = scene.camera { anchor.transform = Self.viewerTransform(eye: cam.eye, target: cam.target, extraYaw: config.yaw) }
                env.illuminate(world)
                content.add(env.root)
                content.add(anchor)
                model.status = "\(id) seed \(seed) \(config.sky.rawValue): \(Int(Date().timeIntervalSince(t0) * 1000)) ms"
            } catch {
                model.status = "error: \(error)"
            }
            model.loading = false
        }
        // Articulated assets: tap a door, drawer, lid or lamp to toggle it.
        .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { $0.entity.realToggle() })
        .task { await RealViewerTracker.shared.start() }
        .task { await captureMotion() }
        .onDisappear { RealViewerTracker.shared.stop() }
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
