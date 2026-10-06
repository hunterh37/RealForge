import simd
import Foundation

/// 27 cm white vitreous china dinner plate: unglazed foot ring, a shallow well (flat food surface at
/// `wellY`), a coved rise to a 3.6 cm flat rim and a rolled rim edge. One lathe, axis at the asset origin.
public struct DinnerPlate: RealAsset {
    public static let id = "dinner-plate"
    public static let summary = "Dinner plate, 27 cm: white vitreous china, shallow well, 3.6 cm flat rim, rolled edge, unglazed foot ring."
    public static let tags = ["prop", "kitchen"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 38, distance: 0.6, studio: true)

    /// Outer diameter (m).
    public var diameter: Float = 0.27
    /// Height of the rim top above the base (m).
    public var height: Float = 0.024
    /// Radius of the flat well floor (m).
    public var wellRadius: Float = 0.088
    /// Top of the well floor above the base (m): where plated food sits.
    public var wellY: Float = 0.0105
    /// Width of the flat rim (m).
    public var rimWidth: Float = 0.036
    /// Glazed body and unglazed foot ring.
    public var glaze: MaterialKey = "ceramic.vitreous"
    public var foot: MaterialKey = "ceramic.bisque:E6E0D2"
    public init() {}

    /// Center of the food surface (asset space).
    public var floorCenter: V3 { V3(0, wellY, 0) }

    public func build(seed: UInt64) -> LODModel {
        let R = diameter / 2, H = height, t: Float = 0.0045
        let rimIn = R - rimWidth, wy = wellY, wr = wellRadius
        // Top surface from the rim edge inward, then the underside back out: one closed profile.
        let er: Float = 0.0024
        // Build explicitly: outer underside -> edge -> rim top -> cove -> well -> center.
        var p: [V2] = []
        p.append(V2(0, 0.0032))                        // underside center (recessed inside the foot)
        p.append(V2(wr * 0.7, 0.0026))
        p.append(V2(wr - 0.004, 0.0024))
        p.append(V2(wr - 0.0025, 0.0006))              // foot ring inner
        p.append(V2(wr - 0.0012, 0))
        p.append(V2(wr + 0.0012, 0))
        p.append(V2(wr + 0.0028, 0.0008))              // foot ring outer
        p.append(V2(wr + 0.008, wy - t + 0.0012))
        // Underside of the cove and rim.
        for k in 1...6 {
            let f = Float(k) / 6
            p.append(V2(wr + 0.008 + (rimIn - wr - 0.004) * f, wy - t + 0.0012 + (H - wy - 0.0018) * (1 - pow(1 - f, 2))))
        }
        p.append(V2(R - 0.012, H - t + 0.0005))
        p.append(V2(R - er, H - 2 * er + 0.0002))
        // Rolled edge (half circle around the rim lip).
        let ec = V2(R - er, H - er)
        for k in 1...7 {
            let a = -Float.pi / 2 + Float(k) / 8 * .pi
            p.append(ec + V2(er * cos(a), er * sin(a)))
        }
        p.append(V2(R - er, H))
        // Flat rim top, a slight downward slope inward, then the cove into the well.
        p.append(V2(R - 0.012, H - 0.0004))
        p.append(V2(rimIn + 0.004, H - 0.0012))
        for k in 1...8 {
            let f = Float(k) / 8
            let x = rimIn + 0.004 - (rimIn + 0.004 - wr) * f
            let y = (H - 0.0012) - (H - 0.0012 - wy) * (0.5 - 0.5 * cos(f * .pi))
            p.append(V2(x, y))
        }
        p.append(V2(wr * 0.6, wy))
        p.append(V2(wr * 0.25, wy))
        p.append(V2(0, wy))
        var body = Prim.lathe(p, segments: 96, seamTile: 0.3, material: glaze)
        body.recomputeNormals()
        // Unglazed foot ring contact face as a separate thin ring so it reads as bisque.
        let fp: [V2] = [V2(wr - 0.0013, 0.0002), V2(wr + 0.0013, 0.0002), V2(wr + 0.0013, -0.00005), V2(wr - 0.0013, -0.00005), V2(wr - 0.0013, 0.0002)]
        let ring = Prim.lathe(fp, segments: 96, seamTile: 0.3, material: foot)
        var m = Model(name: Self.id)
        m.add(body)
        m.add(ring)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(0, -b.min.y, 0)))
        groundAO(&m, height: 0.012, floor: 0.7)
        _ = seed
        return LODModel(m)
    }
}
