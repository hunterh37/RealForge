import simd
import Foundation

/// Walnut knife block with five forged knives and a honing steel: the block leans back with a raked top,
/// slots cut across it, knives seated to their bolsters with riveted black POM handles out, the steel in
/// a round hole at the back. Front faces +Z.
public struct KnifeBlock: RealAsset {
    public static let id = "knife-block"
    public static let summary = "Walnut knife block with six forged knives and a honing steel: riveted handles, steel bolsters, angled slots."
    public static let tags = ["prop", "kitchen", "cookware", "wood", "metal", "tool"]
    public static let budget = 14000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 20, distance: 1.0, studio: true)

    /// Block width along X (m).
    public var width: Float = 0.15
    /// Block depth at the base (m).
    public var depth: Float = 0.23
    /// Height of the block's top front corner (m).
    public var height: Float = 0.27
    public var wood: MaterialKey = "wood.walnut-oiled"
    public var slotShadow: MaterialKey = "plastic.matte:141210"
    public var steel: MaterialKey = "metal.stainless"
    public init() {}

    /// Side outline (z, y): base, raked front, top, back.
    func outline() -> [V2] {
        let d = depth / 2
        return Shape2D.rounded([V2(-d, 0), V2(d, 0), V2(d, 0.032), V2(-0.01, height), V2(-d, height - 0.03)], radius: 0.006, segments: 3)
    }
    var frontDir: V2 { simd_normalize(V2(-0.01, height) - V2(depth / 2, 0.032)) }
    var topA: V2 { V2(-0.01, height) }
    var topB: V2 { V2(-depth / 2, height - 0.03) }

    func model(detail: Bool) -> Model {
        var m = Model(name: Self.id)
        // Block: side outline (z, y) extruded across X; rotating -90 about Y maps outline x to world z.
        let block = Prim.extrude(outline(), depth: width, bevel: 0.004, bevelSegments: detail ? 3 : 1, material: wood)
        m.add(block, Xform(rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 1, 0))))
        func world(_ q: V2, x: Float) -> V3 { V3(x, q.y, q.x) }
        let u2 = frontDir
        let u = simd_normalize(V3(0, u2.y, u2.x))            // knife axis, out of the top
        let w = V3(0, -u.z, u.y)                             // toward the front (spine side)
        let tTop = simd_normalize(world(topB - topA, x: 0)), xh = V3(1, 0, 0)
        let nTop = simd_cross(tTop, xh)
        let slotRot = simd_quatf(simd_float3x3(xh, nTop, tTop))
        func onTop(_ t: Float) -> V2 { topA + (topB - topA) * t }
        // Knives: (x, t along top, handle length, scale).
        // Six knives in two staggered rows: chef, bread, slicer in front; utility, two steak/paring behind.
        let knives: [(Float, Float, Float, Float)] = [(-0.045, 0.2, 0.125, 1.0), (0, 0.2, 0.122, 0.96), (0.045, 0.2, 0.118, 0.92),
                                                      (-0.045, 0.5, 0.108, 0.84), (0, 0.5, 0.096, 0.76), (0.045, 0.5, 0.096, 0.76)]
        for (x, t, hl, sc) in knives {
            var k = ChefKnife()
            k.handleLength = hl
            k.handleThickness = 0.019 * (0.85 + 0.15 * sc)
            let mouth = world(onTop(t), x: x)
            // Knife frame: -X out of the block (u), +Z toward the spine (w), +Y across (world X).
            let basis = simd_float3x3(-u, V3(1, 0, 0), w)
            let rot = simd_quatf(basis)
            let handle = k.handleParts(detail: false)
            m.add(handle, Xform(translation: mouth + u * 0.009 + w * (0.0125 * sc), rotation: rot, scale: V3(1, 1, sc)))
            // Slot mouth: dark recess where the blade enters, longer than the bolster.
            let slotLen = 0.046 * sc
            m.add(Prim.roundedBox(V3(0.0055, 0.0012, slotLen), radius: 0.0005, bevelSegments: 1, material: slotShadow),
                  Xform(translation: mouth + tTop * (slotLen / 2 - 0.012) + nTop * 0.0002, rotation: slotRot))
        }
        // Honing steel at the back: round hole, ring guard, black handle, hanging ring.
        let sp = world(onTop(0.82), x: -0.03)
        let su = u
        let hprof: [(Float, Float)] = [(0, -0.002), (0.0045, -0.002), (0.0045, 0.002), (0.016, 0.004), (0.016, 0.008), (0.009, 0.011),
                                       (0.0115, 0.04), (0.0125, 0.08), (0.0105, 0.105), (0.006, 0.112), (0, 0.113)]
        let sRot = simd_quatf(from: .up, to: su)
        m.add(turned(Array(hprof.prefix(5)) + [(0.0, 0.008)], segments: detail ? 24 : 12, material: steel), Xform(translation: sp, rotation: sRot))
        m.add(turned([(0, 0.008), (0.009, 0.008)] + Array(hprof.suffix(6)), segments: detail ? 24 : 12, material: "plastic.pom"),
              Xform(translation: sp, rotation: sRot))
        m.add(Prim.torus(major: 0.009, minor: 0.0016, segments: detail ? 20 : 10, sides: 6, material: steel),
              Xform(translation: sp + su * 0.122, rotation: sRot * simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))))
        m.add(Prim.cylinder(radius: 0.0062, height: 0.0012, bevel: 0.0004, segments: 16, material: slotShadow),
              Xform(translation: sp - su * 0.0008, rotation: sRot))
        // Lift onto felt feet and center the footprint.
        let b = m.bounds
        var out = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, 0.003, -(b.min.z + b.max.z) / 2)))
        for (fx, fz) in [(-0.055, -0.09), (0.055, -0.09), (-0.055, 0.09), (0.055, 0.09)] as [(Float, Float)] {
            out.add(Prim.cylinder(radius: 0.009, height: 0.003, bevel: 0.001, segments: 12, material: "fabric.wool:2A2622"),
                    Xform(translation: V3(fx, 0, fz - (b.min.z + b.max.z) / 2)))
        }
        groundAO(&out, height: 0.06, floor: 0.5)
        return out
    }

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(detail: true), model(detail: false)], switchDistances: [4])
    }
}
