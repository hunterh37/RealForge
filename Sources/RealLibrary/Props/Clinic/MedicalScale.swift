import simd
import Foundation

/// Physician mechanical beam scale (Detecto 339 class, 350 lb / 160 kg): white enamel cast base with
/// two rear transport wheels and a ribbed black rubber platform mat worn where feet stand, square
/// column, fulcrum housing with a twin beam (main beam 0-350 lb in 50 lb notches, fine beam 0-50 lb in
/// 1 lb graduations) and two sliding poises, balance pointer in a trig loop at the beam tip, and a
/// telescoping height rod behind the column with a flip-out headpiece.
public struct MedicalScale: RealArticulated {
    public static let id = "medical-scale"
    public static let summary = "Physician mechanical beam scale (Detecto 339 class): platform with rubber mat, column, twin-poise beam, balance pointer and telescoping height rod."
    public static let tags = ["prop", "medical", "articulated", "metal", "rubber", "interior", "hospital"]
    public static let budget = 5_800
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 14, distance: 2.6, studio: true)

    public var enamel: MaterialKey = "metal.powder-white"
    public var beam: MaterialKey = "metal.stainless"
    /// Beam graduation length (m) for the full main / fine beam ranges.
    public var beamTravel: Float = 0.24
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [7])
        let ink: MaterialKey = "plastic.matte:151515", mat: MaterialKey = "rubber"
        let colZ: Float = -0.2, colTop: Float = 1.335, baseTop: Float = 0.07
        let fy: Float = 1.385                                   // beam fulcrum height

        // MARK: base, mat, column, housing, wheels
        for l in 0..<2 {
            let bs = 1
            var m = Model(name: Self.id)
            // Cast base: rounded plan corners, a generous rounded top edge.
            m.add(Prim.extrude(Shape2D.roundedRect(0.33, 0.52, radius: 0.035, segments: l == 0 ? 5 : 2), depth: baseTop - 0.012, bevel: l == 0 ? 0.014 : 0.008,
                               bevelSegments: l == 0 ? 3 : 1, material: enamel),
                  Xform(translation: V3(0, 0.012 + (baseTop - 0.012) / 2, 0), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
            // Platform mat (front of the base).
            m.add(Prim.roundedBox(V3(0.28, 0.008, 0.37), radius: 0.003, bevelSegments: 1, material: mat), Xform(translation: V3(0, baseTop + 0.004, 0.05)))
            // Column boss and square column.
            m.add(Prim.roundedBox(V3(0.09, 0.05, 0.09), radius: 0.01, bevelSegments: bs, material: enamel), Xform(translation: V3(0, baseTop + 0.025, colZ)))
            m.add(Prim.roundedBox(V3(0.048, colTop - baseTop, 0.048), radius: 0.005, bevelSegments: bs, material: enamel), Xform(translation: V3(0, (colTop + baseTop) / 2, colZ)))
            // Fulcrum housing on top of the column.
            m.add(Prim.roundedBox(V3(0.1, 0.09, 0.064), radius: 0.01, bevelSegments: bs, material: enamel), Xform(translation: V3(0, colTop + 0.04, colZ)))
            // Feet.
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] where sz > 0 {
                m.add(Prim.cylinder(radius: 0.016, height: 0.0125, bevel: 0.003, segments: l == 0 ? 14 : 8, bevelSegments: 1, material: mat),
                      Xform(translation: V3(sx * 0.13, 0, sz * 0.22)))
            }}
            // Rear transport wheels (just clear of the floor).
            for sx: Float in [-1, 1] {
                m.add(Prim.lathe([V2(0, -0.013), V2(0.022, -0.013), V2(0.03, -0.009), V2(0.031, 0), V2(0.03, 0.009), V2(0.022, 0.013), V2(0, 0.013)],
                                 segments: l == 0 ? 20 : 10, seamTile: 0.1, material: "rubber"),
                      Xform(translation: V3(sx * 0.178, 0.033, -0.215), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
            }
            rig.base[l] = m
        }
        // Mat ribs (LOD0) and two worn patches where feet stand (story detail).
        var ribs = Surface(material: mat)
        for k in 0..<13 {
            let x = -0.12 + Float(k) * 0.02
            ribs.append(Prim.extrude(Shape2D.roundedRect(0.008, 0.004, radius: 0.0015, segments: 1), depth: 0.35, bevel: 0, material: mat),
                        Xform(translation: V3(x, baseTop + 0.0085, 0.05)))
        }
        rig.base[0].add(ribs)
        for sx: Float in [-1, 1] {
            rig.base[0].add(Prim.superellipsoid(V3(0.075, 0.0016, 0.2), exponent: 2.2, subdivisions: 4, material: "rubber:4A4744"),
                            Xform(translation: V3(sx * 0.055 + rng.float(-0.006...0.006), baseTop + 0.0108, 0.07), rotation: simd_quatf(degrees: sx * 6, axis: .up)))
        }
        // Wheel axle bosses and a maker's plate on the column.
        for sx: Float in [-1, 1] {
            rig.base[0].add(Prim.cylinder(radius: 0.008, height: 0.014, bevel: 0.002, segments: 10, bevelSegments: 1, material: beam),
                            Xform(translation: V3(sx * 0.166, 0.033, -0.215), rotation: simd_quatf(degrees: sx > 0 ? -90 : 90, axis: V3(0, 0, 1))))
        }
        rig.base[0].add(Prim.roundedBox(V3(0.034, 0.05, 0.0012), radius: 0.0005, bevelSegments: 1, material: "metal.anodized-black"),
                        Xform(translation: V3(0, 1.05, colZ + 0.0245)))
        // Trig loop at the beam tip (static), and the rod guides on the column back.
        let tipX: Float = 0.3
        let loop = [V3(tipX - 0.008, fy - 0.03, colZ), V3(tipX + 0.03, fy - 0.03, colZ), V3(tipX + 0.03, fy + 0.04, colZ), V3(tipX - 0.008, fy + 0.04, colZ)]
        rig.base[0].add(Prim.sweep(Shape2D.roundedRect(0.006, 0.012, radius: 0.0025, segments: 1), along: loop, up: V3(0, 0, 1), closedPath: true, material: enamel))
        rig.base[1].add(Prim.sweep(Shape2D.rect(0.006, 0.012), along: loop, up: V3(0, 0, 1), closedPath: true, material: enamel))
        // Loop bracket back to the housing.
        for l in 0..<2 {
            rig.base[l].add(Prim.roundedBox(V3(0.006, 0.012, 0.06), radius: 0.002, bevelSegments: 1, material: enamel), Xform(translation: V3(tipX + 0.03, fy - 0.03, colZ - 0.026)))
            rig.base[l].add(Prim.roundedBox(V3(tipX - 0.02, 0.012, 0.008), radius: 0.003, bevelSegments: 1, material: enamel), Xform(translation: V3((tipX + 0.04) / 2, fy - 0.03, colZ - 0.052)))
        }
        let rodZ = colZ - 0.024 - 0.0125
        for gy: Float in [0.95, 1.3] {
            rig.base[0].add(Prim.roundedBox(V3(0.034, 0.02, 0.034), radius: 0.004, bevelSegments: 1, material: enamel), Xform(translation: V3(0, gy, rodZ - 0.002)))
        }

        // MARK: beam (tilts a degree or two about the fulcrum), poises ride on it
        rig.part("beam", pivot: V3(0, fy, colZ), joint: .hinge(axis: V3(0, 0, 1), -2...2, duration: 1.2))
        let mainY = fy - 0.012, fineY = fy + 0.022, x0: Float = 0.05
        for (y, h) in [(mainY, Float(0.024)), (fineY, Float(0.016))] {
            rig.add(Prim.roundedBox(V3(tipX + 0.07, h, 0.008), radius: 0.0025, bevelSegments: 1, material: beam),
                    Xform(translation: V3((tipX - 0.07) / 2, y, colZ)), to: "beam")
        }
        // Tip pointer into the trig loop, and the counterweight on the short arm.
        rig.add(Prim.extrude([V2(0, -0.006), V2(0.026, 0), V2(0, 0.006)], depth: 0.004, bevel: 0.0005, bevelSegments: 1, material: beam),
                Xform(translation: V3(tipX - 0.004, fy + 0.005, colZ)), to: "beam")
        rig.add(Prim.cylinder(radius: 0.016, height: 0.03, bevel: 0.003, segments: 16, bevelSegments: 1, material: beam),
                Xform(translation: V3(-0.085, fy, colZ), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))), to: "beam")
        // Graduations: main beam notches every 50 lb, fine beam every 1 lb (long every 5).
        var ticks = Surface(material: ink)
        for k in 0...7 {
            let x = x0 + beamTravel * Float(k) / 7
            ticks.append(cuboid(V3(0.0014, 0.012, 0.0006), material: ink), Xform(translation: V3(x, mainY + 0.004, colZ + 0.0042)))
        }
        for k in 0...50 {
            let x = x0 + beamTravel * Float(k) / 50, long = k % 5 == 0
            ticks.append(cuboid(V3(0.0007, long ? 0.008 : 0.005, 0.0006), material: ink), Xform(translation: V3(x, fineY + (long ? 0.002 : 0.0035), colZ + 0.0042)))
        }
        rig.add(ticks, to: "beam", lods: 0...0)

        // Poises: slide along the beam (+X), main poise big with a notch pointer, fine poise small.
        rig.part("main-poise", parent: "beam", pivot: V3(x0, mainY, colZ), joint: .slide(axis: V3(1, 0, 0), 0...beamTravel, duration: 0.8))
        rig.part("fine-poise", parent: "beam", pivot: V3(x0, fineY, colZ), joint: .slide(axis: V3(1, 0, 0), 0...beamTravel, duration: 0.8))
        for l in 0..<2 {
            let bs = 1
            rig.add(Prim.roundedBox(V3(0.026, 0.04, 0.024), radius: 0.005, bevelSegments: bs, material: beam), Xform(translation: V3(x0, mainY - 0.004, colZ)), to: "main-poise", lods: l...l)
            rig.add(Prim.roundedBox(V3(0.016, 0.026, 0.02), radius: 0.004, bevelSegments: bs, material: beam), Xform(translation: V3(x0, fineY + 0.001, colZ)), to: "fine-poise", lods: l...l)
        }
        rig.add(Prim.roundedBox(V3(0.018, 0.012, 0.026), radius: 0.003, bevelSegments: 1, material: "plastic.matte:1E1F21"),
                Xform(translation: V3(x0, mainY - 0.03, colZ)), to: "main-poise", lods: 0...0)
        rig.add(Prim.extrude([V2(-0.003, 0), V2(0.003, 0), V2(0, -0.004)], depth: 0.001, bevel: 0, material: ink),
                Xform(translation: V3(x0, mainY + 0.016, colZ + 0.0125)), to: "main-poise", lods: 0...0)

        // MARK: height rod (slides up behind the column) and headpiece (flips forward)
        let rodTop: Float = 1.42
        rig.part("rod", pivot: V3(0, rodTop, rodZ), joint: .slide(axis: .up, 0...0.6, duration: 1.0))
        for l in 0..<2 {
            rig.add(Prim.roundedBox(V3(0.02, rodTop - 0.62, 0.02), radius: 0.003, bevelSegments: 1, material: beam),
                    Xform(translation: V3(0, (rodTop + 0.62) / 2, rodZ)), to: "rod", lods: l...l)
        }
        // Inch graduations on the rod's right face.
        var rodTicks = Surface(material: ink)
        for k in 0..<32 {
            let y = rodTop - 0.03 - Float(k) * 0.0254
            rodTicks.append(cuboid(V3(0.0006, 0.0012, k % 4 == 0 ? 0.014 : 0.008), material: ink), Xform(translation: V3(0.0102, y, rodZ + (k % 4 == 0 ? 0 : 0.003))))
        }
        rig.add(rodTicks, to: "rod", lods: 0...0)
        let hp = V3(0, rodTop + 0.004, rodZ)
        rig.part("headpiece", parent: "rod", pivot: hp, joint: .hinge(axis: V3(1, 0, 0), 0...90, duration: 0.5))
        rig.add(Prim.roundedBox(V3(0.024, 0.13, 0.006), radius: 0.0025, bevelSegments: 1, material: beam),
                Xform(translation: hp + V3(0, 0.065, -0.007)), to: "headpiece")
        rig.add(Prim.cylinder(radius: 0.005, height: 0.03, bevel: 0.001, segments: 10, bevelSegments: 1, material: beam),
                Xform(translation: hp + V3(-0.015, 0, -0.003), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "headpiece")

        groundAO(&rig, height: 0.08, floor: 0.6)
        let lb = { (w: Float, range: Float) -> Float in self.beamTravel * w / range }
        rig.states = [
            RigState("zeroed"),
            RigState("settling", ["main-poise": lb(150, 350), "fine-poise": lb(8, 50), "beam": 1.6]),
            RigState("weighing", ["main-poise": lb(150, 350), "fine-poise": lb(12.5, 50)]),
            RigState("measuring", ["main-poise": lb(150, 350), "fine-poise": lb(12.5, 50), "rod": 0.36, "headpiece": 90]),
        ]
        return rig
    }
}
