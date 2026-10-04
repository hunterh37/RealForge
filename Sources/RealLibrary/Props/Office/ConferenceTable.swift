import simd
import Foundation

/// Boardroom table, 320 x 120 x 74 cm: 40 mm walnut-veneered top with soft-radiused corners and a
/// knife-edge underside chamfer (the edge reads 15 mm thick), two black powder-coated steel slab legs
/// with foot plates and glides on a hidden steel spine, and a flush power/data module in the center of
/// the top (brushed stainless trim and lid, black cable-exit brush strip and push latch).
public struct ConferenceTable: RealAsset {
    public static let id = "conference-table"
    public static let summary = "Boardroom table: 40 mm walnut veneer top with chamfered underside, black steel slab legs and a flush stainless power module."
    public static let tags = ["prop", "office", "furniture", "wood", "metal"]
    public static let budget = 5_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 22, distance: 1.0, studio: true)

    public var length: Float = 3.2
    public var depth: Float = 1.2
    public var height: Float = 0.74
    /// Top veneer (`wood.veneer-oak` for the light version).
    public var wood: MaterialKey = "wood.veneer-walnut"
    public var steel: MaterialKey = "metal.powdercoat:1C1C1D"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [8])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length, D = depth, H = height
        let topT: Float = 0.04, edgeT: Float = 0.015, chamfer: Float = 0.05
        let corner: Float = 0.06
        let outline = Shape2D.roundedRect(L, D, radius: corner, segments: detail ? 6 : 3)
        let flat = simd_quatf(degrees: -90, axis: V3(1, 0, 0))
        // Upper slab: the visible 15 mm edge with a 2 mm soft arris on top.
        m.add(Prim.extrude(outline, depth: edgeT, bevel: 0.002, bevelSegments: detail ? 2 : 1, material: wood),
              Xform(translation: V3(0, H - edgeT / 2, 0), rotation: flat))
        // Underside chamfer: lofted band from the edge down and in to the thick core.
        let inset = Shape2D.offset(outline, -chamfer)
        let y0 = H - edgeT + 0.0004, y1 = H - topT
        m.add(Prim.loft([Prim.ring(inset, y: y1), Prim.ring(Shape2D.offset(outline, -0.001), y: y0)], material: wood))
        m.add(Prim.extrude(inset, depth: 0.002, bevel: 0, material: wood), Xform(translation: V3(0, y1 + 0.001, 0), rotation: flat))

        // Slab legs: 60 mm steel plate frames 0.8 m deep, foot plate and glides, under a steel spine.
        let legX = L / 2 - 0.55, legD: Float = 0.78, legT: Float = 0.06, foot: Float = 0.008
        let legH = y1 - 0.025 - foot
        for s: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(legT, legH, legD), radius: 0.004, bevelSegments: detail ? 2 : 1, material: steel),
                  Xform(translation: V3(s * legX, foot + legH / 2, 0)).jittered(&rng, deg: 0.03, offset: 0.0002))
            m.add(Prim.roundedBox(V3(0.1, 0.012, legD + 0.04), radius: 0.003, bevelSegments: 1, material: steel),
                  Xform(translation: V3(s * legX, foot + 0.006, 0)))
            // Mounting plate under the top.
            m.add(Prim.roundedBox(V3(0.1, 0.025, legD - 0.04), radius: 0.003, bevelSegments: 1, material: steel),
                  Xform(translation: V3(s * legX, y1 - 0.0125, 0)))
            if detail {
                for z in [-legD / 2, legD / 2] {
                    m.add(Prim.cylinder(radius: 0.018, height: foot, bevel: 0.002, segments: 16, bevelSegments: 1, material: "plastic.black"),
                          Xform(translation: V3(s * legX, 0, z * 0.92)))
                }
            }
        }
        // Spine beam joining the legs, 100 x 50 mm, and cable basket over the module.
        m.add(Prim.roundedBox(V3(2 * legX, 0.05, 0.1), radius: 0.003, bevelSegments: 1, material: steel),
              Xform(translation: V3(0, y1 - 0.025, -0.2)))

        // Power/data module, 420 x 140 mm, flush in the top (trim 0.8 mm proud).
        let mw: Float = 0.42, md: Float = 0.14
        let trim = Shape2D.roundedRect(mw, md, radius: 0.008, segments: detail ? 3 : 2)
        let hole = Shape2D.roundedRect(mw - 0.012, md - 0.012, radius: 0.004, segments: detail ? 3 : 2)
        // Trim ring: thin lofted collar (outer wall + flat top), the lid sits inside it.
        let ring = Prim.loft([Prim.ring(trim, y: H - 0.0005), Prim.ring(trim, y: H + 0.0006), Prim.ring(Shape2D.offset(trim, -0.0015), y: H + 0.0009),
                              Prim.ring(hole, y: H + 0.0009), Prim.ring(hole, y: H - 0.004)], material: "metal.stainless")
        m.add(ring)
        m.add(Prim.extrude(Shape2D.offset(hole, -0.0008), depth: 0.002, bevel: 0.0006, bevelSegments: 1, material: "metal.stainless"),
              Xform(translation: V3(0, H - 0.0002, 0), rotation: flat))
        // Black inserts: cable-exit brush strip along the back edge and the push latch.
        m.add(Prim.roundedBox(V3(mw - 0.05, 0.0014, 0.008), radius: 0.0005, bevelSegments: 1, material: "plastic.black"),
              Xform(translation: V3(0, H + 0.0003, -md / 2 + 0.014)))
        m.add(Prim.cylinder(radius: 0.007, height: 0.001, bevel: 0.0004, segments: 14, bevelSegments: 1, material: "plastic.black"),
              Xform(translation: V3(mw / 2 - 0.03, H + 0.0006, 0.02)))
        if detail {
            // Socket body hanging below the top.
            m.add(Prim.roundedBox(V3(mw - 0.02, 0.1, md - 0.02), radius: 0.004, bevelSegments: 1, material: "plastic.black"),
                  Xform(translation: V3(0, y1 - 0.05, 0)))
        }
        groundAO(&m, height: 0.1, floor: 0.6)
        return m
    }
}
