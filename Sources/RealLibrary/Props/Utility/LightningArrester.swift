import simd
import Foundation

/// 10 kV MCOV heavy-duty distribution surge arrester (PDV-100 class) for a 12.47 kV wye feeder: a stack
/// of metal-oxide blocks moulded into a gray silicone housing with nine sheds, stainless line terminal
/// stud on top with a flat washer and two hex nuts, and a ground stud below the base cap. The ground
/// stud carries the black isolator (disconnector) that blows off the bottom when the arrester fails.
public struct LightningArrester: RealAsset {
    public static let id = "lightning-arrester"
    public static let summary = "10 kV MCOV polymer-housed MOV distribution arrester: gray silicone housing with nine sheds, stainless line and ground studs with nuts."
    public static let tags = ["prop", "utility", "electrical", "handheld", "metal"]
    public static let budget = 12000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 10, distance: 1.2, studio: true)

    /// Number of sheds.
    public var sheds = 9
    /// Shed radius (m).
    public var shedRadius: Float = 0.063
    /// Housing core radius (m).
    public var coreRadius: Float = 0.029
    /// Housing length, base cap to top cap (m).
    public var housingLength: Float = 0.235
    /// Show the ground-lead isolator under the base.
    public var isolator = false
    public var housing: MaterialKey = "rubber.silicone-gray:5E646A"
    public var stud: MaterialKey = "metal.stainless"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let rc = coreRadius, R = shedRadius
        let studLen: Float = 0.055
        let base: Float = studLen + (isolator ? 0.0 : 0)
        let h0 = base, h1 = base + housingLength
        // Ground stud, isolator and washer under the base.
        if isolator {
            m.add(Prim.lathe([V2(0, 0.012), V2(0.012, 0.012), V2(0.0135, 0.016), V2(0.0135, 0.034), V2(0.011, 0.038), V2(0, 0.038)],
                             segments: 24, material: "plastic.matte:1E1E20"))
        }
        m.add(Prim.cylinder(radius: 0.0062, height: studLen + 0.004, bevel: 0.001, segments: 14, material: stud))
        for k in 0..<5 { m.add(Prim.torus(major: 0.0062, minor: 0.0008, segments: 14, sides: 4, material: stud), Xform(translation: V3(0, 0.004 + Float(k) * 0.0022, 0))) }
        m.add(Prim.cylinder(radius: 0.0115, height: 0.0055, bevel: 0.0012, segments: 6, material: stud), Xform(translation: V3(0, 0.04, 0)))
        m.add(Prim.cylinder(radius: 0.016, height: 0.0018, bevel: 0.0005, segments: 20, material: stud), Xform(translation: V3(0, 0.046, 0)))
        // Base end cap (aluminum) under the housing skirt.
        m.add(Prim.lathe([V2(0, h0 - 0.008), V2(0.02, h0 - 0.008), V2(0.024, h0 - 0.004), V2(0.024, h0 + 0.004), V2(0, h0 + 0.004)],
                         segments: 28, material: "metal.aluminum-cast"))
        // Housing: core with sheds; slightly thicker at the root, thin rim, drip-angled underside.
        var prof: [V2] = [V2(0, h0), V2(rc - 0.004, h0), V2(rc, h0 + 0.004)]
        let n = max(1, sheds)
        let pitch = (housingLength - 0.024) / Float(n - 1 > 0 ? n - 1 : 1)
        for i in 0..<n {
            let y = h0 + 0.006 + pitch * Float(i)
            let top = i == n - 1
            prof += [V2(rc, y - 0.003), V2(rc + 0.004, y - 0.0012), V2(R - 0.003, y + 0.0004), V2(R - 0.0005, y + 0.0012),
                     V2(R, y + 0.0028), V2(R - 0.0012, y + 0.0045), V2(R - 0.008, y + (top ? 0.0085 : 0.0068)), V2(rc + 0.008, y + (top ? 0.0165 : 0.0145)), V2(rc + 0.002, y + 0.0175), V2(rc, y + 0.0185)]
        }
        prof += [V2(rc - 0.004, h1), V2(0.018, h1 + 0.002), V2(0, h1 + 0.002)]
        m.add(Prim.lathe(prof, segments: 40, seamTile: 0.25, material: housing))
        // Top cap, line stud, washer, two nuts.
        m.add(Prim.lathe([V2(0, h1), V2(0.017, h1), V2(0.018, h1 + 0.003), V2(0.014, h1 + 0.006), V2(0, h1 + 0.006)],
                         segments: 28, material: "metal.aluminum-cast"))
        let ty = h1 + 0.006
        m.add(Prim.cylinder(radius: 0.0062, height: 0.055, bevel: 0.001, segments: 14, material: stud), Xform(translation: V3(0, ty, 0)))
        for k in 0..<12 { m.add(Prim.torus(major: 0.0062, minor: 0.0008, segments: 14, sides: 4, material: stud), Xform(translation: V3(0, ty + 0.022 + Float(k) * 0.0025, 0))) }
        m.add(Prim.cylinder(radius: 0.016, height: 0.0018, bevel: 0.0005, segments: 20, material: stud), Xform(translation: V3(0, ty + 0.004, 0)))
        m.add(Prim.cylinder(radius: 0.0115, height: 0.0055, bevel: 0.0012, segments: 6, material: stud), Xform(translation: V3(0, ty + 0.006, 0)))
        m.add(Prim.cylinder(radius: 0.0115, height: 0.0055, bevel: 0.0012, segments: 6, material: stud), Xform(translation: V3(0, ty + 0.016, 0), rotation: simd_quatf(angle: 0.3, axis: .up)))
        // Moulded rating band on the core between the two lowest sheds.
        m.add(Prim.lathe([V2(rc + 0.0006, h0 + 0.006), V2(rc + 0.0006, h0 + 0.014)], segments: 48, material: "rubber.silicone-gray:5A5F64"))
        groundAO(&m, height: 0.03, floor: 0.6)
        return LODModel(m)
    }
}
