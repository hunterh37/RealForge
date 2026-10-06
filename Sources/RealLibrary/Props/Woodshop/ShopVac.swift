import simd
import Foundation

/// 12 gallon wet/dry shop vacuum (generic, red drum and black head): 0.40 m polypropylene drum on a
/// four-arm caster dolly, motor head with molded carry handle, two side lid latches, rocker switch, rear
/// blower/exhaust port with grille, front 2.5 in inlet with a ribbed 2.5 in (64 mm OD) hose coiled on the
/// floor to a 12 in floor nozzle, rear cord wrap with the cord wound on, front drain cap. One story detail:
/// a duct-tape repair on the hose near the cuff.
///
/// Frame: drum axis on the origin, base (caster wheels) at y = 0, inlet facing +Z. The hose loop sits in
/// front and to the right, so the bounds are not centered. `hoseEnd` is the free end of the flexible hose
/// (where the floor nozzle neck plugs in); `nozzleIntake` is the centre of the nozzle's floor slot.
public struct ShopVac: RealAsset {
    public static let id = "shop-vac"
    public static let summary = "12 gallon wet/dry shop vacuum: drum on a caster dolly, motor head with handle and latches, switch, 2.5 in hose coiled to a floor nozzle, cord wrap."
    public static let tags = ["prop", "workshop", "plastic", "metal"]
    public static let budget = 15_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 18, distance: 1.25, studio: true)

    /// Drum color (sRGB hex).
    public var drumColor: UInt32 = 0xC4241A
    /// Head, dolly and trim color (sRGB hex).
    public var headColor: UInt32 = 0x1E1E20
    /// Hose color (sRGB hex).
    public var hoseColor: UInt32 = 0x2B2C2E
    /// Drum radius at the rim (m) and drum top height (m).
    public var drumRadius: Float = 0.2
    public var drumTop: Float = 0.47
    /// Hose outer radius (m): 2.5 in hose, 64 mm OD.
    public var hoseRadius: Float = 0.032
    /// Draw the duct-tape repair on the hose.
    public var tapeRepair = true
    public init() {}

    /// Inlet port centre on the drum front (m).
    public var inlet: V3 { V3(0, drumTop - 0.09, drumRadius * 0.94 + 0.065) }
    /// Free end of the flexible hose (centre of the end cuff), in asset space (m).
    public var hoseEnd: V3 { hosePath.last! }
    /// Centre of the floor nozzle's intake slot, on the floor (m).
    public var nozzleIntake: V3 { V3(-0.37, 0, 0.47) }

    /// Hose centreline from the inlet cuff to the free end (control points).
    var hosePath: [V3] {
        let r = hoseRadius, i = inlet
        return [i, i + V3(0, -0.01, 0.06), V3(0.03, 0.27, 0.42), V3(0.1, 0.09, 0.45), V3(0.2, r, 0.45), V3(0.33, r, 0.41),
                V3(0.38, r, 0.53), V3(0.27, r, 0.63), V3(0.09, r, 0.6), V3(-0.09, r, 0.53), V3(-0.2, r, 0.49)]
    }

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [5])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let drum: MaterialKey = "plastic.tool:" + String(format: "%06X", drumColor)
        let head: MaterialKey = "plastic.tool:" + String(format: "%06X", headColor)
        let hoseMat: MaterialKey = "plastic.tool:" + String(format: "%06X", hoseColor)
        let dark: MaterialKey = "plastic.matte:121214"
        let steel: MaterialKey = "metal.steel"
        let R = drumRadius, top = drumTop, base: Float = 0.085
        let seg = detail ? 40 : 20

        // MARK: dolly: four molded arms on a ring, swivel casters
        m.add(Prim.lathe([V2(0, base - 0.012), V2(0.16, base - 0.012), V2(0.168, base - 0.006), V2(0.168, base + 0.004), V2(0.15, base + 0.006), V2(0, base + 0.006)],
                         segments: detail ? 28 : 16, seamTile: 0.2, material: head))
        for k in 0..<4 {
            let a = Float(k) * .pi / 2 + .pi / 4
            let dir = V3(cos(a), 0, sin(a))
            let arm = Shape2D.rounded([V2(-0.03, -0.012), V2(0.03, -0.012), V2(0.024, 0.006), V2(-0.024, 0.006)], radius: 0.004, segments: 1)
            m.add(Prim.sweep(arm, along: [dir * 0.12 + V3(0, base - 0.004, 0), dir * 0.245 + V3(0, base - 0.006, 0)], up: .up, material: head))
            if detail {
                // Light swivel caster: plate, swivel race, pressed fork, 60 mm wheel on an axle bolt.
                let p0 = dir * 0.225, yaw = simd_quatf(degrees: rng.float(0...360), axis: .up)
                let top = base - 0.012
                m.add(Prim.roundedBox(V3(0.05, 0.003, 0.05), radius: 0.001, bevelSegments: 1, material: "metal.galvanized"), Xform(translation: p0 + V3(0, top - 0.0015, 0), rotation: yaw))
                m.add(Prim.cylinder(radius: 0.016, height: 0.007, bevel: 0.002, segments: 12, bevelSegments: 1, material: "metal.galvanized"), Xform(translation: p0 + V3(0, top - 0.01, 0)))
                for s: Float in [-1, 1] {
                    let leg = Shape2D.rounded([V2(-0.014, 0), V2(0.014, 0), V2(0.022, -(top - 0.03 - 0.01)), V2(0.004, -(top - 0.03 - 0.01) - 0.008)], radius: 0.003, segments: 1)
                    m.add(Prim.extrude(leg, depth: 0.0025, bevel: 0.0006, bevelSegments: 1, material: "metal.galvanized"),
                          Xform(translation: p0 + yaw.act(V3(0, top - 0.01, s * 0.0135)), rotation: yaw))
                }
                let wc = p0 + yaw.act(V3(0.012, 0.03, 0))
                m.add(Prim.lathe([V2(0, -0.0095), V2(0.022, -0.0095), V2(0.028, -0.008), V2(0.03, -0.004), V2(0.03, 0.004), V2(0.028, 0.008), V2(0.022, 0.0095), V2(0, 0.0095)],
                                 segments: 12, seamTile: 0.1, material: "rubber"), Xform(translation: wc, rotation: yaw * simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
                m.add(Prim.cylinder(radius: 0.005, height: 0.032, bevel: 0.001, segments: 8, bevelSegments: 1, material: "metal.galvanized"),
                      Xform(translation: wc + yaw.act(V3(0, 0, -0.016)), rotation: yaw * simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            } else {
                m.add(Prim.cylinder(radius: 0.03, height: 0.022, bevel: 0.006, segments: 10, bevelSegments: 1, material: "rubber"),
                      Xform(translation: dir * 0.225 + V3(0, 0.03, -0.011), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
                m.add(Prim.roundedBox(V3(0.03, base - 0.042, 0.03), radius: 0.003, bevelSegments: 1, material: "metal.galvanized"),
                      Xform(translation: dir * 0.225 + V3(0, 0.03 + (base - 0.042) / 2 + 0.012, 0)))
            }
        }

        // MARK: drum with molded bands and rim
        let drumProf: [V2] = [V2(0, base + 0.004), V2(R * 0.78, base + 0.004), V2(R * 0.85, base + 0.016), V2(R * 0.87, base + 0.05),
                               V2(R * 0.9, base + 0.1), V2(R * 0.905, base + 0.112), V2(R * 0.92, base + 0.12), V2(R * 0.94, top - 0.15),
                               V2(R * 0.945, top - 0.138), V2(R * 0.962, top - 0.13), V2(R * 0.975, top - 0.03), V2(R, top - 0.012), V2(R, top - 0.002), V2(0, top - 0.002)]
        m.add(Prim.lathe(drumProf, segments: seg + 8, seamTile: 0.25, material: drum))
        // Printed label on the drum front, below the inlet (follows the drum's taper).
        do {
            var band = Surface(material: "label.shop-vac")
            let y0 = base + 0.13, y1 = top - 0.16, a0: Float = -0.62, a1: Float = 0.62
            func rr(_ y: Float) -> Float { R * 0.92 + (R * 0.94 - R * 0.92) * (y - (base + 0.12)) / ((top - 0.15) - (base + 0.12)) + 0.0006 }
            let nb = 14
            for k in 0...nb {
                let t = Float(k) / Float(nb), a = a0 + (a1 - a0) * t
                let n = V3(sin(a), 0, cos(a))
                _ = band.add(V3(sin(a) * rr(y1), y1, cos(a) * rr(y1)), n, V2(t, 0))
                _ = band.add(V3(sin(a) * rr(y0), y0, cos(a) * rr(y0)), n, V2(t, 1))
            }
            for k in 0..<UInt32(nb) { band.quad(2 * k, 2 * k + 1, 2 * k + 3, 2 * k + 2) }
            band.computeTangents()
            m.add(band)
        }
        // Recessed side grips (dark shadow pockets) at +-X.
        for sx: Float in [-1, 1] {
            m.add(Prim.superellipsoid(V3(0.02, 0.035, 0.12), exponent: 4, subdivisions: detail ? 3 : 2, material: head),
                  Xform(translation: V3(sx * (R * 0.94 - 0.004), top - 0.075, 0)))
        }
        // Drain cap at the front base.
        m.add(Prim.cylinder(radius: 0.022, height: 0.018, bevel: 0.003, segments: 16, bevelSegments: 1, material: head),
              Xform(translation: V3(0, base + 0.06, R * 0.86), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        if detail {
            for k in 0..<8 {
                let a = Float(k) / 8 * 2 * .pi
                m.add(cuboid(V3(0.004, 0.004, 0.006), material: head), Xform(translation: V3(cos(a) * 0.022, base + 0.06 + sin(a) * 0.022, R * 0.86 + 0.009)))
            }
        }

        // MARK: inlet port and cuff
        let inl = inlet
        m.add(Prim.lathe([V2(0.046, 0), V2(0.05, 0.004), V2(0.05, 0.016), V2(0.04, 0.02), V2(0.037, 0.02), V2(0.037, 0.075), V2(0.0, 0.075)],
                         segments: seg / 2 + 8, seamTile: 0.2, material: drum),
              Xform(translation: V3(0, inl.y, R * 0.92 - 0.02), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        m.add(Prim.lathe([V2(0, 0), V2(0.039, 0), V2(0.041, 0.004), V2(0.041, 0.05), V2(0.036, 0.056), V2(0, 0.056)], segments: 20, seamTile: 0.2, material: head),
              Xform(translation: V3(0, inl.y, inl.z - 0.04), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))

        // MARK: motor head: lid, motor dome, carry handle, latches, switch, exhaust
        let lid: [V2] = [V2(0, top - 0.004), V2(R + 0.006, top - 0.004), V2(R + 0.009, top + 0.002), V2(R + 0.009, top + 0.022), V2(R + 0.002, top + 0.03),
                         V2(R * 0.9, top + 0.036), V2(R * 0.8, top + 0.06), V2(R * 0.66, top + 0.09), V2(R * 0.6, top + 0.094), V2(R * 0.55, top + 0.11),
                         V2(R * 0.4, top + 0.124), V2(R * 0.2, top + 0.13), V2(0, top + 0.131)]
        m.add(Prim.lathe(lid, segments: seg, seamTile: 0.25, material: head))
        // Motor cooling vents: ring of dark slots on the dome shoulder.
        for k in 0..<(detail ? 18 : 0) {
            let a = Float(k) / 18 * 2 * .pi
            if abs(sin(a)) > 0.9 { continue }
            m.add(cuboid(V3(0.004, 0.012, 0.022), material: dark),
                  Xform(translation: V3(cos(a) * R * 0.71, top + 0.077, sin(a) * R * 0.71), rotation: simd_quatf(angle: -a, axis: .up) * simd_quatf(degrees: -38, axis: V3(0, 0, 1))))
        }
        // Carry handle: molded arch across X over the dome.
        let hp = catmull([V3(-0.1, top + 0.105, 0), V3(-0.085, top + 0.17, 0), V3(-0.05, top + 0.19, 0), V3(0.05, top + 0.19, 0), V3(0.085, top + 0.17, 0), V3(0.1, top + 0.105, 0)], per: detail ? 3 : 2)
        m.add(Prim.sweep(Shape2D.roundedRect(0.026, 0.036, radius: 0.011, segments: detail ? 2 : 1), along: hp, up: V3(0, 0, 1), material: head))
        // Rocker switch on the front of the dome.
        let sw = V3(0, top + 0.104, 0.085)
        m.add(Prim.roundedBox(V3(0.046, 0.012, 0.032), radius: 0.003, bevelSegments: 1, material: dark), Xform(translation: sw, rotation: simd_quatf(degrees: 22, axis: V3(1, 0, 0))))
        m.add(Prim.roundedBox(V3(0.034, 0.01, 0.022), radius: 0.003, bevelSegments: 1, material: "plastic.matte:D23A1E"),
              Xform(translation: sw + V3(0, 0.007, 0.002), rotation: simd_quatf(degrees: 30, axis: V3(1, 0, 0))))
        // Rear blower port with grille slats.
        let ex = V3(0, top + 0.05, -(R * 0.82))
        m.add(Prim.lathe([V2(0.044, 0), V2(0.044, 0.04), V2(0.04, 0.046), V2(0.034, 0.046), V2(0.034, 0.03), V2(0.0, 0.03)], segments: 22, seamTile: 0.2, material: head),
              Xform(translation: ex, rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
        for k in -2...2 {
            m.add(cuboid(V3(0.062, 0.003, 0.006), material: head), Xform(translation: ex + V3(0, Float(k) * 0.011, -0.04)))
        }
        // Lid latches at +-X: hinged clamp lever hooking under the drum rim.
        for sx: Float in [-1, 1] {
            let lx = sx * (R + 0.015)
            m.add(Prim.roundedBox(V3(0.014, 0.06, 0.05), radius: 0.004, bevelSegments: 1, material: head), Xform(translation: V3(lx, top - 0.006, 0)))
            m.add(Prim.roundedBox(V3(0.008, 0.012, 0.044), radius: 0.003, bevelSegments: 1, material: head), Xform(translation: V3(lx - sx * 0.008, top - 0.04, 0)))
            if detail {
                m.add(Prim.cylinder(radius: 0.003, height: 0.056, bevel: 0.001, segments: 8, bevelSegments: 1, material: steel),
                      Xform(translation: V3(lx, top + 0.018, -0.028), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            }
        }

        // MARK: cord wrap on the back of the drum
        let cy = top - 0.19, cz = -(R * 0.93)
        for sx: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.018, 0.05, 0.04), radius: 0.004, bevelSegments: 1, material: head), Xform(translation: V3(sx * 0.075, cy, cz - 0.012)))
            m.add(Prim.roundedBox(V3(0.022, 0.012, 0.012), radius: 0.003, bevelSegments: 1, material: head), Xform(translation: V3(sx * 0.075, cy + 0.03, cz - 0.03)))
        }
        let cordR: Float = 0.0038
        let cord: MaterialKey = "plastic.matte:18181A"
        for k in 0..<(detail ? 4 : 3) {
            let z = cz - 0.019 - Float(k % 3) * 0.0075 - (k >= 3 ? 0.0 : 0)
            let yo = (Float(k / 3) - 0.5) * 0.0076 * (detail ? 1 : 0)
            let loop = Shape2D.roundedRect(0.17 + rng.float(-0.004...0.004), 0.048, radius: 0.022, segments: detail ? 4 : 2).map { V3($0.x, cy + $0.y + yo, z) }
            m.add(Prim.sweep(Shape2D.circle(cordR, segments: detail ? 5 : 4), along: loop, closedPath: true, caps: false, material: cord))
        }
        // Cord leaves the head at the back and drops to the wrap; plug tucked under a loop.
        let cp = catmull([V3(0.04, top + 0.03, -(R + 0.008)), V3(0.07, top - 0.03, -(R * 1.0) - 0.02), V3(0.085, cy + 0.028, cz - 0.028)], per: 4)
        m.add(Prim.tube(cp, radii: cp.map { _ in cordR }, sides: 6, seamTile: 0.02, material: cord, capEnd: false))
        m.add(Prim.roundedBox(V3(0.024, 0.04, 0.02), radius: 0.005, bevelSegments: 1, material: cord),
              Xform(translation: V3(-0.03, cy - 0.04, cz - 0.03), rotation: simd_quatf(degrees: 20, axis: V3(0, 0, 1))))
        if detail {
            for bx: Float in [-0.0063, 0.0063] {
                m.add(cuboid(V3(0.0016, 0.016, 0.0064), material: "metal.brass"), Xform(translation: V3(-0.03 + bx * 0.94 - 0.006, cy - 0.066, cz - 0.03), rotation: simd_quatf(degrees: 20, axis: V3(0, 0, 1))))
            }
        }

        // MARK: hose (ribbed: alternating ring radii every half pitch)
        let ctrl = hosePath
        let smooth = catmull(ctrl, per: 8)
        let pitchHalf: Float = detail ? 0.007 : 0.03
        let path = resample(smooth, spacing: pitchHalf) + [smooth.last!]
        let r = hoseRadius
        var radii: [Float] = []
        for k in path.indices { radii.append(detail ? (k % 2 == 0 ? r : r * 0.9) : r * 0.95) }
        // Cuffs: smooth plastic for the first and last 6 cm.
        var acc: Float = 0, lens: [Float] = [0]
        for k in 1..<path.count { acc += simd_distance(path[k], path[k - 1]); lens.append(acc) }
        for k in path.indices where lens[k] < 0.05 || lens[k] > acc - 0.06 { radii[k] = r * 1.04 }
        m.add(Prim.tube(path, radii: radii, sides: detail ? 8 : 7, seamTile: 0.05, material: hoseMat, capEnd: true))
        if tapeRepair {
            // Duct tape wrap ~25 cm along the hose: slightly larger sleeve with a lifted end.
            let a0 = lens.firstIndex { $0 > 0.22 } ?? 10
            let a1 = lens.firstIndex { $0 > 0.29 } ?? 20
            let tape = Array(path[a0...a1])
            m.add(Prim.tube(tape, radii: tape.map { _ in r * 1.06 }, sides: detail ? 10 : 7, seamTile: 0.05, material: "fabric.canvas:8E9196", capEnd: false))
        }
        // Floor nozzle: neck from the hose end, 12 in head lying on the floor with a squeegee lip and wheels.
        let he = ctrl.last!
        let headC = V3(nozzleIntake.x, 0.022, nozzleIntake.z)
        let neck = catmull([he, he + V3(-0.07, -0.004, -0.005), V3(headC.x + 0.07, 0.04, headC.z), V3(headC.x + 0.02, 0.032, headC.z)], per: 4)
        m.add(Prim.tube(neck, radii: neck.map { _ in r * 0.98 }, sides: detail ? 12 : 7, seamTile: 0.05, material: head, capEnd: false))
        let noz = Shape2D.rounded([V2(-0.04, -0.022), V2(0.035, -0.022), V2(0.035, 0.008), V2(0.0, 0.022), V2(-0.04, 0.016)], radius: 0.007, segments: 2)
        m.add(Prim.extrude(noz, depth: 0.3, bevel: 0.006, bevelSegments: detail ? 2 : 1, material: head), Xform(translation: headC + V3(0, 0, 0)))
        m.add(Prim.roundedBox(V3(0.006, 0.006, 0.29), radius: 0.002, bevelSegments: 1, material: "rubber"), Xform(translation: headC + V3(0.028, -0.019, 0)))
        m.add(Prim.roundedBox(V3(0.006, 0.006, 0.29), radius: 0.002, bevelSegments: 1, material: "rubber"), Xform(translation: headC + V3(-0.034, -0.019, 0)))
        if detail {
            // Dust caked in the intake slot and a few drifts by the nozzle (story: just used).
            m.add(Prim.roundedBox(V3(0.02, 0.003, 0.27), radius: 0.001, bevelSegments: 1, material: "wood.sawdust"), Xform(translation: headC + V3(-0.003, -0.0205, 0)))
            for k in 0..<4 {
                var heap = Prim.superellipsoid(V3(rng.float(0.03...0.06), 0.008, rng.float(0.03...0.05)), exponent: 2.2, subdivisions: 3, material: "wood.sawdust")
                heap.deform { p in V3(p.x, max(0, p.y), p.z) }
                m.add(heap, Xform(translation: V3(headC.x + rng.float(-0.06...0.05), 0, headC.z + Float(k - 2) * 0.08 + rng.float(-0.02...0.02))))
            }
        }
        groundAO(&m, height: 0.12, floor: 0.55)
        return m
    }
}
