import simd
import Foundation
@_exported import simd
@_exported import RealCore
@_exported import RealMaterials

/// A parameterized, seeded asset generator. Rules (enforced by `Tests/RealForgeTests/AssetContractTests`):
/// - `id` is unique, kebab-case, permanent. Renaming an id breaks apps that load by id.
/// - `tags[0]` is the kind (`AssetTag.kinds`); every tag is in `AssetTag.vocabulary`.
/// - `summary` is one sentence ending in a period: what it is and how it's built.
/// - `build(seed:)` is deterministic; LOD 0 has triangles within `budget`; LODs get cheaper.
/// - Every surface uses a `MaterialLibrary` key (optionally with a `:RRGGBB` tint).
/// - Meters, +Y up, base at y = 0, centered on X/Z.
/// - `docs/assets/<id>.png` exists (`swift run -q realforge thumbs <id>`).
public protocol RealAsset: Sendable {
    static var id: String { get }
    static var summary: String { get }
    static var tags: [String] { get }
    /// Triangle budget for LOD 0 (tests fail above it).
    static var budget: Int { get }
    /// Credit shown in CATALOG.md: a GitHub handle, or "realforge" for core assets.
    static var author: String { get }
    /// Camera and lighting defaults for `realforge render` and `realforge thumbs`.
    static var preview: PreviewHint { get }
    init()
    func build(seed: UInt64) -> LODModel
}

public extension RealAsset {
    static var budget: Int { 40_000 }
    static var author: String { "realforge" }
    static var preview: PreviewHint { PreviewHint() }
    func build() -> LODModel { build(seed: 1) }
    func with(_ edit: (inout Self) -> Void) -> Self { var c = self; edit(&c); return c }
}

/// How the CLI frames an asset. Angles in degrees; `distance` scales the auto-fit distance.
public struct PreviewHint: Sendable {
    public var azimuth: Float = 35
    public var elevation: Float = 10
    public var distance: Float = 1.15
    /// Put the asset on a flat forest-floor patch.
    public var ground = true
    /// Fog density override (0 = none); nil keeps the sky preset's.
    public var fog: Float?
    public init(azimuth: Float = 35, elevation: Float = 10, distance: Float = 1.15, ground: Bool = true, fog: Float? = nil) {
        self.azimuth = azimuth; self.elevation = elevation; self.distance = distance; self.ground = ground; self.fog = fog
    }
}

/// Grounded transform helper for scenes.
public func place(_ x: Float, _ z: Float, y: Float = 0, yaw: Float = 0, scale: Float = 1) -> Xform {
    Xform(translation: V3(x, y, z), rotation: simd_quatf(degrees: yaw, axis: .up), scale: V3(repeating: scale))
}
