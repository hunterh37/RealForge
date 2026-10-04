import simd
import Foundation

/// Standard folding hospital wheelchair (Invacare Tracer / Drive Silver Sport class), 18 in (457 mm)
/// seat at 49.5 cm, 68 cm wide, 91 cm to the push handles: 25 mm chrome steel side frames with fixed
/// arms and padded arm rests, folding X cross brace with a center pivot bolt, black vinyl seat and back
/// slings, 24 in rear wheels (solid tires, aluminum rims, 36 crossed spokes, push rims on six tabs),
/// 8 in front casters, swing-away footrest hangers with flip-up composite footplates, toggle wheel
/// locks. Front is +Z. Joints: wheels (hinge about the axle, right mimics left), footrests (hinge about
/// Y, swing outward) > footplates (flip up), wheel locks (hinge about X).
public struct Wheelchair: RealArticulated {
    public static let id = "wheelchair"
    public static let summary = "Folding hospital wheelchair: chrome tube frame with X-brace, 24-inch spoked wheels and push rims, 8-inch casters, swing-away footrests, black vinyl slings."
    public static let tags = ["prop", "medical", "hospital", "furniture", "metal", "articulated"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 14, distance: 1.9, studio: true)

    /// Sling vinyl.
    public var sling: MaterialKey = "vinyl.medical-black"
    /// Frame finish.
    public var frame: MaterialKey = "metal.chrome"
    /// Seat width between the side frames (m) and sling height (m).
    public var seatWidth: Float = 0.457
    public var seatHeight: Float = 0.495
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [7])
        let black: MaterialKey = "plastic.matte:1E1F21", grip: MaterialKey = "rubber"
        let fx = seatWidth / 2 + 0.006, tr: Float = 0.0127
        let axle = V2(0.305, -0.16)          // (y, z)
        let wheelX = fx + 0.05, wheelR: Float = 0.305
        let seatY = seatHeight - 0.01
        let caneZ: Float = -0.185, frontZ: Float = 0.24, lowY: Float = 0.3, armY: Float = 0.7

        // MARK: frame (static): side frames, canes, arms, casters, cross brace, slings.
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let sides = l == 0 ? 12 : 6, bs = l == 0 ? 5 : 2
            for s: Float in [-1, 1] {
                let x = s * fx
                // Back cane with the push handle bent rearward.
                let cane = PatientKit.bend([V3(x, lowY - 0.03, caneZ + 0.01), V3(x, 0.84, caneZ - 0.01), V3(x, 0.895, caneZ - 0.1)], radius: 0.06, seg: bs)
                m.add(PatientKit.tube(cane, r: tr, sides: sides, material: frame))
                m.add(PatientKit.tube(PatientKit.bend([V3(x, 0.887, caneZ - 0.06), V3(x, 0.907, caneZ - 0.175)], radius: 0.01), r: tr + 0.004, sides: sides, material: grip))
                // Side frame: lower rail, front post, arm rail back to the cane.
                let side = PatientKit.bend([V3(x, lowY, caneZ), V3(x, lowY, frontZ), V3(x, armY, frontZ), V3(x, armY, caneZ - 0.002)], radius: 0.045, seg: bs)
                m.add(PatientKit.tube(side, r: tr, sides: sides, material: frame))
                // Seat rail (sling tube) on the inside, with welded clips to the cane and front post.
                m.add(PatientKit.rod(V3(s * (fx - 0.012), seatY, caneZ + 0.012), V3(s * (fx - 0.012), seatY, frontZ + 0.01), r: 0.011, sides: sides, material: frame))
                // Arm pad.
                m.add(Prim.superellipsoid(V3(0.055, 0.035, 0.3), exponent: 4, subdivisions: l == 0 ? 5 : 3, material: black),
                      Xform(translation: V3(x, armY + 0.028, 0.02)))
                // Caster housing on the front post and the 8 in caster.
                m.add(Prim.cylinder(radius: 0.02, height: 0.065, bevel: 0.004, segments: l == 0 ? 14 : 8, bevelSegments: 1, material: frame),
                      Xform(translation: V3(x, lowY - 0.07, frontZ)))
                if l == 0 {
                    caster(&m, at: V3(x, 0, frontZ), height: 0.232, wheelRadius: 0.1, yaw: 180 + rng.float(-8...8), frame: frame, wheel: "rubber", hub: "plastic.matte:3A3B3E")
                    // Axle plate and nut.
                    m.add(PatientKit.box(V3(0.008, 0.09, 0.06), V3(x + s * 0.016, axle.x, axle.y), r: 0.003, seg: 1, material: frame))
                    m.add(Prim.cylinder(radius: 0.012, height: 0.01, bevel: 0.002, segments: 6, bevelSegments: 1, material: frame),
                          Xform(translation: V3(s * (wheelX + 0.045), axle.x, axle.y), rotation: simd_quatf(degrees: -s * 90, axis: V3(0, 0, 1))))
                    // Weld beads where the arm rail and lower rail meet the cane.
                    for y in [lowY, armY] { m.add(PatientKit.weld(at: V3(x, y, caneZ + tr), axis: V3(0, 0, 1), r: tr, material: frame)) }
                } else {
                    m.add(Prim.cylinder(radius: 0.1, height: 0.024, bevel: 0.006, segments: 10, bevelSegments: 1, material: "rubber"),
                          Xform(translation: V3(x - 0.012, 0.1, frontZ - 0.03), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
                    m.add(PatientKit.box(V3(0.04, 0.13, 0.03), V3(x, 0.17, frontZ - 0.015), r: 0.006, seg: 1, material: frame))
                    m.add(PatientKit.box(V3(0.06, 0.09, 0.06), V3(x + s * 0.016, axle.x, axle.y), r: 0.003, seg: 1, material: frame))
                }
            }
            // Folding X brace: two tubes crossing under the seat with a pivot bolt, a stay to the canes.
            let bz: Float = -0.01
            m.add(PatientKit.rod(V3(-fx + 0.012, lowY + 0.005, bz - 0.012), V3(fx - 0.012, seatY - 0.006, bz - 0.012), r: 0.011, sides: sides, material: frame))
            m.add(PatientKit.rod(V3(fx - 0.012, lowY + 0.005, bz + 0.012), V3(-fx + 0.012, seatY - 0.006, bz + 0.012), r: 0.011, sides: sides, material: frame))
            m.add(Prim.cylinder(radius: 0.009, height: 0.05, bevel: 0.002, segments: 8, bevelSegments: 1, material: "metal.stainless"),
                  Xform(translation: V3(0, (lowY + seatY) / 2, bz - 0.025), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            // Seat sling: sags between the rails, wraps them, double-sided.
            let seatPath = stride(from: caneZ + 0.005, through: frontZ + 0.02, by: l == 0 ? 0.04 : 0.1).map { V3(0, seatY + 0.011, $0) }
            let sag = { (j: Int, steps: Int) -> V3 in let u = Float(j) / Float(steps) * 2 - 1; return V3(0, -0.018 * (1 - u * u), 0) }
            let st = l == 0 ? 8 : 2
            var seat = PatientKit.ribbon(seatPath.reversed(), across: V3(1, 0, 0), width: 2 * fx - 0.01, steps: st, material: sling) { _, j in sag(j, st) }
            seat.append(seat.flipped(), Xform(translation: V3(0, -0.003, 0)))
            m.add(seat)
            // Back sling between the canes, bellied rearward.
            let backPath = stride(from: seatY + 0.05, through: 0.86, by: l == 0 ? 0.04 : 0.1).map { y -> V3 in V3(0, y, caneZ - 0.002 - (y - seatY) * 0.06) }
            var back = PatientKit.ribbon(backPath, across: V3(-1, 0, 0), width: 2 * fx - 0.005, steps: st, material: sling) { _, j in
                let u = Float(j) / Float(st) * 2 - 1; return V3(0, 0, -0.022 * (1 - u * u))
            }
            back.append(back.flipped(), Xform(translation: V3(0, 0, -0.003)))
            m.add(back)
            if l == 0 {
                // Rolled sling hems along the canes and a ward property tag on the back of the back sling.
                for s: Float in [-1, 1] {
                    m.add(PatientKit.rod(V3(s * (fx - 0.006), seatY + 0.05, caneZ - 0.006), V3(s * (fx - 0.006), 0.86, caneZ - 0.025), r: 0.016, sides: 8, material: sling))
                    m.add(PatientKit.rod(V3(s * (fx - 0.016), seatY + 0.01, caneZ + 0.01), V3(s * (fx - 0.016), seatY + 0.01, frontZ + 0.0), r: 0.016, sides: 8, material: sling))
                }
                m.add(PatientKit.panel(V3(0.06, 0.74, caneZ - 0.042), right: V3(-1, 0, 0), up: .up, w: 0.08, h: 0.05, material: "label.rx"))
            }
            rig.base[l] = m
        }

        // MARK: rear wheels: tire, rim, hub, 36 crossed spokes, push rim on tabs.
        rig.part("wheel-left", pivot: V3(-wheelX, axle.x, axle.y), joint: .hinge(axis: V3(1, 0, 0), -360...360, duration: 1.5))
        rig.part("wheel-right", pivot: V3(wheelX, axle.x, axle.y), joint: Joint(.revolute, axis: V3(1, 0, 0), range: -360...360, mimic: .init("wheel-left")))
        let toX = simd_quatf(degrees: 90, axis: V3(0, 0, 1))
        for (name, s) in [("wheel-left", Float(-1)), ("wheel-right", Float(1))] {
            let c = V3(s * wheelX, axle.x, axle.y)
            for l in 0..<2 {
                let seg = l == 0 ? 48 : 24
                rig.add(Prim.torus(major: wheelR - 0.017, minor: 0.017, segments: seg, sides: l == 0 ? 7 : 5, minorY: 0.016, material: "rubber"),
                        Xform(translation: c, rotation: toX), to: name, lods: l...l)
                rig.add(Prim.torus(major: wheelR - 0.036, minor: 0.008, segments: seg, sides: l == 0 ? 6 : 4, minorY: 0.012, material: "metal.aluminum-brushed"),
                        Xform(translation: c, rotation: toX), to: name, lods: l...l)
                let pr = c + V3(s * 0.038, 0, 0)
                rig.add(Prim.torus(major: 0.265, minor: 0.0095, segments: seg, sides: l == 0 ? 8 : 4, material: frame), Xform(translation: pr, rotation: toX), to: name, lods: l...l)
                rig.add(Prim.cylinder(radius: 0.028, height: 0.075, bevel: 0.006, segments: l == 0 ? 16 : 8, bevelSegments: 1, material: "metal.aluminum-brushed"),
                        Xform(translation: c + V3(-s * 0.04, 0, 0), rotation: simd_quatf(degrees: -s * 90, axis: V3(0, 0, 1))), to: name, lods: l...l)
            }
            // Push rim standoff tabs.
            var tabs = Surface(material: frame)
            for k in 0..<6 {
                let a = Float(k) / 6 * 2 * .pi
                let d = V3(0, cos(a), sin(a))
                tabs.append(PatientKit.rod(c + d * (wheelR - 0.04), c + d * 0.265 + V3(s * 0.038, 0, 0), r: 0.004, sides: 5, material: frame))
            }
            rig.add(tabs, to: name)
            // Spokes: 36, alternate flanges, crossed tangentially.
            var spokes = Surface(material: "metal.stainless")
            for k in 0..<36 {
                let side: Float = k % 2 == 0 ? 1 : -1
                let a = Float(k) / 36 * 2 * .pi
                let hubA = a + side * 0.35
                let h = c + V3(side * 0.028, cos(hubA) * 0.026, sin(hubA) * 0.026)
                let r = c + V3(0, cos(a) * (wheelR - 0.042), sin(a) * (wheelR - 0.042))
                spokes.append(Prim.tube([h, r], radii: [0.0011, 0.0011], sides: 3, seamTile: 0.01, material: spokes.material, capEnd: false))
            }
            rig.add(spokes, to: name, lods: 0...0)
            // LOD1: the spoke field reads as a thin translucent disc.
            rig.add(Prim.cylinder(radius: wheelR - 0.04, height: 0.003, bevel: 0, segments: 20, bevelSegments: 1, material: "plastic.frosted:A9ADB2"),
                    Xform(translation: c + V3(-0.0015, 0, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: name, lods: 1...1)
            // Valve stem as a spin cue.
            rig.add(PatientKit.rod(c + V3(0, wheelR - 0.045, 0), c + V3(0, wheelR - 0.03, 0), r: 0.003, sides: 6, material: "metal.brass"), to: name, lods: 0...0)
        }

        // MARK: swing-away footrests with flip-up footplates.
        let pivZ = frontZ + 0.012, pivY: Float = seatY - 0.02
        for (name, s) in [("footrest-left", Float(-1)), ("footrest-right", Float(1))] {
            let x = s * fx
            if s < 0 {
                rig.part(name, pivot: V3(x, pivY, pivZ), joint: .hinge(axis: V3(0, -1, 0), 0...90, duration: 0.8))
            } else {
                rig.part(name, pivot: V3(x, pivY, pivZ), joint: Joint(.revolute, axis: V3(0, 1, 0), range: 0...90, mimic: .init("footrest-left")))
            }
            // Hanger: latch block at the top, bent tube down and forward, plate bracket at the bottom.
            rig.add(PatientKit.box(V3(0.036, 0.05, 0.04), V3(x, pivY + 0.005, pivZ + 0.02), r: 0.006, seg: 2, material: black), to: name)
            let hanger = PatientKit.bend([V3(x, pivY, pivZ + 0.03), V3(x, pivY - 0.05, pivZ + 0.06), V3(s * (fx - 0.02), 0.13, pivZ + 0.2)], radius: 0.06, seg: 4)
            rig.add(PatientKit.tube(hanger, r: tr, sides: 10, material: frame), to: name)
            rig.add(PatientKit.box(V3(0.03, 0.04, 0.03), V3(s * (fx - 0.022), 0.115, pivZ + 0.205), r: 0.004, seg: 1, material: black), to: name)
            let plate = "footplate-" + (s < 0 ? "left" : "right")
            let px = s * (fx - 0.035)
            rig.part(plate, parent: name, pivot: V3(px, 0.105, pivZ + 0.2), joint: .hinge(axis: V3(0, 0, -s), 0...85, duration: 0.5))
            let pw: Float = 0.165
            var p = Prim.extrude(Shape2D.roundedRect(pw, 0.14, radius: 0.02, segments: 3), depth: 0.01, bevel: 0.002, bevelSegments: 1, material: black)
            p = p.transformed(Xform(translation: V3(px - s * pw / 2, 0.1, pivZ + 0.215), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
            rig.add(p, to: plate)
            var ribs = Surface(material: black)
            for k in 0..<6 {
                ribs.append(cuboid(V3(pw - 0.03, 0.003, 0.005), material: black), Xform(translation: V3(px - s * pw / 2, 0.1065, pivZ + 0.165 + Float(k) * 0.02)))
            }
            rig.add(ribs, to: plate, lods: 0...0)
        }

        // MARK: toggle wheel locks: lever with a rubber tip, shoe toward the tire.
        let lockZ: Float = 0.2, lockY: Float = 0.37
        for (name, s) in [("lock-left", Float(-1)), ("lock-right", Float(1))] {
            let x = s * (fx + 0.022)
            rig.part(name, pivot: V3(x, lockY, lockZ), joint: .hinge(axis: V3(1, 0, 0), 0...24, duration: 0.3))
            rig.add(PatientKit.box(V3(0.012, 0.03, 0.05), V3(x, lockY, lockZ), r: 0.003, seg: 1, material: frame), to: name)
            rig.add(PatientKit.rod(V3(x, lockY, lockZ), V3(x, lockY + 0.16, lockZ + 0.05), r: 0.006, sides: 8, material: frame), to: name)
            rig.add(Prim.superellipsoid(V3(0.022, 0.05, 0.022), exponent: 2.5, subdivisions: 3, material: "rubber:B3261E"),
                    Xform(translation: V3(x, lockY + 0.17, lockZ + 0.053), rotation: simd_quatf(degrees: 17, axis: V3(1, 0, 0))), to: name)
            let shoe = PatientKit.bend([V3(x, lockY, lockZ), V3(x, lockY - 0.02, lockZ - 0.03), V3(x, lockY - 0.03, lockZ - 0.04)], radius: 0.01, seg: 2)
            rig.add(Prim.sweep(Shape2D.roundedRect(0.008, 0.016, radius: 0.002, segments: 1), along: shoe, up: V3(1, 0, 0), material: frame), to: name)
            rig.add(PatientKit.box(V3(0.036, 0.016, 0.012), V3(s * (fx + 0.038), lockY - 0.03, lockZ - 0.042), r: 0.003, seg: 1, material: frame), to: name)
            // Clamp to the lower rail.
            rig.add(PatientKit.box(V3(0.016, 0.07, 0.022), V3(s * (fx + 0.012), lockY - 0.035, lockZ), r: 0.003, seg: 1, material: black), to: name, lods: 0...0)
        }

        groundAO(&rig, height: 0.08, floor: 0.6)
        rig.states = [RigState("ready"), RigState("footrests-away", ["footrest-left": 90, "footplate-left": 85, "footplate-right": 85]),
                      RigState("brakes-on", ["lock-left": 24, "lock-right": 24]), RigState("rolled", ["wheel-left": 140])]
        return rig
    }
}
