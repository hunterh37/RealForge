import simd
import Foundation

/// Chicago style come-along wire grip (Klein 1656 class) lying on its side: a forged body with the fixed
/// upper jaw, a parallel lower jaw carried on two links, the long toggle lever that closes the jaws when
/// pulled, and the bent round-bar bail (pulling eye) hooked through the lever's end, all yellow-chromate
/// plated steel with rivet pivots and a spring latch keeper. Jaws toward -X.
public struct WireGrip: RealAsset, RealHandTool {
    public static let id = "wire-grip"
    public static let summary = "Chicago style come-along wire grip: parallel jaws, toggle linkage and pulling bail in yellow-zinc steel."
    public static let tags = ["prop", "tool", "handheld", "utility", "metal"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 15, elevation: 50, distance: 0.9, studio: true)
    static let k: Float = 0.78
    static let shift: V3 = {
        let b = Self().raw().bounds
        return V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2) * k
    }()
    /// The bail, where a hand or hoist hook pulls.
    public static let grip = V3(0.16, 0.006, -0.04) * k + shift
    /// Jaw throat between the parallel jaws, where the conductor sits.
    public static let tip = V3(-0.07, 0.006, 0.015) * k + shift

    /// Plating material (yellow chromate zinc).
    public var plating: MaterialKey = "metal.screw-zinc-yellow:B39552"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var out = Model(name: Self.id)
        out.add(raw(), Xform(translation: Self.shift, scale: V3(repeating: Self.k)))
        groundAO(&out, height: 0.03)
        return LODModel(out)
    }

    /// Full-scale geometry in construction coordinates (jaws toward -X).
    func raw() -> Model {
        var m = Model(name: Self.id)
        let p = plating, steel: MaterialKey = "metal.steel"
        let flat = simd_quatf(angle: -.pi / 2, axis: V3(1, 0, 0))   // outline (x, y) -> (x, -z); extrude along +y
        func plate(_ o: [V2], _ t: Float, _ y: Float, _ mat: MaterialKey? = nil) {
            m.add(Prim.extrude(Shape2D.rounded(o.map { V2($0.x, -$0.y) }.reversed(), radius: 0.003), depth: t, bevel: 0.0012, bevelSegments: 2, material: mat ?? p),
                  Xform(translation: V3(0, y + t / 2, 0), rotation: flat))
        }
        // Fixed jaw and body bar (x, z plan), with a wire groove lip along its inner edge.
        plate([V2(-0.135, 0.030), V2(0.02, 0.030), V2(0.034, 0.038), V2(0.03, 0.06), V2(-0.13, 0.062), V2(-0.142, 0.05)], 0.012, 0.0)
        m.add(Prim.tube([V3(-0.132, 0.006, 0.031), V3(-0.02, 0.006, 0.031)], radii: [0.0042, 0.0042], sides: 8, seamTile: 0.03, material: p))
        // Body tail down to the lever pivot.
        plate([V2(0.0, 0.032), V2(0.03, 0.04), V2(0.054, -0.024), V2(0.042, -0.036), V2(0.026, -0.026)], 0.008, 0.012)
        // Moving jaw, parallel below the fixed jaw.
        plate([V2(-0.13, -0.022), V2(-0.02, -0.022), V2(-0.008, -0.014), V2(-0.008, 0.0), V2(-0.125, 0.0), V2(-0.134, -0.01)], 0.011, 0.0)
        m.add(Prim.tube([V3(-0.128, 0.0055, -0.0005), V3(-0.02, 0.0055, -0.0005)], radii: [0.004, 0.004], sides: 8, seamTile: 0.03, material: p))
        // Parallel links on top, riveted at both ends.
        for lx: Float in [-0.112, -0.05] {
            plate([V2(lx - 0.007, -0.014), V2(lx + 0.005, -0.016), V2(lx + 0.027, 0.044), V2(lx + 0.015, 0.048)], 0.005, 0.012)
            rivet(&m, at: V3(lx, 0.017, -0.012), normal: V3(0, 1, 0), radius: 0.0042, material: steel)
            rivet(&m, at: V3(lx + 0.021, 0.016, 0.045), normal: V3(0, 1, 0), radius: 0.0042, material: steel)
        }
        // Toggle lever from the moving jaw heel to the bail eye.
        plate([V2(-0.03, -0.02), V2(-0.012, -0.006), V2(0.1, -0.05), V2(0.098, -0.066), V2(0.086, -0.066)], 0.009, 0.011)
        rivet(&m, at: V3(-0.02, 0.020, -0.012), normal: V3(0, 1, 0), radius: 0.0045, material: steel)
        rivet(&m, at: V3(0.042, 0.020, -0.03), normal: V3(0, 1, 0), radius: 0.0045, material: steel)
        // Bail: slender U loop of round bar through the lever eye.
        let ex: Float = 0.093, ez: Float = -0.058, w: Float = 0.013, len: Float = 0.1
        let dir = simd_normalize(V3(1, 0, 0.25)), side = V3(-dir.z, 0, dir.x)
        var loop: [V3] = [V3(ex, 0.006, ez) + side * w * 0.6]
        loop.append(V3(ex, 0.006, ez) + side * w + dir * 0.012)
        loop.append(V3(ex, 0.006, ez) + side * w + dir * len)
        for i in 1...9 { let a = Float(i) / 10 * .pi; loop.append(V3(ex, 0.006, ez) + dir * (len + w * sin(a)) + side * w * cos(a)) }
        loop.append(V3(ex, 0.006, ez) - side * w + dir * len)
        loop.append(V3(ex, 0.006, ez) - side * w + dir * 0.012)
        loop.append(V3(ex, 0.006, ez) - side * w * 0.6)
        m.add(Prim.tube(loop, radii: Array(repeating: 0.0048, count: loop.count), sides: 10, seamTile: 0.04, material: p))
        // Latch keeper spring across the jaw mouth.
        m.add(Prim.tube([V3(-0.14, 0.012, 0.046), V3(-0.146, 0.012, 0.03), V3(-0.14, 0.011, 0.016)], radii: [0.0014, 0.0014, 0.0014], sides: 6, seamTile: 0.02, material: steel))
        return m
    }
}
