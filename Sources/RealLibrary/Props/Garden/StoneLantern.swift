import simd
import Foundation

/// Kasuga-style granite garden lantern (kasuga-doro), 1.5 m: hexagonal foundation with a sloped top
/// (kiso), round post with carved bands (sao), hexagonal platform with lotus petals (chudai), six-post
/// light box with open windows front and back and moon reliefs on the sides (hibukuro), six-sided roof
/// with upturned warabi corners (kasa), lotus collar and jewel finial (hoju). Weathered moss-capped
/// granite throughout; seeds vary proportions, lean and roof rotation.
public struct StoneLantern: RealAsset {
    public static let id = "stone-lantern"
    public static let summary = "Kasuga-style granite garden lantern, 1.5 m: hexagonal base, round shaft, carved light box with openings, curved roof, jewel finial."
    public static let tags = ["prop", "garden", "stone", "decor"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 10, distance: 1.1, studio: true)

    public var stone: MaterialKey = "stone.granite-moss"
    /// Roof eave radius to the corner tips (m).
    public var roofRadius: Float = 0.31
    /// Upturn of the roof corners (m).
    public var curl: Float = 0.065
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let s = stone
        func hex(_ r: Float) -> [V2] { (0..<6).map { k in let a = Float(k) * .pi / 3; return V2(cos(a) * r, sin(a) * r) } }
        func ringW(_ r: Float, _ y: Float, per: Int = 1, lift: ((Float) -> Float)? = nil) -> [V3] {
            var out: [V3] = []
            for k in 0..<6 { for j in 0..<per {
                let t = Float(j) / Float(per)
                let a0 = Float(k) * .pi / 3, a1 = Float(k + 1) * .pi / 3
                let p = simd_mix(V2(cos(a0), sin(a0)), V2(cos(a1), sin(a1)), V2(repeating: t)) * r
                let c = pow(abs(2 * t - 1), 3)          // 1 at corners, 0 mid-edge
                out.append(V3(p.x, y + (lift?(c) ?? 0), -p.y))
            }}
            return out
        }
        func prism(_ outline: [V2], y0: Float, h: Float, bevel: Float = 0.012) {
            m.add(Prim.extrude(Shape2D.rounded(outline, radius: 0.012, segments: 2), depth: h, bevel: bevel, bevelSegments: 2, material: s),
                  Xform(translation: V3(0, y0 + h / 2, 0), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
        }
        // Kiso: hexagonal foundation with a sloped, lotus-banded top.
        let kr = rng.vary(0.27, 0.03)
        prism(hex(kr), y0: 0, h: 0.13, bevel: 0.02)
        m.add(Prim.loft([ringW(kr - 0.012, 0.125, per: 2), ringW(kr * 0.82, 0.17, per: 2), ringW(kr * 0.66, 0.195, per: 2), ringW(kr * 0.64, 0.205, per: 2)],
                        capEnd: true, material: s))
        // Sao: post with slight entasis and two carved bands.
        let postTop: Float = 0.68
        m.add(turned([(0.09, 0.2), (0.093, 0.24), (0.088, 0.45), (0.08, postTop - 0.02), (0.088, postTop)], segments: 28, material: s))
        for y: Float in [0.36, 0.5] {
            m.add(Prim.torus(major: 0.09, minor: 0.011, segments: 28, sides: 8, material: s), Xform(translation: V3(0, y, 0)))
        }
        // Chudai: hexagonal platform flaring out, lotus petals on the slope.
        m.add(Prim.loft([ringW(0.095, postTop - 0.005, per: 2), ringW(0.16, postTop + 0.04, per: 2), ringW(0.215, postTop + 0.075, per: 2),
                         ringW(0.225, postTop + 0.085, per: 2), ringW(0.225, postTop + 0.115, per: 2), ringW(0.205, postTop + 0.125, per: 2)],
                        capEnd: true, material: s))
        for k in 0..<12 {
            let a = Float(k) / 12 * 2 * .pi + .pi / 12
            let dir = V3(cos(a), 0, -sin(a))
            let petal = Prim.superellipsoid(V3(0.07, 0.05, 0.022), exponent: 2.4, subdivisions: 3, material: s)
            m.add(petal, Xform(translation: dir * 0.15 + V3(0, postTop + 0.04, 0), rotation: simd_quatf(from: V3(0, 0, 1), to: dir) * simd_quatf(degrees: -48, axis: V3(1, 0, 0))))
        }
        // Hibukuro: rails, six corner posts, side panels with moon reliefs, open windows on +-Z.
        let boxY = postTop + 0.125, boxH: Float = 0.29, hr: Float = 0.15
        prism(hex(hr + 0.01), y0: boxY, h: 0.04)
        prism(hex(hr + 0.012), y0: boxY + boxH - 0.04, h: 0.04)
        for k in 0..<6 {
            let a = Float(k) * .pi / 3
            let p = V3(cos(a), 0, -sin(a)) * (hr - 0.012)
            m.add(Prim.roundedBox(V3(0.05, boxH - 0.07, 0.05), radius: 0.008, bevelSegments: 2, material: s),
                  Xform(translation: p + V3(0, boxY + boxH / 2, 0), rotation: simd_quatf(angle: a, axis: .up)))
        }
        for k in [0, 2, 3, 5] {
            let a = (Float(k) + 0.5) * .pi / 3
            let dir = V3(cos(a), 0, -sin(a))
            let face = hr * cos(.pi / 6)
            let rot = simd_quatf(from: V3(0, 0, 1), to: dir)
            m.add(Prim.roundedBox(V3(hr * 0.86, boxH - 0.08, 0.035), radius: 0.006, bevelSegments: 1, material: s),
                  Xform(translation: dir * (face - 0.03) + V3(0, boxY + boxH / 2, 0), rotation: rot))
            if k == 0 || k == 3 {
                // Crescent moon relief: a disc with a smaller disc cut by offsetting a recessed one.
                m.add(Prim.cylinder(radius: 0.045, height: 0.008, bevel: 0.003, segments: 20, bevelSegments: 1, material: s),
                      Xform(translation: dir * (face - 0.014) + V3(0, boxY + boxH / 2, 0), rotation: rot * simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            }
        }
        // Dark floor of the light chamber (old soot) seen through the windows.
        prism(hex(hr - 0.02), y0: boxY + 0.03, h: 0.012, bevel: 0.004)
        // Kasa: six-sided roof, eave thickness, concave slope, warabi corners curling up.
        let roofY = boxY + boxH
        let R = roofRadius, c = curl
        let roof = [ringW(0.15, roofY, per: 4), ringW(R * 0.8, roofY - 0.002, per: 4, lift: { $0 * c * 0.3 }),
                    ringW(R, roofY + 0.0, per: 4, lift: { $0 * c }), ringW(R, roofY + 0.036, per: 4, lift: { $0 * c * 1.05 }),
                    ringW(R * 0.8, roofY + 0.072, per: 4, lift: { $0 * c * 0.45 }), ringW(R * 0.5, roofY + 0.13, per: 4, lift: { $0 * c * 0.1 }),
                    ringW(0.085, roofY + 0.19, per: 4), ringW(0.07, roofY + 0.2, per: 4)]
        var roofSurface = Prim.loft(roof, capStart: true, capEnd: true, material: s)
        let yaw = rng.float(-4...4)
        roofSurface = roofSurface.transformed(Xform(rotation: simd_quatf(degrees: yaw, axis: .up)))
        m.add(roofSurface)
        // Hoju: lotus collar and pointed jewel.
        let jy = roofY + 0.2
        m.add(turned([(0, jy - 0.005), (0.06, jy - 0.005), (0.068, jy + 0.015), (0.055, jy + 0.035), (0.042, jy + 0.045), (0.05, jy + 0.06),
                      (0.072, jy + 0.1), (0.074, jy + 0.13), (0.06, jy + 0.165), (0.032, jy + 0.195), (0.012, jy + 0.21), (0, jy + 0.215)],
                     segments: 28, material: s))
        // Settle: a slight lean from frost heave.
        let lean = rng.float(-0.8...0.8)
        m = m.transformed(Xform(rotation: simd_quatf(degrees: lean, axis: V3(1, 0, 0.3))))
        let bb = m.bounds
        m = m.transformed(Xform(translation: V3(0, -bb.min.y - 0.004, 0)))
        groundAO(&m, height: 0.25, floor: 0.5)
        return LODModel(m)
    }
}
