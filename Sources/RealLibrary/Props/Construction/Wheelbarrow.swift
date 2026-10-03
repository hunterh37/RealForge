import simd
import Foundation

/// Contractor wheelbarrow, 1.5 m long, 0.66 m to the tray rim: pressed steel tray (0.95 x 0.68 m, 0.24 m
/// deep, 6 cu ft) with a rolled rim, hardwood handles, painted steel legs and braces, 0.4 m pneumatic wheel.
public struct Wheelbarrow: RealAsset {
    public static let id = "wheelbarrow"
    public static let summary = "Contractor wheelbarrow: pressed steel tray with rolled rim, hardwood handles, steel legs, pneumatic wheel."
    public static let tags = ["prop", "construction", "metal", "tool", "vehicle"]
    public static let budget = 9_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 125, elevation: 20)

    public var trayColor: UInt32 = 0x2E6B3A
    public var frameColor: UInt32 = 0x2A2C30
    public var trayDepth: Float = 0.24
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let tray = String(format: "metal.painted:%06X", trayColor), frame = String(format: "metal.painted:%06X", frameColor)
        let wheelR: Float = 0.2, axle = V3(0.62, wheelR, 0)
        // Handles: grips at the back, bolted to the wheel forks at the front.
        func handleY(_ x: Float) -> Float { 0.5 - (x + 0.85) * 0.215 }
        func handleZ(_ x: Float) -> Float { 0.27 - (x + 0.85) / 1.3 * 0.15 }
        for sz: Float in [-1, 1] {
            let a = V3(-0.85, handleY(-0.85), sz * handleZ(-0.85)), b = V3(0.45, handleY(0.45), sz * handleZ(0.45))
            let (s, x) = board(from: a, to: b, width: 0.045, thick: 0.04, up: .up, bevel: 0.01, material: "wood.oak")
            m.add(s, x.jittered(&rng, deg: 0.3))
            // Rubber grip sleeve.
            let gd = simd_normalize(b - a)
            m.add(CFKit.pipe([a - gd * 0.01, a + gd * 0.13], radius: 0.022, sides: 10, material: "rubber"))
            // Wheel fork strap from the handle end to the axle.
            m.add(CFKit.pipe([b - gd * 0.05 + V3(0, -0.02, 0), V3(axle.x - 0.02, axle.y + 0.01, sz * 0.065), V3(axle.x, axle.y, sz * 0.06)],
                             radius: 0.009, sides: 8, material: frame))
            // Leg: steel bar bolted under the handle, bent foot.
            let lx: Float = -0.32
            let top = V3(lx, handleY(lx) - 0.02, sz * (handleZ(lx) + 0.01))
            m.add(CFKit.pipe([top, V3(lx - 0.04, 0.12, sz * (handleZ(lx) + 0.03)), V3(lx - 0.05, 0.015, sz * (handleZ(lx) + 0.035)), V3(lx - 0.13, 0.012, sz * (handleZ(lx) + 0.035))],
                             radius: 0.011, sides: 8, material: frame))
            // Tray stay from the front of the tray to the handle.
            m.add(CFKit.pipe([V3(0.47, 0.55, sz * 0.19), V3(0.3, handleY(0.3) + 0.01, sz * handleZ(0.3))], radius: 0.008, sides: 8, material: frame))
        }
        // Cross brace between the legs.
        m.add(CFKit.pipe([V3(-0.34, 0.24, -handleZ(-0.34) - 0.02), V3(-0.34, 0.24, handleZ(-0.34) + 0.02)], radius: 0.01, sides: 8, material: frame))
        // Tray: lofted from a small bottom outline to the flared rim; the front leans out toward the wheel.
        let yb: Float = 0.42, yt = yb + trayDepth
        var rings: [([V2], Float)] = []
        let steps = 5
        for k in 0...steps {
            let t = Float(k) / Float(steps), e = sqrt(t)
            let half = V2(lerp(0.3, 0.475, e), lerp(0.21, 0.34, e))
            let c = V2(lerp(0.0, 0.08, t), 0)
            rings.append((CFKit.roundedRect(center: c, half: half, radius: lerp(0.09, 0.17, e), perCorner: 5), lerp(yb + 0.025, yt, t)))
        }
        // Rounded bottom edge: shrink toward a flat floor.
        let floorRing = (CFKit.roundedRect(center: .zero, half: V2(0.27, 0.18), radius: 0.07, perCorner: 5), yb)
        let outer = [floorRing] + rings
        var trayOut = CFKit.loft(outer, material: tray)
        trayOut.bakeCavityAO(strength: 0.3, floor: 0.8)
        m.add(trayOut)
        let inner = outer.map { (ring, y) -> ([V2], Float) in
            let c = ring.reduce(V2.zero, +) / Float(ring.count)
            return (ring.map { c + ($0 - c) * (1 - 0.006 / max(0.1, simd_length($0 - c))) }, y + 0.003)
        }
        m.add(CFKit.loft(inner, material: tray, outward: false))
        for (ring, y, up) in [(floorRing.0, yb, Float(-1)), (inner[0].0, yb + 0.003, Float(1))] {
            var f = Surface(material: tray)
            let ci = f.add(V3(0, y, 0), V3(0, up, 0), .zero)
            for p in ring { f.add(V3(p.x, y, p.y), V3(0, up, 0), p) }
            for i in 0..<UInt32(ring.count) { f.tri(ci, 1 + i, 1 + (i + 1) % UInt32(ring.count)) }
            CFKit.orient(&f) { _ in V3(0, up, 0) }
            m.add(f)
        }
        let rim = rings.last!.0.map { p -> V3 in
            let c = rings.last!.0.reduce(V2.zero, +) / Float(rings.last!.0.count)
            let q = p + simd_normalize(p - c) * 0.008
            return V3(q.x, yt + 0.004, q.y)
        }
        m.add(CFKit.loop(rim, radius: 0.012, sides: 8, material: tray))
        // Wheel: tire, rim and hub on an axle along Z.
        let tire = turned([(0.12, -0.04), (0.15, -0.045), (0.185, -0.04), (0.2, -0.015), (0.2, 0.015), (0.185, 0.04), (0.15, 0.045), (0.12, 0.04)],
                          segments: 36, material: "rubber.tire", seamTile: 0.2)
        let rimS = turned([(0.03, -0.05), (0.03, -0.035), (0.12, -0.03), (0.125, -0.04), (0.125, 0.04), (0.12, 0.03), (0.03, 0.035), (0.03, 0.05)],
                          segments: 24, material: "metal.painted:B8B9BA", seamTile: 0.2)
        let wx = Xform(translation: axle, rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)))
        var tireS = tire
        // Flip the profile winding to the outside of the torus: it runs inner to outer, then around.
        CFKit.orient(&tireS) { p in
            let r = simd_length(V2(p.x, p.z))
            return V3(p.x, 0, p.z) / max(r, 1e-4) * (r - 0.165) + V3(0, p.y, 0)
        }
        m.add(tireS, wx)
        m.add(rimS, wx)
        m.add(CFKit.pipe([V3(axle.x, axle.y, -0.08), V3(axle.x, axle.y, 0.08)], radius: 0.008, sides: 8, material: "metal.steel"))
        groundAO(&m, height: 0.25, floor: 0.6)
        return LODModel(m)
    }
}
