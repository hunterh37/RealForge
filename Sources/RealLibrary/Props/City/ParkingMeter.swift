import simd
import Foundation

/// Single-space smart parking meter: a cast aluminum head with a domed acrylic window over the
/// display, coin slot, card slot, four keypad buttons and a solar cell on the crown, on a 60 mm steel
/// pipe post with a bolted base flange. Paint is scuffed where hands and bumpers reach.
public struct ParkingMeter: RealAsset {
    public static let id = "parking-meter"
    public static let summary = "Single-space parking meter: cast housing with a domed glass dome, coin slot and card reader on a steel pipe post."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "metal"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 10, distance: 1.1)

    /// Overall height (m).
    public var height: Float = 1.5
    /// Post outer radius (m).
    public var postRadius: Float = 0.03
    /// Head width, height, depth (m).
    public var head = V3(0.2, 0.36, 0.16)
    /// Housing paint, post, window, display.
    public var housing: MaterialKey = "metal.painted:6A7075"
    public var post: MaterialKey = "metal.painted:2E3134"
    public var window: MaterialKey = "glass.shelter"
    public var display: MaterialKey = "screen.bedside-lcd-off"
    public var trim: MaterialKey = "metal.steel"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let hy = height - head.y - 0.04
        // Base flange with four bolts, post, and the head saddle.
        m.add(Prim.cylinder(radius: 0.085, height: 0.012, bevel: 0.004, segments: 24, material: post))
        for k in 0..<4 { let a = Float(k) * .pi / 2 + .pi / 4
            hexBolt(&m, at: V3(cos(a) * 0.062, 0.012, sin(a) * 0.062), normal: .up, size: 0.014, material: trim) }
        m.add(Prim.cylinder(radius: postRadius, height: hy, bevel: 0.003, segments: 20, material: post))
        m.add(turned([(0, hy - 0.01), (0.045, hy - 0.01), (0.05, hy + 0.02), (0.06, hy + 0.04), (0, hy + 0.04)], segments: 20, material: housing))
        // Head: lower cash vault, upper mechanism with a sloped front.
        let hx = head.x, hd = head.z, y0 = hy + 0.04
        m.add(Prim.roundedBox(V3(hx, head.y * 0.45, hd), radius: 0.015, bevelSegments: 2, material: housing), Xform(translation: V3(0, y0 + head.y * 0.225, 0)))
        let side: [V2] = Shape2D.rounded([V2(-hd / 2, 0), V2(hd / 2, 0), V2(hd / 2 - 0.03, head.y * 0.55), V2(-hd / 2, head.y * 0.55)], radius: 0.014, segments: 3)
        var upper = Prim.extrude(side, depth: hx, bevel: 0.006, bevelSegments: 2, material: housing)
        upper = upper.transformed(Xform(rotation: simd_quatf(degrees: -90, axis: .up)))
        m.add(upper, Xform(translation: V3(0, y0 + head.y * 0.45 - 0.002, 0)))
        // Vault door seam and lock.
        m.add(cuboid(V3(hx - 0.03, 0.003, 0.002), material: "metal.steel:1A1A1A"), Xform(translation: V3(0, y0 + 0.02, hd / 2 + 0.0005)))
        m.add(Prim.cylinder(radius: 0.011, height: 0.008, bevel: 0.002, segments: 14, material: trim),
              Xform(translation: V3(0.06, y0 + head.y * 0.12, hd / 2), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Sloped face: domed window over the LCD, coin slot, card slot, keypad.
        let slope = atan2(0.03, head.y * 0.55)
        let faceX = Xform(translation: V3(0, y0 + head.y * 0.45, hd / 2), rotation: simd_quatf(angle: -slope, axis: V3(1, 0, 0)))
        let face = { (p: V3) in faceX.child(Xform(translation: p)) }
        m.add(Prim.roundedBox(V3(0.13, 0.075, 0.004), radius: 0.003, bevelSegments: 1, material: display), face(V3(0, 0.135, -0.001)))
        m.add(strokeText("0 45", height: 0.03, stroke: 0.005, depth: 0.0006, material: "plastic.black"), face(V3(0, 0.135, 0.0012)))
        var dome = Prim.superellipsoid(V3(0.15, 0.095, 0.022), exponent: 3, subdivisions: 6, material: window)
        dome = dome.transformed(Xform(translation: V3(0, 0.135, 0.0)))
        m.add(dome, faceX)
        m.add(Prim.roundedBox(V3(0.165, 0.11, 0.008), radius: 0.004, bevelSegments: 1, material: trim), face(V3(0, 0.135, -0.017)))
        m.add(Prim.roundedBox(V3(0.03, 0.006, 0.008), radius: 0.002, bevelSegments: 1, material: "metal.steel:101010"), face(V3(-0.045, 0.055, -0.006)))
        m.add(Prim.roundedBox(V3(0.05, 0.018, 0.012), radius: 0.003, bevelSegments: 1, material: "plastic.black"), face(V3(0.04, 0.055, -0.004)))
        m.add(cuboid(V3(0.036, 0.003, 0.004), material: "metal.steel:101010"), face(V3(0.04, 0.055, 0.0025)))
        for i in 0..<4 {
            m.add(Prim.cylinder(radius: 0.007, height: 0.005, bevel: 0.0015, segments: 10, material: i == 3 ? "plastic.resin-red" : "plastic.black"),
                  face(V3(-0.045 + Float(i) * 0.03, 0.025, -0.006)).child(Xform(rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)))))
        }
        // Blue P decal on the vault door.
        m.add(Prim.roundedBox(V3(0.07, 0.07, 0.0012), radius: 0.008, bevelSegments: 1, material: "sign.white"), Xform(translation: V3(0, y0 + head.y * 0.3, hd / 2 + 0.0006)))
        m.add(Prim.roundedBox(V3(0.062, 0.062, 0.0012), radius: 0.006, bevelSegments: 1, material: "sign.green:1E4FA0"), Xform(translation: V3(0, y0 + head.y * 0.3, hd / 2 + 0.0012)))
        m.add(strokeText("P", height: 0.042, stroke: 0.008, depth: 0.0008, material: "sign.white"), Xform(translation: V3(0, y0 + head.y * 0.3, hd / 2 + 0.0018)))
        // Crown: solar cell under glass, and a rain cap.
        let ty = y0 + head.y
        m.add(Prim.roundedBox(V3(hx + 0.01, 0.014, hd - 0.02), radius: 0.006, bevelSegments: 2, material: housing), Xform(translation: V3(0, ty + 0.002, -0.008)))
        m.add(Prim.roundedBox(V3(hx - 0.04, 0.003, hd - 0.06), radius: 0.001, bevelSegments: 1, material: "glass.signal-off"), Xform(translation: V3(0, ty + 0.0095, -0.008)))
        // Story detail: a pay-by-phone zone sticker on the side, slightly crooked.
        m.add(cuboid(V3(0.0008, 0.06, 0.09), material: "sign.green"), Xform(translation: V3(hx / 2 + 0.0004, y0 + head.y * 0.25, 0), rotation: simd_quatf(angle: rng.float(-0.08...0.08), axis: V3(1, 0, 0))))
        m.add(cuboid(V3(0.0009, 0.02, 0.06), material: "sign.white"), Xform(translation: V3(hx / 2 + 0.0006, y0 + head.y * 0.25, 0)))
        groundAO(&m, height: 0.25, floor: 0.6)
        return LODModel(m)
    }
}
