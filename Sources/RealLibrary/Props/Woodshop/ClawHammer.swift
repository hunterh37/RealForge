import simd
import Foundation

/// 16 oz curved claw hammer lying on its side: drop-forged steel head 133 mm long (smooth, slightly
/// crowned 28 mm face with a chamfered rim, round neck, oval eye block, split curved claws with a
/// V nail slot) on a 13 in lacquered hickory handle that swells to a 33 mm grip and flares at the butt.
/// The handle shows through the top of the eye with a hardwood wedge and a round steel cross wedge.
///
/// Tool frame: handle along -X (top of the eye at x = +0.019), head axis along Y (face at +Y, claws at -Y
/// curving toward the handle), thickness along Z. `rest` lays it on its cheek (tool +Z up).
public struct ClawHammer: RealAsset {
    public static let id = "claw-hammer"
    public static let summary = "16 oz curved claw hammer: forged steel head with a smooth crowned face and split claws, hickory handle wedged in the eye."
    public static let tags = ["prop", "workshop", "tool", "handheld", "metal", "wood"]
    public static let budget = 7_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 28, elevation: 40, distance: 0.85)

    /// Overall length, top of the eye to the butt (m), 13 in.
    public var length: Float = 0.337
    public var head: MaterialKey = "metal.hammer-painted"
    public var face: MaterialKey = "metal.machined"
    public var handle: MaterialKey = "wood.hammer-hickory"
    public var wedge: MaterialKey = "wood.lumber-walnut"
    public init() {}

    static let faceR: Float = 0.0142, faceY: Float = 0.0695, eyeTop: Float = 0.0188

    /// Tool frame -> asset space: tilt so the butt and the face rim both touch, lay on the cheek, center.
    func rest() -> Xform {
        let butt = eyeTopX - length
        let drop = Self.faceR - 0.0131
        let psi = -atan(drop / (0.0 - (butt + 0.012)))          // lowers the butt end
        let tilt = simd_quatf(angle: psi, axis: V3(0, 1, 0))
        let lay = simd_quatf(angle: -.pi / 2, axis: V3(1, 0, 0))
        let pivot = V3(0, 0, -Self.faceR)
        var x = Xform(translation: lay.act(pivot - tilt.act(pivot)) + V3(0, Self.faceR, 0), rotation: lay * tilt)
        let c = x.point(V3((butt + eyeTopX) / 2, 0, 0))
        x.translation += V3(-c.x, 0, -c.z)
        return x
    }
    var eyeTopX: Float { Self.eyeTop }

    /// Center of the striking face, asset space.
    public var faceCenter: V3 { rest().point(V3(0, Self.faceY + 0.0006, 0)) }
    /// Outward normal of the striking face (unit), asset space.
    public var faceNormal: V3 { rest().direction(V3(0, 1, 0)) }
    /// Center of the hand hold on the handle grip, asset space.
    public var grip: V3 { rest().point(V3(eyeTopX - length + 0.085, 0, 0)) }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)

        // MARK: head body, face to claw root, lofted along -Y (section x = Z width, y = X depth)
        let st: [(y: Float, w: Float, h: Float, e: Float)] = [
            (0.0690, 0.0262, 0.0262, 2), (0.0682, 0.0280, 0.0280, 2), (0.0668, 0.0284, 0.0284, 2), (0.0600, 0.0282, 0.0282, 2),
            (0.0530, 0.0262, 0.0262, 2), (0.0440, 0.0214, 0.0218, 2), (0.0350, 0.0208, 0.0230, 2.2), (0.0275, 0.0226, 0.0290, 2.8),
            (0.0215, 0.0240, 0.0352, 3.6), (0.0100, 0.0248, 0.0364, 4.2), (-0.0050, 0.0248, 0.0364, 4.2), (-0.0160, 0.0242, 0.0350, 3.6),
            (-0.0225, 0.0226, 0.0320, 3.0), (-0.0270, 0.0212, 0.0280, 2.6),
        ]
        let headPath = st.map { V3(0, $0.y, 0) }
        var headS = HTKit.loft(headPath, up: V3(1, 0, 0), material: head) { i in HTKit.section(st[i].w, st[i].h, n: 28, exponent: st[i].e) }
        // Rubbed bright around the striking end, darker oxidized cheeks.
        headS.paintSplat { q in smoothstep(0.053, 0.061, q.y) }
        m.add(headS)
        // Polished, slightly crowned face.
        var faceDisc = Prim.cylinder(radius: 0.0131, height: 0.0012, bevel: 0.0006, segments: 28, bevelSegments: 2, material: face)
        faceDisc.deform { q in V3(q.x, q.y + 0.0004 * (1 - (q.x * q.x + q.z * q.z) / (0.0131 * 0.0131)), q.z) }
        m.add(faceDisc, Xform(translation: V3(0, Self.faceY - 0.0007, 0)))

        // MARK: claws: two prongs curving back toward the handle with a V slot that opens toward the tips
        let spine: [V2] = catmull([V3(0.0, -0.022, 0), V3(-0.0015, -0.038, 0), V3(-0.0075, -0.053, 0), V3(-0.018, -0.0645, 0),
                                   V3(-0.031, -0.0705, 0), V3(-0.041, -0.0715, 0)], per: 3).map { V2($0.x, $0.y) }
        for side: Float in [-1, 1] {
            let path: [V3] = spine.indices.map { i in
                let t = Float(i) / Float(spine.count - 1)
                let gap = 0.0007 + 0.0055 * pow(t, 1.3), w = 0.0108 - 0.0052 * t
                return V3(spine[i].x, spine[i].y, side * (gap / 2 + w / 2))
            }
            let prong = HTKit.loft(path, up: V3(0, 0, 1), material: head) { i in
                let t = Float(i) / Float(spine.count - 1)
                let thick = 0.0215 * (1 - t) + 0.0032 * t, w = 0.0108 - 0.0052 * t
                // Wedge section: full width on the outer face, bevelled to a knife edge along the slot side.
                let base = HTKit.section(thick, w, n: 12, exponent: 3)
                return base.map { q in
                    let inner = side * q.y < 0 ? 1 : 0          // half of the section that faces the slot
                    return V2(q.x * (1 - 0.35 * Float(inner) * (abs(q.y) / (w / 2))), q.y)
                }
            }
            var pr = prong
            pr.paintSplat { q in smoothstep(-0.026, -0.036, q.x) }
            m.add(pr)
        }

        // MARK: hickory handle through the eye, lofted along -X (section x = Z thickness, y = Y depth)
        let top = eyeTopX, butt = eyeTopX - length
        let hs: [(x: Float, w: Float, h: Float)] = [
            (top + 0.0006, 0.0122, 0.0246), (top - 0.004, 0.0126, 0.0252), (-0.0200, 0.0128, 0.0256), (-0.0260, 0.0142, 0.0266),
            (-0.0400, 0.0146, 0.0250), (-0.0700, 0.0150, 0.0244), (-0.1200, 0.0176, 0.0282), (-0.1700, 0.0212, 0.0326),
            (butt + 0.100, 0.0236, 0.0344), (butt + 0.040, 0.0246, 0.0350), (butt + 0.016, 0.0258, 0.0362), (butt + 0.006, 0.0254, 0.0352),
            (butt + 0.0015, 0.0222, 0.0310), (butt, 0.0170, 0.0240),
        ]
        let hPath = hs.map { V3($0.x, 0.0006 * sin(($0.x - butt) / length * .pi), 0) }
        var wood = HTKit.loft(hPath, up: V3(0, 1, 0), material: handle) { i in HTKit.section(hs[i].w, hs[i].h, n: 20, exponent: 2.3) }
        // Darker hand grime over the grip.
        wood.paintSplat { q in smoothstep(butt + 0.15, butt + 0.06, q.x) * (1 - smoothstep(butt + 0.012, butt + 0.002, q.x)) }
        m.add(wood)
        // Top of the handle: hardwood wedge along the eye and a round steel cross wedge.
        m.add(Prim.roundedBox(V3(0.0016, 0.0022, 0.0224), radius: 0.0004, bevelSegments: 1, material: wedge),
              Xform(translation: V3(top + 0.0004, 0, 0), rotation: simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))))
        let ring = Prim.cylinder(radius: 0.0026, height: 0.0016, bevel: 0.0005, segments: 14, bevelSegments: 1, material: face)
        m.add(ring, Xform(translation: V3(top - 0.0002, 0.0042 * rng.float(-1...1), 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))))

        let x = rest()
        var out = Model(name: Self.id)
        for s in m.surfaces { out.add(s, x) }
        groundAO(&out, height: 0.02, floor: 0.55)
        return LODModel(out)
    }
}
