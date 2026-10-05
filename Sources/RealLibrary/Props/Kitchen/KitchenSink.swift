import simd
import Foundation

/// Undermount single-bowl stainless sink (18 gauge, satin): deep bowl with coved corners, flat
/// mounting flange that sits under the counter, basket strainer with a stopper and a tailpiece.
/// Fits `BaseCabinet.sinkCutout` (0.74 x 0.42 opening, 5 mm reveal). Base at the tailpiece bottom;
/// the flange top is at `flangeTopY`, so place it at `cabinet.sinkCenter.y - counterThickness - flangeTopY`.
public struct KitchenSink: RealAsset {
    public static let id = "kitchen-sink"
    public static let summary = "Undermount stainless single-bowl sink, 73 x 41 cm opening: coved bowl, flange, basket strainer."
    public static let tags = ["prop", "kitchen", "metal"]
    public static let budget = 5000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 50, distance: 1.3, studio: true)

    /// Bowl opening (x, z) at the rim.
    public var opening = V2(0.73, 0.41)
    public var bowlDepth: Float = 0.23
    public var material: MaterialKey = "metal.stainless"
    /// Bowl floor: water spots and haze from use.
    public var floorMaterial: MaterialKey = "metal.stainless-smudged"
    public init() {}

    static let tail: Float = 0.08
    /// Height of the flange top above the asset base.
    public var flangeTopY: Float { Self.tail + bowlDepth }
    /// Drain center on the bowl floor (rear of center).
    public var drainCenter: V3 { V3(0, Self.tail, -0.06) }

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let H = flangeTopY, y0 = Self.tail
        let n = 5
        // Flange: a 2 cm flat ring around the rim.
        m.add(KitchenFit.counterSlab(width: opening.x + 0.04, depth: opening.y + 0.04, thickness: 0.0012, ease: 0.0005, corner: 0.04,
                                     hole: (V2(0, 0), opening, 0.02), material: material), Xform(translation: V3(0, H - 0.0012, 0)))
        // Bowl wall: rim, straight sides with a slight draft, coved bottom corners (inner face up/in).
        let rings: [(V2, Float, Float)] = [(opening, 0.02, H), (opening - V2(0.004, 0.004), 0.022, H - 0.03), (opening - V2(0.02, 0.02), 0.03, y0 + 0.03),
                                            (opening - V2(0.034, 0.034), 0.04, y0 + 0.008), (opening - V2(0.05, 0.05), 0.045, y0 + 0.0012)]
        let loops = rings.map { r in KitchenFit.rrect(center: .zero, size: r.0, radius: r.1, n: n).map { V3($0.p.x, r.2, $0.p.y) } }
        m.add(Prim.loft(loops, material: material).flipped())
        // Outside skin (seen under the counter).
        let outer = rings.map { r in KitchenFit.rrect(center: .zero, size: r.0 + V2(0.0024, 0.0024), radius: r.1 + 0.0012, n: n).map { V3($0.p.x, r.2 - 0.0012, $0.p.y) } }
        m.add(Prim.loft(outer, material: material))
        // Floor with the drain opening.
        let floorSize = opening - V2(0.05, 0.05)
        m.add(KitchenFit.counterSlab(width: floorSize.x, depth: floorSize.y, thickness: 0.0012, ease: 0.0005, corner: 0.045,
                                     hole: (V2(drainCenter.x, drainCenter.z), V2(0.09, 0.09), 0.045), material: floorMaterial),
              Xform(translation: V3(0, y0, 0)))
        // Basket strainer: polished flange, perforated basket, stopper post, tailpiece and nut.
        let dc = drainCenter
        m.add(Prim.lathe([V2(0.0445, 0.0002), V2(0.056, 0.0012), V2(0.055, 0.003), V2(0.046, 0.0035), V2(0.043, 0.0)], segments: 32, material: "metal.chrome"),
              Xform(translation: dc + V3(0, 0.0012, 0)))
        m.add(Prim.lathe([V2(0.043, 0.0), V2(0.041, -0.03), V2(0.03, -0.075), V2(0.001, -0.076)], segments: 28, material: "metal.powdercoat:2C2C2C").flipped(),
              Xform(translation: dc))
        m.add(Prim.lathe([V2(0.001, 0), V2(0.036, 0), V2(0.036, 0.002), V2(0.001, 0.0025)], segments: 24, material: "metal.basket-mesh"), Xform(translation: dc + V3(0, -0.012, 0)))
        m.add(Prim.lathe([V2(0.001, 0), V2(0.006, 0), V2(0.007, 0.012), V2(0.005, 0.016), V2(0.001, 0.017)], segments: 12, material: "metal.chrome"), Xform(translation: dc + V3(0, -0.012, 0)))
        m.add(Prim.lathe([V2(0.05, 0), V2(0.05, 0.02), V2(0.044, 0.02)], segments: 16, material: "plastic.black"), Xform(translation: V3(dc.x, y0 - 0.04, dc.z)))
        m.add(Prim.cylinder(radius: 0.019, height: y0 - 0.02, bevel: 0.002, segments: 14, material: "metal.chrome"), Xform(translation: V3(dc.x, 0, dc.z)))
        var lod = m
        groundAO(&lod, height: 0.02, floor: 0.8)
        return LODModel(lod)
    }
}
