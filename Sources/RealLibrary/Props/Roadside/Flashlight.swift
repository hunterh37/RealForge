import simd
import Foundation

/// D-cell flashlight: black anodized, lightly worn edges. Lies along +X on its barrel; knurled grip, tapered head with reflector and lens, tail cap button, lanyard ring.
public struct Flashlight: RealAsset {
    public static let id = "flashlight"
    public static let summary = "25 cm black anodized aluminum flashlight with knurled grip, tapered head with reflector and lens, tail cap switch and lanyard loop."
    public static let tags = ["prop", "tool", "light", "metal", "handheld"]
    public static let budget = 4800
    public static let author = "realityhd"

    /// Barrel radius in meters (D-cell tube).
    public var barrelRadius: Float = 0.0165
    /// Head outer radius at the bezel.
    public var headRadius: Float = 0.0275
    /// Barrel and head anodize.
    public var barrelMaterial = "metal.anodized-black"
    public var headMaterial = "metal.anodized-black"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let r = barrelRadius, R = headRadius
        // Built upright along +Y (tail at 0, bezel at 0.25) then laid on its side along +X.
        var parts = Model(name: Self.id)
        // Tail cap with a chamfer, then barrel, grip band, head flare.
        parts.add(turned([(0, 0), (r * 0.9, 0), (r * 1.05, 0.004), (r * 1.05, 0.02), (r, 0.022), (r, 0.058)], segments: 40, material: headMaterial, seamTile: 0.1))
        parts.add(turned([(r, 0.058), (r, 0.19), (r * 1.08, 0.194), (r * 1.08, 0.2)], segments: 40, material: barrelMaterial, seamTile: 0.1))
        // Knurled grip band.
        parts.add(turned([(r * 1.002, 0.075), (r * 1.03, 0.077), (r * 1.03, 0.165), (r * 1.002, 0.167)], segments: 40, material: "metal.knurl-chrome:151515", seamTile: 0.05))
        // Head: tapered flare, bezel lip, hollow with cone reflector.
        let head: [(Float, Float)] = [(r * 1.08, 0.2), (r * 1.15, 0.206), (R * 0.82, 0.218), (R, 0.236), (R * 1.04, 0.241), (R * 1.04, 0.25),
                                       (R * 0.93, 0.25), (R * 0.93, 0.2475)]
        parts.add(turned(head, segments: 48, material: headMaterial, seamTile: 0.1))
        // Reflector cone + hot spot.
        parts.add(turned([(R * 0.93, 0.2475), (R * 0.9, 0.246), (R * 0.45, 0.224), (R * 0.1, 0.22), (0, 0.22)], segments: 48, material: "metal.chrome", seamTile: 0.05))
        parts.add(Prim.cylinder(radius: R * 0.1, height: 0.004, bevel: 0.0005, segments: 12, material: "emissive.warm"), Xform(translation: V3(0, 0.219, 0)))
        // Worn bare-aluminum edges: bezel rim, head-to-barrel shoulder, tail chamfer.
        parts.add(turned([(R * 1.04, 0.2415), (R * 1.041, 0.25), (R * 0.985, 0.25), (R * 0.985, 0.2415)], segments: 48, material: "metal.aluminum-brushed", seamTile: 0.05))
        parts.add(turned([(r * 1.081, 0.1985), (r * 1.16, 0.2065), (r * 1.14, 0.2085), (r * 1.075, 0.2)], segments: 40, material: "metal.aluminum-brushed", seamTile: 0.05))
        parts.add(turned([(r * 0.9, -0.0004), (r * 1.052, 0.0036), (r * 1.052, 0.0055), (r * 0.9, 0.0015)], segments: 40, material: "metal.aluminum-brushed", seamTile: 0.05))
        // Lens.
        parts.add(Prim.cylinder(radius: R * 0.93, height: 0.0016, bevel: 0.0004, segments: 48, material: "glass.clear"), Xform(translation: V3(0, 0.2466, 0)))
        // Tail switch boot and lanyard ring.
        parts.add(turned([(0, 0.0), (r * 0.5, 0.0), (r * 0.52, 0.006), (r * 0.4, 0.0105), (0, 0.0105)], segments: 24, material: "rubber.silicone"), Xform(translation: V3(0, -0.0105 + 0.0105, 0)))
        parts.add(Prim.torus(major: r * 0.5, minor: 0.0014, segments: 24, sides: 8, material: "metal.steel"),
                  Xform(translation: V3(0, 0.002, r * 1.05), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        m.add(parts, Xform(translation: V3(-0.125, R * 1.04, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        groundAO(&m, height: 0.04, floor: 0.5)
        return LODModel(m)
    }
}
