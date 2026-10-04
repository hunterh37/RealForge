import simd
import Foundation

/// Wall-set style diagnostic otoscope (Welch Allyn MacroView on a 3.5 V C-cell handle class), standing
/// on its handle: knurled chrome handle 27 mm x 111 mm with a screw end cap, ribbed black rheostat
/// collar with an index dot, chrome bayonet socket; black MacroView head (about 65 mm long, 34 mm tall)
/// with a hinged rear magnifier window, a chrome speculum spigot with the fiber-optic ring, an
/// insufflation port, and a black 4 mm disposable speculum. The rheostat collar turns the lamp on
/// (fiber ring lit, small spot light); the window swings up on its top hinge; the speculum option puts
/// it off the spigot and down on the table. A biomed inspection sticker sits on the handle.
public struct Otoscope: RealArticulated {
    public static let id = "otoscope"
    public static let summary = "Welch Allyn MacroView class otoscope standing on a knurled C-cell handle with rheostat collar, magnifier window and black disposable speculum."
    public static let tags = ["prop", "medical", "handheld", "articulated", "tool", "electronics", "metal", "plastic"]
    public static let budget = 6_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 130, elevation: 22, distance: 0.55, studio: true)

    /// Handle radius (m).
    public var radius: Float = 0.0135
    /// Head housing plastic (sRGB hex).
    public var headColor: UInt32 = 0x1B1C1E
    /// Rheostat turn for the "on" states (degrees).
    public var onTurn: Float = 150
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        let rng = SeededRNG(seed: seed); _ = rng
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3])
        let R = radius
        let chrome: MaterialKey = "metal.chrome", knurl: MaterialKey = "metal.knurl-chrome"
        let head: MaterialKey = "plastic.matte:" + String(format: "%06X", headColor)
        let black: MaterialKey = "plastic.matte:0E0E0F"
        let segs = [30, 14]
        let yc: Float = 0.150                    // viewing axis height
        let toZ = simd_quatf(degrees: 90, axis: V3(1, 0, 0))   // lathe +Y -> +Z
        func axialZ(_ prof: [V2], _ sg: Int, _ mat: MaterialKey) -> Surface {
            Prim.lathe(prof, segments: sg, seamTile: 0.02, material: mat).transformed(Xform(translation: V3(0, yc, 0), rotation: toZ))
        }

        // MARK: handle
        let capTop: Float = 0.009, k0: Float = 0.014, k1: Float = 0.09, colY0: Float = 0.097, colY1: Float = 0.111, sockY1: Float = 0.118
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let sg = segs[l]
            var cap: [V2] = [V2(0, 0), V2(R - 0.0022, 0), V2(R - 0.0005, 0.0005), V2(R, 0.0016)]
            if l == 0 { for g: Float in [0.0042, 0.0062] { cap += [V2(R, g - 0.0006), V2(R - 0.00045, g - 0.0002), V2(R - 0.00045, g + 0.0002), V2(R, g + 0.0006)] } }
            cap += [V2(R, capTop - 0.0005), V2(R - 0.0005, capTop)]
            m.add(Prim.lathe(cap, segments: sg, seamTile: 0.02, material: chrome))
            m.add(Prim.lathe([V2(R - 0.0005, capTop + 0.0002), V2(R - 0.0001, capTop + 0.0006), V2(R - 0.0001, k0)], segments: sg, seamTile: 0.02, material: chrome))
            m.add(Prim.lathe([V2(R - 0.0001, k0), V2(R + 0.0002, k0 + 0.0004), V2(R + 0.0002, k1 - 0.0004), V2(R - 0.0001, k1)],
                             segments: sg, seamTile: 0.09, material: l == 0 ? knurl : chrome))
            m.add(Prim.lathe([V2(R - 0.0001, k1), V2(R - 0.0001, colY0 - 0.0006), V2(R - 0.0008, colY0)], segments: sg, seamTile: 0.02, material: chrome))
            // Bayonet socket above the collar.
            m.add(Prim.lathe([V2(R - 0.003, colY1 - 0.0003), V2(0.0118, colY1), V2(0.0118, sockY1 - 0.0008), V2(0.0112, sockY1), V2(0.0098, sockY1)],
                             segments: sg, seamTile: 0.02, material: chrome))
            // MARK: head
            // Neck boss down into the socket.
            m.add(Prim.lathe([V2(0.0092, sockY1 - 0.001), V2(0.0104, sockY1 + 0.0004), V2(0.0108, sockY1 + 0.004), V2(0.0112, 0.137)],
                             segments: sg, seamTile: 0.03, material: head))
            // Housing: lofted rounded sections from the eyepiece back to the nose.
            let st: [(Float, Float, Float, Float)] = [(-0.0405, 0.025, 0.025, 3), (-0.0375, 0.030, 0.030, 3.2), (-0.026, 0.033, 0.034, 3.4),
                                                     (-0.010, 0.032, 0.033, 3.2), (0.004, 0.026, 0.026, 2.8), (0.015, 0.0185, 0.0185, 2.4),
                                                     (0.0225, 0.0158, 0.0158, 2.2)]
            let n = l == 0 ? 28 : 14
            let rings = st.map { (z, w, h, e) in Shape2D.superellipse(w, h, exponent: e, segments: n).map { V3($0.x, yc + $0.y, z) } }
            m.add(Prim.loft(l == 0 ? rings : [rings[0], rings[2], rings[4], rings[6]], capStart: true, capEnd: true, material: head))
            // Eyepiece bore behind the window (dark) and the window seat ring.
            m.add(Prim.cylinder(radius: 0.0088, height: 0.0006, bevel: 0.0002, segments: sg, bevelSegments: 1, material: "plastic.matte:050505"),
                  Xform(translation: V3(0, yc, -0.0405), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
            // Speculum spigot: chrome, retention ridge.
            m.add(axialZ([V2(0.0066, 0.021), V2(0.0064, 0.026), V2(0.0068, 0.0275), V2(0.0064, 0.029), V2(0.0058, 0.0355), V2(0.0050, 0.0362), V2(0.0045, 0.0362)],
                         sg, chrome))
            rig.base[l] = m
        }
        // Insufflation port on the right side of the head, and the head's lamp-change seam.
        rig.base[0].add(Prim.cylinder(radius: 0.0019, height: 0.006, bevel: 0.0004, segments: 10, bevelSegments: 1, material: chrome),
                        Xform(translation: V3(0.0148, yc - 0.004, 0.006), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        rig.base[0].add(Prim.torus(major: 0.0026, minor: 0.0005, segments: 12, sides: 5, material: chrome),
                        Xform(translation: V3(0.0205, yc - 0.004, 0.006), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        rig.base[0].add(Prim.loft([Shape2D.superellipse(0.0332, 0.0342, exponent: 3.4, segments: 28).map { V3($0.x, yc + $0.y, -0.0262) },
                                   Shape2D.superellipse(0.0332, 0.0342, exponent: 3.4, segments: 28).map { V3($0.x, yc + $0.y, -0.0252) }],
                                  material: "plastic.matte:060606"))

        // Biomed inspection sticker wrapped on the knurl (story detail): one label tile across it.
        var sticker = Surface(material: "label.biomed")
        let sw: Float = 0.018, sh: Float = 0.013, sy0: Float = 0.032, rr = R + 0.00035, th0: Float = -2.3   // th from +Z toward +X
        let cols = 6
        for j in 0...1 { for i in 0...cols {
            let u = Float(i) / Float(cols), v = Float(j)
            let th = th0 + (u - 0.5) * sw / rr
            _ = sticker.add(V3(rr * sin(th), sy0 + sh * (1 - v), rr * cos(th)), V3(sin(th), 0, cos(th)), V2(u, v) * 0.012)
        }}
        for i in 0..<UInt32(cols) { sticker.quad(i, i + UInt32(cols) + 1, i + UInt32(cols) + 2, i + 1) }
        sticker.computeTangents()

        // MARK: rheostat collar (rotates about Y)
        rig.part("rheostat", pivot: V3(0, colY0, 0), joint: .hinge(axis: V3(0, 1, 0), 0...300, duration: 0.6))
        for l in 0..<2 {
            let ribs = 24, k = l == 0 ? ribs * 4 : 20
            let outline = (0..<k).map { i -> V2 in
                let a = Float(i) / Float(k) * 2 * .pi
                let r = R + 0.0007 + (l == 0 ? 0.00045 * cos(Float(ribs) * a) : 0)
                return V2(r * cos(a), r * sin(a))
            }
            rig.add(Prim.extrude(outline, depth: colY1 - colY0, bevel: 0.0006, bevelSegments: 1, material: black),
                    Xform(translation: V3(0, (colY0 + colY1) / 2, 0), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))), to: "rheostat", lods: l...l)
        }
        rig.add(Prim.cylinder(radius: 0.0011, height: 0.0004, bevel: 0.0001, segments: 8, bevelSegments: 1, material: "plastic.gloss:C8261E"),
                Xform(translation: V3(0, (colY0 + colY1) / 2, R + 0.0015), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "rheostat", lods: 0...0)

        // MARK: magnifier window, hinged on its top edge (axis X); positive swings it up and back.
        let wz: Float = -0.0412, wTop = yc + 0.0128
        rig.part("window", pivot: V3(0, wTop, wz), joint: .hinge(axis: V3(1, 0, 0), 0...100, duration: 0.5))
        let frame = Prim.extrude(Shape2D.circle(0.0115, segments: 28), depth: 0.0022, bevel: 0.0007, bevelSegments: 1, material: head)
        rig.add(frame, Xform(translation: V3(0, yc, wz - 0.0006)), to: "window")
        rig.add(Prim.extrude(Shape2D.circle(0.0082, segments: 24), depth: 0.0008, bevel: 0.0003, bevelSegments: 1, material: "glass.clear"),
                Xform(translation: V3(0, yc, wz - 0.0021)), to: "window")
        rig.add(Prim.roundedBox(V3(0.009, 0.0034, 0.004), radius: 0.0012, bevelSegments: 1, material: head), Xform(translation: V3(0, wTop + 0.0002, wz + 0.0004)), to: "window")
        rig.add(Prim.roundedBox(V3(0.006, 0.0022, 0.0024), radius: 0.0008, bevelSegments: 1, material: head),
                Xform(translation: V3(0, yc - 0.0118, wz - 0.0012)), to: "window", lods: 0...0)   // thumb tab

        // MARK: lamp: fiber-optic ring on the spigot face.
        rig.part("lamp", pivot: V3(0, yc, 0.036), joint: .fixed, options: 2)
        let ring = axialZ([V2(0.0044, 0.0361), V2(0.0044, 0.0364), V2(0.0026, 0.0364), V2(0.0026, 0.0358)], 20, "plastic.frosted")
        rig.add(ring, to: "lamp")
        rig.add(axialZ([V2(0.0044, 0.0361), V2(0.0044, 0.0364), V2(0.0026, 0.0364), V2(0.0026, 0.0358)], 20, "emissive.bulb"), to: "lamp", option: 1)
        rig.lights = [RigLight(name: "beam", kind: .spot(inner: 8, outer: 20), part: "lamp", option: 1, position: V3(0, yc, 0.066),
                               direction: V3(0, -0.05, 1), color: V3(1, 0.92, 0.8), intensity: 80, attenuationRadius: 1.5)]

        // MARK: speculum: on the spigot (0) or set down on the table (1).
        rig.part("speculum", pivot: V3(0, yc, 0.02), joint: .fixed, options: 2)
        let specProf: [V2] = [V2(0.0091, 0.0198), V2(0.0094, 0.0204), V2(0.0094, 0.0222), V2(0.0082, 0.0232), V2(0.0072, 0.03),
                              V2(0.0042, 0.054), V2(0.0029, 0.0615), V2(0.0026, 0.0622), V2(0.0021, 0.0619), V2(0.0024, 0.061),
                              V2(0.0037, 0.054), V2(0.0066, 0.03), V2(0.0068, 0.0235), V2(0.0072, 0.0205), V2(0.0085, 0.0198)]
        var spec0 = Surface(material: black), spec1 = Surface(material: black)
        spec0.append(axialZ(specProf, segs[0], black)); spec1.append(axialZ(specProf, segs[1], black))
        rig.add(spec0, to: "speculum", lods: 0...0)
        rig.add(spec1, to: "speculum", lods: 1...1)
        // Lying: axis turned toward +X and tipped onto a generator line, then dropped to the table.
        let half = atan2(Float(0.0094 - 0.0029), Float(0.0415)) * 180 / .pi
        let lay = simd_quatf(degrees: -half, axis: V3(0, 0, 1)) * simd_quatf(degrees: 70, axis: V3(0, 1, 0))
        func lying(_ s: Surface) -> Surface {
            var t = s.transformed(Xform(translation: -V3(0, yc, 0.04)).then(Xform(rotation: lay)))
            let minY = t.positions.map(\.y).min() ?? 0
            t = t.transformed(Xform(translation: V3(0.03, -minY + 0.0001, 0.046)))
            return t
        }
        rig.add(lying(spec0), to: "speculum", option: 1, lods: 0...0)
        rig.add(lying(spec1), to: "speculum", option: 1, lods: 1...1)

        groundAO(&rig, height: 0.02, floor: 0.6)
        var stk = Model(name: "sticker"); stk.add(sticker)
        rig.base[0].add(stk)
        rig.states = [RigState("off"), RigState("on", ["rheostat": onTurn], options: ["lamp": 1]),
                      RigState("window-open", ["rheostat": onTurn, "window": 95], options: ["lamp": 1]),
                      RigState("speculum-off", options: ["speculum": 1])]
        return rig
    }
}
