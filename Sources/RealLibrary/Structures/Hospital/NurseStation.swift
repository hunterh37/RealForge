import simd
import Foundation

/// L-shaped ward nurse station (custom millwork class), 4.05 x 1.73 m: a 2.9 m main run with a 1070 mm
/// solid-surface transaction ledge over oak-veneer fascia panels (8 mm black reveals, recessed stainless
/// kick base), a 740 mm laminate staff work surface with cable grommets, a three-drawer pedestal, a
/// return wing at desk height whose solid-surface top overhangs the visitor face as a lowered accessible
/// counter, and an 815 mm oak pass-through gate on two pivot hinges between the main run and a 300 mm
/// end pier. On the staff side: two 24-inch monitors on stands (off / EHR desktop and central vitals), a
/// keyboard and mouse, and a steel chart rack holding coloured binders. Visitor side faces +Z.
public struct NurseStation: RealArticulated {
    public static let id = "nurse-station"
    public static let summary = "L-shaped nurse station: solid-surface transaction ledge, oak fascia, staff work surface with two monitors, keyboard, chart rack and a swing gate."
    public static let tags = ["structure", "medical", "hospital", "interior", "furniture", "wood", "electronics", "articulated"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 18, distance: 1.0, studio: true)

    public var ledgeHeight: Float = 1.07
    public var workHeight: Float = 0.74
    public var fascia: MaterialKey = "wood.veneer-oak"
    public var top: MaterialKey = "stone.solid-surface"
    public var work: MaterialKey = "laminate.white"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [9])
        let O = V3(-0.075, 0, 0.485)                          // centres the L on the origin
        let LH = ledgeHeight, WH = workHeight
        let xL: Float = -1.95, xA: Float = 0.95, xP0: Float = 1.8, xP1: Float = 2.1
        let zFront: Float = 0.35, zBack: Float = -0.4, zWing: Float = -1.35
        let kick: Float = 0.1, panelT: Float = 0.022, ledgeT: Float = 0.03, workT: Float = 0.028
        let black: MaterialKey = "plastic.black", steel: MaterialKey = "metal.casework"

        for l in 0..<2 {
            var m = Model(name: Self.id)
            let seg = l == 0 ? 2 : 1
            func box(_ a: V3, _ b: V3, _ mat: MaterialKey, r: Float = 0.003) {
                let c = (a + b) / 2 + O, s = simd_abs(b - a)
                m.add(Prim.roundedBox(s, radius: min(r, s.min() * 0.45), bevelSegments: seg, material: mat), Xform(translation: c).jittered(&rng, deg: 0.01, offset: 0.0002))
            }
            // Main run carcass (behind the fascia), fascia panels with reveals, kick base.
            box(V3(xL + 0.03, kick, zFront - panelT - 0.03), V3(xA, LH - ledgeT, zFront - panelT), work)
            box(V3(xL + 0.03, 0, zFront - panelT - 0.05), V3(xA, kick, zFront - panelT - 0.02), steel, r: 0.002)
            let cuts: [Float] = [xL + 0.03, -0.95, 0.0, xA]
            for i in 0..<3 {
                box(V3(cuts[i] + 0.004, kick + 0.004, zFront - panelT), V3(cuts[i + 1] - 0.004, LH - ledgeT - 0.004, zFront), fascia, r: 0.002)
            }
            for x in cuts.dropFirst().dropLast() {
                box(V3(x - 0.004, kick, zFront - panelT - 0.002), V3(x + 0.004, LH - ledgeT, zFront - 0.006), black, r: 0.001)
            }
            // Transaction ledge (eased edges, 30 mm front overhang) and its end returns.
            box(V3(xL, LH - ledgeT, 0.08), V3(xA + 0.015, LH, zFront + 0.03), top, r: 0.005)
            box(V3(xA - 0.005, 0, zBack), V3(xA + 0.025, LH - ledgeT, zFront), fascia, r: 0.003)
            // Staff work surface (main + wing), modesty under the ledge, pedestal.
            box(V3(xL, WH - workT, zBack), V3(xA - 0.005, WH, zFront - panelT - 0.03), work, r: 0.003)
            box(V3(xL, WH - workT, zWing), V3(-1.25, WH, zBack + 0.001), work, r: 0.003)
            box(V3(-0.2, 0.02, zBack + 0.02), V3(0.25, WH - workT, zBack + 0.62), work, r: 0.003)
            box(V3(-0.2, 0, zBack + 0.04), V3(0.25, 0.02, zBack + 0.6), black, r: 0.002)
            // Wing: oak visitor face, lowered solid-surface counter overhanging it, back end panel, kick.
            box(V3(xL, kick, zWing), V3(xL + panelT, WH - workT - 0.004, zFront - panelT), fascia, r: 0.002)
            box(V3(xL + 0.02, 0, zWing + 0.02), V3(xL + 0.05, kick, zFront - 0.06), steel, r: 0.002)
            box(V3(xL - 0.035, WH - 0.004, zWing - 0.01), V3(-1.25, WH + 0.026, zBack), top, r: 0.005)
            box(V3(-1.28, 0, zWing), V3(-1.25, WH - workT, zWing + 0.6), fascia, r: 0.003)
            box(V3(xL, 0, zWing), V3(-1.28, WH - workT, zWing + panelT), fascia, r: 0.003)
            // High run end above the wing counter.
            box(V3(xL, WH + 0.026, 0.08), V3(xL + 0.03, LH - ledgeT, zFront), fascia, r: 0.003)
            // End pier: oak box with the ledge on top, the gate's strike side.
            box(V3(xP0, kick, zBack), V3(xP1, LH - ledgeT, zFront), fascia, r: 0.003)
            box(V3(xP0 + 0.02, 0, zBack + 0.02), V3(xP1 - 0.02, kick, zFront - 0.03), steel, r: 0.002)
            box(V3(xP0 - 0.015, LH - ledgeT, zBack + 0.3), V3(xP1 + 0.015, LH, zFront + 0.03), top, r: 0.005)
            rig.base[l] = m
        }
        // Drawer fronts, pulls, grommets, scuffs (LOD0 detail).
        var pulls = Surface(material: steel), shadow = Surface(material: black)
        for k in 0..<3 {
            let y0: Float = 0.04 + Float(k) * 0.225
            shadow.append(cuboid(V3(0.44, 0.004, 0.002), material: black), Xform(translation: V3(0.025, y0 + 0.215, zBack + 0.0195) + O))
            pulls.append(barHandle(length: 0.128, standoff: 0.025, radius: 0.005, material: steel),
                         Xform(translation: V3(0.025, y0 + 0.17, zBack + 0.02) + O, rotation: simd_quatf(degrees: 180, axis: V3(0, 1, 0))))
        }
        rig.base[0].add(pulls); rig.base[0].add(shadow)
        for gx: Float in [-1.25, -0.6] {
            rig.base[0].add(Prim.lathe([V2(0.03, -0.02), V2(0.03, 0), V2(0.04, 0.0005), V2(0.04, 0.0015), V2(0.0385, 0.0025), V2(0.03, 0.0025), V2(0, 0.0015)],
                                       segments: 20, seamTile: 0.1, material: black), Xform(translation: V3(gx, WH, -0.12) + O))
        }
        // Scuffed kick base: dark shoe marks along the visitor side.
        var scuffs = Surface(material: "rubber")
        for _ in 0..<9 {
            let x = rng.float(-1.8...0.8), w = rng.float(0.03...0.09)
            scuffs.append(cuboid(V3(w, rng.float(0.006...0.018), 0.0008), material: "rubber"),
                          Xform(translation: V3(x, rng.float(0.02...0.07), zFront - panelT - 0.0196) + O, rotation: simd_quatf(degrees: rng.float(-12...12), axis: V3(0, 0, 1))))
        }
        rig.base[0].add(scuffs)
        // Warm LED line tucked under the ledge overhang.
        for l in 0..<2 {
            rig.base[l].add(cuboid(V3(xA - xL - 0.06, 0.004, 0.008), material: "emissive.warm"), Xform(translation: V3((xL + xA) / 2, LH - ledgeT - 0.0025, zFront + 0.012) + O))
        }

        // MARK: gate (pivot hinges on the main run's end gable, swings to the staff side)
        let hingeX = xA + 0.03, gateZ = zFront - 0.02
        rig.part("gate", pivot: V3(hingeX, 0, gateZ) + O, joint: .hinge(axis: V3(0, 1, 0), 0...90, duration: 0.9))
        let gw = xP0 - hingeX - 0.012
        for l in 0..<2 {
            rig.add(Prim.roundedBox(V3(gw, 0.86, 0.03), radius: 0.004, bevelSegments: l == 0 ? 2 : 1, material: fascia),
                    Xform(translation: V3(hingeX + 0.006 + gw / 2, 0.1 + 0.43, gateZ) + O), to: "gate", lods: l...l)
        }
        rig.add(Prim.roundedBox(V3(0.1, 0.3, 0.003), radius: 0.003, bevelSegments: 1, material: "metal.stainless"),
                Xform(translation: V3(hingeX + gw - 0.08, 0.62, gateZ - 0.017) + O), to: "gate")
        for y: Float in [0.18, 0.85] {
            rig.add(Prim.cylinder(radius: 0.009, height: 0.07, bevel: 0.002, segments: 12, bevelSegments: 1, material: "metal.stainless"),
                    Xform(translation: V3(hingeX, y, gateZ) + O), to: "gate")
        }

        // MARK: monitors (screens face the staff, -Z)
        let mons: [(Float, MaterialKey)] = [(-1.15, "screen.ui"), (-0.45, "screen.vitals")]
        var lights: [RigLight] = []
        for (i, (mx, onMat)) in mons.enumerated() {
            let mz: Float = -0.03, sy: Float = 1.06
            let yaw = simd_quatf(degrees: Float(i == 0 ? 8 : -6), axis: V3(0, 1, 0))
            func mp(_ p: V3) -> V3 { V3(mx, 0, mz) + yaw.act(p - V3(mx, 0, mz)) + O }
            for l in 0..<2 {
                rig.base[l].add(Prim.roundedBox(V3(0.24, 0.012, 0.19), radius: 0.004, bevelSegments: 1, material: "plastic.matte"), Xform(translation: mp(V3(mx, WH + 0.006, mz)), rotation: yaw))
                rig.base[l].add(Prim.roundedBox(V3(0.06, sy - WH - 0.05, 0.025), radius: 0.006, bevelSegments: 1, material: "plastic.matte"),
                                Xform(translation: mp(V3(mx, WH + (sy - WH - 0.05) / 2, mz + 0.04)), rotation: yaw))
                rig.base[l].add(Prim.roundedBox(V3(0.56, 0.34, 0.045), radius: 0.008, bevelSegments: l == 0 ? 2 : 1, material: "plastic.matte"),
                                Xform(translation: mp(V3(mx, sy, mz + 0.01)), rotation: yaw))
            }
            let name = "monitor\(i + 1)"
            rig.part(name, pivot: mp(V3(mx, sy, mz)), joint: .fixed, options: 2)
            for (o, mat) in [(0, "screen.off"), (1, onMat)] {
                rig.add(screen(mp(V3(mx, sy + 0.005, mz - 0.0126)), right: yaw.act(V3(-1, 0, 0)), up: V3(0, 1, 0), w: 0.527, h: 0.297, mat: mat), to: name, option: o)
            }
            lights.append(RigLight(name: "\(name)-glow", kind: .point, part: name, option: 1, position: mp(V3(mx, sy, mz - 0.35)),
                                   color: V3(0.8, 0.86, 1), intensity: 70, attenuationRadius: 1.4))
            // Cable down to the grommet.
            let cable = catmull([mp(V3(mx, sy - 0.12, mz + 0.06)) - O, V3(mx + 0.02, WH + 0.08, mz + 0.09), V3(i == 0 ? -1.25 : -0.6, WH + 0.01, -0.12)], per: 5)
            rig.base[0].add(Prim.tube(cable.map { $0 + O }, radii: cable.map { _ in 0.003 }, sides: 6, seamTile: 0.05, material: black))
        }
        rig.lights = lights
        // Keyboard and mouse.
        let kq = simd_quatf(degrees: 4, axis: V3(0, 1, 0))
        for l in 0..<2 {
            rig.base[l].add(Prim.roundedBox(V3(0.44, 0.018, 0.14), radius: 0.005, bevelSegments: 1, material: "plastic.matte"), Xform(translation: V3(-0.85, WH + 0.009, -0.24) + O, rotation: kq))
        }
        var keys = Surface(material: "plastic.matte:1A1B1D")
        for r in 0..<5 { for c in 0..<18 {
            let p = V3(-0.85 - 0.2 + 0.0118 + Float(c) * 0.0225, WH + 0.0185, -0.24 - 0.05 + Float(r) * 0.022)
            keys.append(cuboid(V3(0.018, 0.004, 0.017), material: "plastic.matte:1A1B1D"), Xform(translation: V3(-0.85, 0, -0.24) + kq.act(p - V3(-0.85, 0, -0.24)) + O, rotation: kq))
        }}
        rig.base[0].add(keys)
        rig.base[0].add(Prim.superellipsoid(V3(0.06, 0.03, 0.105), exponent: 2.6, subdivisions: 4, material: "plastic.matte") { d in d.y < 0 ? 0.6 : 1 },
                        Xform(translation: V3(-0.5, WH + 0.009, -0.26) + O))

        // MARK: chart rack with binders
        let rx: Float = 0.45, rz: Float = -0.05
        for l in 0..<2 {
            for s: Float in [-1, 1] {
                rig.base[l].add(Prim.roundedBox(V3(0.006, 0.3, 0.32), radius: 0.002, bevelSegments: 1, material: steel), Xform(translation: V3(rx + s * 0.25, WH + 0.15, rz) + O))
            }
            rig.base[l].add(Prim.roundedBox(V3(0.5, 0.006, 0.32), radius: 0.002, bevelSegments: 1, material: steel), Xform(translation: V3(rx, WH + 0.003, rz) + O))
        }
        let binderColors: [MaterialKey] = ["plastic.matte:2A5FA8", "plastic.matte:B5322C", "plastic.matte:2E7D4F"]
        for k in 0..<7 {
            var r = rng.fork(k + 40)
            let x = rx - 0.21 + Float(k) * 0.068 + r.float(-0.006...0.006)
            let lean = simd_quatf(degrees: r.float(-4...4), axis: V3(0, 0, 1)) * simd_quatf(degrees: r.float(-2...2), axis: V3(0, 1, 0))
            for l in 0..<2 {
                rig.base[l].add(Prim.roundedBox(V3(0.05, 0.28, 0.27), radius: 0.006, bevelSegments: 1, material: binderColors[k % 3]),
                                Xform(translation: V3(x, WH + 0.006 + 0.14, rz + r.float(-0.01...0.02)) + O, rotation: lean))
            }
            rig.base[0].add(quad(V3(x, WH + 0.2, rz - 0.136 + 0.001) + O, right: V3(-1, 0, 0), up: V3(0, 1, 0), w: 0.034, h: 0.06, mat: "label.binder"))
            if k < 6 { rig.base[0].add(Prim.roundedBox(V3(0.003, 0.08, 0.3), radius: 0.001, bevelSegments: 1, material: steel), Xform(translation: V3(x + 0.034, WH + 0.04, rz) + O)) }
        }

        groundAO(&rig, height: 0.1, floor: 0.6)
        rig.states = [
            RigState("closed"),
            RigState("gate-open", ["gate": 90]),
            RigState("screens-on", options: ["monitor1": 1, "monitor2": 1]),
        ]
        return rig
    }
}

/// Display quad with UVs 0...1 (v up the panel), facing cross(right, up).
private func screen(_ c: V3, right: V3, up: V3, w: Float, h: Float, mat: MaterialKey) -> Surface {
    var s = Surface(material: mat)
    let n = simd_normalize(simd_cross(right, up)), r = right * (w / 2), u = up * (h / 2)
    let t = artSpan(mat)
    let a = s.add(c - r - u, n, V2(0, 0)), b = s.add(c + r - u, n, V2(t, 0))
    let cc = s.add(c + r + u, n, V2(t, t)), d = s.add(c - r + u, n, V2(0, t))
    s.quad(a, b, cc, d)
    s.computeTangents()
    return s
}

/// Label quad with UVs 0...1.
private func quad(_ c: V3, right: V3, up: V3, w: Float, h: Float, mat: MaterialKey) -> Surface {
    var s = Surface(material: mat)
    let n = simd_normalize(simd_cross(right, up)), r = right * (w / 2), u = up * (h / 2)
    let t = artSpan(mat)
    let a = s.add(c - r - u, n, V2(0, 0)), b = s.add(c + r - u, n, V2(t, 0))
    let cc = s.add(c + r + u, n, V2(t, t)), d = s.add(c - r + u, n, V2(0, t))
    s.quad(a, b, cc, d)
    s.computeTangents()
    return s
}

/// UV span for one artwork across a label or screen: the material's tileSize (so texel density lints at ~1), else 1.
private func artSpan(_ mat: MaterialKey) -> Float {
    let s = MaterialLibrary.spec(for: String(mat.split(separator: ":")[0]))
    return s.program != nil && s.tileSize > 0 ? s.tileSize : 1
}
