import simd
import Foundation

/// Geometry helpers shared by the woodshop saws (blade-plane slabs, axis cylinders, arcs).
enum SawGeo {
    static let flat = simd_quatf(angle: -.pi / 2, axis: V3(1, 0, 0))     // extrude depth -> +Y, outline (x, -z)
    static let toYZ = simd_quatf(angle: -.pi / 2, axis: V3(0, 1, 0))     // extrude depth -> X, outline (z, y)
    static let alongX = simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))   // +Y -> +X
    static let alongZ = simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))    // +Y -> +Z

    /// Point on a circle of radius `r` around `c` at `deg` (0 = +first axis, 90 = +second axis).
    static func pol(_ c: V2, _ r: Float, _ deg: Float) -> V2 { c + V2(cos(radians(deg)), sin(radians(deg))) * r }
    static func arc(_ c: V2, _ r: Float, _ a0: Float, _ a1: Float, _ n: Int) -> [V2] {
        (0...n).map { pol(c, r, a0 + (a1 - a0) * Float($0) / Float(n)) }
    }
    /// Slab from an outline in world (x, z), between heights y0 and y1.
    static func slabXZ(_ pts: [V2], _ y0: Float, _ y1: Float, bevel: Float, seg: Int = 2, _ mat: MaterialKey) -> (Surface, Xform) {
        (Prim.extrude(pts.map { V2($0.x, -$0.y) }, depth: y1 - y0, bevel: bevel, bevelSegments: seg, material: mat),
         Xform(translation: V3(0, (y0 + y1) / 2, 0), rotation: flat))
    }
    /// Slab from an outline in world (z, y), between x0 and x1.
    static func slabYZ(_ pts: [V2], _ x0: Float, _ x1: Float, bevel: Float, seg: Int = 2, _ mat: MaterialKey) -> (Surface, Xform) {
        (Prim.extrude(pts, depth: abs(x1 - x0), bevel: bevel, bevelSegments: seg, material: mat),
         Xform(translation: V3((x0 + x1) / 2, 0, 0), rotation: toYZ))
    }
    /// Slab from an outline in world (x, y), between z0 and z1.
    static func slabXY(_ pts: [V2], _ z0: Float, _ z1: Float, bevel: Float, seg: Int = 2, _ mat: MaterialKey) -> (Surface, Xform) {
        (Prim.extrude(pts, depth: abs(z1 - z0), bevel: bevel, bevelSegments: seg, material: mat),
         Xform(translation: V3(0, 0, (z0 + z1) / 2)))
    }
    /// Cylinder along X from x0 to x1 through (y, z).
    static func cylX(_ r: Float, _ x0: Float, _ x1: Float, y: Float, z: Float, bevel: Float = 0.001, seg: Int = 20, _ mat: MaterialKey) -> (Surface, Xform) {
        (Prim.cylinder(radius: r, height: x1 - x0, bevel: bevel, segments: seg, bevelSegments: 1, material: mat),
         Xform(translation: V3(x0, y, z), rotation: alongX))
    }
    /// Cylinder along Z from z0 to z1 through (x, y).
    static func cylZ(_ r: Float, _ z0: Float, _ z1: Float, x: Float, y: Float, bevel: Float = 0.001, seg: Int = 20, _ mat: MaterialKey) -> (Surface, Xform) {
        (Prim.cylinder(radius: r, height: z1 - z0, bevel: bevel, segments: seg, bevelSegments: 1, material: mat),
         Xform(translation: V3(x, y, z0), rotation: alongZ))
    }
    /// Rotates `p` by `deg` about the line through `pivot` along `axis`.
    static func rotate(_ p: V3, about pivot: V3, axis: V3, _ deg: Float) -> V3 {
        pivot + simd_quatf(angle: radians(deg), axis: simd_normalize(axis)).act(p - pivot)
    }
    /// Concentric (radial grind) UVs for a disc built in its local XY plane.
    static func radialUV(_ s: inout Surface) {
        for i in s.positions.indices {
            let p = s.positions[i], r = simd_length(V2(p.x, p.y))
            s.uvs[i] = V2(atan2(p.y, p.x) * max(r, 0.01), r)
        }
        s.computeTangents()
    }
    /// Toothed saw plate outline: `n` hook teeth with gullets, tip radius `rp`.
    static func toothed(_ n: Int, _ rp: Float, mirror: Bool = false) -> [V2] {
        var o: [V2] = []
        let p = 360 / Float(n)
        for k in 0..<n {
            let a = Float(k) * p
            o += [pol(.zero, rp, a), pol(.zero, rp - 0.003, a + 0.22 * p), pol(.zero, rp - 0.0095, a + 0.6 * p), pol(.zero, rp - 0.0068, a + 0.92 * p)]
        }
        return mirror ? o.map { V2($0.x, -$0.y) } : o
    }
    /// Carbide tips for a toothed plate, in the plate's local XY frame (depth along Z).
    static func carbide(_ n: Int, _ rTip: Float, kerf: Float, mirror: Bool = false, _ mat: MaterialKey) -> Surface {
        var s = Surface(material: mat)
        let p = 360 / Float(n)
        for k in 0..<n {
            let a = (Float(k) * p + 0.05 * p) * (mirror ? -1 : 1)
            s.append(cuboid(V3(0.0045, 0.0026, kerf), material: mat),
                     Xform(translation: V3(pol(.zero, rTip - 0.00225, a), 0), rotation: simd_quatf(angle: radians(a), axis: V3(0, 0, 1))))
        }
        return s
    }
}

/// 10-inch (254 mm) compound miter saw, non-sliding, 0.5 m wide with extension wings, 0.5 m tall with the
/// arm raised. Die-cast base on four bench-mount ears, ground side tables, a rotating turntable with a
/// kerf insert, front miter arm with lock handle, detent release and a scale with detent notches; a tall
/// two-piece fence; rear trunnion with bevel scale, pointer and lock knob; pivot arm with motor, D-handle
/// (trigger and lock-off), fixed upper guard with rotation arrow, clear lower guard, dust port and bag,
/// hold-down post holes and a power cord to a plug on the bench.
///
/// Frame (asset space): operator at +Z, base on y = 0. The fence runs along X; its front face is
/// `fenceZ`. Table top is `tableY`. At miter 0 / bevel 0 the blade plane is YZ at x = 0 with the arbor
/// along X. Rig chain: `miter` (hinge +Y about `turntableCenter`, `miterRange`; positive swings the front
/// handle toward +X) > `bevel` (hinge +Z about `bevelPivot`, `bevelRange`; positive tilts the blade top
/// toward -X) > `arm` (hinge -X about `armPivot`, `armRange`; 0 = raised rest, negative lowers) >
/// `blade` (hinge +X through the arbor, 0...360, increasing turns the front teeth downward, the real cut
/// direction), `trigger` (0...14, 14 = pulled) and `lower-guard` (mimics `arm`, retracts into the upper guard).
public struct MiterSaw: RealArticulated {
    public static let id = "miter-saw"
    public static let summary = "10 in compound miter saw: die-cast base and wings, turntable with miter scale, two-piece fence, bevel pivot, D-handle arm, carbide blade, dust bag."
    public static let tags = ["prop", "workshop", "tool", "metal", "articulated"]
    public static let budget = 15000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 32, elevation: 20, distance: 1.1, studio: true)

    /// Table top height above the base underside (m).
    public var tableY: Float = 0.095
    /// Fence front face z (m). The turntable rotates about (0, tableY, fenceZ).
    public var fenceZ: Float = -0.01
    /// Blade radius to the carbide tips (254 mm blade).
    public var bladeRadius: Float = 0.127
    /// Cut width (carbide tip width), m.
    public var kerf: Float = 0.0030
    /// Turntable radius (m).
    public var turntableRadius: Float = 0.146
    /// Fence height above the table (m).
    public var fenceHeight: Float = 0.085
    /// Arm travel from the raised rest to full plunge (degrees).
    public var armTravel: Float = 41
    /// Number of carbide teeth on the blade.
    public var teeth: Int = 36
    /// Livery body color (motor housing, handle), sRGB hex. Teal 0x1E7F8C also fits.
    public var bodyColor: UInt32 = 0xF2B705
    /// Trim color (handles, inserts, knobs), sRGB hex.
    public var trimColor: UInt32 = 0x1A1A1B
    public init() {}

    // MARK: game contract

    /// Arm joint range (degrees): 0 = raised rest, `-armTravel` = full plunge through a 2x6 into the kerf slot.
    public var armRange: ClosedRange<Float> { -armTravel...0 }
    /// Miter joint range (degrees). Positive swings the front handle toward +X.
    public var miterRange: ClosedRange<Float> { -50...50 }
    /// Bevel joint range (degrees). Positive tilts the blade top toward -X (left).
    public var bevelRange: ClosedRange<Float> { 0...45 }
    /// Positive-stop miter detents (degrees), matching the notches on the scale.
    public var miterDetents: [Float] { [-45, -31.6, -22.5, -15, 0, 15, 22.5, 31.6, 45] }
    /// Turntable rotation center on the table top.
    public var turntableCenter: V3 { V3(0, tableY, fenceZ) }
    /// A point on the bevel axis (axis along Z through x = 0 at table height, behind the fence).
    public var bevelPivot: V3 { V3(0, tableY, fenceZ - 0.155) }
    /// Arm hinge point (axis along X), at rest.
    public var armPivot: V3 { V3(0, tableY + 0.15, fenceZ - 0.145) }
    /// Arbor center at full plunge (arm = -armTravel, miter 0, bevel 0): blade bottom 24 mm below the table.
    public var plungeArbor: V3 { V3(0, tableY + 0.103, fenceZ + 0.07) }
    /// Arbor center at rest (arm raised).
    public var arborRest: V3 { SawGeo.rotate(plungeArbor, about: armPivot, axis: V3(-1, 0, 0), armTravel) }
    /// Top-of-table surface (side tables and wings) as an XZ rectangle at y = tableY.
    public var tableBounds: (min: V2, max: V2) { (V2(-0.25, fenceZ - 0.065), V2(0.25, fenceZ + 0.135)) }
    /// D-handle grip center at rest (where the operator's hand closes).
    public var gripRest: V3 { V3(0.046, arborRest.y + 0.131, arborRest.z + 0.07) }
    /// Trigger hinge point at rest.
    var triggerPivot: V3 { V3(0.046, arborRest.y + 0.116, arborRest.z + 0.06) }

    /// Maps a point fixed to the arm (given at rest) through arm, bevel and miter joint values (degrees).
    public func armPoint(_ rest: V3, arm: Float, miter: Float, bevel: Float) -> V3 {
        var p = SawGeo.rotate(rest, about: armPivot, axis: V3(-1, 0, 0), arm)
        p = SawGeo.rotate(p, about: bevelPivot, axis: V3(0, 0, 1), bevel)
        return SawGeo.rotate(p, about: turntableCenter, axis: V3(0, 1, 0), miter)
    }
    /// Arbor center in asset space for joint values in degrees.
    public func arborCenter(arm: Float, miter: Float, bevel: Float) -> V3 { armPoint(arborRest, arm: arm, miter: miter, bevel: bevel) }
    /// Lowest blade point (y) at miter 0, bevel 0 for an arm value. Below `tableY` means the blade is in the kerf slot.
    public func bladeLowestY(arm: Float) -> Float { arborCenter(arm: arm, miter: 0, bevel: 0).y - bladeRadius }
    /// Unit normal of the blade plane (+X at miter 0, bevel 0).
    public func bladeNormal(miter: Float, bevel: Float) -> V3 {
        let n = simd_quatf(angle: radians(bevel), axis: V3(0, 0, 1)).act(V3(1, 0, 0))
        return simd_normalize(simd_quatf(angle: radians(miter), axis: V3(0, 1, 0)).act(n))
    }
    /// D-handle grip center for joint values in degrees.
    public func handleGrip(arm: Float, miter: Float, bevel: Float) -> V3 { armPoint(gripRest, arm: arm, miter: miter, bevel: bevel) }

    // MARK: rig

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [4])
        typealias G = SawGeo
        let tY = tableY, fZ = fenceZ, R = turntableRadius
        let A = arborRest, P = armPivot
        let body = String(format: "plastic.tool:%06X", bodyColor)
        let trim = String(format: "plastic.tool:%06X", trimColor)
        let cast: MaterialKey = "metal.diecast", table: MaterialKey = "metal.diecast", steel: MaterialKey = "metal.steel"
        let dark: MaterialKey = "plastic.matte:0E0E0F", clear: MaterialKey = "plastic.clear", rubber: MaterialKey = "rubber"
        let red: MaterialKey = "plastic.matte:C4241A", paint: MaterialKey = "metal.powdercoat:34373A", scale: MaterialKey = "metal.stainless"
        let a2 = V2(A.z, A.y)

        rig.part("miter", pivot: turntableCenter, joint: .hinge(axis: V3(0, 1, 0), miterRange, duration: 0.8))
        rig.part("bevel", parent: "miter", pivot: bevelPivot, joint: .hinge(axis: V3(0, 0, 1), bevelRange, duration: 0.8))
        rig.part("arm", parent: "bevel", pivot: P, joint: .hinge(axis: V3(-1, 0, 0), armRange, duration: 0.7))
        rig.part("blade", parent: "arm", pivot: A, joint: .hinge(axis: V3(1, 0, 0), 0...360, duration: 0.3))
        rig.part("lower-guard", parent: "arm", pivot: A,
                 joint: Joint(.revolute, axis: V3(-1, 0, 0), range: 0...110, mimic: .init("arm", ratio: -100 / armTravel)))
        rig.part("trigger", parent: "arm", pivot: triggerPivot, joint: .hinge(axis: V3(-1, 0, 0), 0...14, duration: 0.15))

        func put(_ sx: (Surface, Xform), _ part: String? = nil, _ lods: ClosedRange<Int> = 0...0) {
            if let part { rig.add(sx.0, sx.1, to: part, lods: lods) } else { for l in lods { rig.base[l].add(sx.0, sx.1) } }
        }
        func ann(_ c: V2, _ r0: Float, _ r1: Float, _ a0: Float, _ a1: Float, _ n: Int) -> [V2] {
            G.arc(c, r1, a0, a1, n) + G.arc(c, r0, a1, a0, n)
        }
        // XZ polar point around the turntable center, phi from +Z toward +X.
        func tp(_ r: Float, _ phi: Float) -> V2 { V2(r * sin(radians(phi)), fZ + r * cos(radians(phi))) }
        func tpArc(_ r: Float, _ p0: Float, _ p1: Float, _ n: Int) -> [V2] { (0...n).map { tp(r, p0 + (p1 - p0) * Float($0) / Float(n)) } }

        // MARK: base (static)
        let cz = fZ + 0.0375
        let rings: [(Float, Float, Float, Float)] = [(0.006, 0.40, 0.225, 0.02), (0.045, 0.394, 0.219, 0.019), (tY - 0.042, 0.384, 0.209, 0.016), (tY - 0.034, 0.37, 0.195, 0.01)]
        for l in 0...1 {
            let rr = rings.map { Prim.ring(Shape2D.roundedRect($0.1, $0.2, radius: $0.3, segments: l == 0 ? 4 : 2), y: $0.0, offset: V3(0, 0, cz)) }
            put((Prim.loft(rr, capStart: true, capEnd: true, material: paint), .identity), nil, l...l)
        }
        for s: Float in [-1, 1] {
            for z in [fZ - 0.05, fZ + 0.125] {
                // Rubber foot and a bench-mount ear with a through hole.
                put((Prim.cylinder(radius: 0.012, height: 0.0065, bevel: 0.002, segments: 10, bevelSegments: 1, material: rubber), Xform(translation: V3(s * 0.165, 0, z))))
                let ear = [V2(0.0045, 0), V2(0.017, 0), V2(0.017, 0.012), V2(0.0152, 0.0155), V2(0.0045, 0.0155), V2(0.0045, 0.002)]
                put((Prim.lathe(ear, segments: 10, seamTile: 0.05, material: paint), Xform(translation: V3(s * 0.218, 0, z))))
                put((cuboid(V3(0.03, 0.012, 0.02), material: paint), Xform(translation: V3(s * 0.197, 0.0075, z))))
            }
            // Side tables: ground tops with a circular bite for the turntable.
            let zr = fZ - 0.065, zf = fZ + 0.135, rb = R + 0.002
            var pts: [V2] = [V2(s * 0.205, zr)]
            for k in 0...14 { let z = zr + (zf - zr) * Float(k) / 14; pts.append(V2(s * sqrt(rb * rb - (z - fZ) * (z - fZ)), z)) }
            pts.append(V2(s * 0.205, zf))
            put(G.slabXZ(pts, tY - 0.036, tY, bevel: 0.0015, seg: 2, table), nil, 0...1)
            // Extension wings on gussets.
            let wing = Shape2D.rounded([V2(s * 0.2, fZ - 0.045), V2(s * 0.25, fZ - 0.03), V2(s * 0.25, fZ + 0.1), V2(s * 0.2, fZ + 0.115)], radius: 0.012, segments: 3)
            put(G.slabXZ(wing, tY - 0.012, tY - 0.0005, bevel: 0.002, seg: 2, cast), nil, 0...1)
            for z in [fZ - 0.015, fZ + 0.085] {
                put(G.slabXY([V2(s * 0.199, 0.025), V2(s * 0.199, tY - 0.011), V2(s * 0.244, tY - 0.011)], z - 0.003, z + 0.003, bevel: 0.0015, seg: 1, paint), nil, 0...1)
            }
            // Two-piece tall fence: L section, face at fenceZ, gap for the blade.
            let H = fenceHeight
            let prof = Shape2D.rounded([V2(fZ, tY + 0.001), V2(fZ, tY + H), V2(fZ - 0.011, tY + H), V2(fZ - 0.011, tY + 0.014),
                                        V2(fZ - 0.036, tY + 0.013), V2(fZ - 0.036, tY + 0.001)], radius: 0.0025, segments: 2)
            put(G.slabYZ(prof, s * 0.013, s * 0.235, bevel: 0.0015, seg: 2, cast), nil, 0...1)
            for gx: Float in [0.06, 0.13, 0.2] {
                put(G.slabYZ([V2(fZ - 0.010, tY + 0.072), V2(fZ - 0.034, tY + 0.0135), V2(fZ - 0.010, tY + 0.0135)], s * gx - 0.0025, s * gx + 0.0025, bevel: 0.001, seg: 1, cast))
            }
            for hx: Float in [0.09, 0.2] {
                put(G.cylZ(0.0035, fZ - 0.004, fZ + 0.0004, x: s * hx, y: tY + 0.05, bevel: 0, seg: 8, dark), nil, 0...0)
            }
            put((Prim.cylinder(radius: 0.0085, height: 0.0015, bevel: 0, segments: 12, bevelSegments: 1, material: steel), Xform(translation: V3(s * 0.165, tY + 0.0128, fZ - 0.024))))
            put(G.slabXZ(Shape2D.polygon(sides: 6, radius: 0.0058).map { $0 + V2(s * 0.165, fZ - 0.024) }, tY + 0.0142, tY + 0.0198, bevel: 0.0007, seg: 1, steel))
            // Hold-down clamp post holes behind the fence.
            let boss = [V2(0.006, 0), V2(0.011, 0), V2(0.011, 0.011), V2(0.0095, 0.0125), V2(0.006, 0.0125), V2(0.006, 0.001)]
            put((Prim.lathe(boss, segments: 12, seamTile: 0.05, material: cast), Xform(translation: V3(s * 0.165, tY - 0.0005, fZ - 0.052))))
            put((Prim.cylinder(radius: 0.0062, height: 0.001, bevel: 0, segments: 8, bevelSegments: 1, material: dark), Xform(translation: V3(s * 0.165, tY + 0.0015, fZ - 0.052))), nil, 0...0)
        }
        // Front apron under the miter arm: scale band, ticks and detent notches.
        put(G.slabXZ(tpArc(0.205, -58, 58, 16) + tpArc(0.15, 58, -58, 10), tY - 0.047, tY - 0.037, bevel: 0.002, seg: 1, paint), nil, 0...1)
        put(G.slabXZ(tpArc(0.198, -52, 52, 14) + tpArc(0.172, 52, -52, 14), tY - 0.0375, tY - 0.0355, bevel: 0.0004, seg: 1, scale))
        var ticks = Surface(material: dark)
        for d in stride(from: -50, through: 50, by: 5) {
            let len: Float = d % 15 == 0 ? 0.012 : 0.007, r = 0.196 - len / 2
            let p = tp(r, Float(d))
            ticks.append(cuboid(V3(0.0008, 0.0004, len), material: dark), Xform(translation: V3(p.x, tY - 0.0354, p.y), rotation: simd_quatf(angle: radians(Float(d)), axis: .up)))
        }
        for d in miterDetents {
            let p = tp(0.2035, d)
            ticks.append(cuboid(V3(0.004, 0.0104, 0.007), material: dark), Xform(translation: V3(p.x, tY - 0.042, p.y), rotation: simd_quatf(angle: radians(d), axis: .up)))
        }
        put((ticks, .identity), nil, 0...0)

        // Story: fine sawdust drifts at the fence and pencil cut marks on the right fence face.
        func dust(_ c: V3, _ w: Float, _ d: Float, _ yaw: Float, _ part: String?) {
            let sd = Prim.superellipsoid(V3(w, 0.0014, d), exponent: 2, subdivisions: 3, material: "wood.sawdust") { dir in 1 + 0.25 * sin(dir.x * 9 + dir.z * 5) }
            put((sd, Xform(translation: c, rotation: simd_quatf(angle: yaw, axis: .up))), part)
        }
        dust(V3(0.105, tY + 0.0002, fZ + 0.016), 0.07, 0.022, 0.05, nil)
        dust(V3(0.03, tY + 0.0002, fZ + 0.09), 0.05, 0.03, 0.4, "miter")
        dust(V3(-0.17, tY + 0.0002, fZ + 0.014), 0.05, 0.018, -0.08, nil)
        var pencil = Surface(material: "plastic.matte:3C3C40")
        for (x, h) in [(Float(0.052), Float(0.024)), (0.058, 0.016), (0.121, 0.03)] {
            pencil.append(cuboid(V3(0.0007, h, 0.0003), material: "plastic.matte:3C3C40"), Xform(translation: V3(x, tY + 0.012 + h / 2, fZ + 0.00016)))
        }
        put((pencil, .identity))

        // MARK: miter (turntable)
        let tw: Float = 0.045, nw: Float = 0.024, zt = fZ + 0.205, tailW: Float = 0.05, zTail = fZ - 0.2
        for l in 0...1 {
            let n = l == 0 ? 12 : 7
            let aT = asin(tw / R), aL = asin(tailW / R)
            var tt: [V2] = [V2(nw, zt), V2(nw, fZ - 0.125), V2(-nw, fZ - 0.125), V2(-nw, zt), V2(-tw, zt)]
            for k in 0...n { let t = Float(k) / Float(n), psi = -aT + (-(Float.pi - aL) + aT) * t; tt.append(V2(R * sin(psi), fZ + R * cos(psi))) }
            tt += [V2(-tailW, zTail), V2(tailW, zTail)]
            for k in 0...n { let t = Float(k) / Float(n), psi = (Float.pi - aL) + (aT - (Float.pi - aL)) * t; tt.append(V2(R * sin(psi), fZ + R * cos(psi))) }
            tt.append(V2(tw, zt))
            put(G.slabXZ(Shape2D.rounded(tt, radius: 0.003, segments: 1), tY - 0.03, tY, bevel: 0.0015, seg: 1, table), "miter", l...l)
        }
        let insertMat = String(format: "plastic.tool:%06X", 0x2A2A2C)
        for s: Float in [-1, 1] {
            let xs = [s * 0.003, s * 0.0235].sorted()
            put(G.slabXZ(Shape2D.rounded([V2(xs[0], fZ - 0.124), V2(xs[1], fZ - 0.124), V2(xs[1], fZ + 0.18), V2(xs[0], fZ + 0.18)], radius: 0.0015, segments: 1),
                         tY - 0.006, tY - 0.0004, bevel: 0.0006, seg: 1, insertMat), "miter", 0...1)
            for z in [fZ - 0.1, fZ + 0.16] {
                put((Prim.cylinder(radius: 0.0025, height: 0.0006, bevel: 0, segments: 8, bevelSegments: 1, material: steel), Xform(translation: V3(s * 0.0135, tY - 0.0006, z))), "miter", 0...0)
            }
        }
        put(G.slabXZ(Shape2D.rounded([V2(-0.0235, fZ + 0.18), V2(0.0235, fZ + 0.18), V2(0.0235, fZ + 0.2035), V2(-0.0235, fZ + 0.2035)], radius: 0.0015, segments: 1),
                     tY - 0.006, tY - 0.0004, bevel: 0.0006, seg: 1, insertMat), "miter", 0...1)
        put((cuboid(V3(0.048, 0.004, 0.33), material: dark), Xform(translation: V3(0, tY - 0.029, fZ + 0.04))), "miter", 0...1)
        // Front lock handle, detent release lever and the clear pointer window.
        let lock = catmull([V3(0, tY - 0.016, fZ + 0.19), V3(0, tY - 0.024, fZ + 0.222), V3(0, tY - 0.038, fZ + 0.245)], per: 4)
        put((Prim.sweep(Shape2D.roundedRect(0.028, 0.014, radius: 0.005, segments: 1), along: lock, up: V3(1, 0, 0), material: trim), .identity), "miter", 0...1)
        put((Prim.superellipsoid(V3(0.036, 0.026, 0.032), exponent: 3, subdivisions: 4, material: rubber), Xform(translation: V3(0, tY - 0.043, fZ + 0.256))), "miter", 0...1)
        let lever = catmull([V3(0.026, tY - 0.031, fZ + 0.17), V3(0.026, tY - 0.034, fZ + 0.205), V3(0.026, tY - 0.046, fZ + 0.235)], per: 3)
        put((Prim.sweep(Shape2D.roundedRect(0.012, 0.003, radius: 0.001, segments: 1), along: lever, up: V3(1, 0, 0), material: steel), .identity), "miter")
        put((Prim.superellipsoid(V3(0.016, 0.01, 0.02), exponent: 3, subdivisions: 3, material: red), Xform(translation: V3(0.026, tY - 0.047, fZ + 0.24))), "miter")
        put(G.slabXZ(Shape2D.roundedRect(0.024, 0.024, radius: 0.003, segments: 1).map { V2($0.x, $0.y + fZ + 0.184) }, tY - 0.0335, tY - 0.0305, bevel: 0.0005, seg: 1, clear), "miter")
        put((cuboid(V3(0.0007, 0.0004, 0.022), material: red), Xform(translation: V3(0, tY - 0.0337, fZ + 0.184))), "miter", 0...0)
        // Bevel scale plate on the tail, ticks, lock knob.
        let bc = V2(0, tY)
        put(G.slabXY(G.arc(bc, 0.064, 70, 150, 16) + [V2(0.064 * cos(radians(150)), tY - 0.004), V2(0.064 * cos(radians(70)), tY - 0.004)],
                     fZ - 0.2, fZ - 0.196, bevel: 0.0008, seg: 1, scale), "miter")
        var bt = Surface(material: dark)
        for d in stride(from: 90, through: 135, by: 5) {
            let len: Float = d % 15 == 0 ? 0.01 : 0.006, p = G.pol(bc, 0.062 - len / 2, Float(d))
            bt.append(cuboid(V3(len, 0.0008, 0.0004), material: dark), Xform(translation: V3(p.x, p.y, fZ - 0.2002), rotation: simd_quatf(angle: radians(Float(d)), axis: V3(0, 0, 1))))
        }
        put((bt, .identity), "miter", 0...0)
        let lobes = (0..<25).map { k -> V2 in let a = Float(k) / 25 * 2 * .pi; return V2(cos(a), sin(a)) * (0.0165 + 0.0035 * cos(5 * a)) + V2(0, tY) }
        put((Prim.extrude(lobes, depth: 0.018, bevel: 0.003, bevelSegments: 1, material: trim), Xform(translation: V3(0, 0, fZ - 0.216))), "miter")
        put(G.cylZ(0.006, fZ - 0.208, fZ - 0.19, x: 0, y: tY, seg: 12, steel), "miter")
        // Power cord: from the bevel axis down behind the saw, across the bench to the plug.
        let cordTail = catmull([V3(0, tY, fZ - 0.24), V3(0, tY - 0.035, fZ - 0.252), V3(0.01, 0.03, fZ - 0.262), V3(0.05, 0.0045, fZ - 0.268),
                                V3(0.14, 0.0045, fZ - 0.255), V3(0.2, 0.0045, fZ - 0.215), V3(0.2, 0.0045, fZ - 0.17)], per: 3)
        put((Prim.tube(cordTail, radii: cordTail.map { _ in 0.0045 }, sides: 6, seamTile: 0.03, material: rubber), .identity), "miter")
        put((Prim.roundedBox(V3(0.024, 0.017, 0.036), radius: 0.005, bevelSegments: 2, material: trim), Xform(translation: V3(0.2, 0.0087, fZ - 0.152))), "miter")
        for px: Float in [-0.0063, 0.0063] {
            put((cuboid(V3(0.0012, 0.0062, 0.016), material: "metal.brass"), Xform(translation: V3(0.2 + px, 0.0087, fZ - 0.127))), "miter")
        }

        // MARK: bevel (trunnion and post)
        put(G.cylZ(0.03, fZ - 0.19, fZ - 0.12, x: 0, y: tY, bevel: 0.003, seg: 20, cast), "bevel", 0...1)
        let post = Shape2D.rounded([V2(-0.028, tY), V2(0.028, tY), V2(0.025, tY + 0.14), V2(0.017, tY + 0.168), V2(0, tY + 0.176),
                                    V2(-0.017, tY + 0.168), V2(-0.025, tY + 0.14)], radius: 0.006, segments: 2)
        put(G.slabXY(post, fZ - 0.175, fZ - 0.125, bevel: 0.004, seg: 2, cast), "bevel", 0...1)
        put(G.cylX(0.022, -0.03, 0.03, y: P.y, z: P.z, bevel: 0.003, seg: 16, cast), "bevel", 0...1)
        put(G.cylX(0.0085, -0.058, 0.058, y: P.y, z: P.z, bevel: 0, seg: 12, steel), "bevel")
        put(G.cylX(0.007, 0.05, 0.075, y: P.y, z: P.z, bevel: 0.002, seg: 12, trim), "bevel")
        put((cuboid(V3(0.005, 0.0015, 0.032), material: red), Xform(translation: V3(0, tY + 0.078, fZ - 0.1875))), "bevel")
        put((cuboid(V3(0.0035, 0.03, 0.0012), material: red), Xform(translation: V3(0, tY + 0.064, fZ - 0.2035))), "bevel")
        let cordMid = catmull([V3(0.068, P.y, P.z), V3(0.07, P.y - 0.03, P.z - 0.02), V3(0.045, tY + 0.07, fZ - 0.185), V3(0.022, tY + 0.03, fZ - 0.232), V3(0, tY, fZ - 0.24)], per: 3)
        put((Prim.tube(cordMid, radii: cordMid.map { _ in 0.0045 }, sides: 6, seamTile: 0.03, material: rubber, capEnd: false), .identity), "bevel")

        // MARK: arm
        for x0: Float in [0.031, -0.05] { put(G.cylX(0.022, x0, x0 + 0.019, y: P.y, z: P.z, bevel: 0.003, seg: 16, cast), "arm", 0...1) }
        put((Prim.roundedBox(V3(0.1, 0.014, 0.03), radius: 0.004, bevelSegments: 1, material: cast), Xform(translation: P + V3(0, 0.035, 0))), "arm", 0...1)
        let beam = catmull([V3(0.041, P.y, P.z), V3(0.041, (P.y + A.y) / 2 + 0.012, (P.z + A.z) / 2), V3(0.041, A.y + 0.02, A.z - 0.035)], per: 6)
        put((Prim.sweep(Shape2D.roundedRect(0.024, 0.042, radius: 0.008, segments: 2), along: beam, up: V3(1, 0, 0), material: cast), .identity), "arm", 0...1)
        // Fixed upper guard: two side plates and a rim, open below so the blade shows.
        for l in 0...1 {
            let n = l == 0 ? 22 : 12
            let outer = G.arc(a2, 0.142, -25, 205, n)
            put(G.slabYZ(outer + G.arc(a2, 0.05, 205, 335, n / 3), 0.0245, 0.028, bevel: 0, seg: 1, cast), "arm", l...l)
            put(G.slabYZ(outer + G.arc(a2, 0.06, 205, -25, n), -0.018, -0.0145, bevel: 0, seg: 1, cast), "arm", l...l)
            put(G.slabYZ(outer + G.arc(a2, 0.135, 205, -25, n), -0.018, 0.028, bevel: 0.002, seg: 1, cast), "arm", l...l)
        }
        // Rotation arrow on the left plate.
        let arrow = G.arc(a2, 0.102, 120, 40, 10) + [G.pol(a2, 0.107, 40), G.pol(a2, 0.099, 29), G.pol(a2, 0.091, 40)] + G.arc(a2, 0.096, 40, 120, 10)
        put(G.slabYZ(arrow, -0.0187, -0.0179, bevel: 0, seg: 1, red), "arm", 0...0)
        // Warning label on the left guard plate: black border, yellow face.
        let lc = G.pol(a2, 0.1, 150)
        put(G.slabYZ(Shape2D.roundedRect(0.046, 0.03, radius: 0.003, segments: 1).map { $0 + lc }, -0.0187, -0.0179, bevel: 0, seg: 1, trim), "arm")
        put(G.slabYZ(Shape2D.roundedRect(0.042, 0.026, radius: 0.002, segments: 1).map { $0 + lc }, -0.0191, -0.0186, bevel: 0, seg: 1, body), "arm")
        put(G.slabYZ([lc + V2(-0.017, -0.009), lc + V2(-0.005, 0.009), lc + V2(0.007, -0.009)], -0.0194, -0.019, bevel: 0, seg: 1, trim), "arm")
        // Gearbox, handle mount and motor.
        put(G.cylX(0.042, 0.026, 0.062, y: A.y, z: A.z, bevel: 0.004, seg: 20, cast), "arm", 0...1)
        let nose = Shape2D.rounded([a2 + V2(-0.03, -0.035), a2 + V2(0.06, -0.02), a2 + V2(0.095, 0.03), a2 + V2(0.08, 0.06), a2 + V2(0.0, 0.05)], radius: 0.012, segments: 3)
        put(G.slabYZ(nose, 0.028, 0.06, bevel: 0.004, seg: 2, cast), "arm", 0...1)
        let M = V3(0.03, A.y + 0.03, A.z - 0.01)
        let motorBody = [V2(0, 0), V2(0.047, 0), V2(0.0525, 0.006), V2(0.0535, 0.05), V2(0.052, 0.11), V2(0, 0.11)]
        let motorCap = [V2(0, 0.108), V2(0.0505, 0.108), V2(0.05, 0.122), V2(0.044, 0.136), V2(0.03, 0.143), V2(0, 0.145)]
        for l in 0...1 {
            put((Prim.lathe(motorBody, segments: l == 0 ? 20 : 12, seamTile: 0.1, material: body), Xform(translation: M, rotation: G.alongX)), "arm", l...l)
            put((Prim.lathe(motorCap, segments: l == 0 ? 20 : 12, seamTile: 0.1, material: trim), Xform(translation: M, rotation: G.alongX)), "arm", l...l)
        }
        var vents = Surface(material: dark)
        for k in 0..<10 {
            let a = Float(k) / 10 * 2 * .pi
            let q = simd_quatf(angle: a, axis: V3(1, 0, 0))
            vents.append(cuboid(V3(0.016, 0.0012, 0.0055), material: dark), Xform(translation: M + V3(0.122, 0, 0) + q.act(V3(0, 0.0505, 0)), rotation: q))
        }
        for k in 0..<6 {
            let a = Float(k) / 6 * 2 * .pi
            let q = simd_quatf(angle: a, axis: V3(1, 0, 0))
            vents.append(cuboid(V3(0.0012, 0.018, 0.004), material: dark), Xform(translation: M + V3(0.1432, 0, 0) + q.act(V3(0, 0.021, 0)), rotation: q))
        }
        put((vents, .identity), "arm", 0...0)
        for dir: Float in [1, -1] {
            put((Prim.cylinder(radius: 0.009, height: 0.007, bevel: 0.002, segments: 10, bevelSegments: 1, material: trim),
                 Xform(translation: M + V3(0.085, dir * 0.051, 0), rotation: facing(V3(0, dir, 0)))), "arm", 0...0)
        }
        // D-handle with rubber overmold, lock-off button, strain relief and cord to the arm pivot.
        let dPath = catmull([(-0.035, 0.062), (-0.01, 0.1), (0.04, 0.128), (0.1, 0.13), (0.14, 0.11), (0.15, 0.075), (0.125, 0.045), (0.085, 0.035)]
            .map { V3(0.046, A.y + $0.1, A.z + $0.0) }, per: 3)
        put((Prim.sweep(Shape2D.circle(0.013, ry: 0.016, segments: 10), along: dPath, up: V3(1, 0, 0), material: body), .identity), "arm", 0...1)
        let gripPath = Array(dPath[6...13])
        put((Prim.sweep(Shape2D.circle(0.0146, ry: 0.0178, segments: 10), along: gripPath, up: V3(1, 0, 0), material: rubber), .identity), "arm")
        put(G.cylX(0.0045, 0.028, 0.064, y: A.y + 0.128, z: A.z + 0.03, bevel: 0.0012, seg: 12, trim), "arm")
        let relief = [V3(0.046, A.y + 0.066, A.z - 0.04), V3(0.047, A.y + 0.069, A.z - 0.058), V3(0.048, A.y + 0.072, A.z - 0.078)]
        put((Prim.tube(relief, radii: [0.0095, 0.0075, 0.0058], sides: 12, seamTile: 0.03, material: rubber), .identity), "arm")
        let cordArm = catmull([V3(0.048, A.y + 0.072, A.z - 0.075), V3(0.052, A.y + 0.06, A.z - 0.12), V3(0.06, A.y + 0.025, A.z - 0.165),
                               V3(0.068, P.y + 0.022, P.z + 0.012), V3(0.068, P.y, P.z)], per: 3)
        put((Prim.tube(cordArm, radii: cordArm.map { _ in 0.0045 }, sides: 6, seamTile: 0.03, material: rubber, capEnd: false), .identity), "arm")
        // Dust port and bag.
        let port = catmull([V3(0.004, A.y + 0.03, A.z - 0.128), V3(0.035, A.y + 0.04, A.z - 0.16), V3(0.08, A.y + 0.045, A.z - 0.185), V3(0.115, A.y + 0.04, A.z - 0.2)], per: 3)
        put((Prim.tube(port, radii: port.map { _ in 0.021 }, sides: 12, seamTile: 0.05, material: trim), .identity), "arm", 0...1)
        let bagDir = simd_normalize(V3(0.15 + rng.float(-0.05...0.05), -0.85, -0.5)), bagTop = V3(0.12, A.y + 0.035, A.z - 0.205)
        put((Prim.tube([bagTop + bagDir * -0.01, bagTop + bagDir * 0.014], radii: [0.025, 0.025], sides: 14, seamTile: 0.05, material: trim), .identity), "arm")
        put((Prim.superellipsoid(V3(0.1, 0.24, 0.1), exponent: 2.4, subdivisions: 5, material: "fabric.canvas:3A3A3C") { d in (1 + 0.12 * max(0, -d.y)) * (d.y > 0.6 ? 0.85 : 1) },
             Xform(translation: bagTop + bagDir * 0.115, rotation: simd_quatf(from: V3(0, -1, 0), to: bagDir))), "arm", 0...1)

        // MARK: blade
        for l in 0...1 {
            var plate = Prim.extrude(l == 0 ? G.toothed(teeth, bladeRadius - 0.0022) : Shape2D.circle(bladeRadius - 0.004, segments: 48),
                                     depth: 0.0018, bevel: 0, bevelSegments: 1, material: "metal.sawblade")
            G.radialUV(&plate)
            put((plate, Xform(translation: V3(0, A.y, A.z), rotation: G.toYZ)), "blade", l...l)
        }
        put((G.carbide(teeth, bladeRadius, kerf: kerf, "metal.carbide"), Xform(translation: V3(0, A.y, A.z), rotation: G.toYZ)), "blade", 0...0)
        var slots = Surface(material: dark)
        for k in 0..<4 {
            let a = Float(k) * 90 + 20
            slots.append(cuboid(V3(0.0011, 0.02, 0.0021), material: dark), Xform(translation: V3(G.pol(.zero, 0.09, a), 0), rotation: simd_quatf(angle: radians(a), axis: V3(0, 0, 1))))
        }
        put((slots, Xform(translation: V3(0, A.y, A.z), rotation: G.toYZ)), "blade", 0...0)
        for (r0, r1, a0) in [(Float(0.038), Float(0.07), Float(15)), (0.038, 0.07, 195)] {
            put(G.slabYZ(ann(a2, r0, r1, a0, a0 + 150, 10), -0.00118, -0.00092, bevel: 0, seg: 1, "plastic.matte:A31F24"), "blade", 0...0)
        }
        put(G.cylX(0.03, -0.0045, -0.0009, y: A.y, z: A.z, bevel: 0.0006, seg: 16, steel), "blade")
        put(G.cylX(0.03, 0.0009, 0.004, y: A.y, z: A.z, bevel: 0.0006, seg: 16, steel), "blade")
        put(G.cylX(0.0135, -0.0057, -0.0045, y: A.y, z: A.z, bevel: 0, seg: 12, steel), "blade")
        let hex = Shape2D.rounded(Shape2D.polygon(sides: 6, radius: 0.0092), radius: 0.0008, segments: 1).map { $0 + a2 }
        put(G.slabYZ(hex, -0.0115, -0.0056, bevel: 0.0008, seg: 1, "metal.chrome"), "blade")

        // MARK: lower guard (clear, retracts into the upper guard)
        let lgOuter = G.arc(a2, 0.1335, 235, 335, 12)
        for x0: Float in [-0.0135, 0.0205] {
            put(G.slabYZ(lgOuter + G.arc(a2, 0.035, 335, 235, 8), x0, x0 + 0.002, bevel: 0, seg: 1, clear), "lower-guard", 0...1)
        }
        put(G.slabYZ(lgOuter + G.arc(a2, 0.13, 335, 235, 12), -0.0135, 0.0225, bevel: 0.0008, seg: 1, clear), "lower-guard", 0...1)
        put(G.slabYZ([G.pol(a2, 0.1, 333), G.pol(a2, 0.1338, 333), G.pol(a2, 0.1338, 337.5), G.pol(a2, 0.1, 337.5)], -0.0142, 0.0232, bevel: 0.001, seg: 1, trim), "lower-guard", 0...1)
        put(G.cylX(0.016, -0.0165, -0.0135, y: A.y, z: A.z, bevel: 0.0008, seg: 14, trim), "lower-guard", 0...1)

        // MARK: trigger
        let trig = Shape2D.rounded([V2(0.06, 0.117), V2(0.095, 0.117), V2(0.093, 0.106), V2(0.084, 0.096), V2(0.072, 0.094), V2(0.063, 0.102)].map { a2 + $0 },
                                   radius: 0.003, segments: 2)
        put(G.slabYZ(trig, 0.04, 0.052, bevel: 0.0015, seg: 1, trim), "trigger", 0...1)

        groundAO(&rig, height: 0.08, floor: 0.6)
        rig.states = [
            RigState("idle"),
            RigState("lowered", ["arm": -armTravel]),
            RigState("running", ["arm": -12, "trigger": 14]),
            RigState("miter-left-45", ["miter": -45]),
            RigState("miter-right-45", ["miter": 45]),
            RigState("bevel-45", ["bevel": 45]),
        ]
        return rig
    }
}
