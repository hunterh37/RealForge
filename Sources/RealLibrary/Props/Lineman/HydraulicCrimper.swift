import simd
import Foundation

/// Battery hydraulic utility crimper (12 ton pistol class, Huskie/Milwaukee style) standing on its 18 V
/// pack: a forged C head with a pair of crimp dies in the throat, the rotating head collar, the black
/// pump and motor housing with its vents, the rubber overmoulded pistol grip with trigger and retract
/// button, and the red-and-black battery. Head toward +X.
public struct HydraulicCrimper: RealAsset, RealHandTool {
    public static let id = "hydraulic-crimper"
    public static let summary = "Battery hydraulic crimper standing on its battery: C head with crimp dies, black pistol body, red 18V pack."
    public static let tags = ["prop", "tool", "handheld", "utility", "electrical", "plastic", "metal"]
    public static let budget = 12000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 15, distance: 1.0, studio: true)
    /// Palm on the pistol grip.
    public static let grip = SIMD3<Float>(-0.03, 0.14, 0)
    /// Centre of the die throat.
    public static let tip = SIMD3<Float>(0.19, 0.245, 0)

    /// Battery colour (sRGB hex).
    public var batteryColor: UInt32 = 0xC0201A
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let body: MaterialKey = "plastic.black", rub: MaterialKey = "rubber.cordless-grip"
        let red: MaterialKey = "plastic.resin-red:" + String(format: "%06X", batteryColor)
        let head: MaterialKey = "metal.anodized-worn:1E1F21", die: MaterialKey = "metal.steel"
        var levels: [Model] = []
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let sub = l == 0 ? 8 : 4
            // Battery pack: black base with a red top shell and latch.
            m.add(Prim.superellipsoid(V3(0.125, 0.04, 0.082), exponent: 6, subdivisions: sub, material: body), Xform(translation: V3(-0.03, 0.02, 0)))
            m.add(Prim.superellipsoid(V3(0.12, 0.042, 0.078), exponent: 6, subdivisions: sub, material: red), Xform(translation: V3(-0.03, 0.055, 0)))
            m.add(Prim.roundedBox(V3(0.02, 0.012, 0.04), radius: 0.003, bevelSegments: 1, material: body), Xform(translation: V3(-0.095, 0.06, 0)))
            // Foot under the grip that the pack slides onto.
            m.add(Prim.superellipsoid(V3(0.1, 0.03, 0.07), exponent: 5, subdivisions: sub, material: body), Xform(translation: V3(-0.025, 0.088, 0)))
            // Pistol grip: lofted, leaning back, rubber overmould.
            var rings: [[V3]] = []
            for i in 0...6 {
                let u = Float(i) / 6
                let c = V3(-0.035 + 0.03 * u, 0.095 + 0.1 * u, 0)
                rings.append(Shape2D.superellipse(0.05 - 0.006 * sin(u * .pi), 0.042, exponent: 2.6, segments: l == 0 ? 20 : 10).map { c + V3($0.x, 0, $0.y) })
            }
            m.add(Prim.loft(rings, capStart: true, capEnd: true, material: rub))
            // Trigger and retract button.
            m.add(Prim.roundedBox(V3(0.014, 0.034, 0.016), radius: 0.005, bevelSegments: 2, material: body), Xform(translation: V3(0.005, 0.165, 0), rotation: simd_quatf(angle: 0.2, axis: V3(0, 0, 1))))
            m.add(Prim.cylinder(radius: 0.006, height: 0.006, bevel: 0.0015, segments: 12, material: red), Xform(translation: V3(-0.015, 0.205, 0.024), rotation: simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))))
            // Pump and motor housing, horizontal over the grip.
            m.add(Prim.superellipsoid(V3(0.25, 0.085, 0.08), exponent: 3.2, subdivisions: sub + 2, material: body), Xform(translation: V3(-0.005, 0.23, 0)))
            for k in 0..<5 {
                m.add(Prim.roundedBox(V3(0.004, 0.03, 0.002), radius: 0.001, bevelSegments: 1, material: "plastic.matte:0E0E0E"),
                      Xform(translation: V3(-0.1 + Float(k) * 0.01, 0.235, 0.0395)))
            }
            // Rotating head collar and ram cylinder.
            m.add(Prim.lathe([V2(0.0, 0), V2(0.032, 0), V2(0.034, 0.004), V2(0.034, 0.03), V2(0.03, 0.034), V2(0.0, 0.034)], segments: l == 0 ? 28 : 12, seamTile: 0.1, material: head),
                  Xform(translation: V3(0.115, 0.23, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))))
            // C head: forged frame open at the top, viewed side-on (outline in x, y), 44 mm thick.
            var c: [V2] = []
            let hc = V2(0.19, 0.245)
            for i in 0...14 { let a = (-150 + Float(i) / 14 * 300) * .pi / 180; c.append(hc + V2(cos(a + .pi / 2) * -1, sin(a + .pi / 2)) * 0.05) }
            for i in 0...14 { let a = (150 - Float(i) / 14 * 300) * .pi / 180; c.append(hc + V2(cos(a + .pi / 2) * -1, sin(a + .pi / 2)) * 0.024) }
            m.add(Prim.extrude(Shape2D.rounded(c, radius: 0.004), depth: 0.044, bevel: 0.003, bevelSegments: 2, material: head))
            // Crimp dies: lower die on the ram, upper die in the head.
            m.add(Prim.roundedBox(V3(0.03, 0.016, 0.038), radius: 0.003, bevelSegments: 2, material: die), Xform(translation: hc + V2(0, -0.016) |> { V3($0.x, $0.y, 0) }))
            m.add(Prim.roundedBox(V3(0.03, 0.012, 0.038), radius: 0.003, bevelSegments: 2, material: die), Xform(translation: V3(hc.x - 0.004, hc.y + 0.022, 0), rotation: simd_quatf(angle: 0.5, axis: V3(0, 0, 1))))
            _ = rng.float()
            groundAO(&m, height: 0.06)
            levels.append(m)
        }
        return LODModel(levels: levels, switchDistances: [4])
    }
}

infix operator |> : AdditionPrecedence
func |> <A, B>(a: A, f: (A) -> B) -> B { f(a) }
