import simd
import Foundation

/// Curved footpath strip, 12 m long and 1.1 m wide, laid along +X. Packed-earth crown with two worn ruts;
/// edges and ends dip below y = 0 along a ragged line, so the path melts into the ground it sits on.
public struct DirtPath: RealAsset {
    public static let id = "dirt-path"
    public static let summary = "Curved 12 m dirt footpath strip: worn ruts, raised crown, ragged edges that sink below the surrounding ground."
    public static let tags = ["nature", "ground", "park", "outdoor"]
    public static let budget = 4_000
    public static let preview = PreviewHint(azimuth: 20, elevation: 24, distance: 0.75)

    /// Length along X in meters.
    public var length: Float = 12
    /// Visible width in meters.
    public var width: Float = 1.1
    /// Sideways meander amplitude in meters.
    public var meander: Float = 1.2
    /// Depth of the two wheel/foot ruts in meters.
    public var rutDepth: Float = 0.016
    /// Crown height above y = 0 in meters.
    public var crown: Float = 0.01
    public var material: MaterialKey = "ground.dirt"
    /// Samples per meter along the path.
    public var density: Float = 8
    public var acrossSegments = 16
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let ns = UInt32(truncatingIfNeeded: rng.next())
        let ph1 = rng.float(0...6.28), ph2 = rng.float(0...6.28)
        let k1 = rng.float(0.35...0.55), k2 = rng.float(0.9...1.3)
        func center(_ x: Float) -> Float { meander * (sin(x * k1 + ph1) * 0.8 + sin(x * k2 + ph2) * 0.2) }
        let n = max(8, Int(length * density)), m = max(6, acrossSegments)
        let half = width / 2 * 1.35
        var s = Surface(material: material)
        var arc: Float = 0, prev = V2(-length / 2, center(-length / 2))
        for i in 0...n {
            let x = -length / 2 + length * Float(i) / Float(n)
            let c = V2(x, center(x))
            arc += simd_distance(c, prev); prev = c
            let d = simd_normalize(V2(1, (center(x + 0.01) - center(x - 0.01)) / 0.02))
            let side = V2(-d.y, d.x)
            let along = abs(Float(i) / Float(n) * 2 - 1)
            let endSink = smoothstep(0.9, 1, along) * 0.06
            for j in 0...m {
                let t = Float(j) / Float(m) * 2 - 1, at = abs(t)
                let edgeT = 0.74 + 0.1 * Noise.fbm(V3(arc * 0.9, t > 0 ? 3 : 7, 0), octaves: 3, seed: ns)
                let rut = exp(-pow((at - 0.42) / 0.11, 2)) * rutDepth
                let bump = Noise.fbm(V3(arc * 2.2, t * 1.5, 0), octaves: 3, seed: ns &+ 2) * 0.006
                var y = crown * (1 - 0.5 * t * t) - rut + bump
                y -= smoothstep(edgeT - 0.3, 1, at) * (crown + 0.04)
                y -= endSink
                let p = c + side * (t * half)
                let k = s.add(V3(p.x, y, p.y), .up, V2(arc, t * half))
                s.occlusion[Int(k)] = 1 - rut / max(rutDepth, 1e-4) * 0.15 - smoothstep(edgeT - 0.2, edgeT, at) * 0.1
            }
        }
        let row = UInt32(m + 1)
        for i in 0..<UInt32(n) { for j in 0..<UInt32(m) {
            let a = i * row + j
            s.quad(a, a + 1, a + row + 1, a + row)
        }}
        let b = s.bounds, mid = (b.min.z + b.max.z) / 2
        s.positions = s.positions.map { V3($0.x, $0.y, $0.z - mid) }
        s.recomputeNormals(weldSeams: false)
        s.computeTangents()
        return LODModel(Model(name: Self.id, surfaces: [s]))
    }
}
