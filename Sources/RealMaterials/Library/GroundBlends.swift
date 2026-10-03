import RealCore

public extension MaterialLibrary {
    /// Two-layer ground: a base floor with a second material painted in through `Surface.splat`
    /// (ShaderGraph path; the PhysicallyBasedMaterial fallback shows the base only).
    static let groundBlends: [MaterialSpec] = [
        /// Lakeshore meadow worn to bare packed earth around a fire, tent and shore path.
        blend("ground.meadow-worn", base: "ground.meadow", splat: "ground.dirt", softness: 0.25),
        /// Autumn broadleaf litter with a trodden earth footpath painted through it.
        blend("ground.litter-path", base: "ground.leaf-litter", splat: "ground.dirt", softness: 0.3),
    ]

    private static func blend(_ key: MaterialKey, base: MaterialKey, splat: MaterialKey, softness: Float) -> MaterialSpec {
        ground.first { $0.key == base }!.with { $0.key = key; $0.splat = splat; $0.splatSoftness = softness; $0.splatHeight = 1.5 }
    }
}
