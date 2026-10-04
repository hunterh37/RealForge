import simd
import Foundation

/// Emergency department transport stretcher (Stryker Prime / Hill-Rom Transtar class): 66 x 193 cm
/// litter, deck height 57-92 cm. Steel base frame under a molded grey shroud on four 200 mm casters
/// with total-lock pedals, two three-stage telescoping lift columns, aluminum litter frame with
/// corner bumpers, 80 mm black vinyl pad with a fitted linen sheet, Fowler backrest (0-85 degrees) with a
/// red CPR release, two side rails that fold down outboard, head-end push handles and a folding IV pole.
/// Head at -X. Joints: lift (slide) > back, rail-right (rail-left mimics), iv-pole.
public struct ErStretcher: RealArticulated {
    public static let id = "er-stretcher"
    public static let summary = "Emergency stretcher: shrouded base on four braked casters, twin lift columns, vinyl pad with linen sheet, Fowler backrest, fold-down side rails and IV pole."
    public static let tags = ["prop", "medical", "hospital", "furniture", "metal", "plastic", "articulated"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 18, distance: 1.0, studio: true)

    /// Base shroud and molded parts.
    public var shroud: MaterialKey = "plastic.medical-grey"
    /// Pad cover and sheet.
    public var pad: MaterialKey = "vinyl.medical-black"
    public var sheet: MaterialKey = "fabric.linen"
    public var litterLength: Float = 1.93
    public var litterWidth: Float = 0.66
    /// Deck height at the lowest setting (m) and lift travel (m).
    public var lowDeck: Float = 0.57
    public var travel: Float = 0.35
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [9])
        let alu: MaterialKey = "metal.casework", chrome: MaterialKey = "metal.chrome", black: MaterialKey = "plastic.matte:1E1F21"
        let L = litterLength / 2, Wp = litterWidth / 2
        let deck = lowDeck, frameY = deck - 0.04, padH: Float = 0.08
        let casterH: Float = 0.2, baseTop: Float = 0.3
        let hingeX: Float = -0.25

        // MARK: base: frame, shroud, casters with pedals.
        for l in 0..<2 {
            var m = Model(name: Self.id)
            for sz: Float in [-1, 1] {
                m.add(PatientKit.bar(V3(-0.86, casterH + 0.02, sz * 0.27), V3(0.86, casterH + 0.02, sz * 0.27), w: 0.05, h: 0.04, r: 0.004, material: alu))
            }
            for sx: Float in [-1, 1] {
                m.add(PatientKit.bar(V3(sx * 0.84, casterH + 0.02, -0.29), V3(sx * 0.84, casterH + 0.02, 0.29), w: 0.06, h: 0.04, r: 0.004, material: alu))
            }
            // Shroud: crowned molded cover with a raised center spine between the columns.
            m.add(Prim.roundedBox(V3(1.62, 0.1, 0.58), radius: 0.035, bevelSegments: l == 0 ? 3 : 1, material: shroud), Xform(translation: V3(0, casterH + 0.075, 0)))
            m.add(Prim.roundedBox(V3(1.2, 0.05, 0.3), radius: 0.02, bevelSegments: l == 0 ? 2 : 1, material: shroud), Xform(translation: V3(0, baseTop - 0.025, 0)))
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                let p = V3(sx * 0.84, 0, sz * 0.27)
                if l == 0 {
                    PatientKit.brakedCaster(&m, at: p, height: casterH, wheelRadius: 0.1, yaw: (sx > 0 ? 0 : 180) + rng.float(-10...10), pedalYaw: sx > 0 ? 180 : 0,
                                            frame: alu, wheel: "rubber", hub: "plastic.matte:3A3B3E", pedal: sz > 0 ? "plastic.matte:2E7D4F" : "plastic.matte:B0302A", detail: false)
                } else {
                    m.add(Prim.cylinder(radius: 0.1, height: 0.024, bevel: 0.006, segments: 10, bevelSegments: 1, material: "rubber"),
                          Xform(translation: p + V3(0.03 * sx, 0.1, -0.012), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
                    m.add(PatientKit.box(V3(0.06, 0.1, 0.04), p + V3(0, casterH - 0.05, 0), r: 0.006, seg: 1, material: alu))
                }
            }}
            rig.base[l] = m
        }

        // MARK: lift: litter frame, deck, seat/foot pad, push handles, bumpers, columns.
        rig.part("lift", pivot: V3(0, frameY, 0), joint: .slide(axis: .up, 0...travel, duration: 1.6))
        for x: Float in [-0.5, 0.5] {
            PatientKit.column(&rig, name: x < 0 ? "col-head" : "col-foot", at: V2(x, 0), bottom: baseTop - 0.01, top: frameY - 0.025, travel: travel,
                              size: V2(0.16, 0.12), housing: shroud, sleeve: "plastic.medical", inner: alu)
        }
        for l in 0..<2 {
            let ring = PatientKit.bend([V3(-L + 0.02, frameY, -0.28), V3(L - 0.02, frameY, -0.28), V3(L - 0.02, frameY, 0.28), V3(-L + 0.02, frameY, 0.28)], radius: 0.06, seg: l == 0 ? 4 : 2)
            rig.add(Prim.sweep(Shape2D.roundedRect(0.05, 0.025, radius: 0.005, segments: 1), along: ring, up: .up, closedPath: true, material: alu), to: "lift", lods: l...l)
        }
        for x: Float in [-0.5, 0.0, 0.5] {
            rig.add(PatientKit.bar(V3(x, frameY - 0.005, -0.27), V3(x, frameY - 0.005, 0.27), w: 0.05, h: 0.04, r: 0.004, material: alu), to: "lift")
        }
        rig.add(PatientKit.box(V3(L - hingeX - 0.02, 0.012, 2 * Wp - 0.04), V3((hingeX + L) / 2, deck - 0.006, 0), r: 0.004, seg: 1, material: shroud), to: "lift")
        for (k, s) in PatientKit.pad(hingeX + 0.006, L - 0.005, y0: deck, h: padH, w: 2 * Wp, material: pad, sheet: sheet, sub: 7, seed: seed).enumerated() {
            rig.add(s, to: "lift", lods: 0...0); _ = k
        }
        for s in PatientKit.pad(hingeX + 0.006, L - 0.005, y0: deck, h: padH, w: 2 * Wp, material: pad, sheet: sheet, sub: 4, seed: seed) { rig.add(s, to: "lift", lods: 1...1) }
        // Restraint strap across the thighs with a buckle (story detail).
        let strapX: Float = 0.25
        let strapPath = stride(from: -Wp - 0.02, through: Wp + 0.02, by: 0.04).map { z -> V3 in
            let e = max(0, abs(z) - (Wp - 0.03)) / 0.05
            return V3(strapX, deck + padH + 0.004 - e * 0.06, z)
        }
        rig.add(PatientKit.ribbon(strapPath, across: V3(-1, 0, 0), width: 0.05, steps: 1, material: "fabric.nylon:22252A"), to: "lift")
        rig.add(Prim.roundedBox(V3(0.07, 0.012, 0.06), radius: 0.004, bevelSegments: 1, material: "plastic.matte:2A2B2D"),
                Xform(translation: V3(strapX, deck + padH + 0.01, 0.08)), to: "lift", lods: 0...0)
        // Corner bumpers.
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
            rig.add(Prim.cylinder(radius: 0.038, height: 0.06, bevel: 0.01, segments: 12, bevelSegments: 1, material: "rubber:5A5C5F"),
                    Xform(translation: V3(sx * (L + 0.005), frameY - 0.03, sz * 0.27)), to: "lift")
        }}
        // Push handles at the head end.
        for sz: Float in [-1, 1] {
            let h = PatientKit.bend([V3(-L + 0.04, frameY, sz * 0.22), V3(-L - 0.03, frameY + 0.02, sz * 0.22), V3(-L - 0.05, deck + 0.34, sz * 0.22)], radius: 0.05, seg: 4)
            rig.add(PatientKit.tube(h, r: 0.0135, sides: 10, material: alu), to: "lift")
            rig.add(PatientKit.rod(V3(-L - 0.044, deck + 0.2, sz * 0.22), V3(-L - 0.05, deck + 0.33, sz * 0.22), r: 0.018, sides: 10, material: "rubber"), to: "lift")
        }

        // MARK: back (Fowler): deck panel, pad and sheet, gas strut bracket, CPR release.
        rig.part("back", parent: "lift", pivot: V3(hingeX, deck + padH - 0.01, 0), joint: .hinge(axis: V3(0, 0, -1), 0...85, duration: 1.2))
        rig.add(PatientKit.box(V3(hingeX + L - 0.03, 0.012, 2 * Wp - 0.04), V3((hingeX - L) / 2, deck - 0.006, 0), r: 0.004, seg: 1, material: shroud), to: "back")
        for s in PatientKit.pad(-L + 0.005, hingeX - 0.006, y0: deck, h: padH, w: 2 * Wp, material: pad, sheet: sheet, sub: 7, seed: seed &+ 3) { rig.add(s, to: "back", lods: 0...0) }
        for s in PatientKit.pad(-L + 0.005, hingeX - 0.006, y0: deck, h: padH, w: 2 * Wp, material: pad, sheet: sheet, sub: 4, seed: seed &+ 3) { rig.add(s, to: "back", lods: 1...1) }
        rig.add(PatientKit.bar(V3(-L + 0.1, deck - 0.02, 0), V3(hingeX - 0.02, deck - 0.02, 0), w: 0.04, h: 0.02, r: 0.003, material: alu), to: "back")
        rig.add(PatientKit.box(V3(0.12, 0.025, 0.03), V3(-0.55, deck - 0.02, Wp - 0.03), r: 0.008, seg: 1, material: "plastic.matte:C0302A"), to: "back")

        // MARK: side rails: tube frames that fold down outboard about a pivot at the litter edge.
        let railZ: Float = Wp + 0.05, pivY = frameY + 0.01
        rig.part("rail-right", parent: "lift", pivot: V3(0, pivY, railZ), joint: .hinge(axis: V3(1, 0, 0), 0...170, duration: 1.0))
        rig.part("rail-left", parent: "lift", pivot: V3(0, pivY, -railZ), joint: Joint(.revolute, axis: V3(-1, 0, 0), range: 0...170, mimic: .init("rail-right")))
        for (name, sz) in [("rail-right", Float(1)), ("rail-left", Float(-1))] {
            let z = sz * railZ, top = deck + 0.3, x0: Float = -0.6, x1: Float = 0.5
            for l in 0..<2 {
                let loop = PatientKit.bend([V3(x0, pivY + 0.005, z), V3(x0, top, z), V3(x1, top, z), V3(x1, pivY + 0.005, z)], radius: 0.06, seg: l == 0 ? 4 : 2)
                rig.add(PatientKit.tube(loop, r: 0.0125, sides: l == 0 ? 10 : 6, material: alu), to: name, lods: l...l)
                for y in [deck + 0.1, deck + 0.2] where l == 0 {
                    rig.add(PatientKit.rod(V3(x0, y, z), V3(x1, y, z), r: 0.009, sides: l == 0 ? 8 : 5, material: alu), to: name, lods: l...l)
                }
            }
            // Pivot brackets and the black release latch.
            for x in [x0, x1] {
                rig.add(PatientKit.box(V3(0.04, 0.04, 0.03), V3(x, pivY, z - sz * 0.012), r: 0.006, seg: 1, material: black), to: name)
            }
            rig.add(PatientKit.box(V3(0.09, 0.035, 0.03), V3((x0 + x1) / 2, top - 0.01, z), r: 0.008, seg: 1, material: black), to: name, lods: 0...0)
        }

        // MARK: IV pole: stowed along the head-end frame side, flips up at the head corner.
        let ivPiv = V3(-L + 0.03, frameY - 0.03, -0.325)
        rig.part("iv-pole", parent: "lift", pivot: ivPiv, joint: .hinge(axis: V3(0, 0, 1), 0...90, duration: 0.8))
        rig.add(Prim.cylinder(radius: 0.02, height: 0.05, bevel: 0.004, segments: 12, bevelSegments: 1, material: black),
                Xform(translation: ivPiv + V3(0.0, 0, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "iv-pole")
        rig.add(PatientKit.rod(ivPiv + V3(0.04, 0, 0), ivPiv + V3(0.62, 0, 0), r: 0.0125, sides: 10, material: chrome), to: "iv-pole")
        rig.add(PatientKit.rod(ivPiv + V3(0.6, 0, 0), ivPiv + V3(0.92, 0, 0), r: 0.009, sides: 8, material: chrome), to: "iv-pole")
        rig.add(PatientKit.box(V3(0.03, 0.03, 0.03), ivPiv + V3(0.61, 0, 0), r: 0.005, seg: 1, material: black), to: "iv-pole")
        for sy: Float in [-1, 1] {
            let hook = PatientKit.bend([ivPiv + V3(0.9, 0, 0), ivPiv + V3(0.9, sy * 0.06, 0), ivPiv + V3(0.94, sy * 0.07, 0), ivPiv + V3(0.95, sy * 0.05, 0)], radius: 0.012, seg: 3)
            rig.add(PatientKit.tube(hook, r: 0.0045, sides: 6, material: chrome), to: "iv-pole", lods: 0...0)
        }

        groundAO(&rig, height: 0.12, floor: 0.55)
        rig.states = [RigState("low-flat"), RigState("transport", ["lift": travel, "iv-pole": 90]),
                      RigState("fowler", ["lift": 0.15, "back": 60]), RigState("rails-down", ["lift": 0.15, "rail-right": 170])]
        return rig
    }
}
