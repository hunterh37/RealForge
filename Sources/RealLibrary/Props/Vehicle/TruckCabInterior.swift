import simd
import Foundation

/// Driver area of a medium-duty conventional truck cab (International DuraStar class) at 1:1. Floor at
/// y = 0 (cab floor), driver faces +Z, door side on +X. Air-ride seat, tilt column with a 20 in four-spoke
/// wheel, dash with a hooded gauge cluster, center stack with PTO, beacon and outrigger switches, floor
/// console with a PRNDL lever, yellow parking brake knob, suspended brake pedal and floor-hinged throttle.
///
/// Parts: `steering` (-540...540 about the column), `speedNeedle` (0...270), `shifter` (P 0, R -8, N -16,
/// D -24, L -32 degrees), `parkingBrake` (pull 0...0.04 m, out = applied), `throttle` (0...18),
/// `brake` (0...20), `pto`, `beaconSwitch` (toggles -20...20). States `parked`, `driving`, `pto-on`.
public struct TruckCabInterior: RealArticulated {
    public static let id = "truck-cab-interior"
    public static let summary = "Truck driver area at 1:1: air-ride seat, tilt steering wheel, gauge cluster, PRNDL lever, parking brake, pedals, PTO and outrigger switches."
    public static let tags = ["prop", "vehicle", "utility", "plastic", "interior", "articulated"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 200, elevation: 18, distance: 1.0, studio: true)

    /// Seated driver eye point (asset space).
    public static let driverEye = V3(0, 1.22, -0.32)
    /// Steering wheel center and column axis (toward the driver).
    public static let steeringCenter = V3(0, 0.86, 0.3)
    public static let steeringAxis = simd_normalize(V3(0, 0.62, -0.78))

    /// Dash plastic.
    public var dash: MaterialKey = "plastic.dash"
    /// Seat upholstery.
    public var seat: MaterialKey = "vinyl.seat-grey"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [4])
        let black: MaterialKey = "plastic.black", chrome: MaterialKey = "metal.chrome", grey: MaterialKey = "plastic.dash:4A4C4F"
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let s = l == 0 ? 2 : 1
            // Floor mat, toe board, door sill.
            m.add(VK.span(V3(-0.85, 0, -0.8), V3(0.5, 0.03, 0.62), "rubber.floor-mat", r: 0.008))
            if l == 0 { for k in 0..<12 { m.add(cuboid(V3(0.9, 0.006, 0.012), material: "rubber.floor-mat"), Xform(translation: V3(-0.1, 0.033, -0.6 + Float(k) * 0.1))) } }
            m.add(VK.side([V2(0.6, 0.0), V2(0.62, 0.03), V2(0.86, 0.36), V2(0.86, 0.0)], width: 1.35, x: -0.175, bevel: 0.01, seg: 1, mat: "rubber.floor-mat"))
            m.add(VK.span(V3(0.5, 0, -0.8), V3(0.6, 0.12, 0.62), "metal.aluminum-brushed", r: 0.01))
            // Dash body: profile in (z, y) along X.
            let dashP: [V2] = [V2(0.62, 0.4), V2(0.56, 0.62), V2(0.56, 0.78), V2(0.62, 0.9), V2(0.74, 0.97), V2(1.05, 0.99), V2(1.05, 0.4)]
            m.add(VK.side(Shape2D.rounded(dashP, radius: 0.04, segments: s), width: 1.35, x: -0.175, bevel: 0.02, seg: s, mat: dash))
            // Gauge hood over the cluster.
            m.add(VK.side(Shape2D.rounded([V2(0.5, 0.95), V2(0.52, 1.02), V2(0.66, 1.06), V2(0.8, 1.0), V2(0.62, 0.9)], radius: 0.03, segments: s), width: 0.56, x: 0.02, bevel: 0.015, seg: s, mat: dash))
            // Cluster face (dark) with gauges.
            m.add(HK.rect("plastic.gloss:0C0D0F", center: V3(0.02, 0.85, 0.555), right: V3(-1, 0, 0), up: .up, w: 0.52, h: 0.17))
            let gauges: [(Float, Float, Float)] = [(0.13, 0.85, 0.068), (-0.08, 0.85, 0.068), (0.25, 0.86, 0.03), (-0.2, 0.86, 0.03), (0.25, 0.8, 0.025), (-0.2, 0.8, 0.025)]
            for g in gauges {
                m.add(Prim.torus(major: g.2, minor: 0.004, segments: l == 0 ? 24 : 12, sides: 5, material: chrome)
                    .transformed(Xform(translation: V3(g.0, g.1, 0.552), rotation: simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0)))))
                m.add(HK.rect("plastic.gloss:15171A", center: V3(g.0, g.1, 0.553), right: V3(-1, 0, 0), up: .up, w: g.2 * 1.7, h: g.2 * 1.7))
                if l == 0 {
                    // Tick marks around the dial.
                    let n = g.2 > 0.05 ? 14 : 6
                    for k in 0...n {
                        let a = Float.pi * 1.25 - Float(k) / Float(n) * Float.pi * 1.5
                        m.add(cuboid(V3(0.0025, g.2 * 0.18, 0.001), material: "plastic.gloss:E8E8E2"),
                              Xform(translation: V3(g.0 - cos(a) * g.2 * 0.8, g.1 + sin(a) * g.2 * 0.8, 0.5525), rotation: simd_quatf(angle: -(a - .pi / 2), axis: V3(0, 0, 1))))
                    }
                }
            }
            // Warning lamp strip.
            m.add(HK.box(V3(0.12, 0.012, 0.004), V3(0.02, 0.92, 0.553), "emissive.led-red", r: 0.002, seg: 1))
            // Center stack: switch panel, outrigger control panel, radio.
            m.add(VK.span(V3(-0.75, 0.42, 0.56), V3(-0.3, 0.9, 0.6), grey, r: 0.012))
            m.add(VK.span(V3(-0.7, 0.78, 0.553), V3(-0.36, 0.86, 0.56), "plastic.gloss:121417", r: 0.004))
            for k in 0..<5 where l == 0 {
                m.add(HK.box(V3(0.016, 0.016, 0.006), V3(-0.66 + Float(k) * 0.035, 0.75, 0.552), black, r: 0.004, seg: 1))
                m.add(HK.cyl(r: 0.012, len: 0.012, at: V3(-0.66 + Float(k) * 0.07, 0.71, 0.551), axis: V3(0, 0, -1), mat: black, seg: 10, bevel: 0.003))
            }
            // Outrigger panel: four labeled lever switches in a yellow-bordered plate.
            m.add(VK.span(V3(-0.7, 0.48, 0.552), V3(-0.38, 0.62, 0.558), "plastic.yellow:D9A514", r: 0.004))
            m.add(VK.span(V3(-0.69, 0.49, 0.548), V3(-0.39, 0.61, 0.553), black, r: 0.003))
            for k in 0..<4 {
                let x = -0.65 + Float(k) * 0.075
                m.add(cuboid(V3(0.012, 0.035, 0.012), material: chrome), Xform(translation: V3(x, 0.555, 0.537)))
                m.add(HK.box(V3(0.05, 0.012, 0.002), V3(x, 0.6, 0.547), "label.inspection", r: 0.001, seg: 1))
            }
            // Steering column shroud.
            let col = Self.steeringAxis
            m.add(HK.cyl(r: 0.05, len: 0.3, at: Self.steeringCenter - col * 0.2, axis: col, mat: dash, seg: l == 0 ? 16 : 8, bevel: 0.01))
            // Floor console with PRNDL gate.
            m.add(VK.span(V3(-0.62, 0.03, -0.3), V3(-0.34, 0.42, 0.56), grey, r: 0.025))
            m.add(VK.span(V3(-0.52, 0.42, 0.18), V3(-0.44, 0.425, 0.4), "plastic.gloss:121417", r: 0.002))
            if l == 0 {
                for k in 0..<5 { m.add(HK.box(V3(0.016, 0.002, 0.012), V3(-0.43 + 0.012, 0.426, 0.21 + Float(k) * 0.045), "plastic.gloss:E8E8E2", r: 0.0008, seg: 1)) }
            }
            // Air-ride seat: base with bellows, cushion, backrest, headrest, armrest.
            m.add(VK.span(V3(-0.22, 0.03, -0.55), V3(0.22, 0.08, -0.05), black, r: 0.01))
            m.add(HK.cyl(r: 0.09, len: 0.18, at: V3(0, 0.17, -0.3), axis: .up, mat: "rubber.plate", seg: l == 0 ? 16 : 8, bevel: 0.03))
            m.add(VK.span(V3(-0.2, 0.26, -0.55), V3(0.2, 0.32, -0.05), black, r: 0.01))
            m.add(Prim.superellipsoid(V3(0.5, 0.13, 0.5), exponent: 5, subdivisions: l == 0 ? 6 : 3, material: seat), Xform(translation: V3(0, 0.39, -0.3)))
            m.add(Prim.superellipsoid(V3(0.5, 0.62, 0.13), exponent: 5, subdivisions: l == 0 ? 6 : 3, material: seat),
                  Xform(translation: V3(0, 0.76, -0.58), rotation: simd_quatf(angle: -0.18, axis: V3(1, 0, 0))))
            m.add(Prim.superellipsoid(V3(0.3, 0.18, 0.1), exponent: 4, subdivisions: l == 0 ? 5 : 3, material: seat),
                  Xform(translation: V3(0, 1.15, -0.66), rotation: simd_quatf(angle: -0.18, axis: V3(1, 0, 0))))
            m.add(VK.span(V3(-0.3, 0.6, -0.55), V3(-0.25, 0.66, -0.15), black, r: 0.02))
            rig.base[l] = m
        }

        // MARK: steering wheel (two-spoke, 20 in padded rim, chrome spoke plate, horn pad)
        let c = Self.steeringCenter, ax = Self.steeringAxis
        let face = simd_quatf(from: .up, to: ax)
        rig.part("steering", pivot: c, joint: .hinge(axis: ax, -540...540, duration: 3))
        for l in 0..<2 {
            rig.add(Prim.torus(major: 0.245, minor: 0.019, segments: l == 0 ? 40 : 16, sides: l == 0 ? 8 : 5, minorY: 0.016, material: "vinyl.seat-grey:4A524E").transformed(Xform(translation: c, rotation: face)), to: "steering", lods: l...l)
            rig.add(Prim.lathe([V2(0, 0.0), V2(0.075, 0.0), V2(0.08, 0.03), V2(0.065, 0.06), V2(0, 0.066)], segments: l == 0 ? 24 : 10, material: "plastic.dash:3A3C3E")
                .transformed(Xform(translation: c - ax * 0.015, rotation: face)), to: "steering", lods: l...l)
            // Spokes sweep down at 4 and 8 o'clock (wheel straight ahead), polished plate with cut-outs.
            for sgn: Float in [-1, 1] {
                let a: Float = -.pi / 2 + sgn * 1.05
                let dir = face.act(V3(cos(a), 0, sin(a)))
                let basis = simd_quatf(simd_float3x3(columns: (dir, ax, simd_normalize(simd_cross(dir, ax)))))
                rig.add(HK.box(V3(0.17, 0.008, 0.055), c + dir * 0.15 - ax * 0.004, "metal.chrome", r: 0.003, seg: 1,
                               rot: basis), to: "steering", lods: l...l)
                if l == 0 { rig.add(HK.box(V3(0.05, 0.004, 0.02), c + dir * 0.16 + ax * 0.002, "plastic.black", r: 0.002, seg: 1, rot: basis), to: "steering", lods: 0...0) }
            }
            rig.add(HK.cyl(r: 0.03, len: 0.004, at: c + ax * 0.054, axis: ax, mat: "metal.painted:A02020", seg: 12, bevel: 0.001), to: "steering", lods: l...l)
        }
        // MARK: speedometer needle
        rig.part("speedNeedle", pivot: V3(0.13, 0.85, 0.551), joint: .hinge(axis: V3(0, 0, 1), 0...270, duration: 1))
        rig.add(cuboid(V3(0.004, 0.06, 0.002), material: "emissive.signal-orange"), Xform(translation: V3(0.13 + 0.03 * sin(0.785), 0.85 - 0.03 * cos(0.785), 0.549), rotation: simd_quatf(angle: 0.785, axis: V3(0, 0, 1))), to: "speedNeedle")
        rig.add(HK.cyl(r: 0.008, len: 0.004, at: V3(0.13, 0.85, 0.548), axis: V3(0, 0, -1), mat: black, seg: 8, bevel: 0.001), to: "speedNeedle")
        // MARK: shifter lever (PRNDL)
        rig.part("shifter", pivot: V3(-0.48, 0.42, 0.38), joint: .hinge(axis: V3(1, 0, 0), -32...0, duration: 0.6))
        rig.add(HK.cyl(r: 0.009, len: 0.18, at: V3(-0.48, 0.51, 0.38), axis: .up, mat: chrome, seg: 8), to: "shifter")
        rig.add(Prim.superellipsoid(V3(0.04, 0.07, 0.04), exponent: 3, subdivisions: 4, material: black), Xform(translation: V3(-0.48, 0.62, 0.38)), to: "shifter")
        // MARK: parking brake knob (yellow diamond, pull = applied)
        rig.part("parkingBrake", pivot: V3(-0.27, 0.66, 0.56), joint: .slide(axis: V3(0, 0, -1), 0...0.04, duration: 0.3))
        rig.add(HK.cyl(r: 0.006, len: 0.05, at: V3(-0.27, 0.66, 0.54), axis: V3(0, 0, -1), mat: chrome, seg: 8), to: "parkingBrake")
        rig.add(HK.box(V3(0.045, 0.045, 0.03), V3(-0.27, 0.66, 0.51), "plastic.yellow:E0B020", r: 0.008, seg: 2, rot: simd_quatf(angle: .pi / 4, axis: V3(0, 0, 1))), to: "parkingBrake")
        // MARK: pedals
        rig.part("throttle", pivot: V3(0.16, 0.08, 0.66), joint: .hinge(axis: V3(1, 0, 0), 0...18, duration: 0.3))
        rig.add(HK.box(V3(0.08, 0.26, 0.02), V3(0.16, 0.2, 0.62), "rubber.floor-mat", r: 0.008, seg: 1, rot: simd_quatf(angle: -0.6, axis: V3(1, 0, 0))), to: "throttle")
        rig.part("brake", pivot: V3(-0.06, 0.55, 0.62), joint: .hinge(axis: V3(-1, 0, 0), 0...20, duration: 0.3))
        rig.add(HK.pipe([V3(-0.06, 0.55, 0.62), V3(-0.06, 0.3, 0.55), V3(-0.06, 0.2, 0.47)], r: 0.012, sides: 6, mat: "metal.painted:1E1F20"), to: "brake")
        rig.add(HK.box(V3(0.12, 0.09, 0.02), V3(-0.06, 0.18, 0.46), "rubber.floor-mat", r: 0.008, seg: 1, rot: simd_quatf(angle: -0.4, axis: V3(1, 0, 0))), to: "brake")
        // MARK: PTO and beacon switches (guarded toggles on the stack)
        for (name, x) in [("pto", Float(-0.62)), ("beaconSwitch", -0.5)] {
            rig.base[0].add(HK.box(V3(0.04, 0.05, 0.01), V3(x, 0.68, 0.553), name == "pto" ? "plastic.gloss:B52A22" : "plastic.yellow:D9A514", r: 0.003, seg: 1))
            rig.part(name, pivot: V3(x, 0.68, 0.548), joint: .hinge(axis: V3(1, 0, 0), -20...20, duration: 0.2))
            rig.add(HK.cyl(r: 0.004, len: 0.03, at: V3(x, 0.68, 0.535), axis: V3(0, 0, -1), mat: chrome, seg: 8), to: name)
        }
        groundAO(&rig, height: 0.1)
        rig.states = [
            RigState("parked", ["parkingBrake": 0.04]),
            RigState("driving", ["shifter": -24, "throttle": 10, "speedNeedle": 60]),
            RigState("pto-on", ["parkingBrake": 0.04, "pto": 20, "beaconSwitch": 20]),
        ]
        return rig
    }
}
