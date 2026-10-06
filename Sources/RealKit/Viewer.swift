import Foundation
import RealityKit
#if os(visionOS)
import ARKit
import QuartzCore

/// Head-pose source for LOD on visionOS. Runs ARKit world tracking (needs an open ImmersiveSpace) and
/// feeds `RealViewer.position` every LOD tick. Without it, LOD measures from `RealViewer.position`.
@MainActor
public final class RealViewerTracker {
    public static let shared = RealViewerTracker()
    let session = ARKitSession()
    /// ARKit refuses to re-run a stopped provider, so each start() makes a fresh one.
    var world = WorldTrackingProvider()
    public private(set) var running = false

    public func start() async {
        guard !running, WorldTrackingProvider.isSupported else { return }
        if world.state == .stopped { world = WorldTrackingProvider() }
        running = true
        do { try await session.run([world]) } catch { running = false }
    }

    public func stop() { session.stop(); running = false }

    func update() {
        guard running, world.state == .running,
              let a = world.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else { return }
        let m = a.originFromAnchorTransform
        RealViewer.position = SIMD3(m.columns.3.x, m.columns.3.y, m.columns.3.z)
        RealViewer.forward = -SIMD3(m.columns.2.x, m.columns.2.y, m.columns.2.z)
    }
}
#endif

extension RealViewer {
    @MainActor static func refresh() {
        #if os(visionOS)
        RealViewerTracker.shared.update()
        #endif
    }
}
