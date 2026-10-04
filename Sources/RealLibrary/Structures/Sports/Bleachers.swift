import simd
import Foundation

/// Aluminum grandstand bleacher section, 7.3 m (24 ft), 8 rows: anodized seat planks with end caps,
/// foot planks between rows, galvanized angle-steel frames every 1.8 m, chain-link back guard on pipe
/// rails. Rows rise 0.2 m and step back 0.6 m. Seating faces +Z; origin at the base center of the front
/// edge; tiles along X every `length` (`endRails` puts the side guard rails on both ends).
public struct Bleachers: RealAsset {
    public static let id = "bleachers"
    public static let summary = "Aluminum bleacher section, 7.3 m, 8 rows: seat and foot planks, galvanized frames, chain-link back guard; tiles along X."
    public static let tags = ["structure", "sports", "furniture", "metal", "outdoor"]
    public static let budget = 20_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 14, distance: 1.0)

    public var length: Float = 7.3
    public var rows: Int = 8
    public var rowRise: Float = 0.2
    public var rowDepth: Float = 0.6
    /// Side guard rails at both ends (set false on inner sections of a long run).
    public var endRails = true
    public var seat: MaterialKey = "metal.aluminum-brushed"
    public var frame: MaterialKey = "metal.galvanized"
    public var mesh: MaterialKey = "fence.chainlink"
    public init() {}

    /// Mesh in design coordinates (origin as documented above, before centering).
    func model(seed: UInt64) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length / 2
        let seatH: Float = 0.43
        func z(_ r: Int) -> Float { -Float(r) * rowDepth - 0.15 }
        func y(_ r: Int) -> Float { Float(r) * rowRise }
        let topY = y(rows - 1) + seatH, backZ = z(rows - 1) - 0.35
        // Planks: seat 10 in wide, foot planks two 5 in boards between rows.
        for r in 0..<rows {
            var s = Prim.roundedBox(V3(length - 0.01, 0.045, 0.25), radius: 0.01, bevelSegments: 1, material: seat)
            s.uvs = s.uvs.map { $0 + V2(rng.float(0...2), 0) }
            m.add(s, Xform(translation: V3(0, y(r) + seatH, z(r))))
            for (k, dz) in [Float(0.2), 0.34].enumerated() {
                var f = Prim.roundedBox(V3(length - 0.01, 0.03, 0.125), radius: 0.008, bevelSegments: 1, material: seat)
                f.uvs = f.uvs.map { $0 + V2(Float(k) * 0.9 + rng.float(0...2), 0) }
                m.add(f, Xform(translation: V3(0, y(r) + 0.02, z(r) + dz)))
            }
            // Vinyl end caps on the seat plank.
            for sx: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(0.01, 0.05, 0.255), radius: 0.003, bevelSegments: 1, material: "plastic.black"),
                      Xform(translation: V3(sx * (L - 0.003), y(r) + seatH, z(r))))
            }
        }
        // Frames: a sloped stringer, vertical legs per row, a ground runner and diagonal braces.
        let nFrames = max(2, Int((length / 1.8).rounded()) + 1)
        let ar: Float = 0.022
        for i in 0..<nFrames {
            let fx = -L + 0.2 + (length - 0.4) * Float(i) / Float(nFrames - 1)
            let s0 = V3(fx, 0.25, 0.1), s1 = V3(fx, topY - 0.05, z(rows - 1) - 0.12)
            m.add(Prim.roundedBox(V3(0.05, 0.05, simd_distance(s0, s1)), radius: 0.004, bevelSegments: 1, material: frame),
                  Xform(translation: (s0 + s1) / 2, rotation: simd_quatf(from: V3(0, 0, -1), to: simd_normalize(s1 - s0))))
            for r in stride(from: 0, to: rows, by: 2) {
                let h = y(r) + seatH - 0.03
                m.add(Prim.roundedBox(V3(0.05, h, 0.05), radius: 0.004, bevelSegments: 1, material: frame),
                      Xform(translation: V3(fx, h / 2, z(r) - 0.05)))
            }
            let backLeg = topY - 0.03
            m.add(Prim.roundedBox(V3(0.05, backLeg, 0.05), radius: 0.004, bevelSegments: 1, material: frame), Xform(translation: V3(fx, backLeg / 2, z(rows - 1) - 0.05)))
            m.add(Prim.roundedBox(V3(0.05, 0.05, -z(rows - 1) + 0.2), radius: 0.004, bevelSegments: 1, material: frame),
                  Xform(translation: V3(fx, 0.03, z(rows - 1) / 2)))
            // Seat and foot plank supports per row.
            for r in 0..<rows {
                m.add(Prim.roundedBox(V3(0.04, 0.04, 0.55), radius: 0.003, bevelSegments: 1, material: frame), Xform(translation: V3(fx, y(r) - 0.005, z(r) + 0.2)))
                m.add(Prim.roundedBox(V3(0.04, 0.04, 0.26), radius: 0.003, bevelSegments: 1, material: frame), Xform(translation: V3(fx, y(r) + seatH - 0.04, z(r))))
            }
            // Foot pads.
            for zz in [Float(0.0), z(rows - 1) - 0.05] {
                m.add(Prim.roundedBox(V3(0.16, 0.012, 0.16), radius: 0.003, bevelSegments: 1, material: frame), Xform(translation: V3(fx, 0.006, zz)))
            }
        }
        // X-bracing between frames under the stand.
        for i in 0..<(nFrames - 1) {
            let xa = -L + 0.2 + (length - 0.4) * Float(i) / Float(nFrames - 1)
            let xb = -L + 0.2 + (length - 0.4) * Float(i + 1) / Float(nFrames - 1)
            let zb = z(rows - 1) - 0.05
            m.add(BallKit.pipe(V3(xa, 0.1, zb), V3(xb, topY - 0.2, zb), radius: 0.012, sides: 6, material: frame))
            m.add(BallKit.pipe(V3(xb, 0.1, zb), V3(xa, topY - 0.2, zb), radius: 0.012, sides: 6, material: frame))
        }
        // Back guard: posts, rails and chain link 1.05 m above the top foot plank.
        let gy0 = y(rows - 1) + 0.04, gy1 = gy0 + 1.05 + seatH
        for i in 0..<nFrames {
            let fx = -L + 0.2 + (length - 0.4) * Float(i) / Float(nFrames - 1)
            m.add(BallKit.pipe(V3(fx, gy0 - 0.3, backZ), V3(fx, gy1, backZ), radius: ar, material: frame))
        }
        for gy in [gy0 + 0.05, gy1] {
            m.add(BallKit.pipe(V3(-L, gy, backZ), V3(L, gy, backZ), radius: ar, material: frame))
        }
        m.add(BallKit.fence(V3(-L, gy0 + 0.05, backZ + 0.03), V3(L, gy0 + 0.05, backZ + 0.03), height: gy1 - gy0 - 0.05, material: mesh))
        // End rails following the slope.
        if endRails {
            for sx: Float in [-1, 1] {
                let ex = sx * (L + 0.04)
                let p0 = V3(ex, seatH + 0.9, z(0) + 0.1), p1 = V3(ex, gy1, backZ)
                m.add(BallKit.pipe(p0, p1, radius: ar, material: frame))
                m.add(BallKit.pipe(p0 - V3(0, 0.45, 0), p1 - V3(0, 0.45, 0), radius: ar * 0.8, material: frame))
                for r in stride(from: 0, to: rows, by: 3) {
                    let t = Float(r) / Float(max(1, rows - 1))
                    let top = p0 + (p1 - p0) * t
                    m.add(BallKit.pipe(V3(ex, y(r) + 0.02, top.z), top, radius: ar, material: frame))
                }
            }
        }
        m = m.transformed(Xform(translation: V3(0, -m.bounds.min.y, 0)))
        groundAO(&m, height: 0.4, floor: 0.6)
        return m
    }

    /// The mesh is re-centered on X/Z; `anchor` is where the design origin landed in mesh coordinates.
    /// Place the asset at `designPoint - anchor` (rotated with it) to put the design origin on `designPoint`.
    public func anchor(seed: UInt64 = 1) -> V2 { -BallKit.centerXZ(model(seed: seed)) }

    public func build(seed: UInt64) -> LODModel {
        let m = model(seed: seed), c = BallKit.centerXZ(m)
        return LODModel(m.transformed(Xform(translation: V3(-c.x, 0, -c.y))))
    }
}
