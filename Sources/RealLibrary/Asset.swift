import simd
import Foundation
@_exported import simd
@_exported import RealCore
@_exported import RealMaterials

/// A parameterized, seeded asset generator. Rules (enforced by tests):
/// - `id` is unique, kebab-case, permanent.
/// - `build(seed:)` is deterministic; LOD 0 has triangles; every LOD uses only library material keys.
/// - Meters, +Y up, base at y = 0, centered on X/Z.
public protocol RealAsset: Sendable {
    static var id: String { get }
    static var summary: String { get }
    static var tags: [String] { get }
    /// Triangle budget for LOD 0 (tests fail above it).
    static var budget: Int { get }
    init()
    func build(seed: UInt64) -> LODModel
}

public extension RealAsset {
    static var budget: Int { 40_000 }
    func build() -> LODModel { build(seed: 1) }
    func with(_ edit: (inout Self) -> Void) -> Self { var c = self; edit(&c); return c }
}

/// Grounded transform helper for scenes.
public func place(_ x: Float, _ z: Float, y: Float = 0, yaw: Float = 0, scale: Float = 1) -> Xform {
    Xform(translation: V3(x, y, z), rotation: simd_quatf(degrees: yaw, axis: .up), scale: V3(repeating: scale))
}
