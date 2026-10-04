import simd
import Foundation

/// Weitlaner self-retaining retractor, 6.5 in (165 mm), 3x4 blunt prongs: two stainless members on a
/// slotted pivot screw (lap joint with round bosses), straight arms ending in vertical rake plates whose
/// blunt ball-tipped prongs curl outward (three on one rake, four on the other, staggered so the rakes
/// nest when closed), handles to oval finger rings, and a curved toothed ratchet bar on one handle running
/// through a catch with a thumb-release lever on the other. The arms do not cross: squeezing the rings
/// spreads the rakes, the bar holds them. Both members hinge about the screw (Y), the second mimicking
/// the first. Rests tipped onto its prong tips and rings. Story detail: orange ID tape on one handle.
public struct WeitlanerRetractor: RealArticulated {
    public static let id = "weitlaner-retractor"
    public static let summary = "Weitlaner self-retaining retractor, 6.5 in: 3x4 blunt rake prongs, pivot screw, curved ratchet bar with thumb release and finger rings."
    public static let tags = ["prop", "medical", "surgical", "handheld", "tool", "metal", "articulated"]
    public static let budget = 5_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 48, distance: 0.36, studio: true)

    public var body: MaterialKey = "metal.surgical"
    public var polished: MaterialKey = "metal.surgical-mirror"
    /// Rotation of each member in the "open" and "wide" states (degrees; the rakes spread by twice this).
    public var openAngle: Float = 8
    public var wideAngle: Float = 14.5
    /// ID tape color (sRGB hex); 0 removes it.
    public var tape: UInt32 = 0xE8761E
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3])
        let hj: Float = 0.0028, gap: Float = 0.00008
        let yMid = hj + gap / 2
        let ringIn = V2(0.0105, 0.0088), wire: Float = 0.0035
        let ringC = V2(-0.078, 0.035)
        let rakeZ: Float = 0.0028, rakeX0: Float = 0.0548, rakeX1: Float = 0.0705
        let top = yMid + 0.0016, bot = yMid - 0.0095
        rig.part("a", pivot: .zero, joint: .hinge(axis: V3(0, 1, 0), -wideAngle...0, duration: 0.5))
        rig.part("b", pivot: .zero, joint: Joint(.revolute, axis: V3(0, 1, 0), range: 0...wideAngle, duration: 0.5, mimic: .init("a", ratio: -1)))
        var psiA: Float = 0.3

        for l in 0..<2 {
            for side: Float in [1, -1] {
                let part = side > 0 ? "a" : "b"
                let yLayer = side > 0 ? hj * 1.5 + gap : hj * 0.5
                let c = V2(ringC.x, side * ringC.y)
                let end = SurgKit.ringPoint(c, y: yMid, rx: ringIn.x, rz: ringIn.y, wire: wire, deg: side * -30)
                let ctrl: [V3] = [V3(0.0605, yMid, side * rakeZ), V3(0.035, yMid, side * 0.0026), V3(0.016, yMid, side * 0.0018),
                                  V3(0.007, yLayer, side * 0.0007), V3(0, yLayer, 0), V3(-0.007, yLayer, side * 0.0029),
                                  V3(-0.016, yMid, side * 0.0068), V3(-0.03, yMid, side * 0.0131), V3(-0.05, yMid, side * 0.0218), end]
                let path = SurgKit.catmullPath(ctrl, per: l == 0 ? 4 : 2)
                func w(_ x: Float) -> Float { x > 0.012 ? 0.0052 : (x > -0.012 ? 0.0062 : 0.0058 - 0.0022 * min(1, (-x - 0.012) / 0.055)) }
                func h(_ x: Float) -> Float { abs(x) < 0.01 ? hj + (0.0034 - hj) * smoothstep(0.006, 0.01, abs(x)) : 0.0034 }
                rig.add(SurgKit.loft(path, material: body) { _, i in SurgKit.section(w(path[i].x), h(path[i].x), n: l == 0 ? 8 : 6, exponent: 4) },
                        to: part, lods: l...l)
                rig.add(SurgKit.ring(c, y: yMid, rx: ringIn.x, rz: ringIn.y, wire: wire, thick: 0.0036, segments: l == 0 ? 24 : 12,
                                     sides: l == 0 ? 8 : 6, material: body), to: part, lods: l...l)
                // Round boss of this member's half of the lap joint.
                rig.add(Prim.cylinder(radius: 0.0062, height: hj, bevel: 0.0005, segments: l == 0 ? 16 : 10, bevelSegments: 1, material: body),
                        Xform(translation: V3(0, yLayer - hj / 2, 0)), to: part, lods: l...l)
                if l == 0 && side < 0 && tape != 0 {
                    // Instrument ID tape on member b's handle, between the ratchet and the ring.
                    let seg = SurgKit.span(path, x0: -0.052, x1: -0.045, n: 4)
                    rig.add(SurgKit.bar(seg, w: { _ in w(-0.048) + 0.0005 }, h: { _ in 0.0034 + 0.0002 }, sides: 10,
                                        material: "plastic.gloss:" + String(format: "%06X", tape)), to: part, lods: 0...0)
                }
                if l == 0 && side > 0 {
                    // Polar angle (from -X toward +Z) where this handle crosses the ratchet radius.
                    if let p = path.filter({ $0.x < 0 }).min(by: { abs(simd_length(V2($0.x, $0.z)) - 0.03) < abs(simd_length(V2($1.x, $1.z)) - 0.03) }) {
                        psiA = atan2(p.z, -p.x)
                    }
                }

                // Rake: vertical plate turned down from the arm end, prongs along its bottom edge.
                let plate = Shape2D.rounded([V2(rakeX0, top), V2(rakeX1 - 0.0012, top), V2(rakeX1, top - 0.0016), V2(rakeX1, bot + 0.0008),
                                             V2(rakeX0 + 0.0014, bot), V2(rakeX0, top - 0.004)], radius: 0.0007, segments: l == 0 ? 3 : 1)
                rig.add(SurgKit.profile(plate, z0: side * rakeZ - 0.0009, z1: side * rakeZ + 0.0009, bevel: 0.0003, material: polished),
                        to: part, lods: l...l)
                let prongXs: [Float] = side > 0 ? [0.0583, 0.0627, 0.0671] : [0.0561, 0.0605, 0.0649, 0.0693]
                for (k, px) in prongXs.enumerated() {
                    var prng = rng.fork(k + (side > 0 ? 0 : 10))
                    let zc = side * rakeZ, curl = prng.float(0.0042...0.0048)
                    let pp: [V3] = [V3(px, bot + 0.0012, zc), V3(px, bot - 0.0028, zc + side * 0.0004), V3(px, bot - 0.0058, zc + side * 0.0024),
                                    V3(px, bot - 0.0071, zc + side * 0.0053), V3(px, bot - 0.0068, zc + side * (curl + 0.0036))]
                    let prong = Prim.tube(l == 0 ? SurgKit.catmullPath(pp, per: 2) : pp, radii: (l == 0 ? SurgKit.catmullPath(pp, per: 2) : pp).map { _ in 0.00095 },
                                          sides: l == 0 ? 6 : 4, seamTile: 0.004, material: polished, capEnd: false)
                    rig.add(prong, to: part, lods: l...l)
                    if l == 0 {
                        rig.add(Prim.superellipsoid(V3(repeating: 0.0023), exponent: 2, subdivisions: 1, material: polished),
                                Xform(translation: pp.last!), to: part, lods: 0...0)
                    }
                }
            }
        }

        // Ratchet bar on member b: an arc about the pivot through member a's handle, teeth outward.
        let rb: Float = 0.030, bw: Float = 0.0026, td: Float = 0.0007, pitch: Float = 2.4 * .pi / 180
        func polar(_ phi: Float, _ r: Float) -> V2 { V2(-r * cos(phi), r * sin(phi)) }
        let phi0 = -psiA - 0.07, phi1 = psiA + 0.12
        for l in 0..<2 {
            var outer: [V2] = []
            var phi = phi0
            if l == 0 {
                outer.append(polar(phi0, rb + bw / 2))
                phi = -psiA + 0.06
                while phi < phi1 - 0.02 {
                    outer.append(polar(phi, rb + bw / 2)); outer.append(polar(phi + pitch * 0.7, rb + bw / 2 + td)); phi += pitch
                }
                outer.append(polar(phi1, rb + bw / 2))
            } else {
                outer = stride(from: phi0, through: phi1, by: 0.08).map { polar($0, rb + bw / 2) }
            }
            let inner = stride(from: phi1, through: phi0, by: -0.06).map { polar($0, rb - bw / 2) }
            rig.add(SurgKit.plate(Shape2D.deduped(outer.reversed() + inner.reversed()), y0: yMid - 0.0009, y1: yMid + 0.0009, bevel: l == 0 ? 0.0003 : 0.0002,
                                  material: body), to: "b", lods: l...l)
        }
        // Catch block on member a around the bar, and its thumb-release lever.
        let cp = polar(psiA, rb + 0.0004)
        let beta = psiA - .pi / 2
        rig.add(Prim.roundedBox(V3(0.0058, 0.0046, 0.0072), radius: 0.0012, bevelSegments: 1, material: body),
                Xform(translation: V3(cp.x, yMid, cp.y), rotation: simd_quatf(angle: beta, axis: V3(0, 1, 0))), to: "a")
        let lever: [V3] = [polar(psiA + 0.02, rb + 0.002), polar(psiA + 0.08, rb + 0.0075), polar(psiA + 0.2, rb + 0.0105), polar(psiA + 0.3, rb + 0.0108)]
            .map { V3($0.x, yMid + 0.0012, $0.y) }
        rig.add(SurgKit.bar(SurgKit.catmullPath(lever, per: 3), w: { t in 0.0036 - 0.0006 * t }, h: { _ in 0.0016 }, sides: 8, material: body), to: "a")
        // Slotted pivot screw on top, flat nut face underneath.
        let topY = 2 * hj + gap
        rig.add(SurgKit.screwHead(at: V3(0, topY - 0.0001, 0), r: 0.0036, h: 0.0007, segments: 14, material: polished), to: "a")
        rig.add(Prim.roundedBox(V3(0.0056, 0.0004, 0.00045), radius: 0.0001, bevelSegments: 1, material: "metal.steel:2B2C2E"),
                Xform(translation: V3(0, topY + 0.0004, 0), rotation: simd_quatf(angle: rng.float(0.3...1.3), axis: V3(0, 1, 0))), to: "a", lods: 0...0)
        rig.add(SurgKit.screwHead(at: V3(0, 0.0001, 0), r: 0.0032, h: 0.00025, down: true, segments: 14, material: body), to: "b", lods: 0...0)

        rig.states = [RigState("closed"), RigState("open", ["a": -openAngle]), RigState("wide", ["a": -wideAngle])]
        SurgKit.settle(&rig, tilt: SurgKit.restTilt(rig, frontX: 0.045, backX: -0.06), aoHeight: 0.008)
        return rig
    }
}
