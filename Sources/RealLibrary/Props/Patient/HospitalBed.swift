import simd
import Foundation

/// Med-surg hospital bed (Hill-Rom Centrella / Stryker S3 class): 89 x 203 cm mattress, deck height
/// 40-76 cm, 2.18 m long and 1.0 m wide over the rails. Steel base under a grey shroud on four 125 mm
/// casters with brake pedals, two three-stage lift columns, a steel deck frame carrying a four-section
/// deck (head 0-65 degrees, fixed seat, thigh that follows the head as auto-contour, foot that drops for
/// the chair position), a navy vinyl mattress in four segments under a fitted linen sheet, pillow and
/// folded blanket, split side rails (head rails ride the head section) that slide down, molded head and
/// footboards with grey inserts, a caregiver panel and a hanging control pendant on the footboard.
/// Head at -X. Joints: lift > head (> head rails), thigh (mimic head) > foot, foot rails.
public struct HospitalBed: RealArticulated {
    public static let id = "hospital-bed"
    public static let summary = "Med-surg hospital bed: four-section deck on lift columns and braked casters, split side rails, head and footboards, pendant, sheeted mattress and pillow."
    public static let tags = ["prop", "medical", "hospital", "furniture", "plastic", "metal", "articulated"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 20, distance: 1.0, studio: true)

    /// Molded plastics (boards, rails).
    public var plastic: MaterialKey = "plastic.medical"
    /// Mattress cover and sheet.
    public var mattress: MaterialKey = "vinyl.medical:2C4568"
    public var sheet: MaterialKey = "fabric.linen"
    /// Deck height at the lowest setting (m) and lift travel (m).
    public var lowDeck: Float = 0.4
    public var travel: Float = 0.36
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [10])
        let grey: MaterialKey = "plastic.medical-grey", steel: MaterialKey = "metal.powder-white:C9CACB", dark: MaterialKey = "plastic.matte:2A2B2D"
        let deck = lowDeck, padH: Float = 0.15, frameY = deck - 0.045
        let mz: Float = 0.445, mx: Float = 1.015
        let headX1: Float = -0.25, seatX1: Float = 0.05, thighX1: Float = 0.42
        let casterH: Float = 0.16, baseY: Float = 0.2

        // MARK: base
        for l in 0..<2 {
            var m = Model(name: Self.id)
            for sz: Float in [-1, 1] {
                m.add(cuboid(V3(1.72, 0.04, 0.05), material: steel), Xform(translation: V3(0, casterH + 0.02, sz * 0.32)))
            }
            for sx: Float in [-1, 1] {
                m.add(cuboid(V3(0.06, 0.039, 0.68), material: steel), Xform(translation: V3(sx * 0.84, casterH + 0.02, 0)))
            }
            m.add(Prim.roundedBox(V3(1.5, 0.05, 0.52), radius: 0.02, bevelSegments: l == 0 ? 2 : 1, material: grey), Xform(translation: V3(0, baseY, 0)))
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                let p = V3(sx * 0.84, 0, sz * 0.32)
                if l == 0 {
                    PatientKit.brakedCaster(&m, at: p, height: casterH, wheelRadius: 0.0625, yaw: (sx > 0 ? 0 : 180) + rng.float(-12...12), pedalYaw: sx > 0 ? 180 : 0,
                                            frame: steel, wheel: "rubber", hub: "plastic.matte:8A8C90", pedal: "plastic.matte:B0302A", detail: false)
                } else {
                    m.add(Prim.cylinder(radius: 0.0625, height: 0.03, bevel: 0.006, segments: 10, bevelSegments: 1, material: "rubber"),
                          Xform(translation: p + V3(0.02 * sx, 0.0625, -0.015), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
                    m.add(PatientKit.box(V3(0.06, 0.07, 0.05), p + V3(0, casterH - 0.035, 0), r: 0.006, seg: 1, material: steel))
                }
            }}
            rig.base[l] = m
        }

        // MARK: lift: columns, deck frame, seat section, boards, foot rails' carriers.
        rig.part("lift", pivot: V3(0, frameY, 0), joint: .slide(axis: .up, 0...travel, duration: 2.0))
        for x: Float in [-0.55, 0.55] {
            PatientKit.column(&rig, name: x < 0 ? "col-head" : "col-foot", at: V2(x, 0), bottom: baseY + 0.02, top: deck - 0.02, travel: travel,
                              size: V2(0.18, 0.14), housing: grey, sleeve: plastic, inner: steel)
        }
        for l in 0..<2 {
            let ring = PatientKit.bend([V3(-1.0, frameY, -0.4), V3(1.0, frameY, -0.4), V3(1.0, frameY, 0.4), V3(-1.0, frameY, 0.4)], radius: 0.05, seg: l == 0 ? 3 : 1)
            rig.add(Prim.sweep(Shape2D.roundedRect(0.06, 0.03, radius: 0.006, segments: 1), along: ring, up: .up, closedPath: true, material: steel), to: "lift", lods: l...l)
        }
        for x: Float in [-0.55, 0.55] {
            rig.add(PatientKit.bar(V3(x, frameY - 0.01, -0.39), V3(x, frameY - 0.01, 0.39), w: 0.06, h: 0.05, r: 0.004, material: steel), to: "lift")
        }
        // Deck sections and mattress segments.
        func section(_ x0: Float, _ x1: Float, to part: String, pillow: Bool = false, blanket: Bool = false) {
            rig.add(PatientKit.box(V3(x1 - x0 - 0.01, 0.012, 2 * mz - 0.04), V3((x0 + x1) / 2, deck - 0.006, 0), r: 0.004, seg: 1, material: grey), to: part)
            for (l, sub) in [(0, 5), (1, 3)] {
                for s in PatientKit.pad(x0 + 0.003, x1 - 0.003, y0: deck, h: padH, w: 2 * mz, material: mattress, sheet: sheet, sub: sub, seed: seed &+ UInt64(x0 * 100 + 200)) {
                    rig.add(s, to: part, lods: l...l)
                }
            }
            if pillow {
                // Pillow, dented where a head lay.
                for (l, sub) in [(0, 5), (1, 3)] {
                    let p = Prim.superellipsoid(V3(0.42, 0.13, 0.66), exponent: 2.6, subdivisions: sub, material: sheet) { d in
                        1 - 0.28 * max(0, d.y) * exp(-(d.x * d.x + d.z * d.z) * 5)
                    }
                    rig.add(p, Xform(translation: V3(-0.78, deck + padH + 0.05, 0.02), rotation: simd_quatf(degrees: -6, axis: V3(0, 0, 1))), to: part, lods: l...l)
                }
            }
            if blanket {
                // Folded blanket across the foot.
                for (l, sub) in [(0, 5), (1, 2)] {
                    rig.add(Prim.superellipsoid(V3(0.36, 0.07, 0.8), exponent: 5, subdivisions: sub, material: "fabric.wool:A9BCD0"),
                            Xform(translation: V3(0.74, deck + padH + 0.034, 0.0), rotation: simd_quatf(degrees: 3, axis: .up)), to: part, lods: l...l)
                }
            }
        }
        section(headX1, seatX1, to: "lift")

        // Headboard and footboard: molded shells with grey inserts and hand slots.
        func board(_ x: Float, top: Float, foot: Bool) {
            let h = top - (frameY - 0.06), cy = frameY - 0.06 + h / 2
            for l in 0..<2 {
                let shell = Prim.extrude(Shape2D.roundedRect(0.92, h, radius: 0.07, segments: l == 0 ? 3 : 2), depth: 0.045, bevel: 0.012, bevelSegments: l == 0 ? 2 : 1, material: plastic)
                rig.add(shell, Xform(translation: V3(x, cy, 0), rotation: simd_quatf(degrees: 90, axis: .up)), to: "lift", lods: l...l)
            }
            let ins = Prim.extrude(Shape2D.roundedRect(0.7, h * 0.48, radius: 0.04, segments: 3), depth: 0.05, bevel: 0.006, bevelSegments: 1, material: grey)
            rig.add(ins, Xform(translation: V3(x, cy - h * 0.12, 0), rotation: simd_quatf(degrees: 90, axis: .up)), to: "lift")
            for sz: Float in [-1, 1] {
                rig.add(Prim.extrude(Shape2D.roundedRect(0.12, 0.035, radius: 0.017, segments: 3), depth: 0.05, bevel: 0.004, bevelSegments: 1, material: dark),
                        Xform(translation: V3(x, top - 0.06, sz * 0.33), rotation: simd_quatf(degrees: 90, axis: .up)), to: "lift", lods: 0...0)
            }
        }
        let hbX: Float = -mx - 0.05, fbX: Float = mx + 0.045
        board(hbX, top: deck + 0.56, foot: false)
        board(fbX, top: deck + 0.4, foot: true)
        // Caregiver panel on the footboard top (angled LCD with buttons) and the hanging pendant.
        let panelC = V3(fbX + 0.012, deck + 0.4 - 0.05, 0.12)
        rig.add(PatientKit.panel(panelC + V3(0.0235, 0, 0), right: V3(0, 0, -1), up: .up, w: 0.12, h: 0.06, material: "screen.lcd:3A6E8F"), to: "lift")
        var keys = Surface(material: grey)
        for k in 0..<4 {
            keys.append(cuboid(V3(0.006, 0.022, 0.022), material: grey), Xform(translation: V3(fbX + 0.025, deck + 0.4 - 0.05, -0.02 - Float(k) * 0.03)))
        }
        rig.add(keys, to: "lift", lods: 0...0)
        let pendC = V3(fbX + 0.05, deck + 0.22, -0.3)
        rig.add(Prim.superellipsoid(V3(0.035, 0.17, 0.075), exponent: 4, subdivisions: 4, material: plastic), Xform(translation: pendC), to: "lift")
        rig.add(cuboid(V3(0.003, 0.09, 0.05), material: "plastic.medical-grey:6F7A84"), Xform(translation: pendC + V3(0.017, 0.02, 0)), to: "lift", lods: 0...0)
        let hook = PatientKit.bend([pendC + V3(0, 0.085, 0), pendC + V3(0, 0.135, 0), pendC + V3(-0.04, 0.155, 0), pendC + V3(-0.05, 0.13, 0)], radius: 0.015, seg: 3)
        rig.add(PatientKit.tube(hook, r: 0.004, sides: 6, material: grey), to: "lift", lods: 0...0)
        let cord = catmull([pendC + V3(0, -0.085, 0), pendC + V3(0.01, -0.2, 0.02), V3(fbX + 0.02, frameY - 0.05, -0.25), V3(fbX - 0.05, frameY - 0.02, -0.3)], per: 5)
        rig.add(PatientKit.tube(cord, r: 0.0035, sides: 6, material: "rubber.tubing:3A3B3D"), to: "lift", lods: 0...0)
        // Head-end wall bumper rollers.
        for sz: Float in [-1, 1] {
            rig.add(Prim.cylinder(radius: 0.035, height: 0.05, bevel: 0.008, segments: 8, bevelSegments: 1, material: "rubber:5A5C5F"),
                    Xform(translation: V3(hbX - 0.06, frameY - 0.04, sz * 0.4)), to: "lift")
            rig.add(cuboid(V3(-1.0 - hbX + 0.06, 0.02, 0.03), material: steel), Xform(translation: V3((-1.0 + hbX - 0.06) / 2, frameY, sz * 0.4)), to: "lift")
        }

        // MARK: head section (Fowler), head rails ride it.
        let pivY = deck + padH - 0.01
        rig.part("head", parent: "lift", pivot: V3(headX1, pivY, 0), joint: .hinge(axis: V3(0, 0, -1), 0...65, duration: 2.0))
        section(-mx, headX1, to: "head", pillow: true)
        // MARK: thigh (auto-contour with the head) > foot.
        rig.part("thigh", parent: "lift", pivot: V3(seatX1, pivY, 0), joint: Joint(.revolute, axis: V3(0, 0, 1), range: 0...20, mimic: .init("head", ratio: 0.3)))
        section(seatX1, thighX1, to: "thigh")
        rig.part("foot", parent: "thigh", pivot: V3(thighX1, pivY, 0), joint: .hinge(axis: V3(0, 0, 1), -75...15, duration: 1.5))
        section(thighX1, mx, to: "foot", blanket: true)

        // MARK: split side rails: molded loops that slide down beside the mattress.
        let railZ = mz + 0.035, railTop = deck + padH + 0.22, railBot = deck + 0.08
        func rail(_ name: String, parent: String, x0: Float, x1: Float, sz: Float) {
            let z = sz * railZ
            rig.part(name, parent: parent, pivot: V3((x0 + x1) / 2, railBot, z), joint: .slide(axis: V3(0, -1, 0), 0...0.3, duration: 1.0))
            for l in 0..<2 {
                let loop = PatientKit.bend([V3(x0, railBot, z), V3(x1, railBot, z), V3(x1, railTop, z), V3(x0, railTop, z)], radius: 0.06, seg: l == 0 ? 3 : 1)
                rig.add(Prim.sweep(Shape2D.roundedRect(0.03, 0.026, radius: 0.01, segments: 1), along: loop, up: V3(0, 0, sz), closedPath: true, material: plastic), to: name, lods: l...l)
            }
            let midY = (railBot + railTop) / 2
            rig.add(Prim.roundedBox(V3(x1 - x0 - 0.02, 0.02, 0.02), radius: 0.008, bevelSegments: 1, material: plastic), Xform(translation: V3((x0 + x1) / 2, midY, z)), to: name)
            // Release latch and the mounting arm to the deck.
            rig.add(PatientKit.box(V3(0.07, 0.025, 0.03), V3((x0 + x1) / 2, railTop - 0.005, z), r: 0.008, seg: 1, material: grey), to: name, lods: 0...0)
            rig.add(cuboid(V3(0.06, 0.14, 0.03), material: steel), Xform(translation: V3((x0 + x1) / 2, railBot - 0.05, z - sz * 0.015)), to: name)
        }
        for sz: Float in [-1, 1] {
            let s = sz > 0 ? "right" : "left"
            rail("head-rail-" + s, parent: "head", x0: -0.92, x1: -0.3, sz: sz)
            rail("foot-rail-" + s, parent: "lift", x0: 0.02, x1: 0.82, sz: sz)
        }

        groundAO(&rig, height: 0.12, floor: 0.55)
        let down = ["head-rail-left": Float(0.3), "head-rail-right": 0.3, "foot-rail-left": 0.3, "foot-rail-right": 0.3]
        rig.states = [RigState("flat"), RigState("fowler", ["lift": 0.12, "head": 45, "foot": -13.5]),
                      RigState("chair-ish", ["lift": 0.2, "head": 65, "foot": -45]), RigState("high", ["lift": travel]),
                      RigState("rails-down", down.merging(["lift": 0.12]) { a, _ in a })]
        return rig
    }
}
