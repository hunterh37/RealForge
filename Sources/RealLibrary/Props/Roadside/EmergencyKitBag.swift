import simd
import Foundation

/// Red nylon roadside emergency kit bag: padded body, zipper, white cross patch, two webbing handles, reflective strip.
public struct EmergencyKitBag: RealAsset {
    public static let id = "emergency-kit-bag"
    public static let summary = "30 x 14 x 20 cm red nylon roadside emergency bag: zippered top, white cross patch, two webbing handles and a reflective strip."
    public static let tags = ["prop", "container", "fabric", "vehicle", "handheld"]
    public static let budget = 11000
    public static let author = "realityhd"

    /// Body width (X), height (Y), depth (Z) in meters.
    public var size = V3(0.30, 0.14, 0.20)
    /// Nylon colour.
    public var nylonMaterial = "fabric.nylon:B3201C"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = size.x, H = size.y, D = size.z
        // Soft padded body: superellipsoid squashed, slight sag on the front.
        m.add(Prim.superellipsoid(V3(W, H, D), exponent: 8, subdivisions: 14, material: nylonMaterial) , Xform(translation: V3(0, H / 2, 0)))
        // Bottom foot panel (black) and corner piping.
        m.add(Prim.roundedBox(V3(W - 0.03, 0.012, D - 0.03), radius: 0.005, bevelSegments: 2, material: "plastic.black"), Xform(translation: V3(0, 0.005, 0)))
        // Zipper along the top centre: tape and teeth, running front to back in an arc over the top.
        let zpts = (0...16).map { k -> V3 in
            let x = (Float(k) / 16 - 0.5) * (W - 0.04)
            return V3(x, H * 0.985 + 0.0 - abs(x) * 0.0, 0)
        }
        m.add(Prim.tube(zpts, radii: Array(repeating: 0.004, count: zpts.count), sides: 6, seamTile: 0.05, material: "plastic.black", capEnd: true))
        for k in 0..<28 {
            let x = (Float(k) / 27 - 0.5) * (W - 0.06)
            m.add(Prim.roundedBox(V3(0.0035, 0.002, 0.012), radius: 0.0004, bevelSegments: 1, material: "metal.chrome"), Xform(translation: V3(x, H * 0.985 + 0.0045, 0)))
        }
        // Zipper pull and tab at the right end.
        m.add(Prim.roundedBox(V3(0.012, 0.004, 0.014), radius: 0.001, bevelSegments: 1, material: "metal.chrome"), Xform(translation: V3(W / 2 - 0.035, H * 0.985 + 0.007, 0)))
        m.add(Prim.roundedBox(V3(0.03, 0.002, 0.007), radius: 0.001, bevelSegments: 1, material: "plastic.black"), Xform(translation: V3(W / 2 - 0.018, H * 0.985 + 0.009, 0.0)))
        // White cross patch on the front (+Z).
        let zf = D / 2 - 0.0035
        m.add(Prim.roundedBox(V3(0.07, 0.07, 0.003), radius: 0.004, bevelSegments: 1, material: "plastic.white"), Xform(translation: V3(-0.03, H * 0.52, zf + 0.0035)))
        m.add(Prim.roundedBox(V3(0.044, 0.014, 0.002), radius: 0.001, bevelSegments: 1, material: nylonMaterial), Xform(translation: V3(-0.03, H * 0.52, zf + 0.0055)))
        m.add(Prim.roundedBox(V3(0.014, 0.044, 0.002), radius: 0.001, bevelSegments: 1, material: nylonMaterial), Xform(translation: V3(-0.03, H * 0.52, zf + 0.0055)))
        // Reflective strip across the front lower third.
        m.add(Prim.roundedBox(V3(W * 0.6, 0.012, 0.0015), radius: 0.0005, bevelSegments: 1, material: "plastic.white"), Xform(translation: V3(0.04, H * 0.2, zf + 0.0035)))
        // Two webbing handles straddling the zipper, stitched at the ends.
        for sz: Float in [-1, 1] {
            let z = sz * D * 0.22
            let pts = [V3(-0.06, H * 0.95, z), V3(-0.058, H + 0.02, z), V3(0, H + 0.032, z), V3(0.058, H + 0.02, z), V3(0.06, H * 0.95, z)]
            let c = catmull(pts, per: 4)
            m.add(Prim.sweep(Shape2D.roundedRect(0.003, 0.018, radius: 0.001, segments: 1), along: c, up: V3(0, 0, 1), material: "fabric.webbing"))
            for x: Float in [-0.06, 0.06] {
                m.add(Prim.roundedBox(V3(0.026, 0.003, 0.006), radius: 0.001, bevelSegments: 1, material: "fabric.webbing"), Xform(translation: V3(x, H * 0.96, z)))
            }
        }
        // Squash folds: shallow wrinkles on the side panels.
        for _ in 0..<5 {
            let sx: Float = rng.chance(0.5) ? -1 : 1
            m.add(Prim.superellipsoid(V3(0.006, rng.float(0.03...0.07), 0.07), exponent: 3, subdivisions: 4, material: nylonMaterial),
                  Xform(translation: V3(sx * (W / 2 - 0.004), H * rng.float(0.35...0.7), rng.float(-0.05...0.05))))
        }
        groundAO(&m, height: 0.05, floor: 0.55)
        return LODModel(m)
    }
}
