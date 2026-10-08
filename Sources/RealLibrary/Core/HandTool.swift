import simd
import RealityKit
import RealKit

/// A hand tool with a hold point and a working end, both in asset space (the rest pose `build` and
/// `rig` produce: base at y = 0, centred on X/Z).
/// `RealityHD.tool(_:)` returns the asset with its origin moved to `grip`, so a hand-anchored or grabbed
/// entity turns about the palm and `tip` (minus `grip`) is the working end in the entity's frame.
public protocol RealHandTool: RealAsset {
    /// Natural hold point (centre of the palm on the handle).
    static var grip: SIMD3<Float> { get }
    /// Working end (jaw, hook, probe, brush face, crown).
    static var tip: SIMD3<Float> { get }
}

public extension Catalog {
    /// Assets with a hold point and a working end.
    static var handTools: [any RealHandTool.Type] { assets.compactMap { $0 as? any RealHandTool.Type } }
}

public extension RealityHD {
    /// A hand tool with its root at `grip`: the asset sits in a child offset by `-grip`, and the root is
    /// grabbable (unless `grabbable: false`). Articulated tools keep their live parts. `tip` relative to the
    /// root is `T.tip - T.grip`.
    static func tool(_ id: String, seed: UInt64 = 1, state: String? = nil, grabbable: Bool = true) async throws -> Entity {
        guard let t = Catalog.type(id) as? any RealHandTool.Type else { throw RealityHDError.unknown(id) }
        let grip = t.grip
        let inner: Entity
        if Catalog.type(id) is any RealArticulated.Type {
            inner = try await articulated(id, seed: seed, state: state, interactive: true, grabbable: false)
        } else {
            inner = try await entity(id, seed: seed, grabbable: false)
        }
        return await MainActor.run {
            let root = Entity()
            root.name = id + ":grip"
            inner.position = -grip
            root.addChild(inner)
            if grabbable { root.makeGrabbable() }
            return root
        }
    }
}
