import simd
import Foundation

/// Ceiling-mounted dual-head LED surgical light (Steris Harmony LED / Maquet PowerLED class): 620 mm ceiling
/// plate and bell canopy, 90 mm central axle with two stacked hubs, each carrying an 0.8 m extension arm
/// (rotates about the axle), a swivel knuckle, a tapered 0.8 m spring arm (lifts and lowers), a curved
/// cardan yoke that turns about its stem and a 700 mm lamp head that tilts in the yoke. The head is a
/// white molded housing with a grey bumper rim, a dark reflector plate with 112 LED lens cells, a
/// sterilizable center handle (head 1 wears a blue disposable handle cover) and a membrane keypad.
/// Authored in place for a 3.0 m ceiling: base y = 0 is the floor, the plate top sits at `mountHeight`.
/// Options: each head's lens field switches to lit 4500 K cells with a spot light (head 1 casts shadows).
public struct SurgicalLight: RealArticulated {
    public static let id = "surgical-light"
    public static let summary = "Dual-head ceiling LED surgical light: central axle, two extension and spring arms, cardan yokes and 700 mm lamp heads with lens arrays that switch on."
    public static let tags = ["structure", "medical", "hospital", "surgical", "interior", "ceiling", "light", "metal", "plastic", "articulated"]
    public static let budget = 19_800
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 12, distance: 1.0, studio: true)

    /// Ceiling height the plate is fixed to (m).
    public var mountHeight: Float = 3.0
    public var headDiameter: Float = 0.7
    public var extensionLength: Float = 0.8
    public var springLength: Float = 0.8
    /// Head center height with the spring arms level (m).
    public var headHeight: Float = 1.95
    public var housing: MaterialKey = "plastic.medical"
    public var armMaterial: MaterialKey = "metal.powder-white"
    public var trim: MaterialKey = "plastic.medical-grey:BFC4C8"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [10])
        let top = mountHeight, R = headDiameter / 2, L1 = extensionLength, L2 = springLength
        let headY = headHeight
        let canopyBottom = top - 0.17

        // MARK: ceiling plate, canopy, axle (static)
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let seg = l == 0 ? 48 : 24
            m.add(Prim.cylinder(radius: 0.31, height: 0.012, bevel: 0.003, segments: seg, bevelSegments: 1, material: armMaterial), Xform(translation: V3(0, top - 0.012, 0)))
            m.add(Prim.lathe([V2(0, canopyBottom), V2(0.1, canopyBottom), V2(0.125, canopyBottom + 0.006), V2(0.19, top - 0.07),
                              V2(0.228, top - 0.03), V2(0.236, top - 0.014), V2(0, top - 0.014)], segments: seg, seamTile: 0.2, material: housing))
            let axleBottom: Float = 2.38
            m.add(Prim.cylinder(radius: 0.045, height: canopyBottom - axleBottom + 0.01, bevel: 0.004, segments: l == 0 ? 28 : 14, bevelSegments: 1, material: armMaterial),
                  Xform(translation: V3(0, axleBottom, 0)))
            m.add(Prim.lathe([V2(0, axleBottom - 0.035), V2(0.025, axleBottom - 0.03), V2(0.045, axleBottom - 0.012), V2(0.048, axleBottom + 0.004), V2(0, axleBottom + 0.004)],
                             segments: l == 0 ? 28 : 14, seamTile: 0.1, material: trim))
            if l == 0 {
                // Canopy fixing screws.
                for k in 0..<4 {
                    let a = Float(k) * .pi / 2 + .pi / 4
                    m.add(HK.cyl(r: 0.004, len: 0.002, at: V3(cos(a) * 0.27, top - 0.0125, sin(a) * 0.27), axis: V3(0, -1, 0), mat: armMaterial, seg: 8, bevel: 0.0005))
                }
            }
            rig.base[l] = m
        }

        // MARK: arm systems (system 2 is system 1 turned 180 degrees about the axle)
        let Ry = R + 0.045
        let Xe = L1 + 0.08 + L2
        func system(_ k: Int, hubY hy: Float) {
            let sys = k == 1 ? Xform.identity : Xform(rotation: simd_quatf(degrees: 180, axis: .up))
            let flip: Float = k == 1 ? 1 : -1
            func P(_ p: V3) -> V3 { sys.point(p) }
            func put(_ s: Surface, _ part: String, _ lods: ClosedRange<Int>? = nil, option: Int = 0) {
                rig.add(s, sys, to: part, option: option, lods: lods)
            }
            let ext = "ext\(k)", swivel = "swivel\(k)", spring = "spring\(k)", yoke = "yoke\(k)", head = "head\(k)", lens = "lens\(k)"
            rig.part(ext, pivot: P(V3(0, hy, 0)), joint: .hinge(axis: .up, -170...170, duration: 2.4))
            rig.part(swivel, parent: ext, pivot: P(V3(L1, hy, 0)), joint: .hinge(axis: .up, -170...170, duration: 2.4))
            rig.part(spring, parent: swivel, pivot: P(V3(L1 + 0.08, hy, 0)), joint: .hinge(axis: V3(0, 0, flip), -50...45, duration: 1.6))
            rig.part(yoke, parent: spring, pivot: P(V3(Xe, hy, 0)), joint: .hinge(axis: .up, -180...180, duration: 2.0))
            rig.part(head, parent: yoke, pivot: P(V3(Xe, headY, 0)), joint: .hinge(axis: V3(flip, 0, 0), -70...70, duration: 1.4))
            rig.part(lens, parent: head, pivot: P(V3(Xe, headY, 0)), joint: .fixed, options: 2)

            for l in 0..<2 {
                let lo = l...l
                let seg = l == 0 ? 32 : 16
                // Extension arm: hub on the axle, rounded rectangular tube, end knuckle.
                put(Prim.cylinder(radius: 0.075, height: 0.12, bevel: 0.01, segments: seg, bevelSegments: l == 0 ? 2 : 1, material: armMaterial)
                        .transformed(Xform(translation: V3(0, hy - 0.06, 0))), ext, lo)
                put(HK.box(V3(L1 - 0.1, 0.08, 0.065), V3(L1 / 2 + 0.005, hy, 0), armMaterial, r: 0.022, seg: l == 0 ? 2 : 1), ext, lo)
                for dy: Float in [-0.062, 0.05] {
                    put(Prim.cylinder(radius: 0.078, height: 0.012, bevel: 0.003, segments: seg, bevelSegments: 1, material: trim)
                            .transformed(Xform(translation: V3(0, hy + dy, 0))), ext, lo)
                }
                if l == 0 {
                    // Parting seam along the top of the extension tube.
                    put(HK.box(V3(L1 - 0.16, 0.003, 0.012), V3(L1 / 2 + 0.005, hy + 0.0395, 0), "plastic.medical-grey:9AA1A7", r: 0.001, seg: 1), ext, lo)
                }
                put(Prim.cylinder(radius: 0.058, height: 0.11, bevel: 0.01, segments: seg, bevelSegments: l == 0 ? 2 : 1, material: armMaterial)
                        .transformed(Xform(translation: V3(L1, hy - 0.055, 0))), ext, lo)
                put(Prim.cylinder(radius: 0.06, height: 0.012, bevel: 0.003, segments: seg, bevelSegments: 1, material: trim)
                        .transformed(Xform(translation: V3(L1, hy - 0.068, 0))), swivel, lo)
                // Swivel clevis carrying the spring-arm lift joint.
                put(HK.box(V3(0.1, 0.1, 0.085), V3(L1 + 0.06, hy, 0), armMaterial, r: 0.028, seg: l == 0 ? 2 : 1), swivel, lo)
                // Spring arm: tapered side profile, grey side covers, end housing.
                let arm = Shape2D.rounded([V2(0, -0.043), V2(L2, -0.03), V2(L2, 0.03), V2(0, 0.043)], radius: 0.022, segments: l == 0 ? 3 : 1)
                put(Prim.extrude(arm, depth: 0.06, bevel: l == 0 ? 0.008 : 0.004, bevelSegments: l == 0 ? 2 : 1, material: armMaterial)
                        .transformed(Xform(translation: V3(L1 + 0.08, hy, 0))), spring, lo)
                let cover = Shape2D.rounded([V2(0.06, -0.022), V2(L2 - 0.08, -0.016), V2(L2 - 0.08, 0.016), V2(0.06, 0.022)], radius: 0.01, segments: 2)
                for sz: Float in [-1, 1] {
                    put(Prim.extrude(cover, depth: 0.004, bevel: 0.0015, bevelSegments: 1, material: trim)
                            .transformed(Xform(translation: V3(L1 + 0.08, hy, sz * 0.0305))), spring, lo)
                }
                put(Prim.cylinder(radius: 0.042, height: 0.1, bevel: 0.008, segments: seg, bevelSegments: l == 0 ? 2 : 1, material: armMaterial)
                        .transformed(Xform(translation: V3(Xe, hy - 0.055, 0))), spring, lo)
                // Yoke: stem and the curved cardan bow over the head, pivot caps at the sides.
                let stemTop = hy - 0.05, bowTop = headY + Ry
                put(HK.pipe([V3(Xe, stemTop, 0), V3(Xe, bowTop + 0.01, 0)], r: 0.021, sides: l == 0 ? 16 : 8, mat: armMaterial), yoke, lo)
                let n = l == 0 ? 28 : 12
                let bow = (0...n).map { i -> V3 in
                    let a = Float.pi * Float(i) / Float(n)
                    return V3(Xe + Ry * cos(a), headY + Ry * sin(a), 0)
                }
                put(Prim.tube(bow, radii: Array(repeating: 0.019, count: bow.count), sides: l == 0 ? 14 : 8, seamTile: 0.1, material: armMaterial), yoke, lo)
                for sx: Float in [-1, 1] {
                    put(HK.cyl(r: 0.03, len: 0.045, at: V3(Xe + sx * (Ry - 0.012), headY, 0), axis: V3(1, 0, 0), mat: trim, seg: l == 0 ? 18 : 10, bevel: 0.006), yoke, lo)
                }
                // Head: housing dome, grey bumper rim, dark reflector plate, center handle.
                let hseg = l == 0 ? 56 : 28
                let c = V3(Xe, headY, 0)
                put(Prim.lathe([V2(R - 0.004, 0.008), V2(R - 0.02, 0.04), V2(R - 0.07, 0.072), V2(0.2, 0.094), V2(0.09, 0.108), V2(0, 0.111)],
                               segments: hseg, seamTile: 0.3, material: housing).transformed(Xform(translation: c)), head, lo)
                put(Prim.lathe([V2(R - 0.03, -0.031), V2(R - 0.004, -0.028), V2(R + 0.006, -0.016), V2(R + 0.007, 0.0), V2(R - 0.002, 0.01)],
                               segments: hseg, seamTile: 0.3, material: trim).transformed(Xform(translation: c)), head, lo)
                put(Prim.lathe([V2(0, -0.0292), V2(R - 0.028, -0.0292), V2(R - 0.028, -0.02), V2(0, -0.02)], segments: hseg, seamTile: 0.3,
                               material: "plastic.medical-grey:2C2F33").transformed(Xform(translation: c)), head, lo)
                let grip: MaterialKey = "plastic.medical-grey:8A939A"
                put(Prim.lathe([V2(0, -0.175), V2(0.024, -0.172), V2(0.03, -0.162), V2(0.03, -0.15), V2(0.021, -0.142), V2(0.019, -0.07),
                                V2(0.03, -0.05), V2(0.048, -0.034), V2(0.05, -0.028), V2(0, -0.028)], segments: l == 0 ? 24 : 12, seamTile: 0.1, material: grip)
                        .transformed(Xform(translation: c)), head, lo)
                if k == 1 {
                    // Story: blue disposable sterile handle cover over head 1's grip.
                    put(Prim.lathe([V2(0, -0.183), V2(0.03, -0.18), V2(0.037, -0.165), V2(0.035, -0.12), V2(0.027, -0.07), V2(0.036, -0.056), V2(0.038, -0.05), V2(0, -0.05)],
                                   segments: l == 0 ? 24 : 12, seamTile: 0.1, material: "drape.surgical").transformed(Xform(translation: c)), head, lo)
                }
                if l == 0 {
                    // Membrane keypad on the dome (+Z side) with three buttons.
                    let kp = V3(Xe, headY + 0.052, R - 0.05)
                    let tilt = simd_quatf(degrees: 38, axis: V3(1, 0, 0))
                    put(HK.box(V3(0.085, 0.01, 0.042), kp, "plastic.medical-grey:3B4046", r: 0.004, seg: 1, rot: tilt), head, lo)
                    for bx: Float in [-0.024, 0, 0.024] {
                        put(HK.box(V3(0.016, 0.004, 0.016), kp + tilt.act(V3(bx, 0.006, 0.002)), "plastic.medical-grey:D5D9DC", r: 0.0015, seg: 1, rot: tilt), head, lo)
                    }
                    put(HK.cyl(r: 0.0025, len: 0.002, at: kp + tilt.act(V3(0.036, 0.005, -0.012)), axis: tilt.act(.up), mat: "plastic.medical-grey:2A4A30", seg: 8, bevel: 0.0005), lens, lo)
                    put(HK.cyl(r: 0.0025, len: 0.002, at: kp + tilt.act(V3(0.036, 0.005, -0.012)), axis: tilt.act(.up), mat: "emissive.led-green", seg: 8, bevel: 0.0005), lens, lo, option: 1)
                }
                // Lens field: 112 hexagonal LED lens cells (one surface), lit option swaps the material.
                for opt in 0..<2 {
                    let mat: MaterialKey = opt == 0 ? "glass.led-lens" : "emissive.surgical"
                    var cells = Surface(material: mat)
                    let yp = headY - 0.0294
                    if l == 0 {
                        for rr: Float in [0.075, 0.125, 0.175, 0.225, 0.275] {
                            let count = Int(2 * .pi * rr / 0.05)
                            for i in 0..<count {
                                let a = 2 * Float.pi * Float(i) / Float(count) + rr * 7
                                let cc = V3(Xe + cos(a) * rr, yp, sin(a) * rr)
                                let apex = cells.add(cc + V3(0, -0.006, 0), V3(0, -1, 0), V2(0.5, 0.5))
                                var rim: [UInt32] = []
                                for j in 0..<6 {
                                    let b = Float(j) * .pi / 3 + a
                                    let d = V3(cos(b), 0, sin(b))
                                    rim.append(cells.add(cc + d * 0.021, simd_normalize(d * 0.6 + V3(0, -1, 0)), V2(0.5 + 0.5 * cos(b), 0.5 + 0.5 * sin(b))))
                                }
                                for j in 0..<6 { cells.tri(apex, rim[j], rim[(j + 1) % 6]) }
                            }
                        }
                    } else {
                        cells = Prim.lathe([V2(0.05, -0.0322), V2(0.3, -0.0322), V2(0.3, -0.0295)], segments: 28, seamTile: 0.3, material: mat)
                            .transformed(Xform(translation: c))
                    }
                    put(cells, lens, lo, option: opt)
                }
            }
            rig.lights.append(RigLight(name: "beam\(k)", kind: .spot(inner: 12, outer: 24), part: lens, option: 1, position: P(V3(Xe, headY - 0.05, 0)),
                                       direction: V3(0, -1, 0), color: V3(1, 0.97, 0.93), intensity: 6000, attenuationRadius: 5, castsShadow: k == 1))
        }
        system(1, hubY: 2.66)
        system(2, hubY: 2.5)

        groundAO(&rig, height: 0.01, floor: 1)
        let on = ["lens1": 1, "lens2": 1]
        rig.states = [
            RigState("off"),
            RigState("on", options: on),
            RigState("positioned", ["ext1": 35, "swivel1": 125, "spring1": -12, "head1": -12,
                                    "ext2": 35, "swivel2": 125, "spring2": -12, "head2": -12], options: on),
            RigState("parked", ["ext1": 80, "swivel1": 150, "spring1": 35, "ext2": -110, "swivel2": -150, "spring2": 35]),
        ]
        // Default pose: arms over the table with both heads lit (thumbnails show the lens fields).
        rig.defaultState = "positioned"
        return rig
    }
}
