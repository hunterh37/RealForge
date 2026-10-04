import simd
import Foundation

/// Rolling physician stool (Midmark 272 / Clinton 2110 class): 635 mm five-star polished aluminum base
/// on 50 mm swivel casters, black gas-lift shroud with a 28 mm chrome piston, 19 mm chrome tube foot ring
/// (440 mm) on a three-spoke clamp collar, 406 mm round seat (75 mm foam in black medical vinyl with a
/// welted top seam) on a molded pan with a swivel plate and a height release paddle. Seat height
/// 48-64 cm. Joints: lift (gas spring slide) > swivel (seat turns about Y).
public struct DoctorStool: RealArticulated {
    public static let id = "doctor-stool"
    public static let summary = "Rolling physician stool: five-star cast base on casters, gas lift with chrome foot ring, swiveling round black vinyl seat with welted seam."
    public static let tags = ["prop", "medical", "hospital", "furniture", "metal", "articulated"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 16, distance: 1.1, studio: true)

    /// Seat cover material.
    public var seatMaterial: MaterialKey = "vinyl.medical-black"
    /// Base finish: "metal.aluminum-brushed" (polished) or "plastic.matte:1E1F21" (black nylon).
    public var baseMaterial: MaterialKey = "metal.aluminum-brushed"
    public var baseRadius: Float = 0.3
    public var seatRadius: Float = 0.203
    /// Seat top at the lowest setting (m) and gas-lift travel (m).
    public var seatHeight: Float = 0.48
    public var travel: Float = 0.16
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [6])
        let black: MaterialKey = "plastic.matte:1E1F21", chrome: MaterialKey = "metal.chrome"
        let R = baseRadius
        let hubTop: Float = 0.135, tipTop: Float = 0.095, casterH: Float = 0.068
        let seatTop = seatHeight, cushionH: Float = 0.075
        let panY = seatTop - cushionH - 0.004          // pan underside top
        let plateY = panY - 0.03                        // swivel plate underside
        let shroudTop: Float = 0.33

        // MARK: base: hub, five tapered arms, sockets, casters, gas-lift shroud, foot ring.
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let segs = l == 0 ? 28 : 14
            m.add(Prim.lathe([V2(0, 0.082), V2(0.034, 0.082), V2(0.044, 0.09), V2(0.046, hubTop - 0.012), V2(0.04, hubTop), V2(0, hubTop)],
                             segments: segs, material: baseMaterial))
            let armProf = Shape2D.roundedRect(0.03, 0.044, radius: 0.011, segments: l == 0 ? 2 : 1)
            for k in 0..<5 {
                let a = Float(k) / 5 * 2 * .pi
                let dir = V3(sin(a), 0, cos(a))
                let path = catmull([dir * 0.03 + V3(0, hubTop - 0.022, 0), dir * 0.15 + V3(0, hubTop - 0.026, 0),
                                    dir * (R - 0.018) + V3(0, tipTop - 0.014, 0)], per: l == 0 ? 4 : 2)
                let scales = path.indices.map { i -> Float in 1 - 0.3 * Float(i) / Float(path.count - 1) }
                m.add(Prim.sweep(armProf, along: path, up: .up, scales: scales, material: baseMaterial))
                let tip = dir * (R - 0.01)
                m.add(Prim.cylinder(radius: 0.017, height: 0.026, bevel: 0.005, segments: l == 0 ? 14 : 8, bevelSegments: 1, material: baseMaterial),
                      Xform(translation: tip + V3(0, casterH - 0.002, 0)))
                let yaw = rng.float(-180...180)
                if l == 0 {
                    caster(&m, at: tip, height: casterH, wheelRadius: 0.025, yaw: yaw, frame: black, wheel: "rubber", hub: "plastic.matte:3A3B3E")
                } else {
                    let q = simd_quatf(degrees: yaw, axis: .up)
                    m.add(Prim.cylinder(radius: 0.025, height: 0.02, bevel: 0.004, segments: 8, bevelSegments: 1, material: black),
                          Xform(translation: tip + q.act(V3(0.009, 0.025, -0.01)), rotation: q * simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
                    m.add(PatientKit.box(V3(0.036, casterH - 0.03, 0.03), tip + V3(0, casterH - 0.02, 0), r: 0.006, seg: 1, material: black))
                }
            }
            // Gas-lift shroud: telescoping black cover over the cylinder, top bushing.
            m.add(Prim.lathe([V2(0.028, hubTop - 0.004), V2(0.029, hubTop + 0.012), V2(0.0285, 0.2), V2(0.025, 0.206), V2(0.0255, shroudTop - 0.008),
                              V2(0.022, shroudTop), V2(0.016, shroudTop + 0.002), V2(0.0145, shroudTop - 0.004)], segments: l == 0 ? 24 : 12, material: black))
            // Foot ring: chrome tube ring on three spokes from a clamp collar.
            let ringY: Float = 0.27, ringR: Float = 0.22
            m.add(Prim.cylinder(radius: 0.034, height: 0.028, bevel: 0.004, segments: l == 0 ? 22 : 10, bevelSegments: l == 0 ? 2 : 1, material: chrome),
                  Xform(translation: V3(0, ringY - 0.014, 0)))
            m.add(Prim.torus(major: ringR, minor: 0.0095, segments: l == 0 ? 40 : 20, sides: l == 0 ? 8 : 6, material: chrome),
                  Xform(translation: V3(0, ringY, 0)))
            for k in 0..<3 {
                let a = Float(k) / 3 * 2 * .pi + 0.6
                let d = V3(sin(a), 0, cos(a))
                let path = PatientKit.bend([d * 0.03 + V3(0, ringY - 0.004, 0), d * 0.12 + V3(0, ringY - 0.004, 0), d * (ringR - 0.004) + V3(0, ringY, 0)], radius: 0.03, seg: 3)
                m.add(PatientKit.tube(path, r: 0.0075, sides: l == 0 ? 10 : 6, material: chrome))
                if l == 0 { m.add(PatientKit.weld(at: d * (ringR - 0.012) + V3(0, ringY, 0), axis: d, r: 0.0075, material: chrome)) }
            }
            if l == 0 {
                // Clamp screw on the collar and the asset-tag sticker on the shroud.
                m.add(Prim.cylinder(radius: 0.006, height: 0.016, bevel: 0.002, segments: 10, bevelSegments: 1, material: black),
                      Xform(translation: V3(0.03, ringY, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
                m.add(PatientKit.panel(V3(0, 0.235, 0.0257), right: V3(1, 0, 0), up: .up, w: 0.03, h: 0.022, material: "label.rx"))
            }
            rig.base[l] = m
        }

        // MARK: lift: chrome piston rising out of the shroud.
        rig.part("lift", pivot: V3(0, shroudTop, 0), joint: .slide(axis: .up, 0...travel, duration: 0.6))
        for l in 0..<2 {
            rig.add(Prim.cylinder(radius: 0.014, height: plateY - 0.12 + 0.004, bevel: 0.002, segments: l == 0 ? 18 : 10, bevelSegments: 1, material: chrome),
                    Xform(translation: V3(0, 0.12, 0)), to: "lift", lods: l...l)
        }

        // MARK: swivel: plate, pan, cushion, welt, paddle.
        rig.part("swivel", parent: "lift", pivot: V3(0, plateY, 0), joint: .hinge(axis: .up, -180...180, duration: 1.0))
        let sr = seatRadius
        // Swivel plate with the cylinder taper socket and the release valve housing.
        rig.add(Prim.lathe([V2(0.022, plateY - 0.012), V2(0.03, plateY - 0.004), V2(0.1, plateY), V2(0.105, plateY + 0.006), V2(0.1, plateY + 0.012),
                            V2(0, plateY + 0.012)], segments: 28, material: "metal.powdercoat:202124"), to: "swivel", lods: 0...0)
        rig.add(Prim.lathe([V2(0.03, plateY - 0.004), V2(0.1, plateY), V2(0.1, plateY + 0.012), V2(0, plateY + 0.012)], segments: 12,
                           material: "metal.powdercoat:202124"), to: "swivel", lods: 1...1)
        // Molded pan: shallow dish whose rim wraps the cushion's lower edge.
        for l in 0..<2 {
            rig.add(Prim.lathe([V2(0.0, plateY + 0.012), V2(sr - 0.03, plateY + 0.014), V2(sr - 0.006, plateY + 0.022), V2(sr + 0.002, panY + 0.004),
                                V2(sr - 0.002, panY + 0.012), V2(sr - 0.01, panY + 0.012)], segments: l == 0 ? 36 : 20, material: black), to: "swivel", lods: l...l)
        }
        // Cushion: crowned foam top with a rounded edge, bottom tucked into the pan.
        func cushionProfile(_ n: Int) -> [V2] {
            let y0 = panY + 0.006, edgeR: Float = 0.03
            var p: [V2] = [V2(0, y0), V2(sr - 0.008, y0), V2(sr - 0.002, y0 + 0.012)]
            for k in 0...n {
                let a = Float(k) / Float(n) * .pi / 2
                p.append(V2(sr - edgeR + edgeR * cos(a), seatTop - edgeR - 0.004 + edgeR * sin(a)))
            }
            p += [V2(sr * 0.6, seatTop), V2(sr * 0.25, seatTop + 0.002), V2(0, seatTop + 0.002)]
            return p
        }
        rig.add(Prim.lathe(cushionProfile(4), segments: 44, material: seatMaterial), to: "swivel", lods: 0...0)
        rig.add(Prim.lathe(cushionProfile(2), segments: 24, material: seatMaterial), to: "swivel", lods: 1...1)
        // Welt cord along the top seam and stitching below it (seam slightly wavy where the vinyl creases).
        let weltY = seatTop - 0.026
        var welt: [V3] = []
        for k in 0..<48 {
            let a = Float(k) / 48 * 2 * .pi
            let wob = 0.0007 * sin(a * 5 + Float(seed % 7))
            welt.append(V3(cos(a) * (sr - 0.0005 + wob), weltY + 0.0008 * sin(a * 3), -sin(a) * (sr - 0.0005 + wob)))
        }
        rig.add(PatientKit.tube(welt, r: 0.0032, sides: 5, material: seatMaterial, closed: true), to: "swivel", lods: 0...0)
        var seam: [V3] = []
        for k in 0...96 {
            let a = Float(k) / 96 * 2 * .pi
            seam.append(V3(cos(a) * (sr + 0.0012), weltY - 0.008, -sin(a) * (sr + 0.0012)))
        }
        rig.add(stitches(along: seam, normal: { V3($0.x, 0, $0.z).normalized }, pitch: 0.0075, material: "thread.white:303134"), to: "swivel", lods: 0...0)
        // Height release paddle: bent flat bar from the plate out under the seat edge with a grip tip.
        let pad = PatientKit.bend([V3(0.04, plateY - 0.004, 0.03), V3(0.12, plateY - 0.004, 0.08), V3(0.17, plateY - 0.012, 0.11)], radius: 0.04, seg: 3)
        rig.add(Prim.sweep(Shape2D.roundedRect(0.004, 0.018, radius: 0.0015, segments: 1), along: pad, up: .up, material: chrome), to: "swivel")
        rig.add(Prim.superellipsoid(V3(0.04, 0.014, 0.026), exponent: 3, subdivisions: 4, material: black),
                Xform(translation: V3(0.172, plateY - 0.013, 0.112), rotation: simd_quatf(degrees: -34, axis: .up)), to: "swivel")
        // Pan screws (four) on the underside.
        for k in 0..<4 {
            let a = Float(k) / 4 * 2 * .pi + .pi / 4
            rig.add(Prim.cylinder(radius: 0.005, height: 0.002, bevel: 0.0008, segments: 8, bevelSegments: 1, material: chrome),
                    Xform(translation: V3(cos(a) * 0.075, plateY - 0.0015, sin(a) * 0.075)), to: "swivel", lods: 0...0)
        }

        groundAO(&rig, height: 0.1, floor: 0.6)
        rig.states = [RigState("low"), RigState("high", ["lift": travel]), RigState("turned", ["lift": travel * 0.5, "swivel": 90])]
        return rig
    }
}
