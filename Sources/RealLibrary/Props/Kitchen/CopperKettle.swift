import simd
import Foundation

/// Hammered copper stovetop kettle, 2 l, 30 x 27 x 20 cm: spun and hammered body with a rolled foot and
/// tinned shoulder seam, domed lid with a walnut knob, tapered gooseneck spout with an open mouth, iron
/// handle arch on brass mounting plates with a turned walnut grip.
public struct CopperKettle: RealAsset {
    public static let id = "copper-kettle"
    public static let summary = "Hammered copper stovetop kettle, 2 l: tinned seams, gooseneck spout, brass hinge, turned wooden handle grip and lid knob."
    public static let tags = ["prop", "kitchen", "metal", "antique"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 16, distance: 1.2, studio: true)

    /// Body radius at the widest point (m).
    public var bodyRadius: Float = 0.1
    /// Copper material key (`metal.copper`, `metal.copper-patina`, `metal.brass`).
    public var copper: MaterialKey = "metal.copper"
    /// Grip and knob wood.
    public var wood: MaterialKey = "wood.walnut"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let r = bodyRadius, brass: MaterialKey = "metal.brass", tin: MaterialKey = "metal.stainless", iron: MaterialKey = "metal.iron"
        // Body: wide base, belly low, shoulder rolling into a short neck.
        let body = Profile.smooth([V2(0, 0.004), V2(r * 0.86, 0.004), V2(r * 0.97, 0.014), V2(r, 0.04), V2(r * 0.96, 0.075),
                                   V2(r * 0.8, 0.11), V2(r * 0.62, 0.13), V2(r * 0.57, 0.138), V2(r * 0.565, 0.145)], per: 4)
        m.add(Prim.lathe(body, segments: 48, seamTile: 0.35, material: copper))
        // Rolled foot rim and tinned shoulder seam bead.
        m.add(Prim.torus(major: r * 0.9, minor: 0.0045, segments: 40, sides: 6, material: copper), Xform(translation: V3(0, 0.0045, 0)))
        m.add(Prim.torus(major: r * 0.97, minor: 0.0016, segments: 48, sides: 6, material: tin), Xform(translation: V3(0, 0.068, 0)))
        // Lid: lip ring, dome, knob seat; walnut knob.
        m.add(Prim.torus(major: r * 0.585, minor: 0.0035, segments: 40, sides: 8, material: copper), Xform(translation: V3(0, 0.146, 0)))
        let lid = Profile.smooth([V2(r * 0.58, 0.146), V2(r * 0.55, 0.156), V2(r * 0.42, 0.172), V2(r * 0.2, 0.181), V2(0.012, 0.183), V2(0, 0.183)], per: 3)
        m.add(Prim.lathe(lid, segments: 40, seamTile: 0.35, material: copper))
        m.add(turned([(0, 0.182), (0.009, 0.182), (0.007, 0.188), (0.012, 0.196), (0.013, 0.203), (0.009, 0.209), (0, 0.211)],
                     segments: 16, material: wood, grainVertical: true))
        // Gooseneck spout: tapered tube from low on the belly, open mouth with a lip.
        let spoutPath = catmull([V3(r * 0.86, 0.045, 0), V3(r * 1.08, 0.06, 0), V3(r * 1.32, 0.095, 0), V3(r * 1.5, 0.14, 0), V3(r * 1.66, 0.168, 0), V3(r * 1.82, 0.176, 0)], per: 4)
        let n = spoutPath.count
        let radii = (0..<n).map { i -> Float in let t = Float(i) / Float(n - 1); return 0.019 * (1 - t) + 0.0085 * t }
        m.add(Prim.tube(spoutPath, radii: radii, sides: 18, seamTile: 0.35, material: copper, capEnd: false))
        let tail = Array(spoutPath.suffix(4))
        m.add(Prim.tube(tail, radii: tail.indices.map { _ in 0.0085 * 0.72 }, sides: 14, seamTile: 0.35, material: copper, capEnd: true).flipped())
        let tip = spoutPath[n - 1], tdir = simd_normalize(spoutPath[n - 1] - spoutPath[n - 2])
        m.add(Prim.torus(major: 0.0075, minor: 0.0016, segments: 18, sides: 6, material: copper), Xform(translation: tip, rotation: facing(tdir)))
        // Spout joint collar where it meets the belly.
        m.add(Prim.torus(major: 0.018, minor: 0.0025, segments: 20, sides: 6, material: tin),
              Xform(translation: spoutPath[1], rotation: facing(simd_normalize(spoutPath[2] - spoutPath[0]))))
        // Handle: iron arch over the lid along X, brass plates riveted to the shoulder, walnut grip on top.
        let hx: Float = r * 0.5, top: Float = 0.252
        let arch = catmull([V3(-hx, 0.128, 0), V3(-hx * 1.18, 0.185, 0), V3(-hx * 1.02, 0.236, 0), V3(-hx * 0.8, top, 0), V3(hx * 0.8, top, 0),
                            V3(hx * 1.02, 0.236, 0), V3(hx * 1.18, 0.185, 0), V3(hx, 0.128, 0)], per: 4)
        m.add(Prim.tube(arch, radii: arch.map { _ in 0.0042 }, sides: 10, seamTile: 0.025, material: iron, capEnd: false))
        for s: Float in [-1, 1] {
            let p = V3(s * hx, 0.126, 0)
            let nrm = simd_normalize(V3(s * 0.75, 0.66, 0))
            m.add(Prim.superellipsoid(V3(0.03, 0.006, 0.022), exponent: 5, subdivisions: 5, material: brass), Xform(translation: p, rotation: facing(nrm)))
            rivet(&m, at: p + nrm * 0.003 + simd_cross(nrm, V3(0, 0, 1)) * 0.009, normal: nrm, radius: 0.0025, material: brass)
            rivet(&m, at: p + nrm * 0.003 - simd_cross(nrm, V3(0, 0, 1)) * 0.009, normal: nrm, radius: 0.0025, material: brass)
        }
        let gripLen = hx * 1.5
        let grip = turned([(0, 0), (0.0105, 0), (0.0125, 0.008), (0.0135, gripLen * 0.5), (0.0125, gripLen - 0.008), (0.0105, gripLen), (0, gripLen)],
                          segments: 20, material: wood, grainVertical: true)
        m.add(grip, Xform(translation: V3(-gripLen / 2, top, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        for s: Float in [-1, 1] {
            m.add(Prim.torus(major: 0.0092, minor: 0.0022, segments: 16, sides: 6, material: brass),
                  Xform(translation: V3(s * gripLen / 2, top, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        }
        // Center the footprint (the spout extends +X) and give each seed a slightly different rotation.
        let bb = m.bounds
        let shift = V3(-(bb.min.x + bb.max.x) / 2, 0, 0)
        m = m.transformed(Xform(translation: shift, rotation: simd_quatf(degrees: rng.float(-2...2), axis: .up)))
        groundAO(&m, height: 0.08, floor: 0.45)
        return LODModel(m)
    }
}
