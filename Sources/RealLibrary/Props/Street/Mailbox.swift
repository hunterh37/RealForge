import simd
import Foundation

public struct Mailbox: RealAsset {
    public static let id = "mailbox"
    public static let summary = "US-style curbside mailbox on a wooden post: tunnel body, door, red flag."
    public static let tags = ["prop", "urban", "metal"]
    public static let budget = 6_000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let paint: MaterialKey = "metal.painted:2A2C30"
        m.add(plank(1.05, 0.1, 0.1, bevel: 0.008, material: "wood.weathered"), Xform(translation: V3(0, 0.525, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        m.add(plank(0.5, 0.2, 0.02, bevel: 0.004, material: "wood.weathered"), Xform(translation: V3(0, 1.06, 0), rotation: simd_quatf(degrees: 90, axis: .up)))
        // Tunnel: box bottom half + half-cylinder top, along Z.
        let L: Float = 0.48, W: Float = 0.17
        m.add(Prim.roundedBox(V3(W, 0.11, L), radius: 0.008, material: paint), Xform(translation: V3(0, 1.07 + 0.055, 0)))
        var arch: [(Float, Float)] = []
        for i in 0...10 { let a = Float(i) / 10 * .pi; arch.append((W / 2 * cos(a), W / 2 * sin(a))) }
        // Half cylinder as a tube along Z (sides chosen so the tube's lower half hides in the box).
        m.add(Prim.tube([V3(0, 1.18, -L / 2), V3(0, 1.18, L / 2)], radii: [W / 2 - 0.001, W / 2 - 0.001], sides: 24, seamTile: 0.3, material: paint, capEnd: true))
        m.add(turned([(0, 0), (W / 2 - 0.001, 0), (W / 2 - 0.001, 0.004), (0, 0.004)], segments: 24, material: paint), Xform(translation: V3(0, 1.18, -L / 2), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
        // Flag.
        m.add(Prim.roundedBox(V3(0.01, 0.2, 0.03), radius: 0.003, material: "metal.painted:B8261C"), Xform(translation: V3(W / 2 + 0.01, 1.2, 0.05)))
        m.add(Prim.roundedBox(V3(0.01, 0.06, 0.08), radius: 0.003, material: "metal.painted:B8261C"), Xform(translation: V3(W / 2 + 0.01, 1.28, 0.08)))
        _ = arch
        return LODModel(m)
    }
}
