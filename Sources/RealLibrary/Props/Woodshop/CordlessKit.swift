import simd
import Foundation

/// Shared parts of the generic 18V cordless tool family (`cordless-drill`, `random-orbit-sander`, `jigsaw`):
/// teal glass-filled nylon with black trim, pebbled rubber overmold, slot vents, Torx clamshell screws and
/// the slide-on 18V 2 Ah battery pack (114 x 77 x 63 mm). Keep the three tools on these helpers so they
/// read as one family.
public enum CordlessKit {
    /// Family body color (sRGB hex) for `plastic.tool`.
    public static let bodyColor: UInt32 = 0x1E7F8C
    /// Family trim color (sRGB hex) for `plastic.tool`.
    public static let trimColor: UInt32 = 0x1A1A1B

    public static func tool(_ hex: UInt32) -> MaterialKey { "plastic.tool:" + String(format: "%06X", hex) }
    /// Scuffed, grimy variant for packs and feet.
    public static func worn(_ hex: UInt32) -> MaterialKey { "plastic.cordless-worn:" + String(format: "%06X", hex) }
    /// Main housing nylon with the molded stipple finish.
    public static func housing(_ hex: UInt32) -> MaterialKey { "plastic.cordless-stipple:" + String(format: "%06X", hex) }
    /// Pebbled rubber overmold.
    public static let grip: MaterialKey = "rubber.cordless-grip"
    /// Dark vent slot interiors and openings.
    public static let slot: MaterialKey = "plastic.matte:080809"
    /// Black-oxide screw heads.
    public static let screwKey: MaterialKey = "metal.anodized-black"

    /// Slide-on pack size: length (x, latch end +X), height with the rail tower (y), width (z).
    public static let pack = V3(0.114, 0.0625, 0.077)
    /// Height of the pack's shoulder (top of the teal band) where the tool foot sits.
    public static let packShoulder: Float = 0.0505

    // MARK: loft helpers

    /// Closed loop of `outline` in the plane spanned by `a`, `b` around `c`; lofts advance along `a x b`.
    public static func section(_ outline: [V2], _ c: V3, _ a: V3, _ b: V3) -> [V3] {
        outline.map { c + a * $0.x + b * $0.y }
    }

    /// Body of revolution about +X (`profile` as (x, radius)), optional ribs (count, depth) on the
    /// outside. Ends are capped.
    public static func spinX(_ profile: [V2], center: V3, segments n: Int, ribs: Int = 0, ribDepth: Float = 0,
                             ribRange: ClosedRange<Float>? = nil, capStart: Bool = true, capEnd: Bool = true, material: MaterialKey) -> Surface {
        let rings = profile.map { p -> [V3] in
            let ribbed = ribs > 0 && (ribRange?.contains(p.x) ?? true)
            return (0..<n).map { k in
                let a = Float(k) / Float(n) * 2 * .pi
                let r = p.y + (ribbed ? ribDepth * (0.5 + 0.5 * cos(Float(ribs) * a)) : 0)
                return V3(center.x + p.x, center.y + r * cos(a), center.z + r * sin(a))
            }
        }
        return Prim.loft(rings, capStart: capStart, capEnd: capEnd, material: material)
    }

    /// Cylinder along `dir` (unit) from `at`, length `h`, beveled.
    public static func rod(_ at: V3, _ dir: V3, radius: Float, length h: Float, bevel: Float = 0.0004, segments: Int = 12, material: MaterialKey) -> (Surface, Xform) {
        (Prim.cylinder(radius: radius, height: h, bevel: bevel, segments: segments, bevelSegments: 1, seamTile: 0.02, material: material),
         Xform(translation: at, rotation: facing(simd_normalize(dir))))
    }

    /// Torx clamshell screw head seated on a surface with outward `normal`.
    public static func screw(_ m: inout Model, at p: V3, normal: V3, radius: Float = 0.0027) {
        let q = facing(simd_normalize(normal))
        m.add(Prim.cylinder(radius: radius, height: 0.0013, bevel: 0.0006, segments: 10, bevelSegments: 1, bottomBevel: false, seamTile: 0.02, material: screwKey),
              Xform(translation: p - simd_normalize(normal) * 0.0003, rotation: q))
        m.add(Prim.extrude(Shape2D.polygon(sides: 6, radius: radius * 0.45), depth: 0.0003, bevel: 0, material: slot),
              Xform(translation: p + simd_normalize(normal) * 0.00095, rotation: q * simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
    }

    /// Row of vent slots: each slot `len` long along `along`, `width` wide, laid on a face with outward
    /// `normal`, spaced by `step` (vector). The slot face sits 0.25 mm proud of `start`.
    public static func vents(_ m: inout Model, start: V3, step: V3, count: Int, along: V3, normal: V3, len: Float, width: Float) {
        let n = simd_normalize(normal), u = simd_normalize(along)
        let v = simd_normalize(simd_cross(n, u))
        let basis = simd_quatf(simd_float3x3(columns: (u, n, -v)))
        for i in 0..<count {
            let c = start + step * Float(i)
            m.add(cuboid(V3(len, 0.0016, width), material: slot),
                  Xform(translation: c - n * 0.00055, rotation: basis))
        }
    }

    // MARK: battery

    /// 18V 2 Ah slide-on pack in its own frame: base on y = 0, latch end with the release button toward +X,
    /// rail tower on top (y 0.0495...0.0625), fuel gauge on the -X end, grip ribs and rating label on both
    /// sides, four rubber feet. `lite` drops the small details.
    public static func battery(lite: Bool, bodyColor: UInt32 = bodyColor) -> Model {
        var m = Model(name: "battery")
        let L = pack.x, W = pack.z
        let case0 = worn(trimColor), band = tool(bodyColor)
        // Lower case: black, slightly drafted, rounded.
        m.add(Prim.roundedBox(V3(L, 0.038, W), radius: 0.0075, bevelSegments: lite ? 1 : 2, material: case0), Xform(translation: V3(0, 0.0205, 0)))
        // Teal shoulder band.
        m.add(Prim.roundedBox(V3(L - 0.003, 0.0125, W - 0.003), radius: 0.0045, bevelSegments: 1, material: band), Xform(translation: V3(0, 0.0448, 0)))
        // Rail tower (slides into the tool foot).
        m.add(Prim.roundedBox(V3(0.082, 0.0142, 0.054), radius: 0.0028, bevelSegments: 1, material: case0), Xform(translation: V3(-0.012, 0.0555, 0)))
        // Release button on the latch end (rubber, ribbed).
        m.add(Prim.roundedBox(V3(0.0065, 0.013, 0.034), radius: 0.0022, bevelSegments: 1, material: "rubber"), Xform(translation: V3(L / 2 + 0.0012, 0.0425, 0)))
        // Pack feet.
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
            m.add(cuboid(V3(0.016, 0.0024, 0.010), material: "rubber"),
                  Xform(translation: V3(sx * (L / 2 - 0.015), 0.0011, sz * (W / 2 - 0.011))))
        }}
        if lite { return m }
        let slotK = slot
        for z: Float in [-0.0262, 0.0262] {   // rail grooves
            m.add(cuboid(V3(0.079, 0.0032, 0.0024), material: slotK), Xform(translation: V3(-0.012, 0.0548, z + (z > 0 ? 0.0005 : -0.0005))))
        }
        for z: Float in [-0.012, 0, 0.012] {  // terminal slots in the tower front
            m.add(cuboid(V3(0.0018, 0.008, 0.0024), material: slotK), Xform(translation: V3(0.0287, 0.0565, z)))
        }
        for k in 0..<4 {                       // release button ribs
            m.add(cuboid(V3(0.0012, 0.0011, 0.030), material: "rubber"),
                  Xform(translation: V3(L / 2 + 0.0047, 0.0378 + Float(k) * 0.0031, 0)))
        }
        // Fuel gauge: lens panel with three LED windows and a push button on the -X end.
        m.add(Prim.roundedBox(V3(0.0016, 0.011, 0.040), radius: 0.0006, bevelSegments: 1, material: "plastic.matte:2A2C2E"), Xform(translation: V3(-L / 2 - 0.0004, 0.025, 0)))
        for (i, z) in [Float(-0.014), -0.0075, -0.001].enumerated() {
            let (s, x) = rod(V3(-L / 2 - 0.0008, 0.025, z), V3(-1, 0, 0), radius: 0.0017, length: 0.0006, segments: 10,
                             material: i < 2 ? "emissive.led-green" : "plastic.matte:1C3322")
            m.add(s, x)
        }
        let (b, bx) = rod(V3(-L / 2 - 0.0008, 0.025, 0.012), V3(-1, 0, 0), radius: 0.0032, length: 0.0012, bevel: 0.0005, segments: 14, material: "rubber")
        m.add(b, bx)
        // Side grip ribs (rear half) and the rating label (front half).
        for sz: Float in [-1, 1] {
            for k in 0..<6 {
                m.add(cuboid(V3(0.0024, 0.024, 0.0026), material: grip),
                      Xform(translation: V3(-0.048 + Float(k) * 0.0068, 0.0205, sz * (W / 2 + 0.0004))))
            }
            m.add(Prim.roundedBox(V3(0.046, 0.017, 0.0012), radius: 0.0012, bevelSegments: 1, material: "plastic.matte:3B3D40"),
                  Xform(translation: V3(0.021, 0.021, sz * (W / 2 + 0.0002))))
            if sz > 0 {   // owner's masking-tape label, slightly crooked (story detail)
                m.add(cuboid(V3(0.030, 0.011, 0.0003), material: "paper.cordless-tape"),
                      Xform(translation: V3(-0.026, 0.026, W / 2 + 0.0019), rotation: simd_quatf(degrees: 4, axis: V3(0, 0, 1))))
            }
            m.add(cuboid(V3(0.012, 0.004, 0.0008), material: band),
                  Xform(translation: V3(0.008, 0.0255, sz * (W / 2 + 0.0008))))
        }
        return m
    }

    // MARK: rig utilities

    /// Flat disc of radius `r` (an opening, a mark, a lens) facing `normal`, 36 triangles.
    public static func disc(_ m: inout Model, at p: V3, normal: V3, radius r: Float, sides: Int = 10, material: MaterialKey) {
        m.add(Prim.extrude(Shape2D.circle(r, segments: sides), depth: 0.0003, bevel: 0, material: material),
              Xform(translation: p, rotation: facing(simd_normalize(normal)) * simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
    }

    /// Moves a whole rig (base, parts, pivots, lights) by `d`.
    public static func shift(_ rig: inout Rig, by d: V3) {
        let x = Xform(translation: d)
        for l in rig.base.indices { rig.base[l] = rig.base[l].transformed(x) }
        for i in rig.parts.indices {
            rig.parts[i].pivot.translation += d
            for l in rig.parts[i].levels.indices { rig.parts[i].levels[l] = rig.parts[i].levels[l].transformed(x) }
            for o in rig.parts[i].alternates.indices { for l in rig.parts[i].alternates[o].indices {
                rig.parts[i].alternates[o][l] = rig.parts[i].alternates[o][l].transformed(x)
            }}
        }
        for i in rig.lights.indices { rig.lights[i].position += d }
    }
}
