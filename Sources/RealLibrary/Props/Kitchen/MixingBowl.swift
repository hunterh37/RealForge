import simd
import Foundation

/// 3 qt spun stainless mixing bowl: 0.8 mm wall curving up from a small flat floor, a rolled rim bead,
/// satin spin-finished interior with utensil scratches, mirror-polished exterior. Axis at the asset
/// origin; the inner floor is its own surface.
public struct MixingBowl: RealAsset {
    public static let id = "mixing-bowl"
    public static let summary = "3 qt stainless mixing bowl: spun 0.8 mm wall, rolled rim, satin interior, mirror exterior."
    public static let tags = ["prop", "kitchen", "cookware", "metal", "container", "handheld"]
    public static let budget = 10_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 32, distance: 0.6, studio: true)

    /// Top of the inner floor above the base (m).
    public var floorY: Float = 0.0012
    /// Radius of the flat floor (m).
    public var innerRadius: Float = 0.05
    /// Height of the rim top (m).
    public var rimY: Float = 0.098
    /// Inner radius at the rim (m).
    public var rimRadius: Float = 0.117
    /// Wall thickness (m).
    public var wall: Float = 0.0008
    /// Rolled bead radius (m).
    public var bead: Float = 0.0024
    public var interior: MaterialKey = "metal.pan-interior"
    public var exterior: MaterialKey = "metal.mirror-polish"
    public init() {}

    /// Bowl axis on the floor top (asset space).
    public var floorCenter: V3 { V3(0, floorY, 0) }

    func vessel() -> Vessel {
        let f = floorY, R = innerRadius, rr = rimRadius, top = rimY - 2 * bead
        var pts: [V2] = [V2(0, f), V2(R - 0.01, f), V2(R, f)]
        for k in 1...14 {
            let t = Float(k) / 14 * .pi / 2
            pts.append(V2(R + (rr - R) * pow(sin(t), 0.85), f + (top - f) * (1 - cos(t))))
        }
        return Vessel(inner: pts, wall: wall, floorRadius: R, rim: .rolled(bead))
    }

    func model(segments: Int) -> Model {
        let v = vessel()
        var m = Model(name: Self.id)
        var floorSurface: Surface?
        for (role, s) in v.surfaces(segments: segments, interior: interior, exterior: exterior, seamTile: 0.12) {
            if role == .floor { floorSurface = s } else { m.add(s) }
        }
        if let fs = floorSurface { m.surfaces.append(fs) }
        groundAO(&m, height: 0.03, floor: 0.55)
        return m
    }

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(segments: 96), model(segments: 40)], switchDistances: [3])
    }
}
