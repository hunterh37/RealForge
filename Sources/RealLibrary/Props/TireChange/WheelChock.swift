import simd
import Foundation

/// Molded rubber wheel chock: ribbed ramp, flat base, finger loop on the tall face.
public struct WheelChock: RealAsset {
    public static let id = "wheel-chock"
    public static let summary = "Molded rubber wheel chock: wedge with ribbed ramp, flat base and carry loop."
    public static let tags = ["prop", "tool", "vehicle", "rubber"]
    public static let budget = 5000
    public static let author = "realityhd"

    /// Length along the wheel path in meters.
    public var length: Float = 0.24
    /// Height of the tall face in meters.
    public var height: Float = 0.13
    /// Width across the tread in meters.
    public var width: Float = 0.2
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length, H = height
        // Side profile in XY, extruded across Z. Ramp rises toward +X, tall face at x = +L/2.
        let outline = Shape2D.rounded([V2(-L / 2, 0), V2(L / 2, 0), V2(L / 2, H), V2(L / 2 - 0.018, H), V2(-L / 2, 0.012)], radius: 0.006)
        m.add(Prim.extrude(outline, depth: width, bevel: 0.006, bevelSegments: 2, material: "plastic.yellow"))
        // Ribs across the ramp face, following its slope.
        let slope = atan2(H - 0.012, L - 0.018)
        let rampLen = sqrt((L - 0.018) * (L - 0.018) + (H - 0.012) * (H - 0.012))
        let ribs = 9
        for i in 0..<ribs {
            let t = (Float(i) + 0.8) / (Float(ribs) + 0.4)
            let x = -L / 2 + t * (L - 0.018)
            let y = 0.012 + t * (H - 0.012)
            _ = rampLen
            m.add(Prim.roundedBox(V3(0.007, 0.006, width - 0.03), radius: 0.0018, bevelSegments: 1, material: "plastic.yellow"),
                  Xform(translation: V3(x - sin(slope) * 0.002, y + cos(slope) * 0.002, 0), rotation: simd_quatf(angle: slope, axis: V3(0, 0, 1))))
        }
        // Raised side flanges on the ramp edges.
        for sz: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(rampLen, 0.008, 0.008), radius: 0.003, bevelSegments: 1, material: "plastic.yellow"),
                  Xform(translation: V3(0, (H + 0.012) / 2 + 0.002, sz * (width / 2 - 0.007)), rotation: simd_quatf(angle: slope, axis: V3(0, 0, 1))))
        }
        // Black tire scuffs smeared on the ramp and dust along the foot.
        for (i, zz) in [Float(-0.045), Float(0.04)].enumerated() {
            let t: Float = 0.5 + Float(i) * 0.12
            m.add(Prim.roundedBox(V3(0.07 - Float(i) * 0.02, 0.0012, 0.03 + Float(i) * 0.015), radius: 0.0005, bevelSegments: 1, material: "plastic.black"),
                  Xform(translation: V3(-L / 2 + t * (L - 0.018) - sin(slope) * 0.0058, 0.012 + t * (H - 0.012) + cos(slope) * 0.0058, zz), rotation: simd_quatf(angle: slope, axis: V3(0, 0, 1))))
        }
        // Molded label plate on the tall face with three raised ridges.
        m.add(Prim.roundedBox(V3(0.0016, 0.045, 0.09), radius: 0.0006, bevelSegments: 1, material: "plastic.black"), Xform(translation: V3(L / 2 + 0.0008, H * 0.22, 0)))
        for k in -1...1 {
            m.add(Prim.roundedBox(V3(0.0016, 0.0035, 0.07), radius: 0.0005, bevelSegments: 1, material: "plastic.yellow"), Xform(translation: V3(L / 2 + 0.0022, H * 0.22 + Float(k) * 0.012, 0)))
        }
        // Dust band along the foot on the tall face and sides.
        m.add(Prim.roundedBox(V3(0.0012, 0.014, width + 0.001), radius: 0.0004, bevelSegments: 1, material: "plastic.matte:8A7B5F"), Xform(translation: V3(L / 2 + 0.0007, 0.008, 0)))
        for sz: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(L - 0.05, 0.012, 0.0012), radius: 0.0004, bevelSegments: 1, material: "plastic.matte:8A7B5F"), Xform(translation: V3(0.005, 0.007, sz * (width / 2 + 0.0007))))
        }
        // Finger loop on the tall face.
        m.add(Prim.torus(major: 0.026, minor: 0.0075, segments: 20, sides: 10, material: "plastic.yellow"),
              Xform(translation: V3(L / 2 + 0.014, H * 0.55, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 1, 0))))
        // Grip bars under the base.
        for i in 0..<3 {
            let x = -L * 0.3 + Float(i) * L * 0.3
            m.add(Prim.roundedBox(V3(0.012, 0.004, width - 0.02), radius: 0.0015, bevelSegments: 1, material: "plastic.black"), Xform(translation: V3(x, -0.0008, 0)))
        }
        // Slight yaw so it does not sit axis-aligned.
        var out = Model(name: Self.id)
        out.add(m, Xform(rotation: simd_quatf(degrees: rng.float(-5...5), axis: V3(0, 1, 0))))
        let b = out.bounds
        out = out.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&out, height: 0.03, floor: 0.5)
        return LODModel(out)
    }
}
