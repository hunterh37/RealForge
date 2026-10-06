import simd
import Foundation

/// Four-seat waiting-room beam seating (Arcadia / KI Arissa class, 600 mm seat pitch, 2.5 m overall):
/// 80 x 40 mm powder-coated steel beam on two T-legs with foot bars and nylon glides, four molded
/// black polypropylene seat and back shells carrying teal medical-vinyl pads, cast steel seat brackets
/// and back spines, three fixed armrests with polyurethane pads, two end arms that swing up for side
/// transfer and bariatric access, and a laminate tablet arm on the right end that folds down over the
/// end seat. Seat height 46 cm, arm height 65 cm.
public struct BeamSeating: RealArticulated {
    public static let id = "beam-seating"
    public static let summary = "Four-seat waiting-room beam seating: steel beam on T-legs, teal vinyl seats and backs on black shells, lift-up end arms and a fold-down tablet."
    public static let tags = ["prop", "medical", "hospital", "interior", "furniture", "metal", "plastic", "articulated"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 16, distance: 1.0, studio: true)

    public var seats = 4
    public var pitch: Float = 0.6
    public var seatHeight: Float = 0.46
    /// Upholstery: `vinyl.medical` (teal), `vinyl.medical-black`, or `vinyl.medical:RRGGBB`.
    public var upholstery: MaterialKey = "vinyl.medical"
    public var frame: MaterialKey = "metal.powdercoat:35373A"
    public var tablet = true
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        let rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [7])
        let n = max(2, seats), P = pitch
        let half = Float(n) * P / 2                      // end arm centre lines at +-half
        let beamY: Float = 0.33, beamZ: Float = -0.03
        let shellMat: MaterialKey = "plastic.matte:1E1F21", padMat: MaterialKey = "plastic.matte:2A2B2E"
        let flat = simd_quatf(degrees: -90, axis: V3(1, 0, 0))
        let seatTop = seatHeight, padH: Float = 0.06
        let shellY = seatTop - padH - 0.008
        let armY: Float = 0.645, pivotZ: Float = -0.13

        for l in 0..<2 {
            var m = Model(name: Self.id)
            let seg = l == 0 ? 2 : 1, sub = l == 0 ? 6 : 3
            // Beam with black end caps (runs past the end arms to carry the tablet bracket).
            let beamL = 2 * half + 0.1
            m.add(Prim.roundedBox(V3(beamL, 0.08, 0.04), radius: 0.004, bevelSegments: seg, material: frame), Xform(translation: V3(0, beamY, beamZ)))
            for s: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(0.006, 0.076, 0.036), radius: 0.002, bevelSegments: 1, material: "plastic.black"), Xform(translation: V3(s * (beamL / 2 + 0.002), beamY, beamZ)))
            }
            // T-legs between seats 1-2 and 3-4: post, foot bar, glides.
            for lx in [-P, P] {
                m.add(Prim.roundedBox(V3(0.06, beamY - 0.04 - 0.03, 0.04), radius: 0.004, bevelSegments: seg, material: frame),
                      Xform(translation: V3(lx, 0.03 + (beamY - 0.07) / 2, beamZ)))
                m.add(Prim.roundedBox(V3(0.06, 0.026, 0.6), radius: 0.006, bevelSegments: seg, material: frame), Xform(translation: V3(lx, 0.012 + 0.013, -0.01)))
                for gz: Float in [-0.28, 0.26] {
                    m.add(Prim.cylinder(radius: 0.022, height: 0.013, bevel: 0.003, segments: l == 0 ? 16 : 8, bevelSegments: 1, material: "plastic.black"),
                          Xform(translation: V3(lx, 0, gz)))
                }
            }
            for i in 0..<n {
                var r = rng.fork(i)
                let x = (Float(i) + 0.5) * P - half
                // Seat bracket: cast saddle from the beam to the shell.
                m.add(Prim.roundedBox(V3(0.24, shellY - beamY - 0.04, 0.05), radius: 0.008, bevelSegments: seg, material: frame),
                      Xform(translation: V3(x, beamY + 0.04 + (shellY - beamY - 0.04) / 2, beamZ + 0.02)))
                // Seat shell and pad (pad crowned, waterfall front, slight seat dish).
                let sw: Float = 0.52, sd: Float = 0.46
                m.add(Prim.extrude(Shape2D.superellipse(sw, sd, exponent: 5, segments: l == 0 ? 32 : 16), depth: 0.014, bevel: 0.004, bevelSegments: 1, material: shellMat),
                      Xform(translation: V3(x, shellY, 0.07), rotation: flat))
                var pad = Prim.superellipsoid(V3(sw - 0.02, padH, sd - 0.02), exponent: 5, subdivisions: sub, material: upholstery)
                let dish = r.float(0.004...0.009)
                pad.deform { p in
                    let fx = p.x / (sw / 2), fz = p.z / (sd / 2)
                    let d = max(0, 1 - fx * fx) * max(0, 1 - pow(fz + 0.1, 2)) * (p.y > 0 ? 1 : 0)
                    let front = p.z > sd / 2 - 0.06 && p.y > 0 ? (p.z - (sd / 2 - 0.06)) * 0.25 : 0
                    return p - V3(0, d * dish + front, 0)
                }
                m.add(pad, Xform(translation: V3(x, shellY + 0.007 + padH / 2, 0.07), rotation: simd_quatf(degrees: r.float(-0.5...0.5), axis: .up)))
                // Back spine: flat steel bar from the beam up behind the back shell.
                let spine = catmull([V3(x, beamY, beamZ - 0.02), V3(x, beamY + 0.08, -0.12), V3(x, 0.52, -0.23), V3(x, 0.66, -0.265)], per: l == 0 ? 4 : 2)
                m.add(Prim.sweep(Shape2D.roundedRect(0.05, 0.012, radius: 0.004, segments: 1), along: spine, up: V3(1, 0, 0), material: frame))
                // Back shell and pad, reclined 12 degrees.
                let bq = simd_quatf(degrees: -12, axis: V3(1, 0, 0))
                let bc = V3(x, 0.655, -0.25)
                m.add(Prim.extrude(Shape2D.superellipse(sw, 0.42, exponent: 5, segments: l == 0 ? 32 : 16), depth: 0.014, bevel: 0.004, bevelSegments: 1, material: shellMat),
                      Xform(translation: bc, rotation: bq))
                m.add(Prim.superellipsoid(V3(sw - 0.02, 0.4, 0.05), exponent: 5, subdivisions: sub, material: upholstery) { d in 1 + 0.06 * max(0, d.z) * (1 - d.y * d.y) },
                      Xform(translation: bc + bq.act(V3(0, 0, 0.031)), rotation: bq))
            }
            rig.base[l] = m
        }
        // Story detail: a strip of black repair tape over a split in the second seat's front edge.
        let tx = 1.5 * P - half + 0.08
        rig.base[0].add(Prim.roundedBox(V3(0.07, 0.03, 0.004), radius: 0.0015, bevelSegments: 1, material: "vinyl.medical-black"),
                        Xform(translation: V3(tx, shellY + 0.04, 0.07 + 0.23 - 0.004), rotation: simd_quatf(degrees: -14, axis: V3(1, 0, 0))))

        // MARK: armrests (inner ones fixed in the base, end ones on hinges at the rear of the pad)
        func arm(_ x: Float, lod: Int) -> (post: Surface, pad: Surface, front: Surface) {
            let post = Prim.tube(catmull([V3(x, beamY + 0.02, beamZ - 0.01), V3(x, 0.47, -0.08), V3(x, armY - 0.025, pivotZ)], per: lod == 0 ? 4 : 2),
                                 radii: Array(repeating: 0.014, count: lod == 0 ? 9 : 5), sides: lod == 0 ? 10 : 6, seamTile: 0.1, material: frame)
            let pad = Prim.superellipsoid(V3(0.056, 0.03, 0.36), exponent: 4, subdivisions: lod == 0 ? 4 : 2, material: padMat)
                .transformed(Xform(translation: V3(x, armY - 0.004, pivotZ + 0.175)))
            // Steel core plate under the pad, visible as a dark lip.
            let front = Prim.roundedBox(V3(0.04, 0.008, 0.33), radius: 0.003, bevelSegments: 1, material: frame)
                .transformed(Xform(translation: V3(x, armY - 0.021, pivotZ + 0.175)))
            return (post, pad, front)
        }
        for k in 0...n {
            let x = Float(k) * P - half
            let end = k == 0 || k == n
            for l in 0..<2 {
                let a = arm(x, lod: l)
                rig.base[l].add(a.post)
                if !end { rig.base[l].add(a.pad); rig.base[l].add(a.front) }
            }
            // Pivot knuckle on top of the post.
            rig.base[0].add(Prim.cylinder(radius: 0.017, height: 0.05, bevel: 0.003, segments: 12, bevelSegments: 1, material: frame),
                            Xform(translation: V3(x - 0.025, armY - 0.025, pivotZ), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
            if end {
                let name = k == 0 ? "left-arm" : "right-arm"
                rig.part(name, pivot: V3(x, armY - 0.025, pivotZ), joint: .hinge(axis: V3(1, 0, 0), -80...0, duration: 0.6))
                for l in 0..<2 {
                    let a = arm(x, lod: l)
                    rig.add(a.pad, to: name, lods: l...l)
                    rig.add(a.front, to: name, lods: l...l)
                }
            }
        }

        // MARK: tablet arm (folds about Z from hanging beside the right arm to flat over the end seat)
        if tablet {
            let px = half + 0.05, py = armY + 0.035, pz: Float = 0.02
            for l in 0..<2 {
                let bracket = Prim.tube(catmull([V3(half + 0.05, beamY, beamZ), V3(px + 0.004, 0.45, -0.02), V3(px + 0.004, py - 0.03, pz - 0.06)], per: l == 0 ? 4 : 2),
                                        radii: Array(repeating: 0.012, count: l == 0 ? 9 : 5), sides: l == 0 ? 8 : 6, seamTile: 0.1, material: frame)
                rig.base[l].add(bracket)
            }
            rig.base[0].add(Prim.cylinder(radius: 0.015, height: 0.06, bevel: 0.003, segments: 12, bevelSegments: 1, material: frame),
                            Xform(translation: V3(px + 0.006, py, pz - 0.09), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            rig.part("tablet", pivot: V3(px, py, pz), joint: .hinge(axis: V3(0, 0, 1), -90...0, duration: 0.7))
            let tw: Float = 0.3, td: Float = 0.38
            let outline = Shape2D.rounded([V2(0, -td / 2), V2(tw, -td / 2 + 0.03), V2(tw, td / 2 - 0.04), V2(0, td / 2)], radius: 0.04, segments: 3)
            // Board hangs down at rest: outline x -> -Y, outline y -> Z, thickness along X.
            let hang = simd_quatf(degrees: -90, axis: V3(0, 0, 1)) * simd_quatf(degrees: 90, axis: V3(1, 0, 0))
            rig.add(Prim.extrude(outline, depth: 0.014, bevel: 0.004, bevelSegments: 2, material: "laminate.white:DCD6CA"),
                    Xform(translation: V3(px + 0.012, py, pz + 0.03), rotation: hang), to: "tablet")
            rig.add(Prim.roundedBox(V3(0.02, 0.05, 0.08), radius: 0.004, bevelSegments: 1, material: frame), Xform(translation: V3(px + 0.012, py - 0.02, pz - 0.02)), to: "tablet")
        }

        groundAO(&rig, height: 0.12, floor: 0.55)
        rig.states = [
            RigState("default"),
            RigState("arms-up", ["left-arm": -80, "right-arm": -80]),
            RigState("tablet-down", ["tablet": -90]),
        ]
        return rig
    }
}
