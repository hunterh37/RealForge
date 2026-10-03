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
    let world = WorldTrackingProvider()
    public private(set) var running = false

    public func start() async {
        guard !running, WorldTrackingProvider.isSupported else { return }
        do { try await session.run([world]); running = true } catch { running = false }
    }

    public func stop() { session.stop(); running = false }

    func update() {
        guard running, world.state == .running,
              let a = world.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else { return }
        let c = a.originFromAnchorTransform.columns.3
        RealViewer.position = SIMD3(c.x, c.y, c.z)
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
