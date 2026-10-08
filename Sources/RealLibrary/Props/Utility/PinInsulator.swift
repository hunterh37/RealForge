import simd
import Foundation

/// ANSI 55-5 class porcelain pin insulator for 15 kV (12.47 kV wye) distribution: a wide ANSI 70 gray
/// glazed skirt with a drip rim and a petticoat underneath, a black semiconducting-glaze crown with a
/// saddle groove across the top and a recessed side tie neck, and a threaded pin hole with a black
/// polyethylene thread insert. `broken` knocks a flashover chip out of the skirt (unglazed body showing)
/// and adds a radial crack, the failed part a lineman swaps out.
public struct PinInsulator: RealAsset {
    public static let id = "pin-insulator"
    public static let summary = "ANSI 55-5 class porcelain pin insulator, 15 kV: wide gray skirt, black semiconducting crown with a top groove and side neck."
    public static let tags = ["prop", "utility", "electrical", "handheld", "ceramic"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 14, distance: 1.0, studio: true)

    /// Skirt radius at the drip rim (m). 55-5: 152 mm across.
    public var skirtRadius: Float = 0.076
    /// Overall height (m), rim to crown top.
    public var height: Float = 0.127
    /// Radius of the conductor saddle groove across the top (m), fits up to 4/0 ACSR.
    public var grooveRadius: Float = 0.019
    /// Knock a chip out of the skirt and crack it (failed insulator).
    public var broken = false
    /// Skirt glaze.
    public var skirt: MaterialKey = "ceramic.porcelain-gray"
    /// Crown glaze (semiconducting black).
    public var crown: MaterialKey = "ceramic.porcelain-black"
    /// Exposed porcelain body at a fracture.
    public var fracture: MaterialKey = "ceramic.porcelain-fracture"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = skirtRadius, H = height, s = H / 0.127
        func p(_ r: Float, _ y: Float) -> V2 { V2(r, y * s) }
        // Skirt: pin hole, petticoat, drip rim, dome up to the glaze line.
        let skirtProf: [V2] = [
            p(0, 0.066), p(0.0175, 0.066), p(0.0185, 0.012), p(0.022, 0.009), p(0.034, 0.008),
            p(0.044, 0.004), p(0.047, 0.006), p(0.052, 0.022), p(0.062, 0.028), p(0.071, 0.012),
            p(R - 0.006, 0.0005), p(R - 0.002, 0.005), p(R, 0.013), p(R + 0.0004, 0.024), p(R - 0.0005, 0.035),
            p(R - 0.003, 0.046), p(R - 0.009, 0.054), p(R - 0.018, 0.0595), p(0.05, 0.0615),
        ]
        var sk = Prim.lathe(skirtProf, segments: 56, seamTile: 0.25, material: skirt)
        if broken {
            // Flashover chip: a scalloped bite out of the rim on one side.
            let a0: Float = 0.35, a1: Float = 1.05
            sk.deform { q in
                let a = atan2(q.z, q.x), r = simd_length(V2(q.x, q.z))
                guard a > a0, a < a1, q.y < 0.04 * s, r > 0.05 else { return q }
                let t = (a - a0) / (a1 - a0), bite = sin(t * .pi)
                let cut = R - bite * (0.022 + 0.006 * sin(t * 23)) * (1 - q.y / (0.04 * s))
                let rr = min(r, cut)
                return V3(cos(a) * rr, q.y, sin(a) * rr)
            }
        }
        m.add(sk)
        // Crown: neck, tie neck recess, ears, saddle groove across X.
        let crownProf: [V2] = [
            p(0.0502, 0.0613), p(0.044, 0.067), p(0.040, 0.074), p(0.0375, 0.080), p(0.0365, 0.084),
            p(0.037, 0.088), p(0.039, 0.093), p(0.041, 0.100), p(0.0455, 0.107), p(0.047, 0.113),
        ]
        var cr = Prim.lathe(crownProf, segments: 80, seamTile: 0.25, material: crown)
        // Crown cap as a polar height field: dome profile cut by the saddle groove (smooth min).
        let capR: [V2] = [V2(0.047, 0.113), V2(0.046, 0.119), V2(0.042, 0.1235), V2(0.033, 0.1265), V2(0.02, 0.127), V2(0, 0.127)]
        func dome(_ r: Float) -> Float {
            for i in 0..<(capR.count - 1) where r <= capR[i].x && r >= capR[i + 1].x {
                let t = (capR[i].x - r) / (capR[i].x - capR[i + 1].x)
                return (capR[i].y + (capR[i + 1].y - capR[i].y) * t) * s
            }
            return capR.last!.y * s
        }
        let gR = grooveRadius, gc = H + gR * 0.05
        func capY(_ r: Float, _ z: Float) -> Float {
            let d = dome(r)
            let az = abs(z)
            let w = gR * 1.45, q = max(0, 1 - (az / w) * (az / w))
            let fl = gc + 0.004 - (gR + 0.004) * q * sqrt(q)
            let k: Float = 0.006, h = max(k - abs(d - fl), 0) / k
            return min(d, fl) - h * h * k * 0.25
        }
        // Square grid mapped onto the disk (concentric mapping): even triangles, round boundary.
        let n = 44
        var cap = Surface(material: crown)
        for i in 0...n {
            for j in 0...n {
                let u = Float(i) / Float(n) * 2 - 1, v = Float(j) / Float(n) * 2 - 1
                var r: Float = 0, a: Float = 0
                if u == 0 && v == 0 { r = 0 } else if abs(u) > abs(v) { r = u; a = .pi / 4 * (v / u) } else { r = v; a = .pi / 2 - .pi / 4 * (u / v) }
                let x = r * cos(a) * 0.047, z = r * sin(a) * 0.047
                _ = cap.add(V3(x, capY(abs(r) * 0.047, z), z), .up, V2(x, z))
            }
        }
        for i in 0..<n {
            for j in 0..<n {
                let a = UInt32(i * (n + 1) + j), b = a + UInt32(n + 1)
                cap.quad(a, a + 1, b + 1, b)
            }
        }
        cap.recomputeNormals()
        cap.computeTangents()
        if cap.normals.reduce(Float(0), { $0 + $1.y }) < 0 { cap = cap.flipped() }
        m.add(cap)
        m.add(cr)
        // Thread insert: black HDPE sleeve in the pin hole with a few thread rings.
        m.add(Prim.lathe([V2(0.0168, 0.012 * s), V2(0.0168, 0.066 * s), V2(0.0, 0.066 * s)], segments: 24, material: "plastic.matte:1A1A1A").flipped())
        for k in 0..<5 {
            m.add(Prim.torus(major: 0.0167, minor: 0.0012, segments: 24, sides: 4, material: "plastic.matte:1A1A1A"),
                  Xform(translation: V3(0, (0.02 + Float(k) * 0.009) * s, 0)))
        }
        if broken {
            // Exposed body on the chip face and loose shards of glaze edge.
            for i in 0..<9 {
                let t = Float(i) / 8, a: Float = 0.38 + t * 0.64, rr = R - sin(t * .pi) * 0.02 - 0.002
                m.add(Prim.superellipsoid(V3(rng.float(0.008...0.014), rng.float(0.01...0.022), rng.float(0.006...0.01)), exponent: 3, subdivisions: 1, material: fracture),
                      Xform(translation: V3(cos(a) * rr, 0.012 * s, sin(a) * rr), rotation: simd_quatf(angle: -a, axis: .up)))
            }
            // Radial crack running up the skirt into the crown.
            var pts: [V3] = []
            for i in 0...8 {
                let t = Float(i) / 8, a: Float = 1.05 + 0.05 * sin(t * 9)
                let y = (0.004 + t * 0.075) * s
                let rr = t < 0.65 ? R - 0.001 - t * 0.04 : 0.047 - (t - 0.65) * 0.02
                pts.append(V3(cos(a) * (rr + 0.0007), y, sin(a) * (rr + 0.0007)))
            }
            m.add(Prim.tube(pts, radii: pts.map { _ in 0.0007 }, sides: 4, seamTile: 0.05, material: "plastic.matte:121212"))
        }
        groundAO(&m, height: 0.03, floor: 0.6)
        return LODModel(m)
    }
}
