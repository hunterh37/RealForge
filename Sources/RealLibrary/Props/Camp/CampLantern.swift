import simd
import Foundation

/// Pressurized two-mantle camp lantern, 36 cm tall: painted steel fuel fount with pump and valve, glowing
/// glass globe around the mantles, vented cap, steel bail handle.
public struct CampLantern: RealAsset {
    public static let id = "camp-lantern"
    public static let summary = "Two-mantle camp lantern, 36 cm: painted fuel fount with pump and valve, glowing globe, vented cap, bail handle."
    public static let tags = ["prop", "camp", "light", "metal", "glass"]
    public static let budget = 4_000
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 30, elevation: 12, distance: 1.25)

    /// Paint color (sRGB hex) of the fount and cap.
    public var paintColor: UInt32 = 0x2F5634
    /// Lit globe; false shows dark glass.
    public var lit = true
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let paint = "metal.painted:" + String(format: "%06X", paintColor)
        let steel: MaterialKey = "metal.steel"
        // Fount: squat drum with rolled base and domed top.
        m.add(turned([(0, 0), (0.078, 0), (0.084, 0.006), (0.086, 0.02), (0.086, 0.075), (0.08, 0.092), (0.06, 0.104), (0.035, 0.11), (0.0, 0.112)],
                     segments: 40, material: paint))
        // Burner collar and frame posts.
        m.add(turned([(0.0, 0.11), (0.038, 0.11), (0.04, 0.125), (0.045, 0.13), (0.064, 0.13), (0.064, 0.137), (0.0, 0.137)], segments: 32, material: steel))
        for k in 0..<2 {
            let a = Float(k) * .pi + 0.4
            let p = V3(cos(a), 0, sin(a)) * 0.072
            m.add(Prim.tube([p + V3(0, 0.13, 0), p + V3(0, 0.285, 0)], radii: [0.0028, 0.0028], sides: 6, seamTile: 0.1, material: steel))
        }
        // Globe: slightly bulged glass cylinder; mantles inside.
        let glass: MaterialKey = lit ? "glass.lamp" : "metal.steel"
        m.add(turned([(0.058, 0.138), (0.062, 0.17), (0.064, 0.205), (0.062, 0.24), (0.058, 0.272)], segments: 32, material: glass))
        if lit {
            for x: Float in [-0.018, 0.018] {
                m.add(turned([(0, 0.18), (0.012, 0.185), (0.016, 0.2), (0.012, 0.215), (0.004, 0.222), (0, 0.222)], segments: 10, material: "emissive.warm"),
                      Xform(translation: V3(x, 0, 0)))
            }
        }
        // Vented cap: ring, dome, chimney nut.
        m.add(turned([(0.0, 0.272), (0.068, 0.272), (0.074, 0.278), (0.072, 0.29), (0.06, 0.305), (0.035, 0.318), (0.02, 0.322), (0.0, 0.322)],
                     segments: 32, material: paint))
        for k in 0..<8 {
            let a = Float(k) / 8 * 2 * .pi
            m.add(Prim.roundedBox(V3(0.018, 0.006, 0.004), radius: 0.0015, bevelSegments: 1, material: "plastic.black"),
                  Xform(translation: V3(cos(a) * 0.064, 0.295, sin(a) * 0.064), rotation: simd_quatf(angle: -a, axis: .up) * simd_quatf(degrees: -35, axis: V3(0, 0, 1))))
        }
        m.add(turned([(0, 0.322), (0.012, 0.322), (0.012, 0.332), (0.008, 0.336), (0, 0.336)], segments: 6, material: steel))
        // Bail handle, resting tilted to one side.
        let tilt = rng.float(-25...25)
        let bail = catmull([V3(-0.074, 0.29, 0), V3(-0.07, 0.34, 0), V3(-0.035, 0.375, 0), V3(0, 0.382, 0), V3(0.035, 0.375, 0), V3(0.07, 0.34, 0), V3(0.074, 0.29, 0)], per: 4)
        let rot = simd_quatf(degrees: tilt, axis: V3(1, 0, 0))
        let pivot = V3(0, 0.29, 0)
        let bailPts = bail.map { rot.act($0 - pivot) + pivot }
        m.add(Prim.tube(bailPts, radii: bailPts.map { _ in 0.0024 }, sides: 6, seamTile: 0.1, material: steel, capEnd: false))
        // Pump plunger and fuel valve on the fount.
        m.add(Prim.tube([V3(0.084, 0.06, 0), V3(0.104, 0.06, 0)], radii: [0.008, 0.008], sides: 10, seamTile: 0.1, material: steel))
        m.add(turned([(0, 0), (0.011, 0), (0.012, 0.004), (0.012, 0.012), (0, 0.014)], segments: 12, material: "plastic.black"),
              Xform(translation: V3(0.104, 0.06, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        let va = Float.pi * 0.6
        let vd = V3(cos(va), 0, -sin(va))
        m.add(Prim.tube([vd * 0.08 + V3(0, 0.1, 0), vd * 0.098 + V3(0, 0.11, 0)], radii: [0.005, 0.005], sides: 8, seamTile: 0.1, material: steel))
        m.add(turned([(0, 0), (0.012, 0), (0.012, 0.008), (0, 0.009)], segments: 12, material: "plastic.black"),
              Xform(translation: vd * 0.099 + V3(0, 0.11, 0), rotation: simd_quatf(from: .up, to: vd)))
        groundAO(&m, height: 0.08, floor: 0.6)
        return LODModel(m)
    }
}
