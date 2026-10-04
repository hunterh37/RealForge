import simd
import Foundation

/// Wall hand sanitizer dispenser (Purell ES8 class), 154 W x 277 H x 102 D mm: white back plate with
/// screw bosses, domed white front cover hinged at the top with a keyed lock and a refill sight window,
/// grey push bar on a top pivot across the lower front, nozzle and drip ledge, and a 1200 mL refill
/// pouch with a pump nozzle and label inside (seen when the cover is open). A dried gel drip sits on
/// the ledge under the nozzle.
public struct SanitizerDispenser: RealArticulated {
    public static let id = "sanitizer-dispenser"
    public static let summary = "Wall hand sanitizer dispenser (Purell ES8 class): white shell, grey push bar, refill window and a hinged front cover over the refill pouch."
    public static let tags = ["prop", "medical", "articulated", "hospital", "plastic", "interior"]
    public static let budget = 5_600
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 12, distance: 0.75, studio: true)

    public var shell: MaterialKey = "plastic.medical"
    public var trim: MaterialKey = "plastic.medical-grey:8A9095"
    /// Gel color seen through the sight window and in the pouch (sRGB hex).
    public var gel: UInt32 = 0xBFD6E4
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [4])
        let backZ: Float = -0.051, plateT: Float = 0.011
        let gelMat: MaterialKey = "plastic.frosted:" + String(format: "%06X", gel)
        let dark: MaterialKey = "plastic.matte:2B2D30"

        // MARK: back plate, lower housing, nozzle, drip ledge
        for l in 0..<2 {
            var m = Model(name: Self.id)
            m.add(Prim.extrude(Shape2D.roundedRect(0.148, 0.268, radius: 0.02, segments: l == 0 ? 4 : 2), depth: plateT, bevel: 0.002, bevelSegments: l == 0 ? 2 : 1, material: shell),
                  Xform(translation: V3(0, 0.008 + 0.134, backZ + plateT / 2)))
            // Lower housing (pump chamber) behind the push bar.
            m.add(Prim.roundedBox(V3(0.142, 0.064, 0.074), radius: 0.012, bevelSegments: l == 0 ? 2 : 1, material: shell),
                  Xform(translation: V3(0, 0.046, backZ + plateT + 0.037)))
            // Drip ledge at the foot of the plate.
            m.add(Prim.roundedBox(V3(0.09, 0.006, 0.05), radius: 0.0025, bevelSegments: 1, material: trim),
                  Xform(translation: V3(0, 0.003, backZ + plateT + 0.024)))
            // Nozzle under the housing.
            m.add(Prim.cylinder(radius: 0.0055, height: 0.008, bevel: 0.0015, segments: l == 0 ? 14 : 8, bevelSegments: 1, material: dark),
                  Xform(translation: V3(0, 0.0095, 0.002)))
            rig.base[l] = m
        }
        // Dried gel drip on the ledge (story detail).
        rig.base[0].add(Prim.superellipsoid(V3(0.016, 0.0024, 0.011), exponent: 2.4, subdivisions: 4, material: "plastic.clear:DCE6EA"),
                        Xform(translation: V3(rng.float(-0.003...0.003), 0.0062, 0.003)))
        // Keyhole slots on the back (wall side).
        for sx: Float in [-0.045, 0.045] {
            rig.base[0].add(Prim.extrude(Shape2D.roundedRect(0.007, 0.018, radius: 0.0034, segments: 3), depth: 0.001, bevel: 0, material: dark),
                            Xform(translation: V3(sx, 0.235, backZ - 0.0003)))
        }
        // Screw bosses visible above the cover hinge.
        for sx: Float in [-0.05, 0.05] {
            rig.base[0].add(Prim.cylinder(radius: 0.0042, height: 0.0016, bevel: 0.0006, segments: 10, bevelSegments: 1, material: "metal.chrome"),
                            Xform(translation: V3(sx, 0.268, backZ + plateT), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }

        // MARK: refill pouch (inside the cover)
        let bagC = V3(0, 0.172, -0.012)
        for l in 0..<2 {
            rig.base[l].add(Prim.superellipsoid(V3(0.118, 0.15, 0.058), exponent: 3.2, subdivisions: l == 0 ? 6 : 3, material: gelMat) { d in 1 - 0.08 * max(0, d.y) },
                            Xform(translation: bagC))
        }
        rig.base[0].add(Prim.cylinder(radius: 0.012, height: 0.02, bevel: 0.002, segments: 14, bevelSegments: 1, material: trim),
                        Xform(translation: V3(0, bagC.y - 0.093, bagC.z)))
        var bagLabel = Surface(material: "label.rx-small")
        let lz = bagC.z + 0.0295, lc = V3(0, bagC.y + 0.01, lz)
        let l0 = bagLabel.add(lc + V3(-0.04, 0.045, 0), V3(0, 0, 1), V2(0, 0)), l1 = bagLabel.add(lc + V3(0.04, 0.045, 0), V3(0, 0, 1), V2(0.07, 0))
        let l2 = bagLabel.add(lc + V3(0.04, -0.045, 0), V3(0, 0, 1), V2(0.07, 0.08)), l3 = bagLabel.add(lc + V3(-0.04, -0.045, 0), V3(0, 0, 1), V2(0, 0.08))
        bagLabel.quad(l0, l3, l2, l1)
        bagLabel.computeTangents()
        rig.base[0].add(bagLabel)

        // MARK: push bar (top pivot; pressing swings the lower edge in)
        let barPivot = V3(0, 0.077, 0.02)
        rig.part("push", pivot: barPivot, joint: .hinge(axis: V3(1, 0, 0), 0...18, duration: 0.25))
        for l in 0..<2 {
            var bar = Prim.superellipsoid(V3(0.15, 0.064, 0.05), exponent: 4.5, subdivisions: l == 0 ? 8 : 4, material: trim)
            bar.deform { p in V3(p.x, p.y, max(p.z, -0.012)) }
            rig.add(bar, Xform(translation: V3(0, 0.046, 0.026)), to: "push", lods: l...l)
        }
        // Finger-pad recess line on the bar.
        rig.add(Prim.roundedBox(V3(0.09, 0.003, 0.002), radius: 0.001, bevelSegments: 1, material: dark),
                Xform(translation: V3(0, 0.036, 0.0505)), to: "push", lods: 0...0)

        // "Push" instruction label on the bar face (curved bar: sits on its flattest band).
        var pushLabel = Surface(material: "label.supply-small")
        let pc = V3(0, 0.054, 0.0512), pn = V3(0, 0, 1)
        let p0 = pushLabel.add(pc + V3(-0.03, 0.009, 0), pn, V2(0, 0)), p1 = pushLabel.add(pc + V3(0.03, 0.009, 0), pn, V2(0.06, 0))
        let p2 = pushLabel.add(pc + V3(0.03, -0.009, 0), pn, V2(0.06, 0.018)), p3 = pushLabel.add(pc + V3(-0.03, -0.009, 0), pn, V2(0, 0.018))
        pushLabel.quad(p0, p3, p2, p1)
        pushLabel.computeTangents()
        rig.add(pushLabel, to: "push", lods: 0...0)
        // Dried gel run down the bar's lower lip (story detail).
        rig.add(Prim.superellipsoid(V3(0.007, 0.016, 0.0016), exponent: 2.2, subdivisions: 3, material: "plastic.clear:C9D8DF"),
                Xform(translation: V3(0.012, 0.024, 0.0495), rotation: simd_quatf(degrees: 8, axis: V3(0, 0, 1))), to: "push", lods: 0...0)

        // MARK: front cover (top hinge, swings up)
        let hinge = V3(0, 0.27, backZ + plateT + 0.004)
        rig.part("cover", pivot: hinge, joint: .hinge(axis: V3(1, 0, 0), -105...0, duration: 0.8))
        let cc = V3(0, 0.177, -0.04)
        for l in 0..<2 {
            var shellS = Prim.superellipsoid(V3(0.154, 0.2, 0.182), exponent: 5, subdivisions: l == 0 ? 12 : 6, material: shell)
            shellS.deform { p in V3(p.x, p.y, max(p.z, -0.001)) }
            rig.add(shellS, Xform(translation: cc), to: "cover", lods: l...l)
        }
        // Sight window: gel behind a clear pane, lower front of the cover.
        let wy: Float = 0.118, wz: Float = 0.0515
        rig.add(Prim.extrude(Shape2D.roundedRect(0.05, 0.022, radius: 0.008, segments: 3), depth: 0.002, bevel: 0.0006, bevelSegments: 1, material: "plastic.matte:3C4247"),
                Xform(translation: V3(0, wy, wz - 0.0004)), to: "cover")
        // Gel level: lower 60 % of the window.
        rig.add(Prim.extrude(Shape2D.roundedRect(0.046, 0.011, radius: 0.004, segments: 2), depth: 0.0008, bevel: 0.0003, bevelSegments: 1, material: "plastic.gloss:8FB9D2"),
                Xform(translation: V3(0, wy - 0.0035, wz + 0.0008)), to: "cover")
        rig.add(Prim.extrude(Shape2D.roundedRect(0.058, 0.03, radius: 0.011, segments: 3), depth: 0.0012, bevel: 0.0005, bevelSegments: 1, material: "plastic.clear"),
                Xform(translation: V3(0, wy, wz + 0.0012)), to: "cover", lods: 0...0)
        // Grey brand badge and keyed lock at the top.
        rig.add(Prim.extrude(Shape2D.roundedRect(0.07, 0.016, radius: 0.008, segments: 3), depth: 0.0014, bevel: 0.0005, bevelSegments: 1, material: "plastic.matte:5A6066"),
                Xform(translation: V3(0, 0.215, 0.0515)), to: "cover")
        rig.add(Prim.extrude(Shape2D.roundedRect(0.044, 0.006, radius: 0.003, segments: 2), depth: 0.0006, bevel: 0.0002, bevelSegments: 1, material: "plastic.medical"),
                Xform(translation: V3(-0.006, 0.215, 0.0525)), to: "cover", lods: 0...0)
        // Dark parting gasket between the cover and the back plate (reads as the shadow line).
        rig.add(Prim.extrude(Shape2D.roundedRect(0.1555, 0.2015, radius: 0.03, segments: 4), depth: 0.0016, bevel: 0.0004, bevelSegments: 1, material: dark),
                Xform(translation: V3(0, 0.177, -0.0405)), to: "cover")
        rig.add(Prim.cylinder(radius: 0.0065, height: 0.003, bevel: 0.0008, segments: 14, bevelSegments: 1, material: trim),
                Xform(translation: V3(0, 0.2615, 0.0405), rotation: simd_quatf(degrees: -38, axis: V3(1, 0, 0))), to: "cover")
        rig.add(Prim.roundedBox(V3(0.0018, 0.0062, 0.0012), radius: 0.0005, bevelSegments: 1, material: dark),
                Xform(translation: V3(0, 0.2635, 0.0433), rotation: simd_quatf(degrees: -38, axis: V3(1, 0, 0))), to: "cover", lods: 0...0)

        groundAO(&rig, height: 0.02, floor: 0.7)
        rig.states = [
            RigState("idle"),
            RigState("pressed", ["push": 18]),
            RigState("cover-open", ["cover": -105]),
        ]
        return rig
    }
}
