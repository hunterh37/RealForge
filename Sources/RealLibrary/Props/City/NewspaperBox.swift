import simd
import Foundation

/// Coin-op newspaper vending box: a sheet-steel cabinet on a welded pedestal, a hinged window door
/// with a pull handle, a coin mechanism on the lid and a stack of papers behind the glass with the
/// masthead lettered on a header plate. Paint is chipped at the door edge and scuffed on the legs.
public struct NewspaperBox: RealAsset {
    public static let id = "newspaper-box"
    public static let summary = "Newspaper vending box: coin-op sheet-steel box with a window door, coin mechanism and a pedestal frame."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "metal", "container"]
    public static let budget = 5600
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 12, distance: 1.1)

    /// Cabinet width, height, depth (m).
    public var body = V3(0.5, 0.62, 0.44)
    /// Pedestal height (m).
    public var pedestal: Float = 0.36
    /// Masthead on the header plate.
    public var masthead = "DAILY NEWS"
    /// Body paint.
    public var paint: MaterialKey = "metal.painted:1F4E8C"
    public var frame: MaterialKey = "metal.painted:2A2C2E"
    public var glass: MaterialKey = "glass.shelter"
    public var steel: MaterialKey = "metal.steel"
    /// Window pane in the door.
    public var showGlass = true
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let w = body.x, h = body.y, d = body.z, y0 = pedestal
        // Pedestal: four square-tube legs on two skids.
        for sx: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.04, 0.03, d + 0.02), radius: 0.005, bevelSegments: 1, material: frame), Xform(translation: V3(sx * (w / 2 - 0.05), 0.015, 0)))
            for sz: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(0.03, y0 - 0.03, 0.03), radius: 0.004, bevelSegments: 1, material: frame),
                      Xform(translation: V3(sx * (w / 2 - 0.05), 0.03 + (y0 - 0.03) / 2, sz * (d / 2 - 0.06))))
            }
        }
        m.add(Prim.roundedBox(V3(w - 0.06, 0.025, 0.03), radius: 0.004, bevelSegments: 1, material: frame), Xform(translation: V3(0, 0.15, 0)))
        // Cabinet and lid with a slight overhang.
        // Cabinet: rear carcass plus a 7 cm deep front bay (cheeks, sill, head) that holds the papers.
        let bay: Float = 0.07
        m.add(Prim.roundedBox(V3(w, h, d - bay), radius: 0.012, bevelSegments: 2, material: paint), Xform(translation: V3(0, y0 + h / 2, -bay / 2)))
        for sx: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.03, h, bay + 0.01), radius: 0.008, bevelSegments: 1, material: paint), Xform(translation: V3(sx * (w / 2 - 0.015), y0 + h / 2, d / 2 - bay / 2)))
        }
        let doorBottom = y0 + h * 0.5 - h * 0.3, doorTop = y0 + h * 0.5 + h * 0.3
        m.add(Prim.roundedBox(V3(w - 0.02, doorBottom - y0, bay + 0.01), radius: 0.008, bevelSegments: 1, material: paint), Xform(translation: V3(0, (y0 + doorBottom) / 2, d / 2 - bay / 2)))
        m.add(Prim.roundedBox(V3(w - 0.02, y0 + h - doorTop, bay + 0.01), radius: 0.008, bevelSegments: 1, material: paint), Xform(translation: V3(0, (doorTop + y0 + h) / 2, d / 2 - bay / 2)))
        // Dark interior back of the bay.
        m.add(cuboid(V3(w - 0.05, doorTop - doorBottom, 0.002), material: "metal.painted:1A1C1E"), Xform(translation: V3(0, (doorTop + doorBottom) / 2, d / 2 - bay + 0.002)))
        m.add(Prim.roundedBox(V3(w + 0.02, 0.03, d + 0.02), radius: 0.01, bevelSegments: 2, material: paint), Xform(translation: V3(0, y0 + h + 0.015, 0)))
        // Door: raised frame, window, handle; papers behind.
        let dz = d / 2, dy = y0 + h * 0.5, dw = w - 0.06, dh = h * 0.6
        for (cx, cy, sx, sy) in [(Float(0), dy + dh / 2, dw, Float(0.04)), (0, dy - dh / 2, dw, 0.06), (-dw / 2 + 0.02, dy, 0.04, dh), (dw / 2 - 0.02, dy, 0.04, dh)] {
            m.add(Prim.roundedBox(V3(sx, sy, 0.016), radius: 0.005, bevelSegments: 1, material: paint), Xform(translation: V3(cx, cy, dz + 0.006)))
        }
        if showGlass { m.add(cuboid(V3(dw - 0.07, dh - 0.09, 0.003), material: glass), Xform(translation: V3(0, dy + 0.01, dz + 0.004))) }
        // Paper stack, front page with masthead and a photo block.
        let pw = dw - 0.12, ph = dh - 0.14
        m.add(Prim.roundedBox(V3(pw, ph, 0.03), radius: 0.003, bevelSegments: 1, material: "paper.sheet"), Xform(translation: V3(0, dy - 0.02, dz - 0.04), rotation: simd_quatf(degrees: -8, axis: V3(1, 0, 0))))
        let page = Xform(translation: V3(0, dy - 0.02, dz - 0.0245), rotation: simd_quatf(degrees: -8, axis: V3(1, 0, 0)))
        m.add(strokeText(masthead, height: 0.03, stroke: 0.005, depth: 0.0006, material: "plastic.black").transformed(Xform(scale: V3(0.75, 1, 1))), page.child(Xform(translation: V3(0, ph / 2 - 0.035, 0))))
        m.add(cuboid(V3(pw * 0.55, ph * 0.38, 0.0006), material: "metal.painted:6A7078"), page.child(Xform(translation: V3(-pw * 0.18, -0.01, 0))))
        for k in 0..<5 { m.add(cuboid(V3(pw * 0.32, 0.004, 0.0006), material: "metal.steel:3A3A3A"), page.child(Xform(translation: V3(pw * 0.28, 0.04 - Float(k) * 0.018, 0)))) }
        m.add(barHandle(length: 0.12, standoff: 0.025, radius: 0.007, material: steel), Xform(translation: V3(0, dy - dh / 2 - 0.0, dz + 0.014)))
        // Header plate with the masthead.
        m.add(Prim.roundedBox(V3(dw, 0.09, 0.008), radius: 0.004, bevelSegments: 1, material: "sign.white"), Xform(translation: V3(0, y0 + h - 0.05, dz + 0.004)))
        m.add(strokeText(masthead, height: 0.05, stroke: 0.009, depth: 0.001, material: "metal.painted:1F4E8C").transformed(Xform(scale: V3(0.72, 1, 1))), Xform(translation: V3(0, y0 + h - 0.05, dz + 0.008)))
        // Coin mechanism on the lid, front right: housing, slot, return button, price plate.
        let cy = y0 + h + 0.03
        m.add(Prim.roundedBox(V3(0.16, 0.11, 0.12), radius: 0.012, bevelSegments: 2, material: steel), Xform(translation: V3(w / 2 - 0.12, cy + 0.055, dz - 0.08)))
        m.add(cuboid(V3(0.004, 0.035, 0.004), material: "metal.steel:101010"), Xform(translation: V3(w / 2 - 0.15, cy + 0.07, dz - 0.019)))
        m.add(Prim.cylinder(radius: 0.012, height: 0.01, bevel: 0.003, segments: 12, material: "metal.chrome"), Xform(translation: V3(w / 2 - 0.09, cy + 0.07, dz - 0.02), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        m.add(cuboid(V3(0.1, 0.03, 0.002), material: "sign.white"), Xform(translation: V3(w / 2 - 0.12, cy + 0.03, dz - 0.019)))
        // Chipped paint at the door edge and scuffs on the front legs.
        for _ in 0..<8 {
            m.add(cuboid(V3(rng.float(0.005...0.018), rng.float(0.004...0.012), 0.001), material: "metal.rust"),
                  Xform(translation: V3(rng.float(-dw / 2...dw / 2), dy - dh / 2 + rng.float(-0.02...0.03), dz + 0.0145)))
        }
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
