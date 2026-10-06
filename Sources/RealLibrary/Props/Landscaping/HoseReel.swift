import simd
import Foundation

/// Hose reel cart, 0.85 m tall: powder-coated steel tube frame on two 0.25 m wheels, a drum on an axle
/// wound with green garden hose, crank handle on one side, push handle on top, a hose end with a brass
/// nozzle hanging from a hook. Dirt on the tires.
public struct HoseReel: RealAsset {
    public static let id = "hose-reel"
    public static let summary = "Hose reel cart, 0.85 m: green steel frame with two wheels, drum wound with garden hose, crank handle and brass nozzle."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "tool", "plastic"]
    public static let budget = 14000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 40, elevation: 18)

    /// Frame color.
    public var frameColor: UInt32 = 0x2F5A35
    /// Hose color.
    public var hoseColor: UInt32 = 0x2D6A3A
    /// Wound hose wraps (layers x turns).
    public var wraps: Int = 9
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let frame = String(format: "metal.powdercoat:%06X", frameColor), hose = String(format: "rubber.tubing:%06X", hoseColor)
        let halfW: Float = 0.22, axleY: Float = 0.36, wheelR: Float = 0.125, tube: Float = 0.0125
        // Side frames: loop from wheel axle up to handle, down to a rear foot.
        for s: Float in [-1, 1] {
            let z = s * halfW
            let pts = catmull([V3(-0.2, 0.02, z), V3(-0.18, 0.2, z), V3(-0.12, axleY, z), V3(-0.08, 0.6, z), V3(-0.06, 0.82, z)], per: 5)
            m.add(Prim.tube(pts, radii: pts.map { _ in tube }, sides: 10, seamTile: 0.1, material: frame))
            let front = [V3(-0.2, 0.02, z), V3(0.0, 0.05, z), V3(0.13, wheelR, z)]
            m.add(Prim.tube(catmull(front, per: 4), radii: Array(repeating: tube, count: 9), sides: 10, seamTile: 0.1, material: frame))
            let brace = [V3(0.13, wheelR, z), V3(0.02, axleY, z)]
            m.add(Prim.tube(brace, radii: [tube, tube], sides: 10, seamTile: 0.1, material: frame))
            // Wheel: tire torus + hub.
            let wc = V3(0.13, wheelR, s * (halfW + 0.05))
            m.add(Prim.torus(major: wheelR - 0.025, minor: 0.025, segments: 32, sides: 10, material: "rubber.tire"),
                  Xform(translation: wc, rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            m.add(Prim.cylinder(radius: wheelR - 0.035, height: 0.03, bevel: 0.005, segments: 24, material: "plastic.black"),
                  Xform(translation: wc - V3(0, 0, 0.015), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            m.add(Prim.cylinder(radius: 0.022, height: 0.04, bevel: 0.004, segments: 14, material: "plastic.yellow"),
                  Xform(translation: wc - V3(0, 0, 0.02), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            // Mud on the lower tire.
            m.add(Prim.superellipsoid(V3(0.1, 0.03, 0.07), exponent: 2.2, subdivisions: 2, material: "ground.mud"),
                  Xform(translation: wc + V3(0.03, -wheelR + 0.03, 0), rotation: simd_quatf(degrees: 30, axis: V3(0, 0, 1))))
        }
        // Wheel axle and cross bars.
        m.add(Prim.tube([V3(0.13, wheelR, -halfW - 0.06), V3(0.13, wheelR, halfW + 0.06)], radii: [0.008, 0.008], sides: 8, seamTile: 0.1, material: "metal.steel"))
        for p in [V3(-0.2, 0.02, 0), V3(-0.06, 0.82, 0), V3(0.0, 0.05, 0)] {
            m.add(Prim.tube([p - V3(0, 0, halfW), p + V3(0, 0, halfW)], radii: [tube, tube], sides: 10, seamTile: 0.1, material: frame))
        }
        // Handle grip.
        m.add(Prim.tube([V3(-0.06, 0.82, -0.12), V3(-0.06, 0.82, 0.12)], radii: [tube + 0.006, tube + 0.006], sides: 12, seamTile: 0.05, material: "plastic.black"))
        // Drum: flanges and core along Z at the axle.
        let drumC = V3(-0.11, axleY, 0)
        for s: Float in [-1, 1] {
            m.add(Prim.cylinder(radius: 0.2, height: 0.012, bevel: 0.004, segments: 40, material: "plastic.black:161616"),
                  Xform(translation: drumC + V3(0, 0, s * 0.19 - (s > 0 ? 0.012 : 0)), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)) * simd_quatf(degrees: 0, axis: .up)))
        }
        m.add(Prim.tube([drumC - V3(0, 0, halfW + 0.02), drumC + V3(0, 0, halfW + 0.04)], radii: [0.012, 0.012], sides: 10, seamTile: 0.1, material: "metal.steel"))
        // Wound hose: one ridged lathe, one ridge per turn of 24 mm hose.
        var prof: [V2] = [V2(0.012, -0.178)]
        let turns = 14
        for k in 0..<turns {
            let y0 = -0.175 + Float(k) * 0.35 / Float(turns)
            for j in 0..<4 { let t = Float(j) / 4; prof.append(V2(0.15 + 0.008 * sin(t * .pi), y0 + t * 0.35 / Float(turns))) }
        }
        prof += [V2(0.15, 0.175), V2(0.012, 0.178)]
        var coil = Prim.lathe(prof, segments: 40, seamTile: 0.08, material: hose)
        coil.deform { p in V3(p.x, p.y + atan2(p.z, p.x) / (2 * .pi) * 0.025, p.z) }
        m.add(coil, Xform(translation: drumC, rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Crank on +Z side.
        let ck = drumC + V3(0, 0, halfW + 0.04)
        m.add(Prim.tube([ck, ck + V3(0.0, 0.11, 0)], radii: [0.008, 0.008], sides: 8, seamTile: 0.05, material: "metal.steel"))
        m.add(Prim.cylinder(radius: 0.012, height: 0.07, bevel: 0.003, segments: 12, material: "plastic.black"),
              Xform(translation: ck + V3(0, 0.11, 0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Hose end hanging from the drum to a nozzle on a hook at the handle.
        let tail = catmull([drumC + V3(0.03, 0.22, 0.05), V3(0.06, 0.5, 0.08), V3(0.06, 0.62, 0.14), V3(-0.04, 0.72, 0.17)], per: 5)
        m.add(Prim.tube(tail, radii: tail.map { _ in 0.012 }, sides: 10, seamTile: 0.08, material: hose))
        let noz = tail.last!
        m.add(Prim.cylinder(radius: 0.015, height: 0.03, bevel: 0.003, segments: 12, material: "metal.brass"),
              Xform(translation: noz, rotation: simd_quatf(from: .up, to: simd_normalize(tail.last! - tail[tail.count - 2]))))
        m.add(turned([(0.0, 0), (0.017, 0), (0.019, 0.02), (0.013, 0.09), (0.008, 0.11), (0, 0.11)], segments: 16, material: "plastic.yellow"),
              Xform(translation: noz + V3(0, 0, 0), rotation: simd_quatf(from: .up, to: simd_normalize(tail.last! - tail[tail.count - 2]))))
        _ = rng.float(0...1)
        let b = m.bounds
        let shift = V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)
        for i in m.surfaces.indices { m.surfaces[i].positions = m.surfaces[i].positions.map { $0 + shift } }
        groundAO(&m, height: 0.15)
        return LODModel(m)
    }
}
