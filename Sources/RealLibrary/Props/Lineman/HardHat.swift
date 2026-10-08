import simd
import Foundation

/// Type I Class E full brim hard hat (Klein/MSA class, 330 x 290 x 165 mm) sitting on its brim: an oval HDPE
/// shell with the raised centre ridge and two side ribs, a full brim that dips at the front and back, the
/// black six point suspension's headband and crown straps under the shell, and the rear ratchet knob.
public struct HardHat: RealAsset, RealHandTool {
    public static let id = "hard-hat"
    public static let summary = "White Class E full brim hard hat with ridged crown and 6 point suspension."
    public static let tags = ["prop", "ppe", "handheld", "utility", "plastic"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 22, distance: 1.0, studio: true)
    static let a: Float = 0.165, b: Float = 0.145, H: Float = 0.165
    /// Hand on the side brim.
    public static let grip = SIMD3<Float>(0, 0.03, b - 0.01)
    /// Crown top (worn side up, the working end of PPE is the shell crown).
    public static let tip = SIMD3<Float>(0, H, 0)

    /// Shell colour (sRGB hex).
    public var shellColor: UInt32 = 0xE4E2DC
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let shell: MaterialKey = "plastic.hardhat:" + String(format: "%06X", shellColor)
        let black: MaterialKey = "plastic.black", strap: MaterialKey = "fabric.webbing"
        let a = Self.a, b = Self.b, H = Self.H
        var levels: [Model] = []
        for l in 0..<2 {
            var m = Model(name: Self.id)
            // Shell profile (normalised radius 0...1 of the brim ellipse, height in m): crown, brim, lip, underside.
            var prof: [V2] = []
            let crown = 14
            for i in 0...crown {
                let t = Float(i) / Float(crown)              // 0 top -> 1 crown base
                let r = 0.78 * sin(t * .pi / 2)
                let y = 0.03 + (H - 0.03) * pow(cos(t * .pi / 2), 0.7)
                prof.append(V2(max(r, 0.0001), y))
            }
            prof += [V2(0.8, 0.027), V2(0.88, 0.02), V2(0.95, 0.013), V2(1.0, 0.009), V2(1.005, 0.006), V2(0.99, 0.004), V2(0.88, 0.016),
                     V2(0.8, 0.023), V2(0.76, 0.026), V2(0.75, 0.06), V2(0.65, 0.11), V2(0.38, 0.145), V2(0.0001, 0.153)]
            var s = Prim.lathe(prof.reversed().map { V2($0.x * a, $0.y) }, segments: l == 0 ? 64 : 28, seamTile: 0.3, material: shell)
            s.deform { p in
                var q = V3(p.x, p.y, p.z * b / a)
                let ang = atan2(p.z, p.x)
                let rr = sqrt(p.x * p.x + p.z * p.z) / a
                // Brim dips at front and back (along X), rises at the sides.
                if rr > 0.78 { q.y += -0.012 * pow(abs(cos(ang)), 2) * (rr - 0.78) / 0.22 + 0.006 * pow(sin(ang), 2) * (rr - 0.78) / 0.22 }
                // Centre ridge along X and two side ribs on the crown.
                if rr < 0.78 && p.y > 0.06 {
                    let dz = q.z
                    let k = min(1, (p.y - 0.06) / 0.03)
                    q.y += k * (0.009 * exp(-pow(dz / 0.011, 2)) + 0.004 * exp(-pow((abs(dz) - 0.052) / 0.007, 2)))
                }
                return q
            }
            m.add(s)
            // Suspension: headband ring, crown straps, rear ratchet knob.
            m.add(Prim.torus(major: 0.1, minor: 0.0015, segments: l == 0 ? 40 : 20, sides: 6, minorY: 0.012, material: black),
                  Xform(translation: V3(0, 0.05, 0), scale: V3(1, 1, 0.85)))
            for k in 0..<3 {
                let ang = Float(k) / 3 * .pi + 0.3
                let d = V3(cos(ang), 0, sin(ang))
                let p0 = V3(d.x * 0.1, 0.055, d.z * 0.085), p1 = V3(0, 0.125, 0), p2 = V3(-d.x * 0.1, 0.055, -d.z * 0.085)
                m.add(Prim.sweep(Shape2D.rect(0.002, 0.02), along: catmull([p0, (p0 + p1) / 2 + V3(0, 0.03, 0), p1, (p1 + p2) / 2 + V3(0, 0.03, 0), p2], per: 4),
                                 up: V3(0, 1, 0), material: strap))
            }
            m.add(Prim.cylinder(radius: 0.016, height: 0.012, bevel: 0.003, segments: 20, material: black),
                  Xform(translation: V3(-0.1, 0.05, 0), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1))))
            _ = rng.float()
            groundAO(&m, height: 0.08)
            levels.append(m)
        }
        return LODModel(levels: levels, switchDistances: [4])
    }
}
