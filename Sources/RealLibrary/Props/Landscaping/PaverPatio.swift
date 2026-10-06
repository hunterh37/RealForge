import simd
import Foundation

/// Herringbone paver patio tile, 1 x 1 m by default: 10 x 20 x 6 cm clay-tone concrete pavers laid
/// in a 90-degree herringbone, cut at a sailor-course border, on a sand bed with swept joint sand.
/// Pavers vary in tone, height and tilt by a millimeter or two; LOD1 is one textured slab.
public struct PaverPatio: RealAsset {
    public static let id = "paver-patio"
    public static let summary = "Herringbone paver patio tile, 1 x 1 m: 10 x 20 cm concrete pavers in a 90-degree herringbone, sailor-course border, sand joints."
    public static let tags = ["prop", "garden", "outdoor", "landscaping", "stone", "concrete"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 38, distance: 1.0, studio: true)

    /// Patio width along X (m).
    public var w: Float = 1.0
    /// Patio depth along Z (m).
    public var d: Float = 1.0
    /// Paver width (m); length is twice this.
    public var paverWidth: Float = 0.1
    /// Paver thickness (m).
    public var thickness: Float = 0.06
    /// Joint gap between pavers (m).
    public var joint: Float = 0.005
    /// Paver material; three tones are made from it with tints.
    public var paver: MaterialKey = "paver.clay"
    /// Paver tones (sRGB hex) mixed across the field.
    public var tones: [UInt32] = [0x9A5A42, 0x84503C, 0xA86A4C]
    /// Stained paver variant mixed in at ~12%.
    public var stained: MaterialKey = "paver.clay-stained"
    /// Moss tufts growing in the border joints.
    public var mossTufts: Int = 22
    /// Joint sand / bedding material.
    public var sand: MaterialKey = "ground.sand"
    /// LOD1 slab material (herringbone texture).
    public var slab: MaterialKey = "paver.herringbone"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let u = paverWidth, g = joint, t = thickness
        let keys = tones.map { "\(paver):\(String(format: "%06X", $0))" }
        func add(_ x0: Float, _ z0: Float, _ x1: Float, _ z1: Float) {
            let sx = x1 - x0 - g, sz = z1 - z0 - g
            guard sx > 0.012, sz > 0.012 else { return }
            let k = rng.chance(0.12) ? stained : keys[rng.int(0...(keys.count - 1))]
            let h = t + rng.float(-0.0025...0.0025) - (rng.chance(0.06) ? 0.004 : 0)
            // Chamfered paver: rounded-rect plan, 5 mm chamfer on the top edges.
            var box = Prim.extrude(Shape2D.roundedRect(sx, sz, radius: 0.004, segments: 2), depth: h, bevel: 0.005, bevelSegments: 1, material: k)
            box = box.transformed(Xform(rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
            var x = Xform(translation: V3((x0 + x1) / 2, h / 2, (z0 + z1) / 2))
            x.rotation = simd_quatf(degrees: rng.float(-0.4...0.4), axis: rng.unitVector())
            m.add(box, x)
        }
        let hx = w / 2, hz = d / 2
        // Sailor-course border: pavers laid lengthwise along each edge.
        func run(_ a: Float, _ b: Float, along: (Float, Float) -> Void) {
            var p = a
            while p < b - 0.01 { let q = min(b, p + 2 * u); along(p, q); p = q }
        }
        run(-hx, hx) { add($0, -hz, $1, -hz + u) }
        run(-hx, hx) { add($0, hz - u, $1, hz) }
        run(-hz + u, hz - u) { add(-hx, $0, -hx + u, $1) }
        run(-hz + u, hz - u) { add(hx - u, $0, hx, $1) }
        // Herringbone field clipped to the inner rectangle.
        let ix0 = -hx + u, ix1 = hx - u, iz0 = -hz + u, iz1 = hz - u
        let off = V2(rng.float(0...4), rng.float(0...4)).rounded(.down)
        let ni = Int(ceil((ix1 - ix0) / u)) + 8, nj = Int(ceil((iz1 - iz0) / u)) + 8
        for s in -nj...ni { for tt in -nj...nj {
            for vert in [false, true] {
                // Horizontal brick H(s,t): x in [t+4s, t+4s+2), y in [t, t+1); vertical V: x = t+4s+4, y in [t+1, t+3).
                let bx = Float(tt + 4 * s) + (vert ? 4 : 0) + off.x, by = Float(tt) + (vert ? 1 : 0) + off.y
                let sx: Float = vert ? 1 : 2, sy: Float = vert ? 2 : 1
                let x0 = ix0 + bx * u, z0 = iz0 + by * u
                let cx0 = max(x0, ix0), cx1 = min(x0 + sx * u, ix1), cz0 = max(z0, iz0), cz1 = min(z0 + sy * u, iz1)
                if cx1 > cx0 && cz1 > cz0 { add(cx0, cz0, cx1, cz1) }
            }
        }}
        // Moss tufts in the shaded joints between the border and the field.
        for k in 0..<mossTufts {
            var r = rng.fork(500 + k)
            let side = r.int(0...3)
            let along = r.float(-0.45...0.45)
            let p: V2 = side == 0 ? V2(along * w, -hz + u) : side == 1 ? V2(along * w, hz - u) : side == 2 ? V2(-hx + u, along * d) : V2(hx - u, along * d)
            let len = r.float(0.02...0.07)
            let sz = side < 2 ? V3(len, 0.008, 0.012) : V3(0.012, 0.008, len)
            m.add(Prim.superellipsoid(sz, exponent: 2.4, subdivisions: 2, material: "moss.cushion"), Xform(translation: V3(p.x, t - 0.002, p.y)))
        }
        // Sand bed showing in the joints, a few mm below the paver tops.
        let bed = Prim.roundedBox(V3(w - 0.004, t - 0.012, d - 0.004), radius: 0.002, bevelSegments: 1, material: sand)
        m.add(bed, Xform(translation: V3(0, (t - 0.012) / 2, 0)))
        groundAO(&m, height: 0.05, floor: 0.7)
        var lite = Model(name: Self.id + "-lite")
        lite.add(Prim.roundedBox(V3(w, t, d), radius: 0.004, bevelSegments: 1, material: slab), Xform(translation: V3(0, t / 2, 0)))
        return LODModel(levels: [m, lite], switchDistances: [10])
    }
}
