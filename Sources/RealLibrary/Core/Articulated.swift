import simd
import Foundation
import RealityKit
import RealKit

/// An asset with moving parts and named states (doors, drawers, lids, lamps). Implement `rig(seed:)`;
/// `build(seed:)` comes for free as the default state baked into a static LODModel, so thumbnails,
/// the prop yard, budgets and instanced fields treat it like any other asset.
///
/// Rules (enforced by `ArticulationTests`): at least two distinct states, the first is the default
/// unless `defaultState` says otherwise; every state value is inside its joint range; every posed
/// state stays within `budget`; parts are declared parents first.
public protocol RealArticulated: RealAsset {
    func rig(seed: UInt64) -> Rig
}

public extension RealArticulated {
    func build(seed: UInt64) -> LODModel { rig(seed: seed).posed() }
    /// A state baked to static geometry (for instanced rows: every chair pushed in, every door open).
    func build(seed: UInt64, state: String) -> LODModel { rig(seed: seed).posed(state) }
    static var states: [String] { Self().rig(seed: 1).stateNames }
}

public extension Catalog {
    /// Articulated assets (subset of `assets`).
    static var articulated: [any RealArticulated.Type] { assets.compactMap { $0 as? any RealArticulated.Type } }
    static func rig(_ id: String, seed: UInt64 = 1) -> Rig? { (type(id) as? any RealArticulated.Type).map { $0.init().rig(seed: seed) } }
}
