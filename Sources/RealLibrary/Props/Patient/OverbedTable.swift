import simd
import Foundation

/// Hospital overbed table (Invacare 6417 / Drive 13008 class): 762 x 381 mm top, 72-112 cm high.
/// H-base of 50 x 25 mm flat-oval steel tube (two 78 cm legs and a crossbar) on four 50 mm casters
/// (the two at the column end braked), a 76 x 50 mm rectangular column with a gas-spring inner stage, a
/// steel support arm, a 19 mm woodgrain laminate top in a PVC T-mold edge band split into a fixed
/// vanity section and a tilting reading panel with a book-stop lip. Joints: lift (column slide) >
/// tilt (reading panel, hinged on its patient-side edge).
public struct OverbedTable: RealArticulated {
    public static let id = "overbed-table"
    public static let summary = "Hospital overbed table: H-base on four casters, gas-spring telescoping column, woodgrain laminate top with a tilting reading panel and vanity section."
    public static let tags = ["prop", "medical", "hospital", "furniture", "metal", "wood", "articulated"]
    public static let budget = 11_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18, distance: 1.05, studio: true)

    /// Frame powder coat.
    public var frame: MaterialKey = "metal.powder-white:D9D6CE"
    /// Top laminate and edge band.
    public var laminate: MaterialKey = "laminate.patient-maple"
    public var edgeBand: MaterialKey = "plastic.matte:5E4C3C"
    public var topWidth: Float = 0.762
    public var topDepth: Float = 0.381
    /// Top surface height at the lowest setting (m) and gas-spring travel (m).
    public var lowHeight: Float = 0.725
    public var travel: Float = 0.4
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [7])
        let black: MaterialKey = "plastic.matte:2A2B2D", chrome: MaterialKey = "metal.chrome"
        let W = topWidth, D = topDepth, topY = lowHeight, slab: Float = 0.019
        let colX: Float = -0.3, colZ: Float = -0.04
        let legZ: Float = 0.17, legX0: Float = -0.4, legX1: Float = 0.37, casterH: Float = 0.065
        let legY = casterH + 0.0125
        let outerTop: Float = 0.62
        let flat = simd_quatf(degrees: -90, axis: V3(1, 0, 0))

        // MARK: base: H of flat-oval tube, end caps, casters, outer column.
        let legProf = Shape2D.superellipse(0.025, 0.05, exponent: 3.2, segments: 16)   // x up (25), y across (50)
        for l in 0..<2 {
            var m = Model(name: Self.id)
            for sz: Float in [-1, 1] {
                m.add(Prim.sweep(legProf, along: [V3(legX0, legY, sz * legZ), V3(legX1, legY, sz * legZ)], up: .up, material: frame))
                // Black end caps on both ends.
                for (x, dir) in [(legX0, Float(-1)), (legX1, Float(1))] {
                    m.add(Prim.superellipsoid(V3(0.016, 0.027, 0.052), exponent: 3.5, subdivisions: l == 0 ? 3 : 2, material: black),
                          Xform(translation: V3(x + dir * 0.005, legY, sz * legZ)))
                }
                for x in [legX0 + 0.03, legX1 - 0.025] {
                    let braked = x < 0
                    if l == 0 {
                        PatientKit.brakedCaster(&m, at: V3(x, 0, sz * legZ), height: casterH, wheelRadius: 0.025, yaw: rng.float(-30...30) + (braked ? 180 : 0),
                                                pedalYaw: 180, frame: black, wheel: "rubber", hub: "plastic.matte:8A8C90",
                                                pedal: braked ? "plastic.matte:B0302A" : nil, detail: true)
                    } else {
                        m.add(Prim.cylinder(radius: 0.025, height: 0.018, bevel: 0.004, segments: 8, bevelSegments: 1, material: black),
                              Xform(translation: V3(x + 0.008, 0.025, sz * legZ - 0.009), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
                        m.add(PatientKit.box(V3(0.04, 0.03, 0.03), V3(x, casterH - 0.02, sz * legZ), r: 0.006, seg: 1, material: black))
                    }
                }
            }
            // Crossbar under the column, welded between the legs.
            m.add(Prim.sweep(legProf, along: [V3(colX, legY, -legZ + 0.02), V3(colX, legY, legZ - 0.02)], up: .up, material: frame))
            if l == 0 {
                for sz: Float in [-1, 1] {
                    let p = V3(colX, legY, sz * (legZ - 0.024))
                    m.add(Prim.torus(major: 0.026, minor: 0.0018, segments: 14, sides: 4, minorY: 0.0016, material: frame),
                          Xform(translation: p, rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)), scale: V3(1, 1, 0.5)))
                }
            }
            // Outer column with a gusset foot and a top bushing.
            m.add(PatientKit.box(V3(0.05, outerTop - legY, 0.076), V3(colX, (outerTop + legY) / 2, colZ), r: 0.005, seg: l == 0 ? 2 : 1, material: frame))
            m.add(PatientKit.box(V3(0.09, 0.006, 0.11), V3(colX, legY + 0.0145, colZ), r: 0.002, seg: 1, material: frame))
            m.add(PatientKit.box(V3(0.056, 0.022, 0.082), V3(colX, outerTop - 0.006, colZ), r: 0.005, seg: l == 0 ? 2 : 1, material: black))
            if l == 0 {
                m.add(PatientKit.panel(V3(colX + 0.0253, 0.47, colZ), right: V3(0, 0, -1), up: .up, w: 0.05, h: 0.032, material: "label.rx"))
            }
            rig.base[l] = m
        }

        // MARK: lift: inner column, support arm, vanity section, release lever.
        rig.part("lift", pivot: V3(colX, outerTop, colZ), joint: .slide(axis: .up, 0...travel, duration: 0.8))
        let armY = topY - slab - 0.03
        for l in 0..<2 {
            rig.add(PatientKit.box(V3(0.04, armY - 0.15, 0.064), V3(colX, 0.15 + (armY - 0.15) / 2, colZ), r: 0.004, seg: l == 0 ? 2 : 1,
                                   material: "metal.aluminum-brushed"), to: "lift", lods: l...l)
        }
        // Support arm: steel channel from the column head out under the reading panel.
        rig.add(PatientKit.box(V3(0.08, 0.04, 0.09), V3(colX, armY - 0.01, colZ), r: 0.006, material: frame), to: "lift")
        rig.add(PatientKit.bar(V3(colX, armY + 0.002, colZ), V3(0.26, armY + 0.002, colZ), w: 0.06, h: 0.024, r: 0.004, material: frame), to: "lift")
        rig.add(PatientKit.bar(V3(-0.36, topY - slab - 0.005, 0), V3(-0.15, topY - slab - 0.005, 0), w: 0.3, h: 0.01, r: 0.003, material: frame), to: "lift")
        // Top sections: laminate slab inside a T-mold edge band.
        func topSection(_ x0: Float, _ x1: Float, to part: String) {
            let w = x1 - x0, cx = (x0 + x1) / 2
            for l in 0..<2 {
                let outline = Shape2D.roundedRect(w - 0.004, D - 0.004, radius: 0.02, segments: l == 0 ? 4 : 2)
                rig.add(Prim.extrude(outline, depth: slab, bevel: 0.001, bevelSegments: 1, material: laminate),
                        Xform(translation: V3(cx, topY - slab / 2, 0), rotation: flat), to: part, lods: l...l)
                let ring = Shape2D.roundedRect(w - 0.002, D - 0.002, radius: 0.021, segments: l == 0 ? 4 : 2).map { V3(cx + $0.x, topY - slab / 2, -$0.y) }
                rig.add(Prim.sweep(Shape2D.roundedRect(0.022, 0.005, radius: 0.002, segments: l == 0 ? 2 : 1), along: ring, up: .up, closedPath: true,
                                   material: edgeBand), to: part, lods: l...l)
            }
        }
        let split: Float = -0.132
        topSection(-W / 2, split - 0.003, to: "lift")
        // Squeeze release lever under the vanity end.
        let lever = PatientKit.bend([V3(-0.33, armY - 0.004, 0.07), V3(-0.37, armY - 0.016, 0.1), V3(-0.37, armY - 0.016, 0.15)], radius: 0.02, seg: 3)
        rig.add(PatientKit.tube(lever, r: 0.005, sides: 8, material: chrome), to: "lift")
        rig.add(Prim.superellipsoid(V3(0.02, 0.016, 0.06), exponent: 3, subdivisions: 3, material: black),
                Xform(translation: V3(-0.37, armY - 0.018, 0.145)), to: "lift", lods: 0...0)

        // Patient's lidded water cup with a bendy straw on the vanity section.
        let cupC = V3(-0.27, topY, 0.07)
        rig.add(Prim.lathe([V2(0, 0.001), V2(0.029, 0.001), V2(0.031, 0.004), V2(0.039, 0.112), V2(0.0405, 0.115), V2(0.037, 0.116)], segments: 20,
                           material: "plastic.frosted:DCE6EA"), Xform(translation: cupC), to: "lift")
        rig.add(Prim.lathe([V2(0.0, 0.122), V2(0.036, 0.122), V2(0.0415, 0.117), V2(0.042, 0.111), V2(0.0385, 0.11)], segments: 20, material: "plastic.white"),
                Xform(translation: cupC), to: "lift")
        let straw = PatientKit.bend([cupC + V3(0.008, 0.06, 0.004), cupC + V3(0.008, 0.15, 0.004), cupC + V3(0.045, 0.16, 0.004)], radius: 0.015, seg: 4)
        rig.add(PatientKit.tube(straw, r: 0.003, sides: 6, material: "plastic.matte:E8E4DA"), to: "lift", lods: 0...0)

        // MARK: tilt: reading panel hinged on its patient-side edge (+Z), far edge rises.
        let hingeZ = D / 2 - 0.012
        rig.part("tilt", parent: "lift", pivot: V3(0, topY - slab, hingeZ), joint: .hinge(axis: V3(1, 0, 0), 0...45, duration: 0.7))
        topSection(split + 0.003, W / 2, to: "tilt")
        // Book-stop lip along the patient edge (aluminum extrusion).
        rig.add(PatientKit.bar(V3(split + 0.03, topY + 0.006, D / 2 - 0.012), V3(W / 2 - 0.03, topY + 0.006, D / 2 - 0.012), w: 0.008, h: 0.014, r: 0.002,
                               material: "metal.aluminum-brushed"), to: "tilt")
        // Panel subframe and hinge barrels.
        for x: Float in [-0.06, 0.3] {
            rig.add(PatientKit.bar(V3(x, topY - slab - 0.006, hingeZ), V3(x, topY - slab - 0.006, -D / 2 + 0.04), w: 0.02, h: 0.012, r: 0.002, material: frame), to: "tilt")
            rig.add(Prim.cylinder(radius: 0.007, height: 0.04, bevel: 0.0015, segments: 10, bevelSegments: 1, material: chrome),
                    Xform(translation: V3(x - 0.02, topY - slab - 0.004, hingeZ), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "tilt", lods: 0...0)
        }

        groundAO(&rig, height: 0.08, floor: 0.6)
        rig.states = [RigState("low"), RigState("high", ["lift": travel]), RigState("tilted", ["lift": 0.12, "tilt": 35])]
        return rig
    }
}
