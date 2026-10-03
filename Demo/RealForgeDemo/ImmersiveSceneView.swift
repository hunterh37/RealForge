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

    var body: some View {
        RealityView { content in
            model.loading = true
            model.status = "building \(config.scene.rawValue)…"
            let t0 = Date()
            do {
                let env = try RealForge.environment(config.sky.sunSky, skybox: true)
                let id = config.scene.rawValue, seed = config.seed
                guard let scene = await Task.detached(priority: .userInitiated, operation: { SceneCatalog.build(id, seed: seed) }).value else {
                    model.status = "unknown scene \(id)"; model.loading = false; return
                }
                let world = try await scene.entity()
                let anchor = Entity()
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
        .task { await RealViewerTracker.shared.start() }
        .onDisappear { RealViewerTracker.shared.stop() }
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
