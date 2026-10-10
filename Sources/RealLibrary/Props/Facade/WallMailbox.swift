import simd
import Foundation

/// Wall-mounted mailbox: a 0.32 x 0.26 m galvanized-steel box with a hinged flap and slot, brass
/// number plate, a cylinder lock with key escutcheon, mounting flange with four screws and rain hood.
public struct WallMailbox: RealAsset {
    public static let id = "wall-mailbox"
    public static let summary = "Wall mailbox, 0.32 m: steel box, rain hood, hinged slot flap, brass number plate, cylinder lock."
    public static let tags = ["prop", "architecture", "facade", "metal", "urban"]
    public static let budget = 6_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 10, distance: 1.1)

    public var width: Float = 0.32
    public var height: Float = 0.26
    public var depth: Float = 0.1
    public var body: MaterialKey = "metal.painted:1E2A33"
    public var plate: MaterialKey = "metal.brass-aged"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, H = height, D = depth
        FA.box(&m, V3(W + 0.04, H + 0.04, 0.008), V3(0, H / 2, 0.004), "metal.galvanized-aged", r: 0.002)
        for (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)] as [(Float, Float)] { hexBolt(&m, at: V3(dx * (W / 2 + 0.005), H / 2 + dy * (H / 2 + 0.005), 0.009), normal: FA.Z, size: 0.01, material: "metal.screw-zinc") }
        FA.box(&m, V3(W, H, D), V3(0, H / 2, D / 2 + 0.004), body, r: 0.006)
        // Rain hood over the slot, angled.
        FA.box(&m, V3(W * 0.76, 0.012, 0.06), V3(0, H * 0.84, D + 0.025), body, r: 0.003, rot: FA.q(-14, FA.X))
        FA.box(&m, V3(W * 0.7, 0.008, 0.005), V3(0, H * 0.78, D + 0.01), "plastic.black", r: 0.001)    // slot shadow
        // Flap hinge barrel.
        FA.cylX(&m, r: 0.006, h: W * 0.7, at: V3(0, H * 0.82, D + 0.01), "metal.stainless", segments: 10)
        // Number plate and lock.
        FA.box(&m, V3(0.1, 0.05, 0.004), V3(0, H * 0.38, D + 0.01), plate, r: 0.002)
        for k in 0..<2 { FA.box(&m, V3(0.012, 0.028, 0.002), V3(-0.016 + Float(k) * 0.032, H * 0.38, D + 0.013), "plastic.black", r: 0.001) }
        FA.cylZ(&m, r: 0.018, h: 0.012, at: V3(0, H * 0.18, D + 0.006), "metal.brass", segments: 14)
        FA.box(&m, V3(0.004, 0.016, 0.003), V3(0, H * 0.18, D + 0.019), "plastic.black", r: 0.0005)
        // Door seam.
        FA.box(&m, V3(W - 0.04, 0.002, 0.002), V3(0, H * 0.62, D + 0.005), "plastic.black", r: 0.0005)
        groundAO(&m, height: 0.05, floor: 0.9)
        return LODModel(FA.centerZ(m))
    }
}
