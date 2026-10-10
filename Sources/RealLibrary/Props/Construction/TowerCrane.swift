import simd
import Foundation

/// Hammerhead tower crane, 35 m to the apex: concrete base, lattice mast, slewing ring, cab, jib with trolley and hook, counter-jib with ballast.
public struct TowerCrane: RealAsset {
    public static let id = "tower-crane"
    public static let summary = "Hammerhead tower crane, 35 m: lattice mast on a concrete base, cab, 24 m jib with trolley and hook, ballasted counter-jib."
    public static let tags = ["prop", "construction", "industrial", "metal"]
    public static let budget = 5800
    public static let author = "hunterh37"

    /// Mast bays of 1.5 m.
    public var bays = 18
    /// Crane paint, sRGB hex.
    public var color: UInt32 = 0xF2B705
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let p = SK.paint(color), w: Float = 0.8, bay: Float = 1.5, base: Float = 1.2
        let top = base + Float(bays) * bay
        K.box(&m, V3(0, base / 2, 0), V3(5, base, 5), "concrete.rough", bevel: 0.03)
        let c: [V3] = [V3(-w, 0, -w), V3(w, 0, -w), V3(w, 0, w), V3(-w, 0, w)]
        for k in 0..<4 { K.rod(&m, [c[k] + V3(0, base, 0), c[k] + V3(0, top, 0)], r: 0.05, p, sides: 6) }
        for i in 0..<bays {
            let y0 = base + Float(i) * bay, y1 = y0 + bay
            for k in 0..<4 {
                let a = c[k], b = c[(k + 1) % 4]
                K.rod(&m, [a + V3(0, y0, 0), b + V3(0, y0, 0)], r: 0.022, p, sides: 5)
                let flip = (i + k) % 2 == 0
                K.rod(&m, [(flip ? a : b) + V3(0, y0, 0), (flip ? b : a) + V3(0, y1, 0)], r: 0.022, p, sides: 5)
            }
        }
        m.add(Prim.cylinder(radius: 0.95, height: 0.3, bevel: 0.02, segments: 24, material: "metal.steel"), Xform(translation: V3(0, top, 0)))
        K.box(&m, V3(0, top + 0.5, 0), V3(1.9, 0.4, 1.9), p, bevel: 0.03)
        K.box(&m, V3(1.5, top + 0.9, 1.25), V3(1.5, 1.6, 1.4), p, bevel: 0.04)
        K.box(&m, V3(2.26, top + 1.0, 1.25), V3(0.04, 0.9, 1.1), "glass.tinted", bevel: 0.006)
        let jb = top + 0.9, jt = top + 2.2, jl: Float = 24
        for z: Float in [-0.6, 0.6] { K.rod(&m, [V3(0.9, jb, z), V3(jl, jb, z)], r: 0.045, p, sides: 6) }
        K.rod(&m, [V3(0.9, jt, 0), V3(jl - 2, jt, 0)], r: 0.05, p, sides: 6)
        K.rod(&m, [V3(jl - 2, jt, 0), V3(jl, jb, 0.6)], r: 0.04, p, sides: 6)
        K.rod(&m, [V3(jl - 2, jt, 0), V3(jl, jb, -0.6)], r: 0.04, p, sides: 6)
        var x: Float = 0.9
        while x + 1.5 <= jl - 2 {
            K.rod(&m, [V3(x, jb, -0.6), V3(x + 0.75, jt, 0), V3(x + 1.5, jb, -0.6)], r: 0.02, p, sides: 5)
            K.rod(&m, [V3(x, jb, 0.6), V3(x + 0.75, jt, 0), V3(x + 1.5, jb, 0.6)], r: 0.02, p, sides: 5)
            K.rod(&m, [V3(x, jb, -0.6), V3(x, jb, 0.6)], r: 0.02, p, sides: 5)
            x += 1.5
        }
        for z: Float in [-0.55, 0.55] { K.rod(&m, [V3(-9, jb, z), V3(0.9, jb, z)], r: 0.045, p, sides: 6) }
        var cx: Float = -9
        while cx < 0.9 { K.rod(&m, [V3(cx, jb, -0.55), V3(cx, jb, 0.55)], r: 0.02, p, sides: 5); cx += 1.5 }
        for bx in [-7.6, -5.8] as [Float] { K.box(&m, V3(bx, jb + 0.65, 0), V3(1.5, 1.3, 1.25), "concrete.rough", bevel: 0.02) }
        let apex = V3(0, top + 8, 0)
        for z: Float in [-0.45, 0.45] { K.rod(&m, [V3(0, top + 0.7, z), V3(0, top + 7.9, z * 0.2)], r: 0.06, p, sides: 6) }
        K.rod(&m, [apex, V3(12, jt, 0)], r: 0.018, "metal.steel", sides: 5)
        K.rod(&m, [apex, V3(jl - 2, jt, 0)], r: 0.018, "metal.steel", sides: 5)
        K.rod(&m, [apex, V3(-9, jb, 0)], r: 0.018, "metal.steel", sides: 5)
        K.box(&m, V3(16, jb - 0.3, 0), V3(1.4, 0.35, 1.5), "metal.painted:2A2B2D", bevel: 0.02)
        K.rod(&m, [V3(16, jb - 0.4, 0), V3(16, jb - 12, 0)], r: 0.012, "metal.steel", sides: 5)
        K.box(&m, V3(16, jb - 12.4, 0), V3(0.5, 0.8, 0.4), p, bevel: 0.03)
        return K.finish(&m, ao: 0.3)
    }
}
