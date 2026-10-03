import simd
import Foundation

/// Barn wall section, 4.0 m wide x 3.0 m tall: vertical 1 x 10 boards (0.24 m) with battens over the joints,
/// painted barn red, white trim around a 1.2 x 2.2 m door opening with a sliding-door track, girts on the back.
/// Origin at the base center; tile along X every `width`.
public struct BarnWall: RealAsset {
    public static let id = "barn-wall"
    public static let summary = "Board-and-batten barn wall, 4 m: red painted boards, battens, white door trim, track, back girts."
    public static let tags = ["structure", "farm", "wall", "wood"]
    public static let budget = 9_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 20, elevation: 8)

    public var width: Float = 4.0
    public var height: Float = 3.0
    public var door = true
    public var doorWidth: Float = 1.2
    public var doorHeight: Float = 2.2
    public var paint: MaterialKey = "wood.barn-red"
    public var trim: MaterialKey = "wood.barn-white"
    public init() {}

    /// Vertical board from y0 to y1 at x, grain along its length.
    func upright(_ x: Float, _ y0: Float, _ y1: Float, w: Float, t: Float, z: Float, mat: MaterialKey) -> (Surface, Xform) {
        var s = Prim.roundedBox(V3(y1 - y0, t, w), radius: 0.004, bevelSegments: 1, material: mat)
        // Each board shows its own stretch of the texture.
        let h = UInt32(bitPattern: Int32(truncatingIfNeeded: Int(x * 1000) &* 7919 &+ Int(y0 * 100)))
        let off = V2(Float(h % 997) / 997 * 3.7, Float((h / 997) % 991) / 991 * 2.3)
        s.uvs = s.uvs.map { $0 + off }
        return (s, Xform(translation: V3(x, (y0 + y1) / 2, z), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1)) * simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width / 2, bw: Float = 0.24, bt: Float = 0.022
        let dx0 = -doorWidth / 2, dx1 = doorWidth / 2, sill: Float = 0.2
        let n = Int((width / bw).rounded())
        let pitch = width / Float(n)
        func inDoor(_ x: Float, _ half: Float) -> Bool { door && x + half > dx0 - 0.09 && x - half < dx1 + 0.09 }
        for i in 0..<n {
            let x = -W + pitch * (Float(i) + 0.5)
            let w = pitch - rng.float(0.004...0.01)
            let top = height - rng.float(0...0.01)
            if inDoor(x, w / 2) {
                let (s, xf) = upright(x, doorHeight + 0.14, top, w: w, t: bt, z: bt / 2, mat: paint)
                m.add(s, xf.jittered(&rng, deg: 0.15, offset: 0.001))
            } else {
                let (s, xf) = upright(x, sill * 0.5, top, w: w, t: bt, z: bt / 2, mat: paint)
                m.add(s, xf.jittered(&rng, deg: 0.15, offset: 0.001))
            }
        }
        // Battens over every joint.
        for i in 1..<n {
            let x = -W + pitch * Float(i)
            let bwid: Float = 0.06
            if inDoor(x, bwid / 2) {
                let (s, xf) = upright(x, doorHeight + 0.14, height - 0.12, w: bwid, t: 0.019, z: bt + 0.0095, mat: paint)
                m.add(s, xf.jittered(&rng, deg: 0.2, offset: 0.001))
            } else {
                let (s, xf) = upright(x, sill * 0.5 + 0.12, height - 0.12, w: bwid, t: 0.019, z: bt + 0.0095, mat: paint)
                m.add(s, xf.jittered(&rng, deg: 0.2, offset: 0.001))
            }
        }
        // Trim: skirt board at the base and frieze board at the top, broken by the door.
        let segs: [(Float, Float)] = door ? [(-W, dx0 - 0.09), (dx1 + 0.09, W)] : [(-W, W)]
        for (a, b) in segs {
            m.add(plank(b - a, 0.2, 0.025, bevel: 0.005, material: trim),
                  Xform(translation: V3((a + b) / 2, sill * 0.5 + 0.1, bt + 0.0125), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }
        m.add(plank(width, 0.12, 0.025, bevel: 0.005, material: trim),
              Xform(translation: V3(0, height - 0.06, bt + 0.0125), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        if door {
            // Door casing: two jambs and a head, plus the sliding-door track on brackets.
            for x in [dx0 - 0.045, dx1 + 0.045] {
                let (s, xf) = upright(x, 0.0, doorHeight + 0.14, w: 0.09, t: 0.025, z: bt + 0.0125, mat: trim)
                m.add(s, xf.jittered(&rng, deg: 0.1, offset: 0.0005))
            }
            m.add(plank(doorWidth + 0.18 + 0.04, 0.14, 0.025, bevel: 0.005, material: trim),
                  Xform(translation: V3(0, doorHeight + 0.07, bt + 0.0125), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            // Threshold.
            m.add(plank(doorWidth, 0.12, 0.04, bevel: 0.006, material: "wood.weathered"), Xform(translation: V3(0, 0.02, 0.0)))
            let trackY = doorHeight + 0.32
            let t0 = dx0 - 0.15, t1 = W - 0.05
            m.add(Prim.roundedBox(V3(t1 - t0, 0.06, 0.05), radius: 0.006, bevelSegments: 1, material: "metal.rust"),
                  Xform(translation: V3((t0 + t1) / 2, trackY, bt + 0.08)))
            for k in 0..<4 {
                let x = t0 + 0.05 + Float(k) / 3 * (t1 - t0 - 0.1)
                m.add(Prim.roundedBox(V3(0.05, 0.12, 0.07), radius: 0.005, bevelSegments: 1, material: "metal.rust"),
                      Xform(translation: V3(x, trackY + 0.02, bt + 0.04)))
            }
        }
        // Back: horizontal girts on posts.
        for gy: Float in [0.3, 1.2, 2.1, 2.85] {
            for (a, b) in (door && gy < doorHeight + 0.1 ? segs : [(-W, W)]) {
                m.add(plank(b - a - 0.02, 0.14, 0.045, bevel: 0.004, material: "wood.weathered"),
                      Xform(translation: V3((a + b) / 2, gy, -0.0225 - 0.002), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))).jittered(&rng, deg: 0.2))
            }
        }
        for x in [-W + 0.05, W - 0.05] + (door ? [dx0 - 0.05, dx1 + 0.05] : []) {
            let (s, xf) = upright(x, 0, height, w: 0.14, t: 0.14, z: -0.045 - 0.07, mat: "wood.weathered")
            m.add(s, xf)
        }
        groundAO(&m, height: 0.4, floor: 0.6)
        return LODModel(m)
    }
}
