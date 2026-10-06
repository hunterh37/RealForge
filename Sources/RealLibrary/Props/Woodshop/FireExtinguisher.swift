import simd
import Foundation

/// 5 lb ABC dry chemical stored-pressure extinguisher, 400 mm tall: red enamel steel cylinder (108 mm) on a
/// rolled foot ring, generic printed label band, threaded collar, cast valve with a pressure gauge (green
/// charged arc between red zones, chrome bezel, lens), squeeze lever over a carry handle with a black
/// grip, pull pin with ring and a breakable plastic tamper seal, black rubber hose to a conical nozzle held
/// in a clip on the left side, and an annual inspection tag on the pin ring. `bracket` adds the steel wall
/// hook bracket behind the neck. Base at y = 0, cylinder on the Y axis, gauge and label facing +Z.
public struct FireExtinguisher: RealAsset {
    public static let id = "fire-extinguisher"
    public static let summary = "5 lb ABC dry chemical extinguisher: red steel cylinder, valve with gauge, pinned squeeze lever, hose and nozzle clipped to the side, label band."
    public static let tags = ["prop", "workshop", "metal", "sign"]
    public static let budget = 8_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 25, elevation: 12, distance: 1.0, studio: true)

    /// Cylinder radius and shoulder height (m).
    public var radius: Float = 0.054
    public var bodyHeight: Float = 0.29
    /// Shell paint (sRGB hex).
    public var color: UInt32 = 0xB51D17
    /// Label band material (medLabel, UVs 0...1 across the band).
    public var label: MaterialKey = "label.fire-extinguisher"
    /// Add the steel wall hook bracket behind the neck.
    public var bracket = false
    /// Hang the annual inspection tag on the pin ring.
    public var inspectionTag = true
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = radius, Hb = bodyHeight
        let paint: MaterialKey = "metal.fire-extinguisher-red:" + String(format: "%06X", color)
        let alu: MaterialKey = "metal.aluminum-brushed", chrome: MaterialKey = "metal.chrome"
        let black: MaterialKey = "plastic.matte:151517"
        let seg = 40

        // MARK: cylinder: foot ring, straight wall, domed shoulder to the neck
        var prof: [V2] = [V2(0, 0.006), V2(R * 0.9, 0.006), V2(R * 0.93, 0.0), V2(R * 0.985, 0.0), V2(R, 0.004), V2(R, 0.012), V2(R * 0.985, 0.016), V2(R, 0.02)]
        prof.append(V2(R, Hb))
        for k in 1...8 {
            let a = Float(k) / 8 * Float.pi / 2
            prof.append(V2(0.017 + (R - 0.017) * cos(a), Hb + sin(a) * (0.034)))
        }
        prof.append(V2(0.017, Hb + 0.04))
        prof.append(V2(0, Hb + 0.04))
        m.add(Prim.lathe(prof, segments: seg, seamTile: 0.34, material: paint))

        // Label band: partial cylinder over the front, UVs 0...1 across.
        let y0: Float = 0.07, y1: Float = 0.245, a0: Float = -1.75, a1: Float = 1.75
        var band = Surface(material: label)
        let nb = 28
        for k in 0...nb {
            let t = Float(k) / Float(nb), a = a0 + (a1 - a0) * t
            let n = V3(sin(a), 0, cos(a))
            _ = band.add(V3(sin(a) * (R + 0.0004), y1, cos(a) * (R + 0.0004)), n, V2(t, 0))
            _ = band.add(V3(sin(a) * (R + 0.0004), y0, cos(a) * (R + 0.0004)), n, V2(t, 1))
        }
        for k in 0..<UInt32(nb) { band.quad(2 * k, 2 * k + 1, 2 * k + 3, 2 * k + 2) }
        band.computeTangents()
        m.add(band)

        // MARK: collar and valve
        let neckY = Hb + 0.04
        m.add(Prim.lathe([V2(0, 0), V2(0.019, 0), V2(0.02, 0.003), V2(0.02, 0.014), V2(0.017, 0.016), V2(0, 0.016)], segments: 20, seamTile: 0.1, material: alu),
              Xform(translation: V3(0, neckY - 0.004, 0)))
        let vy = neckY + 0.012
        m.add(Prim.roundedBox(V3(0.036, 0.038, 0.03), radius: 0.006, bevelSegments: 2, material: alu), Xform(translation: V3(0, vy + 0.019, 0)))
        // Lever pivot boss and outlet boss on the left.
        m.add(Prim.cylinder(radius: 0.009, height: 0.036, bevel: 0.002, segments: 14, bevelSegments: 1, material: alu),
              Xform(translation: V3(0.016, vy + 0.032, -0.018), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        m.add(Prim.cylinder(radius: 0.008, height: 0.016, bevel: 0.002, segments: 14, bevelSegments: 1, material: alu),
              Xform(translation: V3(-0.016, vy + 0.016, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        // Gauge: chrome bezel, white dial, green charged arc between red zones, needle, lens.
        let gc = V3(0, vy + 0.02, 0.017)
        let toFront = simd_quatf(degrees: 90, axis: V3(1, 0, 0))
        m.add(Prim.lathe([V2(0, 0), V2(0.0125, 0), V2(0.0135, 0.002), V2(0.0128, 0.006), V2(0.011, 0.0062), V2(0.011, 0.004), V2(0, 0.004)], segments: 20, seamTile: 0.05, material: chrome),
              Xform(translation: gc, rotation: toFront))
        m.add(Prim.lathe([V2(0, 0), V2(0.011, 0), V2(0.011, 0.0004), V2(0, 0.0004)], segments: 20, seamTile: 0.05, material: "plastic.matte:F2F0EA"),
              Xform(translation: gc + V3(0, 0, 0.004), rotation: toFront))
        func arc(_ from: Float, _ to: Float, _ mat: MaterialKey) {
            let s = Prim.torus(major: 0.0078, minor: 0.0011, segments: 8, sides: 3, arc: (to - from) * .pi / 180, minorY: 0.0003, material: mat)
            m.add(s, Xform(translation: gc + V3(0, 0, 0.0046), rotation: simd_quatf(degrees: from, axis: V3(0, 0, 1)) * simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }
        arc(-30, 30, "plastic.matte:2E9A3E")
        arc(30, 120, "plastic.matte:C42A1E")
        arc(-120, -30, "plastic.matte:C42A1E")
        m.add(cuboid(V3(0.0012, 0.0085, 0.0004), material: "plastic.matte:111111"),
              Xform(translation: gc + V3(0, 0.0035, 0.0049), rotation: simd_quatf(degrees: rng.float(-12...8), axis: V3(0, 0, 1))))
        m.add(Prim.lathe([V2(0, 0.0024), V2(0.0112, 0), V2(0.0112, 0.0004), V2(0, 0.0028)], segments: 20, seamTile: 0.05, material: "glass.gauge-lens"),
              Xform(translation: gc + V3(0, 0, 0.0046), rotation: toFront))

        // MARK: carry handle and squeeze lever (pressed steel, extending +X), grip on the handle
        let handle = Shape2D.rounded([V2(0.005, -0.006), V2(0.08, -0.012), V2(0.118, -0.02), V2(0.124, -0.012), V2(0.085, -0.001), V2(0.005, 0.006)], radius: 0.004, segments: 2)
        m.add(Prim.extrude(handle, depth: 0.02, bevel: 0.0015, bevelSegments: 1, material: chrome), Xform(translation: V3(0.012, vy + 0.012, 0)))
        m.add(Prim.superellipsoid(V3(0.06, 0.014, 0.024), exponent: 3, subdivisions: 4, material: black),
              Xform(translation: V3(0.1, vy + 0.0, 0), rotation: simd_quatf(degrees: -10, axis: V3(0, 0, 1))))
        let lever = Shape2D.rounded([V2(-0.006, -0.006), V2(0.07, 0.008), V2(0.115, 0.022), V2(0.118, 0.03), V2(0.07, 0.018), V2(-0.004, 0.006)], radius: 0.004, segments: 2)
        m.add(Prim.extrude(lever, depth: 0.018, bevel: 0.0015, bevelSegments: 1, material: chrome), Xform(translation: V3(0.012, vy + 0.042, 0)))
        // Pull pin through the handle and lever ears (along Z) with its ring on the front.
        let pin = V3(0.03, vy + 0.032, 0)
        m.add(Prim.cylinder(radius: 0.0018, height: 0.05, bevel: 0.0005, segments: 8, bevelSegments: 1, material: "metal.stainless"),
              Xform(translation: pin + V3(0, 0, -0.022), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        let ringC = pin + V3(0.0, -0.002, 0.028 + 0.012)
        m.add(Prim.torus(major: 0.012, minor: 0.0016, segments: 18, sides: 6, material: "metal.stainless"),
              Xform(translation: ringC, rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1)) * simd_quatf(degrees: 15, axis: V3(1, 0, 0))))
        // Tamper seal: thin plastic strap looping from the ring to the handle, with a molded tab.
        let seal = catmull([ringC + V3(0, -0.011, -0.004), ringC + V3(0.012, -0.018, -0.012), V3(0.045, vy + 0.008, 0.012), V3(0.05, vy + 0.004, 0.0)], per: 4)
        m.add(Prim.tube(seal, radii: seal.map { _ in 0.0008 }, sides: 4, seamTile: 0.01, material: "plastic.matte:E8C21C", capEnd: false))
        m.add(Prim.roundedBox(V3(0.007, 0.01, 0.002), radius: 0.0008, bevelSegments: 1, material: "plastic.matte:E8C21C"),
              Xform(translation: ringC + V3(0.009, -0.02, -0.006)))
        if inspectionTag {
            // Punched card tag on a short string from the ring.
            let tagTop = ringC + V3(-0.004, -0.014, 0.004)
            let str = [tagTop + V3(0, 0.003, 0), tagTop + V3(-0.004, -0.02, 0.006)]
            m.add(Prim.tube(str, radii: [0.0006, 0.0006], sides: 4, seamTile: 0.01, material: "plastic.matte:EDEAE0", capEnd: false))
            var tag = Surface(material: "label.inspection")
            let tw: Float = 0.032, th: Float = 0.058
            let tq = simd_quatf(degrees: 12, axis: V3(0, 0, 1)) * simd_quatf(degrees: 28, axis: .up)
            let tc = tagTop + V3(-0.004, -0.02 - th / 2, 0.008)
            for (side, n) in [(Float(1), V3(0, 0, 1)), (-1, V3(0, 0, -1))] {
                let o = V3(0, 0, side * 0.0002)
                let a = tag.add(tq.act(V3(-tw / 2, th / 2, 0) + o) + tc, tq.act(n), V2(0, 0)), b = tag.add(tq.act(V3(tw / 2, th / 2, 0) + o) + tc, tq.act(n), V2(1, 0))
                let c = tag.add(tq.act(V3(tw / 2, -th / 2, 0) + o) + tc, tq.act(n), V2(1, 1)), d = tag.add(tq.act(V3(-tw / 2, -th / 2, 0) + o) + tc, tq.act(n), V2(0, 1))
                if side > 0 { tag.quad(a, d, c, b) } else { tag.quad(a, b, c, d) }
            }
            tag.computeTangents()
            m.add(tag)
        }

        // MARK: hose, nozzle, side clip
        let out = V3(-0.032, vy + 0.016, 0)
        let hose = catmull([out, out + V3(-0.02, -0.004, 0.0), V3(-R - 0.03, Hb - 0.01, 0.004), V3(-R - 0.014, Hb - 0.08, 0.006),
                            V3(-R - 0.01, 0.2, 0.008), V3(-R - 0.011, 0.155, 0.008)], per: 6)
        m.add(Prim.tube(hose, radii: hose.map { _ in 0.0068 }, sides: 10, seamTile: 0.03, material: "rubber", capEnd: false))
        m.add(Prim.lathe([V2(0, 0), V2(0.0085, 0), V2(0.0085, 0.012), V2(0.0078, 0.014), V2(0, 0.014)], segments: 14, seamTile: 0.05, material: alu),
              Xform(translation: out + V3(0.004, 0, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        let nz = hose.last!
        m.add(Prim.lathe([V2(0, 0.0), V2(0.0045, 0.0), V2(0.006, 0.01), V2(0.0085, 0.04), V2(0.0085, 0.046), V2(0, 0.046)], segments: 14, seamTile: 0.05, material: black),
              Xform(translation: nz + V3(0, -0.046, 0), rotation: .identity))
        // Hose retaining band with a molded clip around the nozzle.
        m.add(Prim.lathe([V2(R - 0.0002, 0), V2(R + 0.0018, 0.001), V2(R + 0.0018, 0.011), V2(R - 0.0002, 0.012)], segments: seg, seamTile: 0.34, material: black),
              Xform(translation: V3(0, 0.124, 0)))
        m.add(Prim.roundedBox(V3(0.012, 0.016, 0.024), radius: 0.003, bevelSegments: 1, material: black), Xform(translation: V3(-R - 0.004, 0.13, 0.008)))
        m.add(Prim.torus(major: 0.0098, minor: 0.0018, segments: 14, sides: 5, arc: 1.7 * .pi, material: black),
              Xform(translation: V3(nz.x, 0.13, nz.z), rotation: simd_quatf(degrees: 120, axis: .up)))

        // MARK: optional wall hook bracket behind the neck
        if bracket {
            let bz = -R - 0.012
            m.add(Prim.roundedBox(V3(0.05, 0.11, 0.003), radius: 0.0012, bevelSegments: 1, material: "metal.powdercoat:1E1E1E"), Xform(translation: V3(0, Hb + 0.03, bz)))
            let saddle = catmull([V3(0, Hb + 0.08, bz), V3(0, Hb + 0.065, bz + 0.03), V3(0, neckY + 0.0, -0.018), V3(0, neckY + 0.01, -0.006)], per: 4)
            m.add(Prim.sweep(Shape2D.roundedRect(0.04, 0.003, radius: 0.0012, segments: 1), along: saddle, up: V3(1, 0, 0), material: "metal.powdercoat:1E1E1E"))
            for y: Float in [Hb - 0.01, Hb + 0.07] {
                m.add(Prim.cylinder(radius: 0.0045, height: 0.002, bevel: 0.0006, segments: 10, bevelSegments: 1, material: "metal.galvanized"),
                      Xform(translation: V3(0, y, bz + 0.0015), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            }
        }
        groundAO(&m, height: 0.06, floor: 0.6)
        return LODModel(m)
    }
}
