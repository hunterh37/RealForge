import simd
import Foundation

/// Desk pile of A4 paper (297 x 210 mm): a squared-up stack of copier paper in loose bundles that fan by a
/// millimeter or two, a clipped document set on top held by a 32 mm black binder clip with steel wire
/// handles, and two loose sheets with a soft curl lying askew.
public struct PaperStack: RealAsset {
    public static let id = "paper-stack"
    public static let summary = "Pile of A4 paper: fanned copier-paper bundles with page edges, a binder-clipped document set and two curled loose sheets."
    public static let tags = ["prop", "office", "paper"]
    public static let budget = 2_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 30, distance: 0.62, studio: true)

    /// Sheet size (m): A4 portrait laid along X.
    public var sheet = V2(0.297, 0.21)
    /// Number of bundles in the main stack and their thickness range (m; 100 sheets = 10 mm).
    public var bundles = 5
    public var bundleThickness: ClosedRange<Float> = 0.0035...0.0065
    public var clip = true
    public init() {}

    /// Page block side faces (`paper.pages`, lines along U) plus a top sheet (`paper.sheet`).
    private func slab(_ m: inout Model, w: Float, d: Float, t: Float, _ x: Xform, top: Bool = true) {
        var sides = Surface(material: "paper.pages")
        let hw = w / 2, hd = d / 2
        let corners = [V3(-hw, 0, hd), V3(hw, 0, hd), V3(hw, 0, -hd), V3(-hw, 0, -hd)]
        for k in 0..<4 {
            let a = corners[k], b = corners[(k + 1) % 4]
            let n = simd_normalize(simd_cross(b - a, V3(0, 1, 0)))
            let len = simd_distance(a, b)
            let i0 = sides.add(a, n, V2(0, 0)), i1 = sides.add(b, n, V2(len, 0))
            let i2 = sides.add(b + V3(0, t, 0), n, V2(len, t)), i3 = sides.add(a + V3(0, t, 0), n, V2(0, t))
            sides.quad(i0, i1, i2, i3)
        }
        sides.computeTangents()
        m.add(sides, x)
        if top { m.add(sheetCard(w: w, d: d, curl: 0), x.then(Xform(translation: V3(0, t, 0)))) }
    }

    /// Single sheet as a gridded card at y = 0, lifting toward the +X/+Z corner by `curl` meters.
    private func sheetCard(w: Float, d: Float, curl: Float, segments: Int = 1) -> Surface {
        var s = Prim.terrain(size: V2(w, d), segments: segments, material: "paper.sheet") { p in
            guard curl > 0 else { return 0 }
            let u = max(0, (p.x / w + 0.5 - 0.55) / 0.45), v = max(0, (p.y / d + 0.5 - 0.4) / 0.6)
            return curl * pow(u, 2.2) * (0.35 + 0.65 * v)
        }
        s.computeTangents()
        return s
    }

    public func build(seed: UInt64) -> LODModel {
        var levels: [Model] = []
        for l in 0..<2 {
            var rng = SeededRNG(seed: seed)
            var m = Model(name: Self.id)
            let W = sheet.x, D = sheet.y
            var y: Float = 0
            // Main stack: bundles nudged a little out of square.
            for _ in 0..<bundles {
                let t = rng.float(bundleThickness)
                let x = Xform(translation: V3(rng.float(-0.0018...0.0018), y, rng.float(-0.0018...0.0018)),
                              rotation: simd_quatf(degrees: rng.float(-0.7...0.7), axis: .up))
                slab(&m, w: W, d: D, t: t, x)
                y += t + 0.00005
            }
            // A loose sheet slid under the clipped set.
            m.add(sheetCard(w: W, d: D, curl: 0), Xform(translation: V3(-0.008, y + 0.0001, 0.006), rotation: simd_quatf(degrees: -6 + rng.float(-1.5...1.5), axis: .up)))
            y += 0.0002
            // Clipped document set, turned a few degrees.
            let docT: Float = 0.0032, yaw = rng.float(2.5...4.5)
            let docX = Xform(translation: V3(0.004, y, 0.003), rotation: simd_quatf(degrees: yaw, axis: .up))
            slab(&m, w: W, d: D, t: docT, docX)
            y += docT
            if clip && l == 0 {
                // 32 mm binder clip on the far edge: folded black spring-steel body, two wire handles. Clip frame:
                // x along the clip width, y up through the jaws (centered on the set), z toward the paper.
                let jaw = docT / 2 + 0.0006, back: Float = 0.0095
                let base = Xform(translation: V3(-0.06, docT / 2, -D / 2 + 0.0045)).then(docX)
                // Outline in (z, y); extrude depth along x.
                let outline = Shape2D.rounded([V2(0, jaw), V2(-back - 0.0005, jaw + 0.0085), V2(-back - 0.0005, -jaw - 0.0085), V2(0, -jaw)],
                                              radius: 0.0016, segments: 2)
                let body = Prim.extrude(outline.map { V2(-$0.x, $0.y) }, depth: 0.032, bevel: 0.0008, bevelSegments: 1, material: "metal.powdercoat:1A1A1C")
                // extrude: outline x -> rotate so local x maps to -z and depth z maps to +x.
                m.add(body, Xform(rotation: simd_quatf(degrees: 90, axis: .up)).then(base))
                let wire: Float = 0.0009
                let up = catmull([V3(-0.012, jaw + 0.007, -back), V3(-0.013, jaw + 0.012, -back - 0.003), V3(-0.012, 0.026, -back - 0.005),
                                  V3(0, 0.029, -back - 0.005), V3(0.012, 0.026, -back - 0.005), V3(0.013, jaw + 0.012, -back - 0.003), V3(0.012, jaw + 0.007, -back)], per: 3)
                let down = catmull([V3(-0.012, -jaw - 0.007, -back), V3(-0.013, -jaw - 0.012, -back - 0.003), V3(-0.012, -0.022, -back - 0.004),
                                    V3(0, -0.025, -back - 0.004), V3(0.012, -0.022, -back - 0.004), V3(0.013, -jaw - 0.012, -back - 0.003), V3(0.012, -jaw - 0.007, -back)], per: 3)
                for path in [up, down] {
                    m.add(Prim.tube(path, radii: path.map { _ in wire }, sides: 5, seamTile: 0.01, material: "metal.chrome", capEnd: false), base)
                }
            }
            // A loose sheet on top, pulled toward the viewer, with a soft curl.
            m.add(sheetCard(w: W, d: D, curl: 0.009, segments: l == 0 ? 8 : 2),
                  Xform(translation: V3(-0.01, y + 0.0002, 0.03), rotation: simd_quatf(degrees: 6 + rng.float(-1.5...1.5), axis: .up)))
            groundAO(&m, height: 0.02, floor: 0.65)
            levels.append(m)
        }
        return LODModel(levels: levels, switchDistances: [3])
    }
}
