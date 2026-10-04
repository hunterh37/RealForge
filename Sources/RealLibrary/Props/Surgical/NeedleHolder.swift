import simd
import Foundation

/// Mayo-Hegar needle holder, 7 in (178 mm), tungsten-carbide (TC) pattern: heavy straight jaws 30 mm
/// from the box screw with brazed dark carbide inserts, crosshatched (two rows of serrations offset half
/// a pitch); box lock with flush screw heads; long satin shanks; three-tooth ratchet; gold-plated finger
/// rings (20 x 17.5 mm inside), the trade mark of TC inserts. Both members hinge about the box screw (Y),
/// the second mimicking the first. The "needle" part shows a 26 mm 3/8-circle suture needle clamped by
/// its swage end, standing up out of the jaws, with violet braided suture trailing on the table.
public struct NeedleHolder: RealArticulated {
    public static let id = "needle-holder"
    public static let summary = "Mayo-Hegar needle holder, 7 in: tungsten-carbide crosshatched jaws, box lock, ratchet, gold rings and an optional clamped needle."
    public static let tags = ["prop", "medical", "surgical", "handheld", "tool", "metal", "articulated"]
    public static let budget = 5_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 18, elevation: 55, distance: 0.42, studio: true)

    /// Jaw length from the box screw to the tip (m).
    public var jawLength: Float = 0.030
    /// Opening between the members in the "open" state (degrees).
    public var openAngle: Float = 26
    public var jaws: MaterialKey = "metal.surgical-mirror"
    public var inserts: MaterialKey = "metal.tungsten-carbide"
    public var rings: MaterialKey = "metal.surgical-gold"
    /// Suture needle radius (m): 26 mm 3/8 circle.
    public var needleRadius: Float = 0.0128
    /// Suture color (sRGB hex): violet braided absorbable.
    public var suture: UInt32 = 0x5B3E8E
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var inst = BoxLockInstrument()
        inst.h = 0.0036; inst.wire = 0.0036; inst.ringInner = V2(0.0102, 0.0088)
        inst.ringC = V2(-0.1342, 0.0140)
        inst.shankCtrl = [V2(-0.03, 0.0012), V2(-0.075, 0.0033), V2(-0.104, 0.0048)]
        inst.shankW = V2(0.0056, 0.0038)
        inst.ratchetX = -0.106; inst.ratchetLen = 0.006; inst.pitch = 0.0014; inst.toothDepth = 0.0007; inst.teeth = 3
        inst.box = V2(0.0122, 0.0084); inst.boxCheek = 0.0007
        inst.ringMaterial = rings
        let L = jawLength, yc = inst.yc
        let hj: Float = 0.0040, xi: Float = 0.0075, ti: Float = 0.0008, ps: Float = 0.0007, amp: Float = 0.00016
        let clear: Float = 0.00003
        func outer(_ x: Float) -> Float {
            var w: Float = x < 0.007 ? 0.0036 : 0.0036 - (x - 0.007) / (L - 0.007) * 0.0013
            let rt: Float = 0.0025
            if x > L - rt { let u = (x - (L - rt)) / rt; w *= sqrt(max(0.05, 1 - u * u)) }
            return w
        }
        let xe = L - 0.0007
        func jaw(_ side: Float, _ lod: Int) -> [Surface] {
            // Steel jaw body: contact face at the center line behind the insert, stepped back by the insert
            // thickness along it. Side +1 lies on -Z.
            var o: [V2] = [V2(-0.004, -side * clear), V2(xi, -side * clear), V2(xi, -side * ti), V2(xe, -side * ti)]
            o += stride(from: L, through: -0.004, by: lod == 0 ? -0.002 : -0.005).map { V2($0, -side * outer($0)) }
            var body = SurgKit.plate(Shape2D.deduped(o), y0: yc - hj / 2, y1: yc + hj / 2, bevel: 0.0003, segments: 1, material: jaws)
            // Carbide insert: two rows of transverse serrations offset half a pitch = crosshatch.
            var ins = Surface(material: inserts)
            for (row, phase) in [(Float(0), Float(0)), (1, 0.5)] where lod == 0 || row == 0 {
                func edge(_ x: Float) -> Float {
                    let f = (x - xi) / ps + phase
                    return amp * (abs(f - floor(f) - 0.5) * 4 - 1)
                }
                var e: [V2] = [V2(xi, -side * ti)]
                if lod == 0 {
                    var x = xi; while x <= xe { e.append(V2(x, edge(x) - side * clear)); x += ps / 2 }
                } else { e.append(V2(xi, -side * clear)); e.append(V2(xe, -side * clear)) }
                e.append(V2(xe, -side * ti))
                let y0 = lod == 0 ? (row == 0 ? yc - hj / 2 + 0.0003 : yc) : yc - hj / 2 + 0.0003
                let y1 = lod == 0 ? (row == 0 ? yc : yc + hj / 2 - 0.0003) : yc + hj / 2 - 0.0003
                ins.append(SurgKit.plate(Shape2D.deduped(e), y0: y0, y1: y1, bevel: 0, material: inserts))
            }
            let taper: (V3) -> V3 = { p in
                let k = 1 - 0.3 * max(0, min(1, (p.x - 0.008) / (L - 0.008)))
                return V3(p.x, yc + (p.y - yc) * k, p.z)
            }
            body.deform(taper); ins.deform(taper)
            return [body, ins]
        }
        let half = openAngle / 2
        var rig = inst.rig(name: Self.id, halfOpen: half, switchDistance: 3, seed: seed, jaw: jaw)

        // Needle on the first ratchet click: the jaw gap at the grip equals the needle diameter.
        let grip = inst.clickAngle(2)                       // relative opening, degrees
        let xn: Float = 0.024
        let wireR = xn * grip * .pi / 180 / 2               // needle radius = half the gap
        rig.part("needle", pivot: V3(xn, yc, 0), joint: .fixed, options: 2)
        let R = needleRadius
        let center = V3(xn, yc - 0.0008, R)
        let arc: [V3] = (0...(28)).map { k in
            let phi = (184 - 135 * Float(k) / 28) * .pi / 180
            return center + V3(0, R * sin(phi), R * cos(phi))
        }
        let radii: [Float] = arc.indices.map { i in
            let t = Float(i) / Float(arc.count - 1)
            return t < 0.82 ? wireR : wireR * max(0.08, (1 - t) / 0.18)      // tapered point
        }
        var needle = Prim.tube(arc, radii: radii, sides: 6, seamTile: 0.002, material: "metal.surgical-mirror")
        needle.append(Prim.tube([arc[0] + V3(0, 0.0012, 0), arc[0] - V3(0, 0.0004, 0)], radii: [wireR * 1.1, wireR * 1.2], sides: 6, seamTile: 0.002,
                                material: "metal.surgical-mirror"))
        rig.add(needle, to: "needle", option: 1)
        // Braided suture from the swage down to the table, trailing in a loose S.
        let sr: Float = 0.00016
        let s0 = arc[0] - V3(0, 0.0004, 0)
        var ctrl: [V3] = [s0, V3(xn + 0.002, sr + 0.0004, -0.004), V3(xn + 0.012, sr, -0.012)]
        for k in 1...4 {
            let f = Float(k)
            ctrl.append(V3(xn + 0.012 + f * 0.012, sr, -0.012 - f * 0.009 + rng.float(-0.006...0.006)))
        }
        let sp = SurgKit.catmullPath(ctrl, per: 6)
        rig.add(Prim.tube(sp, radii: sp.map { _ in sr }, sides: 4, seamTile: 0.001, material: "fabric.nylon:" + String(format: "%06X", suture)),
                to: "needle", option: 1, lods: 0...0)

        rig.states = [RigState("open", ["a": half]), RigState("locked"), RigState("locked-with-needle", ["a": grip / 2], options: ["needle": 1])]
        SurgKit.settle(&rig, tilt: Xform(rotation: simd_quatf(angle: 0.006, axis: V3(0, 0, 1))))
        return rig
    }
}
