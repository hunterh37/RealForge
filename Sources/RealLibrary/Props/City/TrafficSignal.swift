import simd
import Foundation

/// Traffic signal on a mast arm: a tapered galvanized pole on a concrete pedestal with anchor bolts,
/// an 8 m tapered arm on a bolted flange, two hanging three-lamp heads with tunnel visors and
/// backplates, a pole-mounted head at driver height and a street name blade under the arm.
/// Asset bounds are centered (convention); the pole sits at x = -width/2 + 0.3.
public struct TrafficSignal: RealAsset {
    public static let id = "traffic-signal"
    public static let summary = "Traffic signal on a mast arm: galvanized pole, 8 m tapered arm, two hanging three-lamp heads with visors and backplates, a pole head and a street blade."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "metal", "light", "sign"]
    public static let budget = 15000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 8, distance: 1.0)

    /// Pole height (m).
    public var poleHeight: Float = 6.9
    /// Arm length from the pole axis (m) and its height at the pole (m).
    public var armLength: Float = 8.3
    public var armHeight: Float = 5.8
    /// Which lamp is lit on every head: 0 red, 1 amber, 2 green.
    public var phase = 0
    /// Street name on the arm blade.
    public var streetName = "ARCH ST"
    /// Materials.
    public var steel: MaterialKey = "metal.galvanized"
    public var aged: MaterialKey = "metal.galvanized-aged"
    public var pedestal: MaterialKey = "concrete.smooth"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Pedestal, base plate, anchor bolts and nuts.
        m.add(Prim.cylinder(radius: 0.33, height: 0.12, bevel: 0.015, segments: 28, material: pedestal))
        m.add(Prim.roundedBox(V3(0.46, 0.03, 0.46), radius: 0.008, bevelSegments: 1, material: aged), Xform(translation: V3(0, 0.135, 0)))
        for k in 0..<4 { let a = Float(k) * .pi / 2 + .pi / 4, p = V3(cos(a), 0, sin(a)) * 0.27
            m.add(Prim.cylinder(radius: 0.013, height: 0.09, bevel: 0.002, segments: 8, material: "metal.steel"), Xform(translation: p + V3(0, 0.15, 0)))
            hexBolt(&m, at: p + V3(0, 0.15, 0), normal: .up, size: 0.04, material: "metal.steel") }
        // Tapered pole with a cap; handhole near the base.
        m.add(turned([(0.0, 0.15), (0.17, 0.15), (0.165, 0.3), (0.15, poleHeight * 0.5), (0.125, poleHeight - 0.05), (0.13, poleHeight - 0.03), (0.08, poleHeight), (0, poleHeight)],
                     segments: 24, material: steel, seamTile: 0.3))
        m.add(Prim.roundedBox(V3(0.14, 0.24, 0.02), radius: 0.01, bevelSegments: 1, material: aged), Xform(translation: V3(0, 0.7, 0.165)))
        // Arm flange box and tapered arm rising 0.4 m to the tip.
        let ay = armHeight
        m.add(Prim.roundedBox(V3(0.08, 0.5, 0.36), radius: 0.01, bevelSegments: 1, material: aged), Xform(translation: V3(0.16, ay, 0)))
        for dy: Float in [-0.18, 0.18] { for dz: Float in [-0.13, 0.13] { hexBolt(&m, at: V3(0.2, ay + dy, dz), normal: V3(1, 0, 0), size: 0.03, material: "metal.steel") } }
        let arm = (0...10).map { i -> V3 in let t = Float(i) / 10; return V3(0.2 + t * (armLength - 0.2), ay + 0.4 * t * t, 0) }
        m.add(Prim.tube(arm, radii: arm.indices.map { 0.12 - 0.065 * Float($0) / 10 }, sides: 18, seamTile: 0.3, material: steel))
        // Tip cap.
        m.add(Prim.cylinder(radius: 0.056, height: 0.02, bevel: 0.006, segments: 16, material: aged),
              Xform(translation: arm.last!, rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        // Hanging heads with clamp hangers.
        func armY(_ x: Float) -> Float { let t = (x - 0.2) / (armLength - 0.2); return ay + 0.4 * t * t }
        for hx in [armLength * 0.5, armLength * 0.88] {
            let y = armY(hx)
            m.add(Prim.roundedBox(V3(0.12, 0.2, 0.14), radius: 0.015, bevelSegments: 1, material: "metal.signal-yellow"), Xform(translation: V3(hx, y - 0.18, 0)))
            m.add(Prim.torus(major: 0.13 - 0.065 * (hx - 0.2) / armLength + 0.01, minor: 0.012, segments: 18, sides: 6, material: aged),
                  Xform(translation: V3(hx, y, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
            citySignalHead(&m, at: Xform(translation: V3(hx, y - 0.86, 0.02), rotation: simd_quatf(angle: rng.float(-0.02...0.02), axis: .up)), lit: phase)
        }
        // Pole-mounted head at the near-side corner, on a side bracket.
        m.add(Prim.roundedBox(V3(0.1, 0.12, 0.26), radius: 0.01, bevelSegments: 1, material: "metal.signal-yellow"), Xform(translation: V3(0, 3.5, 0.24)))
        citySignalHead(&m, at: Xform(translation: V3(0, 3.5, 0.48)), lit: phase, backplate: false)
        // Street name blade hung under the arm.
        let bx = armLength * 0.25, by = armY(bx)
        for dx: Float in [-0.55, 0.55] {
            m.add(Prim.roundedBox(V3(0.04, 0.26, 0.04), radius: 0.008, bevelSegments: 1, material: aged), Xform(translation: V3(bx + dx, by - 0.2, 0)))
        }
        citySignPlate(&m, outline: Shape2D.roundedRect(1.8, 0.3, radius: 0.03, segments: 3), x: Xform(translation: V3(bx, by - 0.45, 0)),
                      thickness: 0.004, border: 0.015, face: "sign.green-worn", back: nil, twoSided: true,
                      text: [(streetName, V2(0, 0), 0.17, 0.7)])
        // Center the bounds on X/Z.
        let b = m.bounds
        let c = (b.min + b.max) / 2
        var out = Model(name: Self.id)
        out.add(m, Xform(translation: V3(-c.x, 0, -c.z)))
        groundAO(&out, height: 0.3, floor: 0.6)
        return LODModel(out)
    }
}
