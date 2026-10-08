import simd
import Foundation

/// Class 4 orange EPDM rubber insulating blanket (Salisbury Salcor class, 914 mm square, 3 mm) lying on the ground with
/// soft waves and a lifted corner, grommet eyelets along the edges, the moulded class stamp, and a nylon
/// blanket clamp pin clipped on one edge.
public struct InsulatingBlanket: RealAsset, RealHandTool {
    public static let id = "insulating-blanket"
    public static let summary = "Orange 36 in rubber insulating blanket lying flat with eyelets and a blanket clamp pin."
    public static let tags = ["prop", "tool", "handheld", "utility", "electrical", "ppe", "rubber"]
    public static let budget = 14500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 38, distance: 1.0, studio: true)
    static let S: Float = 0.914
    static func wave(_ x: Float, _ z: Float) -> Float {
        let h = 0.006 * sin(x * 7.1 + 0.6) * sin(z * 5.3 + 1.1) + 0.006 * max(0, sin(z * 4.0 - 0.8))
        let cornerLift = 0.045 * pow(max(0, (x + z) / S - 0.62) / 0.38, 2)
        return 0.0035 + max(0, h) + cornerLift
    }
    /// Hand at the lifted corner.
    public static let grip = SIMD3<Float>(S / 2 - 0.05, wave(S / 2 - 0.05, S / 2 - 0.05), S / 2 - 0.05)
    /// Blanket centre (the face that goes on the conductor).
    public static let tip = SIMD3<Float>(0, wave(0, 0), 0)

    /// Rubber colour (sRGB hex).
    public var color: UInt32 = 0xE0601E
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let rub: MaterialKey = "rubber.insulating-orange:" + String(format: "%06X", color)
        let S = Self.S, t: Float = 0.003
        var levels: [Model] = []
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let seg = l == 0 ? 36 : 16
            m.add(Prim.terrain(size: V2(S, S), segments: seg, material: rub) { p in Self.wave(p.x, p.y) })
            m.add(Prim.terrain(size: V2(S, S), segments: seg / 3, material: rub) { p in Self.wave(p.x, p.y) - t }.flipped())
            // Edge band closing the sheet.
            var edge: [V3] = []
            let n = seg * 4
            for i in 0..<n {
                let u = Float(i) / Float(n) * 4
                let side = Int(u), f = u - Float(side)
                var p: V2
                switch side { case 0: p = V2(-S / 2 + f * S, -S / 2); case 1: p = V2(S / 2, -S / 2 + f * S); case 2: p = V2(S / 2 - f * S, S / 2); default: p = V2(-S / 2, S / 2 - f * S) }
                edge.append(V3(p.x, Self.wave(p.x, p.y) - t / 2, p.y))
            }
            m.add(Prim.sweep(Shape2D.roundedRect(t, t * 0.9, radius: t * 0.4, segments: 2), along: edge, up: V3(0, 1, 0), closedPath: true, material: rub))
            // Grommet eyelets: 3 per edge plus corners, brass rings set into the rubber.
            if l == 0 {
                for i in 0..<4 { for k in 0..<4 {
                    let f = -S / 2 + 0.03 + Float(k) * (S - 0.06) / 3
                    let p: V2 = [V2(f, -S / 2 + 0.03), V2(S / 2 - 0.03, f), V2(-f, S / 2 - 0.03), V2(-S / 2 + 0.03, -f)][i]
                    m.add(Prim.torus(major: 0.0065, minor: 0.0016, segments: 16, sides: 6, material: "metal.brass-aged"),
                          Xform(translation: V3(p.x, Self.wave(p.x, p.y) + 0.0002, p.y)))
                    m.add(Prim.cylinder(radius: 0.0052, height: 0.0004, bevel: 0.0001, segments: 14, bevelSegments: 1, material: "plastic.black"),
                          Xform(translation: V3(p.x, Self.wave(p.x, p.y) + 0.0001, p.y)))
                } }
                // Class stamp near one corner: raised moulded patch.
                let sp = V2(-S / 2 + 0.11, S / 2 - 0.07)
                m.add(Prim.roundedBox(V3(0.11, 0.0008, 0.04), radius: 0.0003, bevelSegments: 1, material: rub + "", ), Xform(translation: V3(sp.x, Self.wave(sp.x, sp.y) + 0.0003, sp.y)))
            }
            // Blanket clamp pin (clothespin style) on the near edge.
            let cx: Float = -0.12, cz = -S / 2 + 0.01, cy = Self.wave(cx, -S / 2)
            for sgn: Float in [1, -1] {
                var jaw = Prim.roundedBox(V3(0.09, 0.008, 0.022), radius: 0.003, bevelSegments: 2, material: "plastic.black")
                jaw.deform { p in V3(p.x, p.y + sgn * 0.0025 * max(0, p.x / 0.045), p.z) }
                m.add(jaw, Xform(translation: V3(cx, cy + sgn * 0.0065, cz), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 1, 0))))
            }
            m.add(Prim.helix(radius: 0.006, pitch: 0.003, turns: 3, wire: 0.0012, material: "metal.steel"),
                  Xform(translation: V3(cx - 0.0045, cy, cz + 0.012), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1))))
            _ = rng.float()
            groundAO(&m, height: 0.03)
            levels.append(m)
        }
        return LODModel(levels: levels, switchDistances: [5])
    }
}
