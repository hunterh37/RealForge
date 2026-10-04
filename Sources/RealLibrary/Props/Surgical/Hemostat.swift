import simd
import Foundation

/// Kelly hemostatic forceps, 5.5 in (140 mm), curved: two coplanar stainless members crossing at a box
/// lock with flush screw heads; polished jaws 36 mm long curving 4.5 mm to one side, transverse
/// serrations on the distal 60 % of the gripping faces; satin shanks; three-tooth ratchet tabs by the
/// oval finger rings (20 x 17.5 mm inside). Lies flat; both members hinge about the box screw (Y), the
/// second mimicking the first, so the ratchet re-engages tooth by tooth. Story detail: yellow ID tape.
public struct Hemostat: RealArticulated {
    public static let id = "hemostat"
    public static let summary = "Kelly hemostatic forceps, 5.5 in curved: box-lock joint, serrated curved jaws, three-tooth ratchet and satin finger rings."
    public static let tags = ["prop", "medical", "surgical", "handheld", "tool", "metal", "articulated"]
    public static let budget = 4_800
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 18, elevation: 58, distance: 0.27, studio: true)

    /// Jaw length from the box screw to the tip (m).
    public var jawLength: Float = 0.040
    /// Lateral curve of the jaws at the tip (m); 0 gives a straight Kelly.
    public var curve: Float = 0.0045
    /// Opening between the members in the "open" state (degrees).
    public var openAngle: Float = 30
    public var jaws: MaterialKey = "metal.surgical-mirror"
    /// ID tape color (sRGB hex); 0 removes it.
    public var tape: UInt32 = 0xE8C020
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var inst = BoxLockInstrument()
        inst.tape = tape
        let L = jawLength, yc = inst.yc
        let x0: Float = 0.004, ps: Float = 0.00085, amp: Float = 0.0002
        func center(_ x: Float) -> Float { let u = max(0, x - x0) / (L - x0); return -curve * u * u }
        func outer(_ x: Float) -> Float {
            var w: Float = x < 0.006 ? 0.0029 : 0.0029 - (x - 0.006) / (L - 0.006) * 0.0016
            let rt: Float = 0.002
            if x > L - rt { let u = (x - (L - rt)) / rt; w *= sqrt(max(0.04, 1 - u * u)) }
            return w
        }
        let serrStart = x0 + (L - x0) * 0.4
        func serr(_ x: Float) -> Float {
            guard x > serrStart && x < L - 0.0006 else { return 0 }
            let f = (x - serrStart) / ps
            return amp * (abs(f - floor(f) - 0.5) * 4 - 1)
        }
        let jawHalf = openAngle / 2
        func jaw(_ side: Float, _ lod: Int) -> [Surface] {
            // Contact edge (serrated), then the outer edge back; side +1 lies on the -Z side of the curve.
            var xs: [Float] = []
            var x: Float = -0.004
            while x < serrStart { xs.append(x); x += lod == 0 ? 0.0025 : 0.005 }
            if lod == 0 { var k: Float = 0; while serrStart + k * ps / 2 < L - 0.0006 { xs.append(serrStart + k * ps / 2); k += 1 } }
            else { var k: Float = 0; while serrStart + k * 0.004 < L - 0.0006 { xs.append(serrStart + k * 0.004); k += 1 } }
            xs.append(L)
            let clear: Float = 0.00003
            var o: [V2] = xs.map { V2($0, center($0) + (lod == 0 ? serr($0) : 0) + side * -clear) }
            let back: [Float] = stride(from: L, through: -0.004, by: lod == 0 ? -0.0015 : -0.004).map { $0 }
            o += back.map { V2($0, center($0) - side * outer($0)) }
            var s = SurgKit.plate(Shape2D.deduped(o), y0: yc - 0.0018, y1: yc + 0.0018, bevel: 0.0003, segments: 1, material: jaws)
            // Jaws thin toward the tip (3.6 mm at the box, 2.2 mm at the tip).
            s.deform { p in
                let k = 1 - 0.39 * max(0, min(1, (p.x - 0.006) / (L - 0.006)))
                return V3(p.x, yc + (p.y - yc) * k, p.z)
            }
            return [s]
        }
        var rig = inst.rig(name: Self.id, halfOpen: jawHalf, switchDistance: 2.5, seed: seed, jaw: jaw)
        // First click: one tooth engaged, two pitches of travel back from full lock.
        let firstClick = inst.clickAngle(inst.teeth - 1) / 2
        rig.states = [RigState("open", ["a": jawHalf]), RigState("closed-locked"), RigState("first-click", ["a": firstClick])]
        // The box cheeks stand 0.6 mm proud, so it rests tipped onto the rings.
        SurgKit.settle(&rig, tilt: Xform(rotation: simd_quatf(angle: 0.0095, axis: V3(0, 0, 1))))
        return rig
    }
}
