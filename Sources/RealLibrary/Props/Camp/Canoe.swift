import simd
import Foundation

/// 16 ft (4.9 m) open canoe, 0.9 m beam, 35 cm deep amidships: lofted molded hull with rocker, sheer rising
/// to the stems and a shallow-arch bottom, inner skin, ash gunwales, center yoke, two seats, end decks.
/// Bow toward +X. 2 LODs.
public struct Canoe: RealAsset {
    public static let id = "canoe"
    public static let summary = "16 ft open canoe, 0.9 m beam: lofted hull with rocker and sheer, inner skin, ash gunwales, yoke, two seats, end decks."
    public static let tags = ["prop", "camp", "vehicle", "plastic", "wood"]
    public static let budget = 10_000
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 30, elevation: 24, distance: 0.8)

    public var length: Float = 4.9
    public var beam: Float = 0.9
    public var depth: Float = 0.35
    /// Hull color (sRGB hex) on the molded plastic.
    public var hullColor: UInt32 = 0xA22A1E
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let hull = "plastic.orange:" + String(format: "%06X", hullColor)
        let wood: MaterialKey = "wood.oak"
        let L = length, B = beam, D = depth
        let skin: Float = 0.007
        func halfBeam(_ t: Float) -> Float { max(0.004, B / 2 * pow(max(0, 1 - pow(abs(t), 2.2)), 0.75)) }
        // Keel line: gentle rocker, then the stems curve up to meet the sheer.
        func keel(_ t: Float) -> Float { 0.05 * t * t + (D + 0.1) * pow(max(0, (abs(t) - 0.78) / 0.22), 2.4) }
        func gunwale(_ t: Float) -> Float { D + 0.2 * pow(abs(t), 4) }
        func sheer(_ t: Float) -> Float { max(0.03, gunwale(t) - keel(t)) }   // section depth
        // Section point: phi in -pi/2...pi/2 from port gunwale through the keel to starboard.
        func point(_ t: Float, _ phi: Float, inset: Float = 0) -> V3 {
            let b = max(0.002, halfBeam(t) - inset)
            let h = sheer(t) - inset * 0.5
            let c = abs(cos(phi))
            let y = keel(t) + inset + (h - inset) * (1 - pow(c, 0.45))
            let tumble = 1 - 0.04 * pow(max(0, (y - keel(t)) / h - 0.7) / 0.3, 2)   // slight tumblehome at the rail
            return V3(t * L / 2, y, b * sin(phi) * tumble)
        }
        func lod(_ nx: Int, _ np: Int, detail: Bool) -> Model {
            var m = Model(name: Self.id)
            var outer: [[V3]] = [], inner: [[V3]] = [], uvs: [[V2]] = []
            for i in 0...nx {
                let u = Float(i) / Float(nx)
                let t = -cos(u * .pi)                                         // denser stations toward the stems
                var ro: [V3] = [], ri: [V3] = [], uv: [V2] = []
                for j in 0...np {
                    let phi = (Float(j) / Float(np) * 2 - 1) * .pi / 2
                    ro.append(point(t, phi)); ri.append(point(t, phi, inset: skin))
                    uv.append(V2(t * L / 2, phi * 0.5))
                }
                outer.append(ro); inner.append(ri); uvs.append(uv)
            }
            func interior(_ p: V3) -> V3 { let t = p.x / (L / 2); return V3(p.x, keel(t) + sheer(t) * 0.8, 0) }
            var o = WoodParts.grid(outer, uvs: uvs, material: hull)
            WoodParts.orientOutward(&o, center: interior)
            o.recomputeNormals(weldSeams: false)
            var n = WoodParts.grid(inner, uvs: uvs, material: hull)
            WoodParts.orientOutward(&n, center: interior)
            for k in stride(from: 0, to: n.indices.count, by: 3) { n.indices.swapAt(k + 1, k + 2) }
            n.recomputeNormals(weldSeams: false)
            n.occlusion = n.positions.map { p in let t = p.x / (L / 2); return 0.6 + 0.4 * smoothstep(keel(t), keel(t) + sheer(t), p.y) }
            o.computeTangents(); n.computeTangents()
            m.add(o); m.add(n)
            // Gunwales: ash rails capping the sheer line, grain along the length.
            for phi in [-Float.pi / 2, Float.pi / 2] {
                var path: [V3] = []
                for i in 0...max(12, nx / 2) {
                    let t = (Float(i) / Float(max(12, nx / 2)) * 2 - 1) * 0.985
                    path.append(point(t, phi, inset: skin / 2) + V3(0, 0.004, 0))
                }
                var g = Prim.tube(path, radii: path.map { p in 0.015 * (0.6 + 0.4 * halfBeam(p.x / (L / 2)) / (B / 2)) }, sides: detail ? 8 : 5,
                                  seamTile: 0.1, material: wood, capEnd: false)
                g.uvs = g.uvs.map { V2($0.y, $0.x) }
                g.computeTangents()
                m.add(g)
            }
            // Yoke, seats and end decks.
            func across(_ x: Float, drop: Float, width: Float, thick: Float) {
                let t = x / (L / 2)
                let y = gunwale(t) - drop
                // Find the hull half-width at that height.
                var z = halfBeam(t)
                for j in 0...60 {
                    let phi = Float(j) / 60 * .pi / 2
                    let p = point(t, phi, inset: skin)
                    if p.y >= y { z = p.z; break }
                }
                let (b, xf) = board(from: V3(x, y, -z + 0.004 + width * 0.12), to: V3(x, y, z - 0.004 - width * 0.12), width: width, thick: thick, bevel: 0.005, material: wood)
                m.add(b, xf.jittered(&rng, deg: 0.3, offset: 0.001))
            }
            across(0, drop: 0.02, width: 0.07, thick: 0.022)                   // yoke
            for (x, w) in [(L * 0.33, 0.24), (-L * 0.36, 0.26)] as [(Float, Float)] {
                across(x, drop: 0.09, width: w, thick: 0.025)                  // seat
            }
            if detail {
                for side: Float in [-1, 1] {
                    let t0: Float = 0.86, t1: Float = 0.985
                    var deck = Surface(material: wood)
                    let steps = 6
                    for k in 0...steps {
                        let t = side * (t0 + (t1 - t0) * Float(k) / Float(steps))
                        let l = point(t, -.pi / 2, inset: skin), r = point(t, .pi / 2, inset: skin)
                        deck.add(l + V3(0, 0.006, 0), .up, V2(l.x, l.z)); deck.add(r + V3(0, 0.006, 0), .up, V2(r.x, r.z))
                    }
                    for k in 0..<UInt32(steps) { deck.quad(k * 2, k * 2 + 1, k * 2 + 3, k * 2 + 2) }
                    WoodParts.orientOutward(&deck) { p in V3(p.x, p.y - 1, p.z) }
                    deck.recomputeNormals(weldSeams: false); deck.computeTangents()
                    m.add(deck)
                }
            }
            // Contact shade under the keel.
            for i in m.surfaces.indices {
                for v in m.surfaces[i].positions.indices {
                    m.surfaces[i].occlusion[v] *= 0.55 + 0.45 * smoothstep(0, 0.12, m.surfaces[i].positions[v].y)
                }
            }
            return m
        }
        return LODModel(levels: [lod(64, 26, detail: true), lod(28, 10, detail: false)], switchDistances: [18])
    }
}
