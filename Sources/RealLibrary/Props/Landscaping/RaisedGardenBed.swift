import simd
import Foundation

/// Cedar raised garden bed, 2.4 x 1.2 m, 0.29 m tall: two courses of 2x6 boards screwed to 4x4 corner
/// posts and a mid-span stake on the long sides, filled with dark garden soil mounded slightly, a
/// 2x6 cap rail around the top, a row of lettuce seedlings. Boards weather lighter on the top edges.
public struct RaisedGardenBed: RealAsset {
    public static let id = "raised-garden-bed"
    public static let summary = "Cedar raised garden bed, 2.4 x 1.2 m x 0.29 m: two courses of 2x6 boards on 4x4 corner posts, top cap rail, mounded garden soil."
    public static let tags = ["prop", "garden", "outdoor", "landscaping", "wood", "container"]
    public static let budget = 13_500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 26, distance: 1.0, studio: true)

    /// Outside length along X (m).
    public var length: Float = 2.4
    /// Outside width along Z (m).
    public var width: Float = 1.2
    /// Board courses (each 14 cm).
    public var courses: Int = 2
    /// Lumber material.
    public var wood: MaterialKey = "wood.cedar"
    /// Soil material.
    public var soil: MaterialKey = "soil.potting"
    /// Number of seedlings planted down the middle.
    public var seedlings: Int = 6
    /// Seedling leaf material.
    public var leaves: MaterialKey = "food.stem-green:4E8A2E"
    /// Screw material.
    public var screws: MaterialKey = "metal.galvanized"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id), lite = Model(name: Self.id + "-lite")
        let bt: Float = 0.038, bw: Float = 0.14, gap: Float = 0.003
        let n = max(1, courses)
        let wallH = Float(n) * (bw + gap)
        let hx = length / 2, hz = width / 2
        // Board walls: long sides run full length, short sides fit between.
        for c in 0..<n {
            let y = Float(c) * (bw + gap) + bw / 2
            for sz: Float in [-1, 1] {
                var r = rng.fork(c * 10 + Int(sz + 1))
                let s = plank(length, bw, bt, bevel: 0.004, material: wood)
                let xf = Xform(translation: V3(0, y, sz * (hz - bt / 2)), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))).jittered(&r, deg: 0.2, offset: 0.001)
                m.add(s, xf); lite.add(s, xf)
            }
            for sx: Float in [-1, 1] {
                var r = rng.fork(c * 10 + Int(sx + 5))
                let s = plank(width - 2 * bt - 0.002, bw, bt, bevel: 0.004, material: wood)
                let xf = Xform(translation: V3(sx * (hx - bt / 2), y, 0), rotation: simd_quatf(degrees: 90, axis: .up) * simd_quatf(degrees: 90, axis: V3(1, 0, 0))).jittered(&r, deg: 0.2, offset: 0.001)
                m.add(s, xf); lite.add(s, xf)
            }
        }
        // Inside corner posts and mid stakes.
        let post: Float = 0.089
        var stakes: [V3] = []
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] { stakes.append(V3(sx * (hx - bt - post / 2 - 0.001), 0, sz * (hz - bt - post / 2 - 0.001))) } }
        for sz: Float in [-1, 1] { stakes.append(V3(0, 0, sz * (hz - bt - 0.02))) }
        for (i, p) in stakes.enumerated() {
            let mid = i >= 4
            let s = Prim.roundedBox(mid ? V3(post, wallH - 0.01, 0.038) : V3(post, wallH - 0.01, post), radius: 0.003, bevelSegments: 1, material: wood)
            m.add(s, Xform(translation: p + V3(0, (wallH - 0.01) / 2, 0)))
        }
        // Screws on the outside faces into the posts.
        for (i, p) in stakes.enumerated() where i < 4 {
            for c in 0..<n { for dy: Float in [0.04, 0.1] {
                let y = Float(c) * (bw + gap) + dy
                let sxn = p.x > 0 ? Float(1) : -1, szn = p.z > 0 ? Float(1) : -1
                rivet(&m, at: V3(p.x, y, szn * hz), normal: V3(0, 0, szn), radius: 0.0045, material: screws)
                rivet(&m, at: V3(sxn * hx, y, p.z), normal: V3(sxn, 0, 0), radius: 0.0045, material: screws)
            }}
        }
        // Cap rail: mitred-look boards lying flat, overhanging 2 cm outside.
        let capW: Float = 0.14, capY = wallH + bt / 2 + 0.001
        for sz: Float in [-1, 1] {
            var r = rng.fork(200 + Int(sz + 1))
            let s = plank(length + 0.04, capW, bt, bevel: 0.005, material: wood)
            let xf = Xform(translation: V3(0, capY, sz * (hz - capW / 2 + 0.02))).jittered(&r, deg: 0.15, offset: 0.001)
            m.add(s, xf); lite.add(s, xf)
        }
        for sx: Float in [-1, 1] {
            var r = rng.fork(210 + Int(sx + 1))
            let s = plank(width - 2 * capW + 0.04 - 0.004, capW, bt, bevel: 0.005, material: wood)
            let xf = Xform(translation: V3(sx * (hx - capW / 2 + 0.02), capY, 0), rotation: simd_quatf(degrees: 90, axis: .up)).jittered(&r, deg: 0.15, offset: 0.001)
            m.add(s, xf); lite.add(s, xf)
        }
        // Soil: mounded fill 4 cm below the cap.
        let sd = UInt32(truncatingIfNeeded: rng.int(0...100_000))
        let ix = hx - bt - 0.002, iz = hz - bt - 0.002
        var soilS = Prim.terrain(size: V2(ix * 2, iz * 2), segments: 36, material: soil) { xz in
            let e = max(abs(xz.x) / ix, abs(xz.y) / iz)
            return wallH - 0.05 + 0.03 * (1 - e * e) + 0.008 * Noise.fbm(V3(xz.x * 10, 0, xz.y * 10), octaves: 4, seed: sd)
        }
        soilS.recomputeNormals(weldSeams: false)
        m.add(soilS)
        lite.add(Prim.terrain(size: V2(ix * 2, iz * 2), segments: 6, material: soil) { _ in wallH - 0.04 })
        // A row of young lettuce seedlings down the middle: rosettes of cupped leaves.
        for k in 0..<seedlings {
            var r = rng.fork(400 + k)
            let x = -ix + 0.2 + (2 * ix - 0.4) * (Float(k) + 0.5) / Float(max(1, seedlings))
            let z = r.float(-0.06...0.06)
            let e = max(abs(x) / ix, abs(z) / iz)
            let y = wallH - 0.05 + 0.03 * (1 - e * e) - 0.004
            let n = r.int(5...7)
            for j in 0..<n {
                let a = Float(j) / Float(n) * 2 * .pi + r.float(-0.3...0.3)
                let len = r.float(0.05...0.08)
                let leaf = Prim.superellipsoid(V3(len, 0.006, len * 0.6), exponent: 2.2, subdivisions: 2, material: leaves) { d in 1 + 0.25 * d.y * d.y }
                m.add(leaf, Xform(translation: V3(x + cos(a) * len * 0.45, y + 0.02, z + sin(a) * len * 0.45),
                                  rotation: simd_quatf(degrees: -a * 180 / .pi, axis: .up) * simd_quatf(degrees: r.float(18...35), axis: V3(0, 0, 1))))
            }
        }
        let bb = m.bounds
        let shift = V3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2)
        m = m.transformed(Xform(translation: shift)); lite = lite.transformed(Xform(translation: shift))
        groundAO(&m, height: 0.15, floor: 0.55); groundAO(&lite, height: 0.15, floor: 0.55)
        return LODModel(levels: [m, lite], switchDistances: [12])
    }
}
