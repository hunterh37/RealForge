import simd
import Foundation

/// Oval stock tank, 1.22 x 0.61 x 0.61 m (4 x 2 x 2 ft): galvanized wall with pressed horizontal ribs,
/// rolled top rim, crimped bottom seam and drain plug. Empty.
public struct WaterTrough: RealAsset {
    public static let id = "water-trough"
    public static let summary = "Oval galvanized stock tank, 1.2 m: ribbed wall, rolled rim, crimped bottom seam, drain plug."
    public static let tags = ["prop", "farm", "metal", "container"]
    public static let budget = 5_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 28)

    public var length: Float = 1.22
    public var width: Float = 0.61
    public var height: Float = 0.61
    public var material: MaterialKey = "metal.galvanized-aged"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let r = width / 2, half = (length - width) / 2
        // Racetrack outline in XZ, counter-clockwise from above.
        var outline: [V2] = []
        let arc = 14, straight = 4
        for (cx, a0) in [(half, -Float.pi / 2), (-half, Float.pi / 2)] {
            for k in 0...arc { let a = a0 + Float(k) / Float(arc) * .pi; outline.append(V2(cx + r * cos(a), r * sin(a))) }
            let from = outline.last!, to = V2(-cx, cx > 0 ? r : -r)
            for k in 1..<straight { outline.append(simd_mix(from, to, V2(repeating: Float(k) / Float(straight)))) }
        }
        let h = height, t: Float = 0.0012
        var prof: [V2] = [V2(-0.006, 0.0), V2(0.004, 0.006), V2(0.004, 0.028), V2(0, 0.034)]
        for y in [0.2, 0.4] as [Float] {
            let yy = y * h / 0.61
            prof += [V2(0, yy - 0.035), V2(0.012, yy - 0.014), V2(0.012, yy + 0.014), V2(0, yy + 0.035)]
        }
        prof += [V2(0, h - 0.03)]
        m.add(CFKit.wall(outline, profile: prof, material: material))
        // Inside face.
        let inner = prof.dropFirst(3).map { V2($0.x - t * 2, $0.y) }
        m.add(CFKit.wall(outline, profile: [V2(-t * 2, 0.03)] + inner, material: material, outwardFacing: false))
        // Rolled rim.
        let rimR: Float = 0.012
        let rimPts = outline.map { p -> V3 in let d = simd_normalize(p - V2(p.x > 0 ? min(p.x, half) : max(p.x, -half), 0)); let q = p + d * (rimR - t); return V3(q.x, h - 0.03 + rimR * 0.6, q.y) }
        m.add(CFKit.loop(rimPts, radius: rimR, sides: 10, material: material))
        // Floor, slightly dished.
        var floor = Surface(material: material)
        let ci = floor.add(V3(0, 0.026, 0), .up, .zero)
        for p in outline { let q = p * 0.985; floor.add(V3(q.x, 0.03, q.y), .up, q) }
        for i in 0..<UInt32(outline.count) { floor.tri(ci, 1 + (i + 1) % UInt32(outline.count), 1 + i) }
        CFKit.orient(&floor) { _ in .up }
        m.add(floor)
        // Drain plug near one end.
        m.add(turned([(0, 0.0), (0.022, 0.0), (0.022, 0.012), (0.016, 0.018), (0, 0.018)], segments: 6, material: "metal.galvanized"),
              Xform(translation: V3(-half - r + 0.003, 0.07, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        groundAO(&m, height: 0.18, floor: 0.55)
        return LODModel(m)
    }
}
