import simd
import Foundation

/// Molded plastic table-saw push stick, 356 mm (14 in) long and 12.7 mm (1/2 in) thick, lying flat on its
/// side. A flat shaft runs from a closed handle loop (88 x 38 mm finger opening, ridged top bar, molded 0.4 mm
/// proud of the shaft) to a notched heel: the heel tooth drops 14 mm below the toe so it hooks the trailing end
/// of a board while the toe presses down on it. Molded details: raised label panel on both faces, ejector pin
/// marks, and a blade nick in the heel from one pass too close.
///
/// Frame: lies flat (thickness along Y, base at y = 0). Length along X with the handle at -X and the heel at +X;
/// the shaft's bottom (pushing) edge faces +Z. Use `grip` and `heelNotch` to place a hand and a board corner.
public struct PushStick: RealAsset {
    public static let id = "push-stick"
    public static let summary = "Orange molded plastic push stick, 14 in long: flat shaft, closed handle loop with grip ridges, notched heel."
    public static let tags = ["prop", "workshop", "tool", "handheld", "plastic"]
    public static let budget = 3_600
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 25, elevation: 48, distance: 0.75, studio: true)

    /// Overall length tip to handle (m).
    public var length: Float = 0.356
    /// Shaft thickness (m); the handle loop is 0.8 mm thicker.
    public var thickness: Float = 0.0127
    /// Plastic tint (sRGB hex), safety orange.
    public var color: UInt32 = 0xE8650F
    public init() {}

    // Profile in (u along the length from the handle end, v across from the pushing edge), meters, before
    // scaling to `length` and recentring.
    static let uMin: Float = 0.0115, uMax: Float = 0.356, vMin: Float = 0, vMax: Float = 0.0985
    private var k: Float { length / (Self.uMax - Self.uMin) }

    /// Maps profile (u, v) and a height above the floor to asset space.
    private func place(_ u: Float, _ v: Float, _ y: Float) -> V3 {
        V3((u - (Self.uMin + Self.uMax) / 2) * k, y, -(v - (Self.vMin + Self.vMax) / 2) * k)
    }

    /// Centre of the handle loop's top bar at mid-thickness: where the palm closes (asset space).
    public var grip: V3 { place(0.0725, 0.09, (thickness + 0.0008) / 2) }
    /// Inner corner of the heel notch at mid-thickness: the board's trailing top corner sits here (asset space).
    public var heelNotch: V3 { place(0.330, 0.014, (thickness + 0.0008) / 2) }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let mat: MaterialKey = "plastic.tool:" + String(format: "%06X", color)
        let t = thickness, tl = thickness + 0.0008
        let lift = tl / 2
        // XY outline -> asset: u -> X, v -> -Z, extrude depth -> Y.
        let toFlat = simd_quatf(degrees: -90, axis: V3(1, 0, 0))
        let uc = (Self.uMin + Self.uMax) / 2, vc = (Self.vMin + Self.vMax) / 2
        func flat(_ s: Surface, y: Float) -> Surface {
            var o = s.transformed(Xform(translation: V3(-uc, -vc, 0)))
            o = o.transformed(Xform(rotation: toFlat))
            o.deform { p in V3(p.x * k, p.y + y, p.z * k) }
            return o
        }
        let nickU = 0.305 + rng.float(-0.005...0.005)

        func level(_ l: Int) -> Model {
            var m = Model(name: Self.id)
            let fil: Float = l == 0 ? 0.0016 : 0.0012, fs = l == 0 ? 3 : 1
            // Shaft with the riser into the loop, heel notch and a blade nick.
            var shaft: [V2] = [
                V2(0.05, 0), V2(nickU + 0.0022, 0)]
            if l == 0 { shaft += [V2(nickU + 0.0016, 0.0024), V2(nickU - 0.0016, 0.0024), V2(nickU - 0.0022, 0)] }
            shaft += [V2(0.330, 0), V2(0.330, 0.014), V2(0.356, 0.014), V2(0.356, 0.027), V2(0.349, 0.034),
                      V2(0.165, 0.034), V2(0.135, 0.039), V2(0.11, 0.04), V2(0.03, 0.04), V2(0.02, 0.032), V2(0.024, 0.014)]
            let shaftS = Prim.extrude(Shape2D.rounded(shaft, radius: fil, segments: fs), depth: t, bevel: 0.0017,
                                      bevelSegments: l == 0 ? 2 : 1, material: mat)
            m.add(flat(shaftS, y: lift))
            // Closed handle loop: rounded-rect centreline, soft rectangular section (thickness x 17 mm).
            let cu: Float = 0.0725, cv: Float = 0.0625, hw: Float = 0.0525, hh: Float = 0.0275, rr: Float = 0.016
            let ring = Shape2D.roundedRect(hw * 2, hh * 2, radius: rr, segments: l == 0 ? 6 : 3).map { V3($0.x + cu, $0.y + cv, 0) }
            let sec = Shape2D.superellipse(tl, 0.017, exponent: 3.2, segments: l == 0 ? 16 : 8)
            let loop = Prim.sweep(sec, along: ring, up: V3(0, 0, 1), closedPath: true, material: mat)
            m.add(flat(loop, y: lift))
            // Grip ridges across the top bar's outer edge.
            if l == 0 {
                for i in 0..<9 {
                    let u = cu - 0.032 + Float(i) * 0.008
                    let r = Prim.roundedBox(V3(0.0026, 0.0022, tl - 0.003), radius: 0.0009, bevelSegments: 1, material: mat)
                    m.add(flat(r.transformed(Xform(translation: V3(u, cv + hh + 0.0085, 0))), y: lift))
                }
                // Raised label panel and ejector pin marks on both faces.
                let panel = Prim.extrude(Shape2D.roundedRect(0.13, 0.016, radius: 0.004, segments: 3), depth: 0.0012, bevel: 0.0004,
                                         bevelSegments: 1, material: mat)
                for face: Float in [-1, 1] {
                    let y = lift + face * (t / 2 - 0.0002)
                    m.add(flat(panel.transformed(Xform(translation: V3(0.235, 0.017, 0))), y: y))
                    for (u, v) in [(Float(0.07), Float(0.0225)), (0.15, 0.017), (0.322, 0.025)] {
                        let pin = Prim.cylinder(radius: 0.0021, height: 0.0004, bevel: 0.0001, segments: 10, bevelSegments: 1, material: "plastic.tool:C9560C")
                        let base = place(u, v, lift + face * (t / 2 - 0.0001))
                        m.add(face > 0 ? pin : pin.transformed(Xform(rotation: simd_quatf(degrees: 180, axis: V3(1, 0, 0)))), Xform(translation: base))
                    }
                }
                // Scuffed, sawdust-greyed heel face (a thin worn skin just proud of the heel tooth).
                let scuff = Prim.extrude([V2(0.316, 0.0003), V2(0.3295, 0.0003), V2(0.3295, 0.0134), V2(0.316, 0.006)], depth: t + 0.0004, bevel: 0.0012,
                                         bevelSegments: 1, material: "plastic.tool:C8581A")
                m.add(flat(scuff, y: lift))
                // Blade scratches across the toe (story: it has met the saw a few times), top face.
                var marks = Surface(material: "plastic.tool:A8460E")
                for i in 0..<4 {
                    let u0 = rng.float(0.300...0.322), ang = rng.float(-0.3...0.3)
                    let len = rng.float(0.008...0.02), w: Float = 0.00045
                    let d = V2(sin(ang), cos(ang)) * len, n2 = V2(cos(ang), -sin(ang)) * w
                    let v0 = rng.float(0.001...0.012) + (i == 0 ? 0 : 0.004)
                    let c = V2(u0, v0)
                    let quad = [c - n2, c + n2, c + n2 + d, c - n2 + d]
                    let b = UInt32(marks.positions.count)
                    for q in quad { _ = marks.add(place(q.x, min(q.y, 0.033), t + 0.0006 + 0.00005), V3(0, 1, 0), q) }
                    marks.quad(b, b + 1, b + 2, b + 3)
                }
                marks.computeTangents()
                m.add(marks)
            }
            return m
        }
        var m0 = level(0), m1 = level(1)
        groundAO(&m0, height: 0.01, floor: 0.6)
        groundAO(&m1, height: 0.01, floor: 0.6)
        return LODModel(levels: [m0, m1], switchDistances: [1.5])
    }
}
