import simd
import Foundation

/// Louvered shutter pair: two painted wood leaves (stiles, top, mid and bottom rails, fixed louvers
/// angled to shed water) on iron strap hinges with pintles, and S-shaped holdbacks. Shown closed, back
/// on the wall plane; base at y = 0, centered on X. Leaves are separate so an app can swing them.
public struct LouveredShutterPair: RealAsset {
    public static let id = "louvered-shutter-pair"
    public static let summary = "Louvered shutter pair, 1.5 m: painted stiles and rails with angled louvers, mid rail, iron strap hinges and S-holdbacks."
    public static let tags = ["structure", "architecture", "facade", "trim", "wood"]
    public static let budget = 12_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 28, elevation: 6, distance: 1.0)

    /// Width of one leaf, height and thickness (m).
    public var leafWidth: Float = 0.48
    public var height: Float = 1.5
    public var thickness: Float = 0.032
    /// Louver pitch (m) and tilt (degrees).
    public var louverPitch: Float = 0.042
    public var louverTilt: Float = 35
    /// Gap between leaves and to the wall (m).
    public var gap: Float = 0.004
    public var paint: MaterialKey = "wood.painted-shaker-worn:2E4636"
    public var hardware: MaterialKey = "metal.cast-iron"
    public init() {}

    func leaf(_ rng: inout SeededRNG) -> Model {
        var m = Model(name: "leaf")
        let W = leafWidth, H = height, t = thickness
        let stile: Float = 0.06, topR: Float = 0.08, midR: Float = 0.08, botR: Float = 0.12
        for x in [stile / 2, W - stile / 2] {
            m.add(Prim.roundedBox(V3(stile, H, t), radius: 0.003, bevelSegments: 1, material: paint), Xform(translation: V3(x, H / 2, t / 2)))
        }
        let iw = W - 2 * stile
        let midY = H * 0.46
        for (y, h) in [(H - topR / 2, topR), (midY, midR), (botR / 2, botR)] {
            // Rails run along X (grain along U).
            m.add(Prim.roundedBox(V3(iw + 0.004, h, t * 0.94), radius: 0.003, bevelSegments: 1, material: paint), Xform(translation: V3(W / 2, y, t / 2)))
        }
        let slat = Prim.roundedBox(V3(iw + 0.006, 0.05, 0.007), radius: 0.0025, bevelSegments: 1, material: paint)
        let tilt = simd_quatf(angle: louverTilt * .pi / 180 - .pi / 2, axis: V3(1, 0, 0))
        for (a, b) in [(botR, midY - midR / 2), (midY + midR / 2, H - topR)] {
            let n = max(1, Int(((b - a) / louverPitch).rounded(.down)))
            let p = (b - a) / Float(n)
            for i in 0..<n {
                var r = rng.fork(i)
                let y = a + p * (Float(i) + 0.5)
                m.add(slat, Xform(translation: V3(W / 2, y, t / 2), rotation: tilt * simd_quatf(angle: r.float(-0.02...0.02), axis: V3(1, 0, 0))))
            }
        }
        return m
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = leafWidth, H = height, t = thickness
        var r1 = rng.fork(1), r2 = rng.fork(2)
        let l = leaf(&r1), rr = leaf(&r2)
        m.add(l, Xform(translation: V3(-W - gap / 2, 0, gap)))
        m.add(rr, Xform(translation: V3(gap / 2, 0, gap)))
        // Strap hinges on the outer stiles, pintles into the wall, S-holdbacks on the wall beside each leaf.
        for s in [Float(-1), 1] {
            for y in [H * 0.14, H * 0.86] {
                let strapLen: Float = 0.26
                m.add(Prim.roundedBox(V3(strapLen, 0.028, 0.004), radius: 0.0015, bevelSegments: 1, material: hardware),
                      Xform(translation: V3(s * (W + gap / 2 - strapLen / 2), y, t + gap + 0.002)))
                m.add(Prim.cylinder(radius: 0.008, height: 0.05, bevel: 0.002, segments: 10, material: hardware),
                      Xform(translation: V3(s * (W + gap / 2 + 0.004), y - 0.025, t / 2 + gap)))
                for k in 0..<3 {
                    m.add(Prim.cylinder(radius: 0.005, height: 0.003, bevel: 0.001, segments: 8, material: hardware),
                          Xform(translation: V3(s * (W + gap / 2 - 0.03 - Float(k) * 0.08), y, t + gap + 0.004), rotation: simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))))
                }
            }
            // S holdback (shutter dog) on the wall below the outer bottom corner.
            var pts: [V3] = []
            for i in 0...20 {
                let u = Float(i) / 20, a = u * 2 * .pi
                pts.append(V3(s * (W + 0.07) + s * 0.03 * sin(a), H * 0.06 + 0.11 * u, 0.012 + 0.006 * sin(a * 0.5)))
            }
            m.add(Prim.tube(pts, radii: Array(repeating: 0.005, count: pts.count), sides: 6, seamTile: 0.05, material: hardware))
            m.add(Prim.cylinder(radius: 0.01, height: 0.012, bevel: 0.002, segments: 10, material: hardware),
                  Xform(translation: V3(s * (W + 0.07), H * 0.06 + 0.055, 0.006), rotation: simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))))
        }
        groundAO(&m, height: 0.1, floor: 0.8)
        return LODModel(ArchTrimKit.ground(m))
    }
}
