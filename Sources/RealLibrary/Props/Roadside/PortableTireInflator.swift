import simd
import Foundation

/// 12 V portable air compressor: yellow and black housing, display, coiled hose, plug cord.
public struct PortableTireInflator: RealAsset {
    public static let id = "portable-tire-inflator"
    public static let summary = "Compact 12 V air compressor, 22 x 12 x 13 cm: yellow and black housing, digital pressure display, coiled air hose, 12 V plug cord."
    public static let tags = ["prop", "tool", "vehicle", "plastic", "handheld"]
    public static let budget = 12000
    public static let author = "realityhd"

    /// Housing length (X), height (Y), depth (Z) in meters.
    public var size = V3(0.22, 0.13, 0.12)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let L = size.x, H = size.y, D = size.z
        // Black base and yellow upper shell with a parting line.
        m.add(Prim.roundedBox(V3(L, 0.04, D), radius: 0.012, bevelSegments: 3, material: "plastic.black"), Xform(translation: V3(0, 0.022, 0)))
        m.add(Prim.roundedBox(V3(L - 0.004, H - 0.052, D - 0.004), radius: 0.016, bevelSegments: 3, material: "plastic.yellow"), Xform(translation: V3(0, 0.042 + (H - 0.052) / 2, 0)))
        // Rubber feet.
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.03, 0.006, 0.02), radius: 0.002, bevelSegments: 1, material: "rubber"), Xform(translation: V3(sx * (L / 2 - 0.03), 0.003, sz * (D / 2 - 0.02))))
        } }
        // Carry handle loop on top.
        m.add(Prim.tube([V3(-0.055, H - 0.012, 0), V3(-0.055, H + 0.02, 0), V3(0.055, H + 0.02, 0), V3(0.055, H - 0.012, 0)], radii: [0.0075, 0.0075, 0.0075, 0.0075], sides: 10, seamTile: 0.1, material: "plastic.black", capEnd: true))
        // Display window and buttons on the front face (+Z).
        let zf = D / 2
        m.add(Prim.roundedBox(V3(0.07, 0.034, 0.003), radius: 0.003, bevelSegments: 2, material: "plastic.black"), Xform(translation: V3(-0.03, 0.095, zf + 0.0005)))
        m.add(Prim.roundedBox(V3(0.056, 0.022, 0.0012), radius: 0.002, bevelSegments: 1, material: "emissive.signal-green"), Xform(translation: V3(-0.03, 0.095, zf + 0.0028)))
        let bx: [Float] = [0.032, 0.056, 0.080]
        for (k, x) in bx.enumerated() {
            m.add(Prim.cylinder(radius: 0.0085, height: 0.005, bevel: 0.0015, segments: 16, material: k == 2 ? "plastic.orange:C8201E" : "plastic.black"),
                  Xform(translation: V3(x, 0.095, zf), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }
        // Vent slots on the front lower yellow section and side.
        for k in 0..<7 {
            m.add(Prim.roundedBox(V3(0.0045, 0.03, 0.002), radius: 0.001, bevelSegments: 1, material: "plastic.black"), Xform(translation: V3(-0.07 + Float(k) * 0.0095, 0.068, zf + 0.0005)))
        }
        // Logo bar.
        m.add(Prim.roundedBox(V3(0.05, 0.008, 0.0012), radius: 0.001, bevelSegments: 1, material: "plastic.black"), Xform(translation: V3(0.05, 0.062, zf + 0.0005)))
        // Hose port on the right end, coiled hose lying around the front, brass chuck with lever.
        let px = L / 2
        m.add(Prim.cylinder(radius: 0.009, height: 0.012, bevel: 0.002, segments: 16, material: "metal.chrome"), Xform(translation: V3(px + 0.006, 0.07, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        // Hose: helix of rings lying flat on the ground beside the unit (loops in XZ plane).
        let cx = px + 0.075, cz: Float = 0.0
        var hose: [V3] = [V3(px + 0.012, 0.07, 0), V3(px + 0.03, 0.04, 0), V3(cx - 0.05, 0.011, 0)]
        let loops = 3
        for k in 0...(loops * 20) {
            let t = Float(k) / 20, a = t * 2 * .pi
            let rr: Float = 0.05 - t * 0.004
            hose.append(V3(cx + cos(a) * rr, 0.011 + t * 0.0, cz + sin(a) * rr))
        }
        let pts = catmull(hose, per: 3)
        m.add(Prim.tube(pts, radii: Array(repeating: 0.0055, count: pts.count), sides: 8, seamTile: 0.1, material: "plastic.black", capEnd: true))
        // Chuck at the free end of the hose, resting on the ground.
        let end = hose.last!
        m.add(Prim.cylinder(radius: 0.0085, height: 0.04, bevel: 0.002, segments: 16, material: "metal.chrome"), Xform(translation: V3(end.x, 0.0085, end.z), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        // 12 V cord out the back-left, plug on the ground.
        let cord = catmull([V3(-L / 2 + 0.005, 0.03, -D / 2 + 0.03), V3(-L / 2 - 0.02, 0.015, -D / 2 - 0.02), V3(-L / 2 - 0.08, 0.004, -D / 2 - 0.01), V3(-L / 2 - 0.13, 0.004, -D / 2 + 0.04)], per: 4)
        m.add(Prim.tube(cord, radii: Array(repeating: 0.0028, count: cord.count), sides: 8, seamTile: 0.1, material: "plastic.black", capEnd: true))
        m.add(Prim.roundedBox(V3(0.03, 0.022, 0.022), radius: 0.004, bevelSegments: 2, material: "plastic.black"), Xform(translation: V3(-L / 2 - 0.145, 0.011, -D / 2 + 0.055), rotation: simd_quatf(degrees: -20, axis: .up)))
        m.add(Prim.cylinder(radius: 0.007, height: 0.02, bevel: 0.002, segments: 12, material: "metal.chrome"), Xform(translation: V3(-L / 2 - 0.172, 0.011, -D / 2 + 0.062), rotation: simd_quatf(degrees: 70, axis: V3(0, 1, 0)) * simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        // Centre on the housing so the footprint stays predictable.
        groundAO(&m, height: 0.04, floor: 0.5)
        return LODModel(m)
    }
}
