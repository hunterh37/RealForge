import simd
import Foundation

/// Bus shelter, 4 x 1.6 m: brushed aluminum box-section frame on bolted base plates, a cantilevered
/// roof with a fascia band and gutter, clear polycarbonate back and end panels with frit dot bands,
/// a lit two-sided advertising panel closing the other end, a perch bench and a route sign.
public struct BusShelter: RealAsset {
    public static let id = "bus-shelter"
    public static let summary = "Bus shelter, 4 x 1.6 m: aluminium frame, clear polycarbonate side and back panels, cantilevered roof, perch bench and a lit advertising panel."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "metal", "glass", "furniture"]
    public static let budget = 13500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 12, distance: 1.0)

    /// Length (X), depth (Z), clear height (m).
    public var length: Float = 4.0
    public var depth: Float = 1.5
    public var height: Float = 2.45
    /// Route number on the sign.
    public var route = "42"
    /// Materials.
    public var frame: MaterialKey = "metal.aluminum-brushed"
    public var roof: MaterialKey = "metal.painted:3A3E42"
    public var glazing: MaterialKey = "glass.shelter"
    public var adLight: MaterialKey = "emissive.panel"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length, D = depth, H = height, ps: Float = 0.08, hx = L / 2, bz = -D / 2
        // Posts along the back (4) and two front posts at the ad-panel end.
        let backX: [Float] = [-hx, -hx / 3, hx / 3, hx]
        for x in backX {
            m.add(Prim.roundedBox(V3(ps, H, ps), radius: 0.008, bevelSegments: 1, material: frame), Xform(translation: V3(x, H / 2, bz)))
            m.add(Prim.roundedBox(V3(0.2, 0.012, 0.2), radius: 0.004, bevelSegments: 1, material: frame), Xform(translation: V3(x, 0.006, bz)))
            for k in 0..<4 { let a = Float(k) * .pi / 2 + .pi / 4; hexBolt(&m, at: V3(x + cos(a) * 0.07, 0.012, bz + sin(a) * 0.07), normal: .up, size: 0.018, material: "metal.steel") }
        }
        m.add(Prim.roundedBox(V3(ps, H, ps), radius: 0.008, bevelSegments: 1, material: frame), Xform(translation: V3(hx, H / 2, bz + 1.1)))
        // Roof: slab cantilevered forward, fascia band, gutter lip.
        let roofD = D + 0.15
        m.add(Prim.roundedBox(V3(L + 0.2, 0.08, roofD), radius: 0.015, bevelSegments: 2, material: roof), Xform(translation: V3(0, H + 0.04, bz + roofD / 2 - 0.1)))
        // Wired-glass roof lights between the purlins, and leaf litter caught on the roof.
        for i in 0..<3 {
            let cx = -hx + L / 6 + Float(i) * L / 3
            m.add(cuboid(V3(L / 3 - 0.2, 0.004, roofD - 0.3), material: "glass.signal-off"), Xform(translation: V3(cx, H + 0.081, bz + roofD / 2 - 0.1)))
        }
        for _ in 0..<12 {
            m.add(Prim.superellipsoid(V3(rng.float(0.04...0.07), 0.003, rng.float(0.03...0.05)), exponent: 2, subdivisions: 2, material: "leaf.oak"),
                  Xform(translation: V3(rng.float(-hx...hx), H + 0.086, bz + rng.float(0.05...(roofD - 0.2))), rotation: simd_quatf(angle: rng.float(0...6.28), axis: .up)))
        }
        m.add(Prim.roundedBox(V3(L + 0.22, 0.18, 0.03), radius: 0.008, bevelSegments: 1, material: roof), Xform(translation: V3(0, H + 0.03, bz + roofD - 0.085)))
        m.add(Prim.roundedBox(V3(L, 0.14, 0.012), radius: 0.003, bevelSegments: 1, material: "sign.white"), Xform(translation: V3(0, H + 0.03, bz + roofD - 0.068)))
        m.add(strokeText("BUS STOP", height: 0.1, stroke: 0.018, depth: 0.002, material: "metal.powdercoat:3A3E42").transformed(Xform(scale: V3(0.8, 1, 1))),
              Xform(translation: V3(-hx + 0.6, H + 0.03, bz + roofD - 0.061)))
        // Rails top and bottom along the back carrying the glazing.
        for y in [Float(0.12), H - 0.06] {
            m.add(Prim.roundedBox(V3(L, 0.05, 0.05), radius: 0.006, bevelSegments: 1, material: frame), Xform(translation: V3(0, y, bz)))
        }
        // Back glazing panels with a frit dot band at eye height.
        for i in 0..<3 {
            let x0 = backX[i], x1 = backX[i + 1], cx = (x0 + x1) / 2, w = x1 - x0 - ps
            m.add(cuboid(V3(w, H - 0.25, 0.01), material: glazing), Xform(translation: V3(cx, 0.12 + (H - 0.18) / 2, bz)))
            for k in 0..<Int(w / 0.06) {
                m.add(cuboid(V3(0.03, 0.03, 0.012), material: "sign.white:B8BCBE"), Xform(translation: V3(x0 + ps / 2 + 0.03 + Float(k) * 0.06, 1.45, bz)))
            }
        }
        // End glazing (open end, -X) on a short side rail.
        m.add(cuboid(V3(0.01, H - 0.6, 1.0), material: glazing), Xform(translation: V3(-hx, 0.4 + (H - 0.6) / 2, bz + 0.55)))
        m.add(Prim.roundedBox(V3(0.05, 0.05, 1.05), radius: 0.006, bevelSegments: 1, material: frame), Xform(translation: V3(-hx, H - 0.06, bz + 0.55)))
        // Ad panel: lit two-sided case closing the +X end.
        let ad = V3(0.16, 1.85, 1.2)
        m.add(Prim.roundedBox(ad, radius: 0.02, bevelSegments: 2, material: roof), Xform(translation: V3(hx, 0.2 + ad.y / 2, bz + 0.6)))
        for s: Float in [-1, 1] {
            m.add(cuboid(V3(0.004, ad.y - 0.12, ad.z - 0.12), material: adLight), Xform(translation: V3(hx + s * (ad.x / 2 + 0.001), 0.2 + ad.y / 2, bz + 0.6)))
            // Poster artwork blocks on the light box.
            m.add(cuboid(V3(0.003, 0.5, 0.8), material: "sign.red-worn:C44A1A"), Xform(translation: V3(hx + s * (ad.x / 2 + 0.004), 1.5, bz + 0.6)))
            m.add(strokeText("SALE", height: 0.16, stroke: 0.03, depth: 0.003, material: "sign.white").transformed(Xform(rotation: simd_quatf(angle: s * .pi / 2, axis: .up))),
                  Xform(translation: V3(hx + s * (ad.x / 2 + 0.006), 1.5, bz + 0.6)))
        }
        // Perch bench along the back.
        for x in [Float(-1.2), 0.2] {
            m.add(Prim.roundedBox(V3(0.05, 0.6, 0.05), radius: 0.006, bevelSegments: 1, material: frame), Xform(translation: V3(x, 0.3, bz + 0.2)))
        }
        m.add(Prim.roundedBox(V3(1.8, 0.04, 0.28), radius: 0.012, bevelSegments: 2, material: "metal.stainless"), Xform(translation: V3(-0.5, 0.62, bz + 0.2)))
        // Route sign on a flag bracket off the front post.
        let sp = V3(hx + 0.05, 2.1, bz + 1.1)
        m.add(Prim.roundedBox(V3(0.35, 0.04, 0.04), radius: 0.006, bevelSegments: 1, material: frame), Xform(translation: sp + V3(0.17, 0.2, 0)))
        citySignPlate(&m, outline: Shape2D.roundedRect(0.3, 0.42, radius: 0.03, segments: 3), x: Xform(translation: sp + V3(0.22, -0.05, 0), rotation: simd_quatf(degrees: 90, axis: .up)),
                      thickness: 0.004, border: 0.012, face: "sign.green:1E4FA0", back: nil, twoSided: true,
                      text: [("BUS", V2(0, 0.1), 0.07, 0.75), (route, V2(0, -0.06), 0.14, 0.8)])
        // Scuff: a sticker and grime line on the back glass.
        m.add(cuboid(V3(0.08, 0.05, 0.013), material: "sign.white:E8D070"), Xform(translation: V3(rng.float(-1.5...1.0), 1.1, bz), rotation: simd_quatf(angle: rng.float(-0.2...0.2), axis: V3(0, 0, 1))))
        groundAO(&m, height: 0.3, floor: 0.6)
        let b = m.bounds, c = (b.min + b.max) / 2
        var out = Model(name: Self.id); out.add(m, Xform(translation: V3(-c.x, 0, -c.z)))
        return LODModel(out)
    }
}
