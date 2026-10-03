import simd
import Foundation

/// Rolling mechanic's tool chest, 72 x 98 x 48 cm: powder-coated steel cabinet with folded edges, a lift
/// lid compartment, eight ball-bearing drawers in four heights with 3 mm reveals, full-width brushed
/// aluminum hook pulls, rubber top mat, chrome side push handle, lid lock, four 100 mm swivel casters.
public struct ToolChest: RealAsset {
    public static let id = "tool-chest"
    public static let summary = "Rolling mechanic's tool chest: red powder-coated steel cabinet, eight drawers with aluminum pulls, side handle, casters."
    public static let tags = ["prop", "workshop", "metal", "container", "tool"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 14, distance: 1.12, studio: true)

    /// Powder coat color (sRGB hex).
    public var color: UInt32 = 0xA8231C
    /// Cabinet width, depth (m); height follows the drawer stack.
    public var width: Float = 0.72
    public var depth: Float = 0.46
    /// Drawer heights bottom to top (m).
    public var drawers: [Float] = [0.16, 0.12, 0.09, 0.08, 0.06, 0.06, 0.05, 0.05]
    /// Index of a drawer pulled open (nil = all closed) and how far (m).
    public var openDrawer: Int? = nil
    public var openAmount: Float = 0.12
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [6])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let paint = "metal.powdercoat:" + String(format: "%06X", color)
        let alu: MaterialKey = "metal.aluminum-brushed", chrome: MaterialKey = "metal.chrome", gapMat: MaterialKey = "plastic.black"
        let W = width, D = depth, base: Float = 0.1, rail: Float = 0.03, stile: Float = 0.026, reveal: Float = 0.003
        let stack = drawers.reduce(0, +)
        let lidH: Float = 0.13
        let bodyTop = base + rail + stack + 0.012
        let topY = bodyTop + lidH
        // Cabinet shell: sides, back, bottom rail, recessed dark front panel behind the drawers.
        m.add(Prim.roundedBox(V3(W, bodyTop - base, D - 0.014), radius: 0.006, bevelSegments: 2, material: paint),
              Xform(translation: V3(0, (base + bodyTop) / 2, -0.007)))
        m.add(Prim.roundedBox(V3(W - 2 * stile + 0.004, stack + 0.006, 0.004), radius: 0.001, bevelSegments: 1, material: gapMat),
              Xform(translation: V3(0, base + rail + stack / 2, D / 2 - 0.016)))
        for sx: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(stile, bodyTop - base, 0.016), radius: 0.004, bevelSegments: 2, material: paint),
                  Xform(translation: V3(sx * (W / 2 - stile / 2), (base + bodyTop) / 2, D / 2 - 0.008)))
        }
        // Pressed side panels: shallow raised field with rounded edges, louvre slots near the top.
        for sx: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.006, bodyTop - base - 0.12, D - 0.12), radius: 0.003, bevelSegments: 2, material: paint),
                  Xform(translation: V3(sx * (W / 2 + 0.0015), (base + bodyTop) / 2, -0.007)))
            for k in 0..<6 {
                m.add(Prim.roundedBox(V3(0.004, 0.008, 0.07), radius: 0.003, bevelSegments: 1, material: gapMat),
                      Xform(translation: V3(sx * (W / 2 + 0.0035), bodyTop - 0.1 - Float(k) * 0.018, -0.007)))
            }
        }
        m.add(Prim.roundedBox(V3(W, rail, 0.016), radius: 0.004, bevelSegments: 2, material: paint), Xform(translation: V3(0, base + rail / 2, D / 2 - 0.008)))
        // Hook pull: extruded aluminum J profile running the drawer width.
        let jProfile = Shape2D.rounded([V2(0, 0), V2(-0.002, 0), V2(-0.002, 0.017), V2(-0.013, 0.017), V2(-0.013, 0.011), V2(-0.0155, 0.011),
                                         V2(-0.0155, 0.021), V2(0, 0.021)], radius: 0.0009, segments: 0)
        func pull(_ len: Float, at p: V3) {
            m.add(Prim.extrude(jProfile, depth: len, bevel: 0.0008, bevelSegments: 1, material: alu),
                  Xform(translation: p, rotation: simd_quatf(degrees: 90, axis: .up)))
            for sx: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(0.004, 0.02, 0.016), radius: 0.0015, bevelSegments: 1, material: alu),
                      Xform(translation: p + V3(sx * (len / 2 + 0.002), 0.011, 0.008)))
            }
        }
        // Drawers: fronts with a folded lower lip, pull along the top edge.
        let fw = W - 2 * stile - 2 * reveal
        var y = base + rail
        for (i, h) in drawers.enumerated() {
            let out: Float = openDrawer == i ? openAmount : 0
            let z = D / 2 - 0.009 + out
            let cy = y + h / 2
            m.add(Prim.roundedBox(V3(fw, h - reveal, 0.018), radius: 0.003, bevelSegments: 1, material: paint), Xform(translation: V3(0, cy, z)).jittered(&rng, deg: 0.05, offset: 0.0003))
            pull(fw - 0.01, at: V3(0, y + h - reveal / 2 - 0.023, z + 0.009))
            if out > 0 {
                // Drawer box sides and a dark interior visible when open.
                for sx: Float in [-1, 1] {
                    m.add(Prim.roundedBox(V3(0.012, h - 0.02, out + 0.02), radius: 0.002, bevelSegments: 1, material: paint),
                          Xform(translation: V3(sx * (fw / 2 - 0.006), cy - 0.004, z - 0.009 - (out + 0.02) / 2)))
                }
                m.add(Prim.roundedBox(V3(fw - 0.024, 0.006, out + 0.02), radius: 0.001, bevelSegments: 1, material: "rubber"),
                      Xform(translation: V3(0, y + 0.012, z - 0.009 - (out + 0.02) / 2)))
            }
            y += h
        }
        // Lift lid compartment: lid box with a shadow seam, pull and lock; rubber mat inset on top.
        m.add(Prim.roundedBox(V3(W + 0.004, lidH - 0.004, D + 0.002), radius: 0.007, bevelSegments: 2, material: paint),
              Xform(translation: V3(0, bodyTop + 0.004 + (lidH - 0.004) / 2, -0.006)))
        m.add(Prim.roundedBox(V3(W - 0.01, 0.006, D - 0.024), radius: 0.002, bevelSegments: 1, material: gapMat),
              Xform(translation: V3(0, bodyTop + 0.002, -0.006)))
        pull(W - 0.12, at: V3(0, bodyTop + 0.012, D / 2 - 0.005 + 0.001))
        m.add(Prim.cylinder(radius: 0.011, height: 0.008, bevel: 0.002, segments: 18, material: chrome),
              Xform(translation: V3(W * 0.36, bodyTop + lidH * 0.55, D / 2 - 0.006), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        m.add(Prim.roundedBox(V3(0.002, 0.008, 0.002), radius: 0.0005, bevelSegments: 1, material: gapMat),
              Xform(translation: V3(W * 0.36, bodyTop + lidH * 0.55, D / 2 + 0.0025)))
        m.add(Prim.roundedBox(V3(W - 0.03, 0.004, D - 0.04), radius: 0.0018, bevelSegments: 2, material: "rubber"),
              Xform(translation: V3(0, topY + 0.002 - 0.001, -0.006)))
        // Side push handle (chrome tube on two cast mounts).
        let hy = bodyTop + lidH * 0.4, hx = W / 2 + 0.002
        let tube = catmull([V3(hx, hy, -D * 0.34), V3(hx + 0.045, hy, -D * 0.3), V3(hx + 0.055, hy, -D * 0.2), V3(hx + 0.055, hy, D * 0.2),
                            V3(hx + 0.045, hy, D * 0.3), V3(hx, hy, D * 0.34)], per: 4)
        m.add(Prim.tube(tube, radii: tube.map { _ in 0.0125 }, sides: 14, seamTile: 0.08, material: chrome, capEnd: false))
        for sz: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.008, 0.05, 0.05), radius: 0.003, bevelSegments: 2, material: chrome), Xform(translation: V3(hx + 0.002, hy, sz * D * 0.34)))
            if detail {
                hexBolt(&m, at: V3(hx + 0.006, hy + 0.014, sz * D * 0.34), normal: V3(1, 0, 0), size: 0.01, material: chrome)
                hexBolt(&m, at: V3(hx + 0.006, hy - 0.014, sz * D * 0.34), normal: V3(1, 0, 0), size: 0.01, material: chrome)
            }
        }
        // Casters under the corners.
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
            let yaw = rng.float(-40...40) + (sx > 0 ? 0 : 180)
            if detail {
                caster(&m, at: V3(sx * (W / 2 - 0.05), 0, sz * (D / 2 - 0.05)), height: base, wheelRadius: 0.04,
                       yaw: yaw, frame: "metal.stainless", wheel: "rubber", hub: "plastic.black")
            } else {
                m.add(Prim.cylinder(radius: 0.04, height: 0.03, bevel: 0.008, segments: 10, bevelSegments: 1, material: "rubber"),
                      Xform(translation: V3(sx * (W / 2 - 0.05), 0.04, sz * (D / 2 - 0.05) - 0.015), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
                m.add(Prim.roundedBox(V3(0.05, base - 0.04, 0.04), radius: 0.004, bevelSegments: 1, material: "metal.stainless"),
                      Xform(translation: V3(sx * (W / 2 - 0.05), 0.04 + (base - 0.04) / 2, sz * (D / 2 - 0.05))))
            }
        }}
        groundAO(&m, height: 0.14, floor: 0.5)
        return m
    }
}
