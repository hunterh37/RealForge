import simd
import Foundation

/// Channelizer drum, 1.0 m tall, 0.6 m across at the bottom band: ribbed orange polyethylene body with two
/// white reflective bands, domed top with a molded handle, sitting in a 0.8 m black rubber tire ring.
public struct TrafficBarrel: RealAsset {
    public static let id = "traffic-barrel"
    public static let summary = "Channelizer drum: ribbed orange body, white reflective bands, molded handle, rubber ballast ring."
    public static let tags = ["prop", "construction", "road", "barrier", "plastic"]
    public static let budget = 5_400
    public static let author = "hunter"

    public var height: Float = 1.0
    public var body: MaterialKey = "plastic.orange"
    public var band: MaterialKey = "plastic.white"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let y0: Float = 0.06, top = height * 0.94
        func r(_ y: Float) -> Float { lerp(0.29, 0.255, (y - y0) / (top - y0)) }
        // Five bands between molded ribs: orange, white, orange, white, orange.
        let edges: [Float] = [y0] + [0.25, 0.4, 0.55, 0.7].map { $0 * height } + [top]
        for i in 0..<(edges.count - 1) {
            let a = edges[i], b = edges[i + 1]
            var prof: [(Float, Float)] = []
            let steps = 6
            for k in 0...steps {
                let t = Float(k) / Float(steps), y = lerp(a + 0.012, b - 0.012, t)
                prof.append((r(y) + 0.006 * sin(.pi * t), y))
            }
            // Rib groove at each band edge.
            prof.insert((r(a) - 0.008, a), at: 0)
            prof.append((r(b) - 0.008, b))
            let mat = i % 2 == 1 ? band : body
            m.add(turned(prof, segments: 40, material: mat, seamTile: 0.3))
        }
        // Domed top and handle.
        m.add(turned([(r(top) - 0.008, top), (r(top) - 0.03, top + 0.03), (0.16, top + 0.05), (0.0, top + 0.055)],
                     segments: 40, material: body, seamTile: 0.3))
        let hy = top + 0.05
        m.add(CFKit.pipe([V3(-0.09, hy - 0.005, 0), V3(-0.07, hy + 0.035, 0), V3(0.07, hy + 0.035, 0), V3(0.09, hy - 0.005, 0)],
                         radius: 0.014, sides: 10, material: body))
        // Rubber ballast ring (a cut truck tire) around the base.
        // Outer bulge then back over the top to the inner edge.
        let tire: [(Float, Float)] = [(0.4, 0.0), (0.415, 0.03), (0.41, 0.07), (0.39, 0.095), (0.34, 0.1), (0.3, 0.09), (0.295, 0.06)]
        m.add(turned(tire, segments: 40, material: "rubber.tire", seamTile: 0.3))
        // Base plate under the drum.
        m.add(turned([(0.0, 0.0), (0.3, 0.0), (0.3, y0), (r(y0) - 0.008, y0)], segments: 40, material: "plastic.black", seamTile: 0.3))
        groundAO(&m, height: 0.25, floor: 0.6)
        return LODModel(m)
    }
}
