import simd
import Foundation

/// Stick-mount audible/visual voltage detector (Salisbury 4344 class) lying on its side: a 44 mm yellow ABS
/// tube body with a moulded grip band, the detector head (a rounded yellow block with a black face, red
/// LED lens, range dial and test button), and at the other end the splined universal end fitting with its
/// cross bolt. The head end is +X; the head's flat bottom and the fitting rest on the floor, so the body
/// lies tilted a few degrees.
public struct VoltageDetector: RealAsset, RealHandTool {
    public static let id = "voltage-detector"
    public static let summary = "Stick-mount audible voltage detector: yellow body, head with LED and range dial, splined end fitting and contact hook."
    public static let tags = ["prop", "tool", "handheld", "utility", "electrical", "plastic", "electronics"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 32, distance: 0.8, studio: true)
    static let tilt: Float = 0.06
    /// Lying pose: tilt about Z, then base to y = 0 and centre X/Z (from the default geometry).
    static let pose: (simd_quatf, V3) = {
        let rot = simd_quatf(angle: tilt, axis: V3(0, 0, 1))
        let b = Self().raw().transformed(Xform(rotation: rot)).bounds
        return (rot, V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2))
    }()
    static func place(_ p: V3) -> V3 { pose.0.act(p) + pose.1 }
    /// Ribbed grip band on the body (body axis).
    public static let grip = place(V3(-0.045, 0, 0))
    /// Contact electrode at the head.
    public static let tip = place(V3(0.15, 0.006, 0))

    /// Body colour (sRGB hex).
    public var bodyColor: UInt32 = 0xF0B400
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var out = Model(name: Self.id)
        out.add(raw(), Xform(translation: Self.pose.1, rotation: Self.pose.0))
        groundAO(&out, height: 0.04)
        return LODModel(out)
    }

    /// Geometry with the body axis on y = 0, head toward +X.
    func raw() -> Model {
        var m = Model(name: Self.id)
        let body: MaterialKey = "plastic.yellow:" + String(format: "%06X", bodyColor)
        let black: MaterialKey = "plastic.black", steel: MaterialKey = "metal.stainless"
        let alongX = simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))
        // Body tube along X, axis at y = 0 (placed later): butt flare, grip band, head socket.
        m.add(Prim.lathe([V2(0.0001, 0), V2(0.016, 0.0005), V2(0.019, 0.004), V2(0.02, 0.02), V2(0.0215, 0.05), V2(0.0215, 0.17),
                          V2(0.023, 0.2), V2(0.026, 0.215), V2(0.026, 0.222)], segments: 32, seamTile: 0.14, material: body),
              Xform(translation: V3(-0.13, 0, 0), rotation: alongX))
        // Collar where the body enters the head.
        m.add(Prim.lathe([V2(0.0215, 0), V2(0.0265, 0.003), V2(0.0265, 0.016), V2(0.024, 0.02)], segments: 32, seamTile: 0.1, material: body),
              Xform(translation: V3(0.055, 0, 0), rotation: alongX))
        // Detector head: rounded block; the instrument face looks out along +X.
        let hx: Float = 0.115
        var head = Prim.superellipsoid(V3(0.07, 0.075, 0.07), exponent: 4, subdivisions: 10, material: body)
        head.deform { p in V3(p.x, p.y, p.z) }
        m.add(head, Xform(translation: V3(hx, 0.006, 0)))
        let fx = hx - 0.0352, toX = simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1))
        m.add(Prim.roundedBox(V3(0.004, 0.058, 0.058), radius: 0.0018, bevelSegments: 2, material: black), Xform(translation: V3(fx, 0.006, 0)))
        // Range dial (left), LED window (right), test button, scale ticks.
        m.add(Prim.lathe([V2(0, 0.005), V2(0.0105, 0.005), V2(0.012, 0.003), V2(0.012, 0)], segments: 24, seamTile: 0.05, material: "plastic.matte:2A2A2A"),
              Xform(translation: V3(fx - 0.0018, 0.022, 0.016), rotation: toX))
        m.add(Prim.roundedBox(V3(0.0025, 0.016, 0.004), radius: 0.001, bevelSegments: 1, material: "plastic.white"), Xform(translation: V3(fx - 0.0072, 0.022, 0.016)))
        m.add(Prim.lathe([V2(0, 0.003), V2(0.009, 0.003), V2(0.0095, 0.0015), V2(0.0095, 0)], segments: 24, seamTile: 0.05, material: "plastic.gloss:8E1410"),
              Xform(translation: V3(fx - 0.0018, 0.022, -0.016), rotation: toX))
        m.add(Prim.lathe([V2(0, 0.0025), V2(0.006, 0.0025), V2(0.0065, 0)], segments: 16, seamTile: 0.05, material: body),
              Xform(translation: V3(fx - 0.0018, -0.02, -0.02), rotation: toX))
        m.add(Prim.lathe([V2(0, 0.0025), V2(0.006, 0.0025), V2(0.0065, 0)], segments: 16, seamTile: 0.05, material: body),
              Xform(translation: V3(fx - 0.0018, -0.02, 0.02), rotation: toX))
        for k in 0..<9 {
            m.add(Prim.roundedBox(V3(0.0008, 0.0012, 0.006), radius: 0.0003, bevelSegments: 1, material: "plastic.white"),
                  Xform(translation: V3(fx - 0.0022, 0.012 - Float(k) * 0.0034, 0.026)))
        }
        // Splined universal end fitting: moulded yellow tongue with a bolt hole and a toothed spline disc.
        let ex: Float = -0.13
        let tongue = Shape2D.rounded([V2(-0.055, -0.016), V2(0.005, -0.016), V2(0.005, 0.016), V2(-0.055, 0.016)], radius: 0.006)
        m.add(Prim.extrude(tongue, depth: 0.014, bevel: 0.002, bevelSegments: 2, material: body), Xform(translation: V3(ex, 0, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(1, 0, 0))))
        m.add(Prim.cylinder(radius: 0.0062, height: 0.016, bevel: 0.0008, segments: 20, material: "plastic.matte:3A3A3A"), Xform(translation: V3(ex - 0.03, -0.008, 0)))
        for k in 0..<10 {
            let a = Float(k) / 10 * 2 * .pi
            m.add(Prim.roundedBox(V3(0.006, 0.014, 0.004), radius: 0.001, bevelSegments: 1, material: body),
                  Xform(translation: V3(ex - 0.055 + 0.002 * cos(a), 0, 0.014 * sin(a)) + V3(-0.004 * abs(cos(a)), 0, 0), rotation: simd_quatf(angle: a, axis: V3(0, 1, 0))))
        }
        return m
    }
}
