import simd
import Foundation

/// Compound teaching-lab microscope (Olympus CX23 class), about 210 W x 375 H x 280 D mm: ivory
/// enamel base with an LED illuminator lens, brightness dial and rocker switch; cast C-arm with
/// coaxial coarse/fine focus knobs on both sides (turning them raises the stage); black mechanical
/// stage with condenser below, slide holder and hanging X/Y knobs; quadruple nosepiece on a tilted
/// axis with four colour-banded objectives (4x red, 10x yellow, 40x blue, 100x white); binocular
/// Siedentopf head with interpupillary adjustment (the two tubes mirror each other). A stained slide
/// sits in the holder.
public struct Microscope: RealArticulated {
    public static let id = "microscope"
    public static let summary = "Compound lab microscope (Olympus CX23 class): LED base, arm, mechanical stage, quadruple nosepiece with four objectives and a binocular head."
    public static let tags = ["prop", "medical", "articulated", "electronics", "metal", "glass", "light"]
    public static let budget = 10_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 16, distance: 1.0, studio: true)

    public var enamel: MaterialKey = "paint.microscope-ivory"
    public var black: MaterialKey = "metal.anodized-black"
    /// Stage rise per degree of focus-knob turn (m).
    public var focusRatio: Float = 0.000018
    /// Nosepiece axis tilt from vertical (degrees).
    public var nosepieceTilt: Float = 20
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3])
        let chrome: MaterialKey = "metal.chrome", rubber: MaterialKey = "rubber"
        let plasticDark: MaterialKey = "plastic.matte:232427"
        let baseH: Float = 0.045, armZ: Float = -0.09
        let sx0: Float = 0, sz0: Float = 0.03                          // optical axis (x, z)
        let stageY: Float = 0.12, stageT: Float = 0.01, stageTop = stageY + stageT

        // MARK: base, arm, head body
        for l in 0..<2 {
            let seg = l == 0 ? 4 : 2
            var m = Model(name: Self.id)
            m.add(Prim.extrude(Shape2D.roundedRect(0.18, 0.25, radius: 0.03, segments: seg), depth: baseH, bevel: l == 0 ? 0.008 : 0.005, bevelSegments: l == 0 ? 2 : 1, material: enamel),
                  Xform(translation: V3(0, baseH / 2, 0.005), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
            // C-arm: swept rounded section from the base rear up and forward under the head.
            let armPath = catmull([V3(0, baseH - 0.01, armZ - 0.005), V3(0, 0.12, armZ), V3(0, 0.22, armZ + 0.004), V3(0, 0.275, armZ + 0.03), V3(0, 0.29, -0.03)], per: l == 0 ? 4 : 2)
            m.add(Prim.sweep(Shape2D.roundedRect(0.058, 0.05, radius: 0.012, segments: seg), along: armPath, up: V3(1, 0, 0), material: enamel))
            // Head body (prism housing) and the nosepiece mount below its front.
            m.add(Prim.roundedBox(V3(0.07, 0.05, 0.1), radius: l == 0 ? 0.012 : 0.008, bevelSegments: 1, material: enamel), Xform(translation: V3(0, 0.283, -0.02)))
            m.add(Prim.roundedBox(V3(0.05, 0.05, 0.05), radius: 0.008, bevelSegments: 1, material: enamel), Xform(translation: V3(0, 0.235, 0.012)))
            // Stage guide on the arm front (the stage bracket rides on it).
            m.add(Prim.roundedBox(V3(0.04, 0.08, 0.012), radius: 0.003, bevelSegments: 1, material: black), Xform(translation: V3(0, 0.115, armZ + 0.029)))
            rig.base[l] = m
        }
        // Rubber feet, LED lens ring, maker's band.
        for fx: Float in [-1, 1] { for fz: Float in [-1, 1] {
            rig.base[0].add(Prim.cylinder(radius: 0.009, height: 0.003, bevel: 0.001, segments: 10, bevelSegments: 1, material: rubber),
                            Xform(translation: V3(fx * 0.065, -0.0005, 0.005 + fz * 0.095)))
        }}
        for l in 0..<2 {
            rig.base[l].add(Prim.cylinder(radius: 0.022, height: 0.004, bevel: 0.0015, segments: l == 0 ? 24 : 10, bevelSegments: 1, material: black),
                            Xform(translation: V3(sx0, baseH - 0.0005, sz0)))
        }
        rig.base[0].add(Prim.roundedBox(V3(0.16, 0.012, 0.0012), radius: 0.0004, bevelSegments: 1, material: "plastic.matte:3B5E8C"),
                        Xform(translation: V3(0, baseH * 0.5, 0.005 + 0.125 + 0.0002)))

        // MARK: illuminator (off / on) with an up-pointing spot
        rig.part("lamp", pivot: V3(sx0, baseH + 0.004, sz0), joint: .fixed, options: 2)
        rig.add(Prim.cylinder(radius: 0.016, height: 0.003, bevel: 0.0012, segments: 20, bevelSegments: 1, material: "glass.clear"),
                Xform(translation: V3(sx0, baseH + 0.003, sz0)), to: "lamp")
        rig.add(Prim.cylinder(radius: 0.016, height: 0.003, bevel: 0.0012, segments: 20, bevelSegments: 1, material: "emissive.surgical"),
                Xform(translation: V3(sx0, baseH + 0.003, sz0)), to: "lamp", option: 1)
        rig.lights = [RigLight(name: "led", kind: .spot(inner: 12, outer: 30), part: "lamp", option: 1, position: V3(sx0, baseH + 0.01, sz0),
                               direction: V3(0, 1, 0), color: V3(0.95, 0.97, 1), intensity: 120, attenuationRadius: 0.8)]

        // Brightness dial (right side) and rocker switch (right rear).
        rig.part("dimmer", pivot: V3(0.09, 0.024, 0.07), joint: .hinge(axis: V3(1, 0, 0), 0...270, duration: 0.6))
        rig.add(Prim.cylinder(radius: 0.014, height: 0.008, bevel: 0.0015, segments: 20, bevelSegments: 1, material: plasticDark),
                Xform(translation: V3(0.088, 0.024, 0.07), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "dimmer", lods: 0...0)
        rig.add(cuboid(V3(0.0015, 0.002, 0.008), material: "plastic.white"), Xform(translation: V3(0.0965, 0.024, 0.07 + 0.008)), to: "dimmer", lods: 0...0)
        rig.part("switch", pivot: V3(0.09, 0.024, -0.07), joint: .hinge(axis: V3(1, 0, 0), 0...14, duration: 0.15))
        rig.add(Prim.roundedBox(V3(0.006, 0.014, 0.02), radius: 0.002, bevelSegments: 1, material: plasticDark), Xform(translation: V3(0.092, 0.024, -0.07)), to: "switch")

        // MARK: focus knobs (driver) and the stage (mimics the focus)
        let fy: Float = 0.1, fz = armZ
        rig.part("focus", pivot: V3(0, fy, fz), joint: .hinge(axis: V3(1, 0, 0), 0...720, duration: 1.6))
        for side: Float in [-1, 1] {
            for l in 0..<2 {
                var coarse = Prim.cylinder(radius: 0.022, height: 0.014, bevel: 0.003, segments: l == 0 ? 28 : 12, bevelSegments: 1, material: black)
                if l == 0 {
                    coarse.deform { p in
                        let r = simd_length(V2(p.x, p.z))
                        guard r > 0.021, p.y > 0.003, p.y < 0.011 else { return p }
                        let a = atan2(p.z, p.x), k: Float = 1 + 0.05 * max(0, cos(a * 14))
                        return V3(p.x * k, p.y, p.z * k)
                    }
                }
                let rot = simd_quatf(degrees: side > 0 ? -90 : 90, axis: V3(0, 0, 1))
                rig.add(coarse, Xform(translation: V3(side * 0.031, fy, fz), rotation: rot), to: "focus", lods: l...l)
                rig.add(Prim.cylinder(radius: 0.012, height: 0.014, bevel: 0.002, segments: l == 0 ? 20 : 8, bevelSegments: 1, material: black),
                        Xform(translation: V3(side * 0.045, fy, fz), rotation: rot), to: "focus", lods: l...l)
            }
        }
        rig.part("stage", pivot: V3(sx0, stageY, sz0), joint: Joint(.prismatic, axis: .up, range: 0...0.014, duration: 1.6, mimic: .init("focus", ratio: focusRatio)))
        for l in 0..<2 {
            rig.add(Prim.extrude(Shape2D.roundedRect(0.15, 0.135, radius: 0.012, segments: l == 0 ? 3 : 1), depth: stageT, bevel: l == 0 ? 0.0015 : 0.001, bevelSegments: 1, material: black),
                    Xform(translation: V3(sx0, stageY + stageT / 2, sz0 - 0.005), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))), to: "stage", lods: l...l)
        }
        // Stage bracket to the arm guide, condenser with its aperture lever.
        rig.add(Prim.roundedBox(V3(0.05, 0.04, 0.05), radius: 0.004, bevelSegments: 1, material: black), Xform(translation: V3(0, stageY - 0.012, armZ + 0.058)), to: "stage")
        rig.add(Prim.lathe([V2(0, 0), V2(0.019, 0), V2(0.02, 0.003), V2(0.02, 0.026), V2(0.014, 0.03), V2(0, 0.03)], segments: 20, seamTile: 0.1, material: black),
                Xform(translation: V3(sx0, stageY - 0.033, sz0)), to: "stage", lods: 0...0)
        rig.add(Prim.cylinder(radius: 0.02, height: 0.03, bevel: 0, segments: 8, bevelSegments: 1, material: black), Xform(translation: V3(sx0, stageY - 0.033, sz0)), to: "stage", lods: 1...1)
        rig.add(Prim.tube([V3(0.018, stageY - 0.016, sz0 + 0.006), V3(0.035, stageY - 0.016, sz0 + 0.03)], radii: [0.0018, 0.0018], sides: 6, seamTile: 0.02, material: chrome),
                to: "stage", lods: 0...0)
        // Hanging X/Y knobs of the mechanical stage (right front, under the stage).
        rig.part("stage-knob", parent: "stage", pivot: V3(0.06, stageY - 0.02, sz0 + 0.03),
                 joint: Joint(.revolute, axis: .up, range: -180...180, duration: 0.8, mimic: .init("stage-x", ratio: 3000)))
        rig.add(Prim.cylinder(radius: 0.0025, height: 0.025, bevel: 0.0005, segments: 6, bevelSegments: 1, material: chrome), Xform(translation: V3(0.06, stageY - 0.025, sz0 + 0.03)), to: "stage-knob")
        for (y, r) in [(stageY - 0.03, Float(0.011)), (stageY - 0.045, Float(0.009))] {
            rig.add(Prim.cylinder(radius: r, height: 0.011, bevel: 0.0015, segments: 16, bevelSegments: 1, material: black), Xform(translation: V3(0.06, y, sz0 + 0.03)), to: "stage-knob", lods: 0...0)
        }

        rig.add(Prim.cylinder(radius: 0.01, height: 0.026, bevel: 0, segments: 6, bevelSegments: 1, material: black), Xform(translation: V3(0.06, stageY - 0.045, sz0 + 0.03)), to: "stage-knob", lods: 1...1)

        // MARK: slide holder and slide (X and front-back travel)
        rig.part("stage-x", parent: "stage", pivot: V3(sx0, stageTop, sz0), joint: .slide(axis: V3(1, 0, 0), -0.03...0.03, duration: 0.8))
        rig.part("stage-y", parent: "stage-x", pivot: V3(sx0, stageTop, sz0), joint: .slide(axis: V3(0, 0, 1), -0.02...0.02, duration: 0.8))
        rig.add(Prim.roundedBox(V3(0.012, 0.006, 0.07), radius: 0.0015, bevelSegments: 1, material: black), Xform(translation: V3(-0.052, stageTop + 0.003, sz0)), to: "stage-y")
        rig.add(Prim.roundedBox(V3(0.03, 0.005, 0.008), radius: 0.0015, bevelSegments: 1, material: black), Xform(translation: V3(-0.034, stageTop + 0.0025, sz0 - 0.017)), to: "stage-y")
        rig.add(Prim.sweep(Shape2D.roundedRect(0.003, 0.004, radius: 0.001, segments: 1),
                           along: catmull([V3(-0.046, stageTop + 0.004, sz0 + 0.03), V3(-0.03, stageTop + 0.004, sz0 + 0.022), V3(-0.012, stageTop + 0.003, sz0 + 0.014)], per: 3),
                           up: .up, material: chrome), to: "stage-y", lods: 0...0)
        // Glass slide (76 x 26 x 1 mm), cover slip, frosted label end and a stained specimen.
        rig.add(Prim.roundedBox(V3(0.076, 0.001, 0.026), radius: 0.0003, bevelSegments: 1, material: "glass.clear"), Xform(translation: V3(-0.008, stageTop + 0.0006, sz0)), to: "stage-y")
        rig.add(cuboid(V3(0.02, 0.0004, 0.025), material: "paper.sheet:F4F1EA"), Xform(translation: V3(-0.036, stageTop + 0.0013, sz0)), to: "stage-y")
        rig.add(Prim.superellipsoid(V3(0.012, 0.0003, 0.009), exponent: 2.2, subdivisions: 3, material: "plastic.matte:B0426E"),
                Xform(translation: V3(rng.float(-0.003...0.003), stageTop + 0.0012, sz0 + rng.float(-0.002...0.002))), to: "stage-y")
        rig.add(cuboid(V3(0.022, 0.0003, 0.022), material: "glass.clear"), Xform(translation: V3(0, stageTop + 0.0015, sz0)), to: "stage-y", lods: 0...0)

        // MARK: quadruple nosepiece on a tilted axis, four objectives
        let tilt = nosepieceTilt * .pi / 180
        let R = simd_quatf(angle: tilt, axis: V3(1, 0, 0))
        let orad: Float = 0.022, olen: Float = 0.042, tipY = stageTop + 0.016
        let C = V3(sx0, tipY + olen + orad * sin(tilt), sz0 - orad * cos(tilt))
        rig.part("nosepiece", pivot: C, frame: R, joint: .hinge(axis: .up, 0...270, duration: 0.9))
        for l in 0..<2 {
            rig.add(Prim.lathe([V2(0, -0.004), V2(0.03, -0.004), V2(0.034, 0.0), V2(0.032, 0.006), V2(0.02, 0.016), V2(0, 0.019)], segments: l == 0 ? 28 : 12, seamTile: 0.1, material: chrome),
                    Xform(translation: C, rotation: R), to: "nosepiece", lods: l...l)
        }
        let bands: [MaterialKey] = ["plastic.matte:C8261E", "plastic.matte:E2B92A", "plastic.matte:2F5FA8", "plastic.matte:EDEDED"]
        let lengths: [Float] = [0.03, 0.036, olen, olen]
        for k in 0..<4 {
            let a = Float(k) * .pi / 2
            let d = V3(sin(a), 0, cos(a))
            let down = simd_normalize(V3(0, -1, 0) + d * tan(tilt))
            let base = C + R.act(d * orad)
            let rot = R * simd_quatf(from: .up, to: down)
            let L = lengths[k]
            for l in 0..<2 {
                let prof: [V2] = l == 0
                    ? [V2(0, 0), V2(0.0105, 0), V2(0.0105, L * 0.45), V2(0.0095, L * 0.5), V2(0.0085, L * 0.92), V2(0.0055, L), V2(0, L)]
                    : [V2(0, 0), V2(0.0105, 0), V2(0.0085, L), V2(0, L)]
                rig.add(Prim.lathe(prof, segments: l == 0 ? 16 : 8, seamTile: 0.05, material: chrome), Xform(translation: base, rotation: rot), to: "nosepiece", lods: l...l)
            }
            rig.add(Prim.cylinder(radius: 0.0107, height: 0.003, bevel: 0.0004, segments: 16, bevelSegments: 1, material: bands[k]),
                    Xform(translation: base + rot.act(V3(0, L * 0.3, 0)), rotation: rot), to: "nosepiece", lods: 0...0)
            rig.add(Prim.cylinder(radius: 0.0035, height: 0.0008, bevel: 0.0002, segments: 10, bevelSegments: 1, material: "glass.clear"),
                    Xform(translation: base + rot.act(V3(0, L - 0.0002, 0)), rotation: rot), to: "nosepiece", lods: 0...0)
        }

        // MARK: binocular eyepiece tubes (interpupillary adjust: right mirrors left)
        let H0 = V3(0, 0.302, 0.0), e = simd_normalize(V3(0, sin(Float(40) * .pi / 180), cos(Float(40) * .pi / 180)))
        let tubeRot = simd_quatf(from: .up, to: e)
        rig.part("ipd-left", pivot: H0, joint: .hinge(axis: e, -12...12, duration: 0.5))
        rig.part("ipd-right", pivot: H0, joint: Joint(.revolute, axis: e, range: -12...12, duration: 0.5, mimic: .init("ipd-left", ratio: -1)))
        for (name, side) in [("ipd-left", Float(-1)), ("ipd-right", Float(1))] {
            let o = H0 + V3(side * 0.029, 0, 0)
            for l in 0..<2 {
                rig.add(Prim.roundedBox(V3(0.034, 0.03, 0.05), radius: 0.008, bevelSegments: 1, material: enamel),
                        Xform(translation: o + tubeRot.act(V3(0, 0.008, 0)) + V3(-side * 0.004, -0.004, -0.006), rotation: tubeRot), to: name, lods: l...l)
                rig.add(Prim.lathe([V2(0, 0), V2(0.0125, 0), V2(0.0125, 0.045), V2(0.0115, 0.047), V2(0, 0.047)], segments: l == 0 ? 20 : 8, seamTile: 0.08, material: black),
                        Xform(translation: o + tubeRot.act(V3(0, 0.02, 0)), rotation: tubeRot), to: name, lods: l...l)
            }
            // Eyepiece (chrome ring, black barrel) and rubber eyecup.
            rig.add(Prim.cylinder(radius: 0.0132, height: 0.005, bevel: 0.0008, segments: 20, bevelSegments: 1, material: chrome),
                    Xform(translation: o + tubeRot.act(V3(0, 0.064, 0)), rotation: tubeRot), to: name, lods: 0...0)
            rig.add(Prim.lathe([V2(0.008, 0), V2(0.0145, 0), V2(0.0155, 0.004), V2(0.0155, 0.016), V2(0.0135, 0.018), V2(0.009, 0.018), V2(0.009, 0.012)],
                               segments: 20, seamTile: 0.08, material: rubber), Xform(translation: o + tubeRot.act(V3(0, 0.069, 0)), rotation: tubeRot), to: name, lods: 0...0)
            rig.add(Prim.cylinder(radius: 0.0155, height: 0.023, bevel: 0, segments: 8, bevelSegments: 1, material: rubber),
                    Xform(translation: o + tubeRot.act(V3(0, 0.064, 0)), rotation: tubeRot), to: name, lods: 1...1)
            rig.add(Prim.cylinder(radius: 0.009, height: 0.0006, bevel: 0.0002, segments: 14, bevelSegments: 1, material: "glass.clear"),
                    Xform(translation: o + tubeRot.act(V3(0, 0.077, 0)), rotation: tubeRot), to: name, lods: 0...0)
        }

        groundAO(&rig, height: 0.03, floor: 0.6)
        rig.states = [
            RigState("off"),
            RigState("on", ["switch": 14, "dimmer": 180], options: ["lamp": 1]),
            RigState("focused", ["switch": 14, "dimmer": 180, "focus": 600, "stage-x": 0.012, "stage-y": -0.006, "ipd-left": 6], options: ["lamp": 1]),
            RigState("nosepiece-turned", ["switch": 14, "dimmer": 180, "focus": 600, "stage-x": 0.012, "stage-y": -0.006, "ipd-left": 6, "nosepiece": 90], options: ["lamp": 1]),
        ]
        return rig
    }
}
