import simd
import Foundation

/// Ratcheting cable cutter lying flat (Klein 63060 class, 270 mm): a black-oxide head with the fixed
/// hooked jaw and the moving blade whose outer arc carries the ratchet teeth, steel side plates bolted
/// over the pivot with the release pawl, and two steel handles under red cushion grips with finger stops
/// and flared ends. Head toward -X.
public struct CableCutter: RealAsset, RealHandTool {
    public static let id = "cable-cutter"
    public static let summary = "Ratcheting cable cutter lying flat: black hooked jaws with ratchet teeth and red cushion grip handles."
    public static let tags = ["prop", "tool", "handheld", "utility", "metal"]
    public static let budget = 10000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 50, distance: 0.9, studio: true)
    static let hc = V2(-0.085, 0)
    /// Palm on the two grips, mid-length.
    public static let grip = SIMD3<Float>(0.075, 0.011, 0.004)
    /// Centre of the cutting throat.
    public static let tip = SIMD3<Float>(-0.085, 0.011, 0)

    /// Grip colour (sRGB hex).
    public var gripColor: UInt32 = 0xD8261C
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let blade: MaterialKey = "metal.anodized-worn:1C1C1E", plateM: MaterialKey = "metal.steel", edge: MaterialKey = "metal.tool-ground"
        let red: MaterialKey = "vinyl.dipped-red:" + String(format: "%06X", gripColor)
        let yc: Float = 0.011
        let flat = simd_quatf(angle: -.pi / 2, axis: V3(1, 0, 0))   // outline (x, y) -> (x, -z)
        let c = Self.hc
        func arcPts(_ r: Float, _ a0: Float, _ a1: Float, _ n: Int) -> [V2] {
            (0...n).map { i in let a = (a0 + (a1 - a0) * Float(i) / Float(n)) * .pi / 180; return c + V2(cos(a), sin(a)) * r }
        }
        func plate(_ o: [V2], _ t: Float, _ y: Float, _ mat: MaterialKey, round: Float = 0.002) {
            let pts = Shape2D.rounded(o, radius: round)
            m.add(Prim.extrude(pts, depth: t, bevel: 0.0008, bevelSegments: 2, material: mat), Xform(translation: V3(0, y + t / 2, 0), rotation: flat))
        }
        // Moving blade (upper layer): ring sector 15..205 deg with a hooked point, teeth on the outer arc.
        var mv: [V2] = []
        let teeth = 22
        for i in 0...teeth {
            let a = 25 + Float(i) / Float(teeth) * 150
            let r: Float = 0.046 - 0.0005 * Float(i % 2)
            mv.append(c + V2(cos(a * .pi / 180), sin(a * .pi / 180)) * r)
        }
        mv += arcPts(0.044, 178, 206, 4)
        mv.append(c + V2(cos(212 * .pi / 180), sin(212 * .pi / 180)) * 0.03)      // hooked point
        mv += arcPts(0.021, 200, 20, 10)
        mv.append(V2(-0.04, 0.012)); mv.append(V2(-0.03, 0.018))
        plate(mv, 0.0065, yc + 0.0005, blade)
        // Ground cutting edge on the inner arc.
        m.add(Prim.tube(arcPts(0.0215, 30, 195, 14).map { V3($0.x, yc + 0.006, -$0.y) }, radii: Array(repeating: 0.0011, count: 15), sides: 6, seamTile: 0.02, material: edge))
        // Fixed jaw (lower layer): hook around the bottom, running back into the fixed handle root.
        var fx: [V2] = arcPts(0.045, 215, 345, 12)
        fx += [V2(-0.03, -0.016), V2(0.0, -0.014), V2(0.0, -0.004), V2(-0.035, -0.004)]
        fx += arcPts(0.021, 330, 222, 8)
        plate(fx, 0.0065, yc - 0.0065, blade)
        // Side plates over the pivot, bolted, with the release pawl.
        let side: [V2] = [V2(-0.058, -0.016), V2(-0.02, -0.018), V2(-0.004, -0.01), V2(-0.004, 0.012), V2(-0.02, 0.02), V2(-0.055, 0.02)]
        plate(side.map { V2($0.x * 1.15 - 0.002, $0.y * 1.35) }, 0.0025, yc + 0.007, blade, round: 0.006)
        plate(side.map { V2($0.x * 1.15 - 0.002, $0.y * 1.35) }, 0.0025, yc - 0.0095, blade, round: 0.006)
        hexBolt(&m, at: V3(-0.045, yc + 0.0095, 0.0), normal: V3(0, 1, 0), size: 0.011, material: plateM)
        hexBolt(&m, at: V3(-0.018, yc + 0.0095, -0.004), normal: V3(0, 1, 0), size: 0.008, material: plateM)
        plate([V2(-0.01, 0.014), V2(0.018, 0.02), V2(0.02, 0.026), V2(-0.008, 0.022)], 0.003, yc + 0.0095, blade, round: 0.0015)
        // Handles: steel cores under red cushion grips, finger stops and flared ends.
        for (s, z1): (Float, Float) in [(1, 0.040), (-1, -0.012)] {
            let a = V3(-0.004, yc, -s * 0.009), b = V3(0.15, yc, -z1)
            let dir = simd_normalize(b - a)
            m.add(Prim.tube([a - dir * 0.012, a + dir * 0.02], radii: [0.0055, 0.0055], sides: 10, seamTile: 0.03, material: plateM))
            let g0 = a + dir * 0.014
            let L = simd_length(b - g0)
            var path: [V3] = [], radii: [Float] = []
            for i in 0...16 {
                let u = Float(i) / 16
                path.append(g0 + dir * (L * u))
                radii.append(0.0112 - 0.0034 * u + 0.0003 * sin(u * 40))
            }
            m.add(Prim.tube(path, radii: radii, sides: 16, seamTile: 0.05, material: red))
            m.add(Prim.superellipsoid(V3(0.016, 0.016, 0.016), exponent: 2.2, subdivisions: 6, material: red),
                  Xform(translation: b, scale: V3(0.5, 1, 1)))
            // Finger stop: flat moulded tab standing out from the grip toward the outside.
            let out = V3(0, 0, -s)
            var tab = Prim.roundedBox(V3(0.005, 0.02, 0.03), radius: 0.0022, bevelSegments: 2, material: red)
            tab.deform { $0 }
            m.add(tab, Xform(translation: g0 + dir * 0.012 + out * 0.012 + V3(0, 0, 0), rotation: simd_quatf(from: V3(1, 0, 0), to: dir)))
            _ = rng.float()
        }
        groundAO(&m, height: 0.03)
        return LODModel(m)
    }
}
