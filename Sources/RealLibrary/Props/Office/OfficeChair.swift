import simd
import Foundation

/// Ergonomic mesh task chair (Aeron / Steelcase class), 68 cm base, seat 44-54 cm: five-star aluminum
/// base on 65 mm twin-wheel casters, gas lift with a black telescoping shroud and chrome column, tilt
/// mechanism with tension knob and height paddle, upholstered seat on a black pan, curved mesh backrest
/// in a black frame with a lumbar bar on a cast spine, and height-adjustable T-armrests with soft pads.
/// Joints: lift (seat height) > swivel > recline (backrest), armrests slide on the swivel.
public struct OfficeChair: RealArticulated {
    public static let id = "office-chair"
    public static let summary = "Mesh task chair: five-star aluminum base on twin-wheel casters, gas lift, upholstered seat, framed mesh back with lumbar bar, T-arms."
    public static let tags = ["prop", "office", "furniture", "fabric", "metal", "articulated"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 12, distance: 1.2, studio: true)

    /// Base finish: "metal.aluminum-brushed" (polished) or "metal.anodized-black".
    public var base: MaterialKey = "metal.aluminum-brushed"
    /// Seat fabric tint (sRGB hex).
    public var seatColor: UInt32 = 0x2C2E32
    public var mesh: MaterialKey = "fabric.mesh"
    public var baseRadius: Float = 0.335
    public var seatWidth: Float = 0.5
    public var seatDepth: Float = 0.47
    public var backWidth: Float = 0.47
    public var backHeight: Float = 0.56
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [6])
        let black: MaterialKey = "plastic.black"
        let seatMat: MaterialKey = "fabric.upholstery:" + String(format: "%06X", seatColor)
        let R = baseRadius
        let hubTop: Float = 0.165, tipTop: Float = 0.112

        // MARK: base (static): hub, five tapered arms, twin-wheel casters, gas cylinder shroud.
        for l in 0..<2 {
            var m = Model(name: Self.id)
            m.add(Prim.lathe([V2(0, 0.105), V2(0.036, 0.105), V2(0.046, 0.115), V2(0.048, hubTop - 0.012), V2(0.042, hubTop), V2(0, hubTop)],
                             segments: l == 0 ? 28 : 14, material: base))
            let armProf = Shape2D.roundedRect(0.034, 0.052, radius: 0.012, segments: l == 0 ? 2 : 1)
            for k in 0..<5 {
                let a = Float(k) / 5 * 2 * .pi + 0.31
                let dir = V3(sin(a), 0, cos(a))
                let path = catmull([dir * 0.03 + V3(0, hubTop - 0.022, 0), dir * 0.16 + V3(0, hubTop - 0.03, 0),
                                    dir * (R - 0.02) + V3(0, tipTop - 0.016, 0)], per: l == 0 ? 4 : 2)
                let scales = path.indices.map { i -> Float in 1 - 0.32 * Float(i) / Float(path.count - 1) }
                m.add(Prim.sweep(armProf, along: path, up: .up, scales: scales, material: base))
                // Caster socket boss at the tip.
                let tip = dir * (R - 0.012)
                m.add(Prim.cylinder(radius: 0.019, height: 0.03, bevel: 0.006, segments: l == 0 ? 12 : 8, bevelSegments: 1, material: base),
                      Xform(translation: tip + V3(0, tipTop - 0.032, 0)))
                // Twin-wheel caster: stem, hooded housing, two wheels trailing on a common axle.
                let yaw = rng.float(-180...180)
                let q = simd_quatf(degrees: yaw, axis: .up)
                let trail: Float = 0.022, wr: Float = 0.0325
                let axle = tip + q.act(V3(0, wr, -trail))
                if l == 0 {
                    m.add(Prim.cylinder(radius: 0.0055, height: 0.03, bevel: 0.001, segments: 8, bevelSegments: 1, material: "metal.chrome"),
                          Xform(translation: tip + V3(0, tipTop - 0.05, 0)))
                }
                let hood = Prim.superellipsoid(V3(0.038, 0.05, 0.07), exponent: 3.2, subdivisions: l == 0 ? 3 : 2, material: black)
                m.add(hood, Xform(translation: tip + q.act(V3(0, wr + 0.016, -trail * 0.6)), rotation: q * simd_quatf(degrees: -12, axis: V3(1, 0, 0))))
                for side: Float in [-1, 1] {
                    let w = Prim.cylinder(radius: wr, height: 0.015, bevel: 0.006, segments: l == 0 ? 12 : 8, bevelSegments: 1, material: black)
                    m.add(w, Xform(translation: axle + q.act(V3(side * 0.0215, 0, 0)),
                                   rotation: q * simd_quatf(degrees: side * 90, axis: V3(0, 0, 1))))
                }
            }
            // Telescoping black shroud over the gas cylinder.
            m.add(Prim.lathe([V2(0.03, hubTop - 0.006), V2(0.031, hubTop + 0.01), V2(0.0295, 0.215), V2(0.0255, 0.222), V2(0.026, 0.282),
                              V2(0.0225, 0.29), V2(0.016, 0.292)], segments: l == 0 ? 24 : 12, material: black))
            rig.base[l] = m
        }

        // MARK: lift: chrome column, extends out of the shroud.
        let mechY: Float = 0.355          // mechanism underside
        rig.part("lift", pivot: V3(0, 0.29, 0), joint: .slide(axis: .up, 0...0.1, duration: 0.5))
        for l in 0..<2 {
            rig.add(Prim.cylinder(radius: 0.014, height: mechY + 0.005 - 0.19, bevel: 0.002, segments: l == 0 ? 18 : 10, bevelSegments: 1, material: "metal.chrome"),
                    Xform(translation: V3(0, 0.19, 0)), to: "lift", lods: l...l)
        }

        // MARK: swivel: mechanism, seat, arm sleeves.
        rig.part("swivel", parent: "lift", pivot: V3(0, mechY, 0), joint: .hinge(axis: .up, -180...180, duration: 1.2))
        let sw = seatWidth, sd = seatDepth, seatZ: Float = 0.03
        // Mechanism: cast body, front tension knob, side height paddle.
        rig.add(Prim.roundedBox(V3(0.17, 0.05, 0.26), radius: 0.012, bevelSegments: 2, material: "metal.anodized-black"),
                Xform(translation: V3(0, mechY + 0.025, 0.0)), to: "swivel")
        rig.add(Prim.roundedBox(V3(0.07, 0.04, 0.06), radius: 0.01, bevelSegments: 2, material: "metal.anodized-black"),
                Xform(translation: V3(0, mechY + 0.01, 0.0)), to: "swivel", lods: 0...0)
        rig.add(Prim.cylinder(radius: 0.026, height: 0.045, bevel: 0.006, segments: 20, bevelSegments: 2, material: black),
                Xform(translation: V3(0, mechY + 0.02, 0.13), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "swivel")
        rig.add(Prim.cylinder(radius: 0.022, height: 0.004, bevel: 0.0015, segments: 16, bevelSegments: 1, material: "plastic.matte:3A3B3E"),
                Xform(translation: V3(0, mechY + 0.02, 0.174), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "swivel", lods: 0...0)
        let paddle = catmull([V3(0.08, mechY + 0.03, 0.06), V3(0.15, mechY + 0.03, 0.08), V3(0.2, mechY + 0.04, 0.1)], per: 3)
        rig.add(Prim.sweep(Shape2D.roundedRect(0.008, 0.024, radius: 0.003, segments: 2), along: paddle, up: .up, material: black), to: "swivel")
        // Seat pan (black shell) and upholstered cushion with a waterfall front edge.
        let panY = mechY + 0.06
        let pan = Prim.superellipsoid(V3(sw - 0.02, 0.03, sd - 0.02), exponent: 6, subdivisions: 6, material: black)
        rig.add(pan, Xform(translation: V3(0, panY, seatZ)), to: "swivel")
        for l in 0..<2 {
            var cush = Prim.superellipsoid(V3(sw, 0.075, sd), exponent: 4.2, subdivisions: l == 0 ? 10 : 6, material: seatMat) { d in
                // Contoured: slight dish in the middle, rolled thigh edges.
                1 + 0.06 * max(0, d.y) * (abs(d.x) - 0.4)
            }
            cush.deform { p in
                var q = p
                let fz = (p.z / (sd / 2))                  // -1 back ... 1 front
                q.y += -0.022 * max(0, fz) * max(0, fz) * max(0, fz)   // waterfall
                q.y += 0.012 * max(0, -fz - 0.5)          // rear rise
                return q
            }
            rig.add(cush, Xform(translation: V3(0, panY + 0.048, seatZ)), to: "swivel", lods: l...l)
        }
        // Arm brackets under the seat with sleeves (static on the swivel).
        let armX: Float = sw / 2 + 0.02, sleeveTop = panY + 0.1
        for sx: Float in [-1, 1] {
            let br = catmull([V3(sx * 0.07, mechY + 0.03, -0.02), V3(sx * (armX - 0.04), mechY + 0.035, -0.02), V3(sx * armX, mechY + 0.07, -0.02),
                              V3(sx * armX, sleeveTop - 0.002, -0.02)], per: 4)
            rig.add(Prim.sweep(Shape2D.roundedRect(0.016, 0.05, radius: 0.006, segments: 1), along: br, up: V3(0, 0, 1), material: "metal.anodized-black"), to: "swivel")
            rig.add(Prim.roundedBox(V3(0.036, 0.09, 0.058), radius: 0.01, bevelSegments: 2, material: black),
                    Xform(translation: V3(sx * armX, sleeveTop - 0.045, -0.02)), to: "swivel")
        }

        // MARK: armrests: inner posts and T pads, left drives, right mimics.
        rig.part("arm-left", parent: "swivel", pivot: V3(-armX, sleeveTop, -0.02), joint: .slide(axis: .up, 0...0.08, duration: 0.4))
        rig.part("arm-right", parent: "swivel", pivot: V3(armX, sleeveTop, -0.02), joint: Joint(.prismatic, axis: .up, range: 0...0.08, mimic: .init("arm-left")))
        let padY = panY + 0.27
        for (name, sx) in [("arm-left", Float(-1)), ("arm-right", Float(1))] {
            rig.add(Prim.roundedBox(V3(0.028, padY - sleeveTop + 0.07, 0.044), radius: 0.008, bevelSegments: 2, material: black),
                    Xform(translation: V3(sx * armX, (sleeveTop + padY) / 2 - 0.035 - 0.012, -0.02)), to: name)
            rig.add(Prim.roundedBox(V3(0.06, 0.02, 0.1), radius: 0.008, bevelSegments: 2, material: black),
                    Xform(translation: V3(sx * armX, padY - 0.022, -0.01)), to: name)
            var pad = Prim.superellipsoid(V3(0.085, 0.03, 0.25), exponent: 3.5, subdivisions: 6, material: "rubber")
            pad.deform { p in V3(p.x, p.y - 0.004 * (p.x * p.x) / 0.0018 + 0.0, p.z) }
            rig.add(pad, Xform(translation: V3(sx * (armX - 0.004), padY, 0.0), rotation: simd_quatf(degrees: sx * 4, axis: .up)), to: name)
            // Adjustment button on the post front.
            rig.add(Prim.roundedBox(V3(0.016, 0.03, 0.01), radius: 0.004, bevelSegments: 1, material: "plastic.matte:3A3B3E"),
                    Xform(translation: V3(sx * armX, padY - 0.07, 0.004)), to: name, lods: 0...0)
        }

        // MARK: recline: spine and mesh backrest, pivot at the rear of the mechanism.
        rig.part("recline", parent: "swivel", pivot: V3(0, mechY + 0.03, -0.06), joint: .hinge(axis: V3(-1, 0, 0), 0...18, duration: 0.8))
        let bw = backWidth, bh = backHeight
        let backY0 = panY + 0.11, backZ0 = -sd / 2 + seatZ - 0.035
        /// Point on the backrest surface: u -1...1 across, v 0 (bottom) ... 1 (top).
        func backPt(_ u: Float, _ v: Float) -> V3 {
            let halfW = bw / 2 * (0.9 + 0.1 * v - 0.06 * exp(-pow((v - 0.25) / 0.2, 2)))
            let x = u * halfW
            let y = backY0 + v * bh
            let lumbar = 0.022 * exp(-pow((v - 0.25) / 0.16, 2))
            let z = backZ0 - v * bh * 0.2 + 0.055 * u * u * (0.7 + 0.3 * v) + lumbar * (1 - 0.6 * u * u) - 0.02 * v * v
            return V3(x, y, z)
        }
        for l in 0..<2 {
            let nu = l == 0 ? 12 : 6, nv = l == 0 ? 14 : 7
            var panel = Surface(material: mesh)
            for j in 0...nv { for i in 0...nu {
                let u = Float(i) / Float(nu) * 2 - 1, v = Float(j) / Float(nv)
                let p = backPt(u * 0.97, v * 0.97 + 0.015)
                _ = panel.add(p, V3(0, 0, 1), V2(p.x, p.y))
            }}
            let row = UInt32(nu + 1)
            for j in 0..<UInt32(nv) { for i in 0..<UInt32(nu) {
                let a = j * row + i
                panel.quad(a, a + 1, a + row + 1, a + row)
            }}
            panel.recomputeNormals(weldSeams: false)
            panel.computeTangents()
            rig.add(panel, to: "recline", lods: l...l)
            rig.add(panel.flipped(), Xform(translation: V3(0, 0, -0.0015)), to: "recline", lods: l...l)
            // Frame: oval tube around the perimeter.
            var loop: [V3] = []
            let n = l == 0 ? 10 : 5
            for i in 0..<n { loop.append(backPt(-1 + 2 * Float(i) / Float(n), 0)) }
            for j in 0..<n { loop.append(backPt(1, Float(j) / Float(n))) }
            for i in 0..<n { loop.append(backPt(1 - 2 * Float(i) / Float(n), 1)) }
            for j in 0..<n { loop.append(backPt(-1, 1 - Float(j) / Float(n))) }
            rig.add(Prim.sweep(Shape2D.roundedRect(0.024, 0.03, radius: 0.01, segments: l == 0 ? 2 : 1), along: loop, up: V3(0, 0, 1),
                               closedPath: true, caps: false, material: black), to: "recline", lods: l...l)
        }
        // Lumbar bar riding on the frame sides.
        let lum = (0...12).map { i -> V3 in backPt(-0.98 + 1.96 * Float(i) / 12, 0.24) + V3(0, 0, -0.016) }
        rig.add(Prim.sweep(Shape2D.roundedRect(0.012, 0.05, radius: 0.005, segments: 2), along: lum, up: V3(0, 0, 1), material: black), to: "recline")
        for sx: Float in [-1, 1] {
            rig.add(Prim.roundedBox(V3(0.03, 0.06, 0.03), radius: 0.008, bevelSegments: 2, material: black),
                    Xform(translation: backPt(sx * 1.0, 0.24) + V3(0, 0, -0.008)), to: "recline")
        }
        // Cast spine from the mechanism to the back of the frame.
        let b0 = backPt(0, 0), b1 = backPt(0, 0.12)
        let spine = catmull([V3(0, mechY + 0.03, -0.1), V3(0, mechY + 0.035, -0.2), V3(0, b0.y - 0.03, b0.z - 0.04), V3(0, b1.y, b1.z - 0.03)], per: 4)
        rig.add(Prim.sweep(Shape2D.roundedRect(0.024, 0.075, radius: 0.01, segments: 2), along: spine, up: .up,
                           scales: spine.indices.map { 1 - 0.1 * Float($0) / Float(spine.count) }, material: "metal.anodized-black"), to: "recline")
        // Back yoke across the bottom of the frame.
        let yoke = (0...10).map { i -> V3 in backPt(-0.9 + 1.8 * Float(i) / 10, 0.06) + V3(0, 0, -0.02) }
        rig.add(Prim.sweep(Shape2D.roundedRect(0.018, 0.045, radius: 0.007, segments: 2), along: yoke, up: V3(0, 0, 1), material: "metal.anodized-black"), to: "recline")

        groundAO(&rig, height: 0.06, floor: 0.6)
        rig.states = [RigState("default", ["lift": 0.05]), RigState("lowered"), RigState("raised", ["lift": 0.1, "arm-left": 0.06]),
                      RigState("reclined", ["lift": 0.05, "recline": 18]), RigState("turned", ["lift": 0.05, "swivel": 40])]
        return rig
    }
}
