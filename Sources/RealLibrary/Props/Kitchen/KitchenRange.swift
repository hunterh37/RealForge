import simd
import Foundation

/// Freestanding 30 in gas range: black porcelain cooktop with five sealed burners (aluminium heads,
/// enamel caps, ceramic igniters) under three continuous matte cast-iron grates, low stainless
/// backguard, front control panel with six knobs (five burners and the oven), windowed oven door
/// with a bar handle over a blue-grey enamel cavity with two racks, broil element and a lamp, and a
/// storage drawer. Turning a burner knob lights its flame crown (`emissive.flame`): high from 10
/// degrees, low from 200 degrees.
///
/// App API: `burnerCenters[i]` is where a pan sits on burner `i + 1` (grate top), `grateTopY` its
/// height. Light burner `n` with `entity.setJoints(KitchenRange.joints(lighting: n))` (or
/// `["knob\(n)": 90]`, low: 240), or switch the flame alone with `entity.setOptions(["flame\(n)": KitchenRange.flameHigh])`.
public struct KitchenRange: RealArticulated {
    public static let id = "kitchen-range"
    public static let summary = "Freestanding 30 in gas range: cast-iron grates over five burners, knob row, windowed oven door and racks, storage drawer."
    public static let tags = ["prop", "kitchen", "metal", "appliance", "articulated"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 24, distance: 1.7, studio: true)

    /// Burner names in knob order (knob1 ... knob5).
    public static let burnerNames = ["left-rear", "left-front", "center", "right-front", "right-rear"]
    /// Burner knob joints, left to right on the panel (the oven knob sits between knob3 and knob4).
    public static let knobNames = ["knob1", "knob2", "knob3", "knob4", "knob5"]
    /// Oven thermostat knob joint (0 off, up to 270).
    public static let ovenKnob = "oven"
    /// Flame parts, one per burner; options `flameOff`, `flameHigh`, `flameLow`.
    public static let flameNames = ["flame1", "flame2", "flame3", "flame4", "flame5"]
    public static let flameOff = 0, flameHigh = 1, flameLow = 2
    /// Knob angles (degrees, counter-clockwise seen from the front) for high and low flame.
    public static let knobHigh: Float = 90, knobLow: Float = 240

    /// Joint values that light burner `n` (1...5) on high or low.
    public static func joints(lighting n: Int, low: Bool = false) -> [String: Float] { ["knob\(n)": low ? knobLow : knobHigh] }

    public var width: Float = 0.76
    public var depth: Float = 0.69
    /// Cooktop surface height.
    public var cooktopY: Float = 0.9
    /// Height of the grate tops (where a pan sits).
    public var grateTopY: Float = 0.935
    /// Burner cap radii in knob order (power burner front right).
    public var burnerRadii: [Float] = [0.03, 0.04, 0.035, 0.05, 0.04]
    public var stainless: MaterialKey = "metal.stainless"
    public var smudged: MaterialKey = "metal.stainless-smudged"
    public var grate: MaterialKey = "metal.grate-iron"
    public var cooktop: MaterialKey = "metal.cooktop-enamel"
    public init() {}

    var backZ: Float { -depth / 2 }
    /// Front face of the door, drawer and control panel (the handle stands 5 cm proud of it).
    public var frontZ: Float { depth / 2 - 0.05 }
    var cooktopCenterZ: Float { (backZ + 0.03 + frontZ) / 2 }
    var sectionX: Float { 0.125 }

    /// Burner centers on the cooktop plane (x, z), knob order.
    var burnerXZ: [V2] {
        let cz = cooktopCenterZ, gx = (width / 2 - 0.01 + sectionX) / 2
        return [V2(-gx, cz - 0.14), V2(-gx, cz + 0.13), V2(0, cz), V2(gx, cz + 0.13), V2(gx, cz - 0.14)]
    }
    /// Where a pan sits on each burner (asset space, grate top), knob order.
    public var burnerCenters: [V3] { burnerXZ.map { V3($0.x, grateTopY, $0.y) } }

    /// Flame crown: a ring of tongues leaving the ports at radius `r0`, height `y0`, curling up and out.
    static func flameCrown(r0: Float, y0: Float, length L: Float, segments n: Int = 26) -> Surface {
        var s = Surface(material: "emissive.flame")
        let rows = 4
        var idx: [[UInt32]] = []
        for j in 0...rows {
            let t = Float(j) / Float(rows)
            let r = r0 + L * 0.82 * t, y = y0 + L * (0.12 * t + 0.55 * t * t)
            let tangent = simd_normalize(V2(L * 0.82, L * (0.12 + 1.1 * t)))
            var row: [UInt32] = []
            for i in 0...n {
                let a = Float(i) / Float(n) * 2 * .pi
                let d = V3(cos(a), 0, -sin(a))
                let nrm = simd_normalize(d * -tangent.y + V3(0, tangent.x, 0))
                row.append(s.add(d * r + V3(0, y, 0), nrm, V2(Float(i) / Float(n), t)))
            }
            idx.append(row)
        }
        for j in 0..<rows { for i in 0..<n { s.quad(idx[j][i], idx[j][i + 1], idx[j + 1][i + 1], idx[j + 1][i]) } }
        s.computeTangents()
        return s
    }

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [6])
        let W = width, bz = backZ, fz = frontZ, ct = cooktopY, gt = grateTopY
        let sideMat: MaterialKey = "metal.oven-enamel:2B2C2E"
        let black: MaterialKey = "plastic.black"
        let alu: MaterialKey = "metal.aluminum-brushed:6E6C68"
        let ovenLo: Float = 0.2, ovenHi: Float = 0.72, cavX: Float = 0.31
        let doorLo: Float = 0.155, doorHi: Float = 0.785, doorT: Float = 0.05
        let panelLo: Float = 0.79, panelHi = ct - 0.006, knobY = (panelLo + panelHi) / 2 - 0.002
        let cavFront = fz - doorT, cavBack = bz + 0.06

        func rbox(_ size: V3, _ c: V3, _ mat: MaterialKey, r: Float = 0.002, seg: Int = 1) -> (Surface, Xform) {
            (Prim.roundedBox(size, radius: r, bevelSegments: seg, material: mat), Xform(translation: c))
        }
        func hbox(_ size: V3, _ c: V3, _ mat: MaterialKey) -> (Surface, Xform) { (cuboid(size, material: mat), Xform(translation: c)) }
        let knobXs: [Float] = [-0.3, -0.2, -0.085, 0.2, 0.3]
        let ovenKnobX: Float = 0.075

        for l in 0..<2 {
            var m = Model(name: Self.id)
            func add(_ b: (Surface, Xform)) { m.add(b.0, b.1) }
            // Carcass: painted sides, back, kick and legs.
            for sx: Float in [-1, 1] {
                add(rbox(V3(0.008, panelLo - 0.02, cavFront - bz), V3(sx * (W / 2 - 0.004), 0.02 + (panelLo - 0.02) / 2, (bz + cavFront) / 2), sideMat, r: 0.002))
                add(rbox(V3(0.008, panelHi - panelLo, fz - 0.04 - bz), V3(sx * (W / 2 - 0.004), (panelLo + panelHi) / 2, (bz + fz - 0.04) / 2), sideMat, r: 0.002))
            }
            add(hbox(V3(W - 0.016, ct - 0.02, 0.01), V3(0, 0.02 + (ct - 0.02) / 2, bz + 0.005), sideMat))
            add(hbox(V3(W - 0.03, 0.022, 0.01), V3(0, 0.013, fz - 0.07), black))
            if l == 0 {
                for sx: Float in [-1, 1] { for z in [bz + 0.05, fz - 0.09] {
                    m.add(Prim.lathe([V2(0.012, 0), V2(0.012, 0.02), V2(0.001, 0.02)], segments: 8, material: black), Xform(translation: V3(sx * (W / 2 - 0.05), 0, z)))
                }}
            }
            // Cooktop: black porcelain sheet with a rolled front edge; low stainless backguard.
            add(rbox(V3(W - 0.002, 0.014, fz + 0.012 - (bz + 0.03)), V3(0, ct - 0.007, (bz + 0.03 + fz + 0.012) / 2), cooktop, r: 0.005, seg: 2))
            add(rbox(V3(W, 0.065, 0.03), V3(0, ct + 0.045 - 0.0325 + 0.0, bz + 0.015), stainless, r: 0.004, seg: 2))
            add(rbox(V3(W - 0.01, 0.008, 0.028), V3(0, ct + 0.0435, bz + 0.016), stainless, r: 0.003, seg: 2))
            // Control panel (handled stainless) with knob bezels and OFF / HI ticks.
            add(rbox(V3(W - 0.002, panelHi - panelLo, 0.045), V3(0, (panelLo + panelHi) / 2, fz - 0.0225), smudged, r: 0.004, seg: 2))
            for x in knobXs + [ovenKnobX] {
                m.add(Prim.lathe([V2(0.034, 0), V2(0.0335, 0.0008), V2(0.02, 0.0008)], segments: 24, material: black),
                      Xform(translation: V3(x, knobY, fz), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
                if l == 0 {
                    m.add(cuboid(V3(0.0015, 0.005, 0.0006), material: "plastic.white"), Xform(translation: V3(x, knobY + 0.0305, fz + 0.0013)))
                    m.add(cuboid(V3(0.005, 0.0015, 0.0006), material: "plastic.white:D0302A"), Xform(translation: V3(x - 0.0305, knobY, fz + 0.0013)))
                }
            }
            // Oven cavity: speckled enamel liner, face frame, racks on side ladders, broil element.
            var cav = Prim.roundedBox(V3(2 * cavX, ovenHi - ovenLo, cavFront - cavBack), radius: 0.02, bevelSegments: 2, material: "metal.oven-enamel").flipped()
            cav = cav.transformed(Xform(translation: V3(0, (ovenLo + ovenHi) / 2, (cavFront + cavBack) / 2)))
            m.add(cav)
            let faceZ = cavFront - 0.004
            add(rbox(V3(W - 0.016, doorHi - ovenHi + 0.004, 0.008), V3(0, (ovenHi + doorHi) / 2, faceZ), "metal.oven-enamel", r: 0.002))
            add(rbox(V3(W - 0.016, ovenLo - doorLo + 0.02, 0.008), V3(0, (doorLo - 0.02 + ovenLo) / 2, faceZ), "metal.oven-enamel", r: 0.002))
            for sx: Float in [-1, 1] {
                add(rbox(V3(W / 2 - cavX - 0.008, ovenHi - ovenLo, 0.008), V3(sx * (cavX + (W / 2 - cavX - 0.008) / 2), (ovenLo + ovenHi) / 2, faceZ), "metal.oven-enamel", r: 0.002))
            }
            if l == 0 {
                for ry: Float in [0.36, 0.52] {
                    let rz0 = cavBack + 0.03, rz1 = cavFront - 0.03, rx = cavX - 0.012
                    let loop = [V3(-rx, ry, rz0), V3(rx, ry, rz0), V3(rx, ry, rz1), V3(-rx, ry, rz1)]
                    m.add(Prim.sweep(Shape2D.circle(0.003, segments: 5), along: loop, up: .up, closedPath: true, caps: false, material: "metal.chrome"))
                    var x = -rx + 0.025
                    while x < rx - 0.01 {
                        m.add(Prim.tube([V3(x, ry - 0.001, rz0), V3(x, ry - 0.001, rz1)], radii: [0.0022, 0.0022], sides: 5, seamTile: 0.02, material: "metal.chrome", capEnd: false))
                        x += 0.04
                    }
                    for sx: Float in [-1, 1] {
                        add(hbox(V3(0.006, 0.01, rz1 - rz0), V3(sx * (cavX - 0.004), ry - 0.008, (rz0 + rz1) / 2), "metal.chrome"))
                    }
                }
                var broil: [V3] = []
                for k in 0..<6 { let z = cavBack + 0.06 + Float(k) * 0.065; broil += [V3(k % 2 == 0 ? -0.24 : 0.24, ovenHi - 0.03, z), V3(k % 2 == 0 ? 0.24 : -0.24, ovenHi - 0.03, z)] }
                m.add(Prim.tube(broil, radii: Array(repeating: 0.0045, count: broil.count), sides: 8, seamTile: 0.05, material: "metal.powdercoat:3A3836"))
            }
            // Burners: spill ring, aluminium head with flame ports, black enamel cap, ceramic igniter.
            for (i, p) in burnerXZ.enumerated() {
                let rb = burnerRadii[i]
                let segs = l == 0 ? 24 : 14
                m.add(Prim.lathe([V2(rb + 0.016, 0), V2(rb + 0.012, 0.0022), V2(rb + 0.002, 0.003)], segments: segs, seamTile: 0.1, material: alu),
                      Xform(translation: V3(p.x, ct, p.y)))
                m.add(Prim.lathe([V2(rb + 0.002, 0.003), V2(rb + 0.001, 0.008), V2(rb - 0.0005, 0.0145), V2(rb * 0.7, 0.0155), V2(0.001, 0.0155)], segments: segs, seamTile: 0.1, material: alu),
                      Xform(translation: V3(p.x, ct, p.y)))
                m.add(Prim.lathe([V2(0.001, 0.0155), V2(rb + 0.0025, 0.0155), V2(rb + 0.0035, 0.0172), V2(rb + 0.0025, 0.0192), V2(rb * 0.75, 0.0212), V2(0.001, 0.022)],
                                 segments: segs, seamTile: 0.1, material: cooktop), Xform(translation: V3(p.x, ct, p.y)))
                if l == 0 {
                    let a = Float(i) * 1.3 + 0.6
                    m.add(Prim.lathe([V2(0.0028, 0), V2(0.0028, 0.011), V2(0.0018, 0.013), V2(0.0005, 0.013)], segments: 7, material: "plastic.white:ECE8DF"),
                          Xform(translation: V3(p.x + cos(a) * (rb + 0.009), ct, p.y + sin(a) * (rb + 0.009))))
                }
            }
            // Grates: three continuous sections, frame bars, a cross bar between front and rear burners,
            // fingers radiating to each burner, rubber feet.
            let bw: Float = 0.011, bh: Float = 0.013
            // Grate bar: rounded-rect section extruded along its length (ends sit in other bars).
            func bar(_ len: Float, _ c: V3, alongZ: Bool, h: Float = bh, w: Float = bw) -> (Surface, Xform) {
                let sec = Prim.extrude(Shape2D.roundedRect(w, h, radius: 0.0032, segments: 2), depth: len, bevel: 0, bevelSegments: 1, material: grate)
                return (sec, Xform(translation: c, rotation: alongZ ? .identity : simd_quatf(degrees: 90, axis: .up)))
            }
            let gz0 = bz + 0.035, gz1 = fz + 0.004
            let sections: [(Float, Float, [Int])] = [(-W / 2 + 0.008, -sectionX - 0.001, [0, 1]), (-sectionX + 0.001, sectionX - 0.001, [2]), (sectionX + 0.001, W / 2 - 0.008, [3, 4])]
            for (x0, x1, burners) in sections {
                let gy = gt - bh / 2
                add(bar(x1 - x0, V3((x0 + x1) / 2, gy, gz0 + bw / 2), alongZ: false))
                add(bar(x1 - x0, V3((x0 + x1) / 2, gy, gz1 - bw / 2), alongZ: false))
                for x in [x0 + bw / 2, x1 - bw / 2] {
                    add(bar(gz1 - gz0 - 2 * bw + 0.002, V3(x, gy, (gz0 + gz1) / 2), alongZ: true))
                }
                var cells: [(Int, Float, Float)] = []   // burner, z min, z max
                if burners.count == 2 {
                    let zm = (burnerXZ[burners[0]].y + burnerXZ[burners[1]].y) / 2
                    add(bar(x1 - x0 - 2 * bw + 0.002, V3((x0 + x1) / 2, gy, zm), alongZ: false))
                    cells = [(burners[0], gz0 + bw, zm - bw / 2), (burners[1], zm + bw / 2, gz1 - bw)]
                } else {
                    cells = [(burners[0], gz0 + bw, gz1 - bw)]
                }
                for (b, cz0, cz1) in cells {
                    let c = burnerXZ[b], rin = burnerRadii[b] + 0.022
                    let angles: [Float] = burners.count == 1 ? [45, 135, 225, 315, 0, 180] : [45, 135, 225, 315]
                    for deg in angles {
                        let a = deg * .pi / 180
                        let d = V2(cos(a), sin(a))
                        var t: Float = 1
                        if d.x > 1e-4 { t = min(t, (x1 - bw - c.x) / d.x) }
                        if d.x < -1e-4 { t = min(t, (x0 + bw - c.x) / d.x) }
                        if d.y > 1e-4 { t = min(t, (cz1 - c.y) / d.y) }
                        if d.y < -1e-4 { t = min(t, (cz0 - c.y) / d.y) }
                        let len = t - rin + 0.004
                        guard len > 0.01 else { continue }
                        let mid = c + d * (rin + len / 2)
                        let f = bar(len, .zero, alongZ: true, h: bh - 0.002, w: 0.009)
                        m.add(f.0, Xform(translation: V3(mid.x, gt - (bh - 0.002) / 2, mid.y), rotation: simd_quatf(angle: -a + .pi / 2, axis: .up)))
                    }
                }
                if l == 0 {
                    for x in [x0 + 0.02, x1 - 0.02] { for z in [gz0 + 0.02, gz1 - 0.02] {
                        m.add(Prim.lathe([V2(0.005, 0), V2(0.005, gt - bh - ct + 0.001), V2(0.001, gt - bh - ct + 0.001)], segments: 6, material: "rubber"), Xform(translation: V3(x, ct, z)))
                    }}
                }
            }
            rig.base[l] = m
        }

        // Knobs: burner knobs turn counter-clockwise (+Z) 0...270.
        let knobProfile = [V2(0.001, 0), V2(0.0235, 0), V2(0.0245, 0.003), V2(0.023, 0.006), V2(0.0205, 0.024), V2(0.0175, 0.0285), V2(0.001, 0.029)]
        for (name, x) in zip(Self.knobNames + [Self.ovenKnob], knobXs + [ovenKnobX]) {
            rig.part(name, pivot: V3(x, knobY, fz), joint: .hinge(axis: V3(0, 0, 1), 0...270, duration: 0.35))
            for l in 0..<2 {
                var m = Model(name: name)
                m.add(Prim.lathe(knobProfile, segments: l == 0 ? 20 : 12, seamTile: 0.05, material: stainless),
                      Xform(translation: V3(x, knobY, fz + 0.0012), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
                m.add(Prim.roundedBox(V3(0.009, 0.04, 0.016), radius: 0.0035, bevelSegments: 1, material: stainless),
                      Xform(translation: V3(x, knobY, fz + 0.035)))
                if l == 0 {
                    m.add(cuboid(V3(0.0016, 0.009, 0.0008), material: "plastic.black"), Xform(translation: V3(x, knobY + 0.013, fz + 0.0434)))
                }
                rig.set(m, part: name, lod: l)
            }
        }

        // Flame crowns, linked to the knobs.
        for (i, p) in burnerXZ.enumerated() {
            let name = Self.flameNames[i], rb = burnerRadii[i]
            rig.part(name, pivot: V3(p.x, ct, p.y), joint: .fixed, options: 3)
            let y0 = ct + 0.012
            rig.add(Self.flameCrown(r0: rb + 0.0012, y0: y0, length: rb * 0.55 + 0.008), Xform(translation: V3(p.x, 0, p.y)), to: name, option: Self.flameHigh)
            rig.add(Self.flameCrown(r0: rb + 0.0012, y0: y0, length: rb * 0.18 + 0.004), Xform(translation: V3(p.x, 0, p.y)), to: name, option: Self.flameLow)
            rig.optionLinks.append(RigOptionLink(part: name, joint: Self.knobNames[i], thresholds: [10, 200]))
        }

        // Oven lamp (rear top corner), linked to the oven knob.
        let lampP = V3(-cavX + 0.05, ovenHi - 0.03, cavBack + 0.004)
        rig.part("ovenlight", pivot: lampP, joint: .fixed, options: 2)
        rig.add(Prim.cylinder(radius: 0.022, height: 0.012, bevel: 0.006, segments: 16, material: "glass.frosted"), Xform(translation: lampP, rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "ovenlight")
        rig.add(Prim.cylinder(radius: 0.022, height: 0.012, bevel: 0.006, segments: 16, material: "emissive.bulb"), Xform(translation: lampP, rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))), to: "ovenlight", option: 1)
        rig.optionLinks.append(RigOptionLink(part: "ovenlight", joint: Self.ovenKnob, thresholds: [10]))
        rig.lights = [RigLight(name: "oven-lamp", kind: .point, part: "ovenlight", option: 1, position: lampP + V3(0.05, -0.05, 0.1),
                               color: V3(1, 0.82, 0.6), intensity: 600, attenuationRadius: 0.9)]

        // Oven door: stainless skin around a smoked window, inner glass and liner, bar handle.
        rig.part("door", pivot: V3(0, doorLo, fz), joint: .hinge(axis: V3(-1, 0, 0), -90...0, duration: 0.9))
        for l in 0..<2 {
            var m = Model(name: "door")
            let dw = W - 0.004, top: Float = 0.125, bot: Float = 0.075, sideW: Float = 0.065
            let winLo = doorLo + bot, winHi = doorHi - top
            func add(_ b: (Surface, Xform)) { m.add(b.0, b.1) }
            add(rbox(V3(dw, top, 0.02), V3(0, doorHi - top / 2, fz - 0.01), stainless, r: 0.005, seg: 2))
            add(rbox(V3(dw, bot, 0.02), V3(0, doorLo + bot / 2, fz - 0.01), stainless, r: 0.005, seg: 2))
            for sx: Float in [-1, 1] {
                add(rbox(V3(sideW, winHi - winLo + 0.004, 0.02), V3(sx * (dw / 2 - sideW / 2), (winLo + winHi) / 2, fz - 0.01), stainless, r: 0.004, seg: 2))
            }
            add(rbox(V3(dw - 2 * sideW + 0.01, winHi - winLo + 0.01, 0.004), V3(0, (winLo + winHi) / 2, fz - 0.006), "glass.oven", r: 0.001))
            // Black frit border inside the window and the door edge walls.
            let ww = dw - 2 * sideW, fr: Float = 0.022
            add(hbox(V3(ww, fr, 0.002), V3(0, winHi - fr / 2, fz - 0.009), "metal.cooktop-enamel"))
            add(hbox(V3(ww, fr, 0.002), V3(0, winLo + fr / 2, fz - 0.009), "metal.cooktop-enamel"))
            for sx: Float in [-1, 1] { add(hbox(V3(fr, winHi - winLo, 0.002), V3(sx * (ww / 2 - fr / 2), (winLo + winHi) / 2, fz - 0.009), "metal.cooktop-enamel")) }
            for sx: Float in [-1, 1] { add(hbox(V3(0.008, doorHi - doorLo, doorT - 0.02), V3(sx * (dw / 2 - 0.004), (doorLo + doorHi) / 2, fz - 0.02 - (doorT - 0.02) / 2), sideMat)) }
            add(hbox(V3(dw, 0.01, doorT - 0.02), V3(0, doorHi - 0.005, fz - 0.035), sideMat))
            add(hbox(V3(dw, 0.01, doorT - 0.02), V3(0, doorLo + 0.005, fz - 0.035), sideMat))
            // Inner liner around a clear inner pane.
            let lz = fz - doorT + 0.004
            let iwLo = winLo + 0.02, iwHi = winHi - 0.02, iw = dw - 2 * sideW - 0.03
            add(hbox(V3(dw - 0.02, doorHi - iwHi, 0.008), V3(0, (iwHi + doorHi) / 2, lz), "metal.oven-enamel"))
            add(hbox(V3(dw - 0.02, iwLo - doorLo, 0.008), V3(0, (doorLo + iwLo) / 2, lz), "metal.oven-enamel"))
            for sx: Float in [-1, 1] { add(hbox(V3((dw - 0.02 - iw) / 2, iwHi - iwLo, 0.008), V3(sx * (iw / 2 + (dw - 0.02 - iw) / 4), (iwLo + iwHi) / 2, lz), "metal.oven-enamel")) }
            add(rbox(V3(iw + 0.01, iwHi - iwLo + 0.01, 0.004), V3(0, (iwLo + iwHi) / 2, lz + 0.002), "glass.clear", r: 0.001))
            m.add(barHandle(length: 0.6, standoff: 0.05, radius: 0.0115, overhang: 0.035, material: smudged), Xform(translation: V3(0, doorHi - 0.05, fz)))
            if l == 0 {
                // Gasket on the inner face.
                let gpath = [V3(-0.29, doorLo + 0.05, lz - 0.006), V3(0.29, doorLo + 0.05, lz - 0.006), V3(0.29, doorHi - 0.07, lz - 0.006), V3(-0.29, doorHi - 0.07, lz - 0.006)]
                m.add(Prim.sweep(Shape2D.circle(0.005, segments: 6), along: gpath, up: V3(0, 0, 1), closedPath: true, caps: false, material: "fabric.wool:5A5650"))
            }
            rig.set(m, part: "door", lod: l)
        }

        // Storage drawer: stainless front with a finger pull, black enamel tub.
        rig.part("drawer", pivot: V3(0, 0.03, fz), joint: .slide(axis: V3(0, 0, 1), 0...0.35, duration: 0.6))
        for l in 0..<2 {
            var m = Model(name: "drawer")
            func add(_ b: (Surface, Xform)) { m.add(b.0, b.1) }
            let dLo: Float = 0.026, dHi = doorLo - 0.004
            add(rbox(V3(W - 0.004, dHi - dLo, 0.022), V3(0, (dLo + dHi) / 2, fz - 0.011), stainless, r: 0.004, seg: 2))
            add(rbox(V3(0.38, 0.012, 0.018), V3(0, dHi - 0.016, fz + 0.007), smudged, r: 0.005, seg: 2))
            let tz1 = fz - 0.022, tz0 = tz1 - 0.42, tw = W - 0.06, th: Float = 0.1
            add(hbox(V3(tw, 0.006, tz1 - tz0), V3(0, dLo + 0.01, (tz0 + tz1) / 2), sideMat))
            for sx: Float in [-1, 1] { add(hbox(V3(0.006, th, tz1 - tz0), V3(sx * tw / 2, dLo + 0.01 + th / 2, (tz0 + tz1) / 2), sideMat)) }
            add(hbox(V3(tw, th, 0.006), V3(0, dLo + 0.01 + th / 2, tz0), sideMat))
            rig.set(m, part: "drawer", lod: l)
        }
        _ = rng.float(0...1)

        groundAO(&rig, height: 0.1, floor: 0.55)
        let allOn = Dictionary(uniqueKeysWithValues: Self.knobNames.map { ($0, Self.knobHigh) })
        let allFlames = Dictionary(uniqueKeysWithValues: Self.flameNames.map { ($0, Self.flameHigh) })
        rig.states = [
            RigState("off"),
            RigState("oven-open", ["door": -88]),
            RigState("front-burner-on", ["knob4": Self.knobHigh], options: ["flame4": Self.flameHigh]),
            RigState("all-on", allOn, options: allFlames),
            RigState("simmer", ["knob1": Self.knobLow, "knob4": Self.knobLow], options: ["flame1": Self.flameLow, "flame4": Self.flameLow]),
            RigState("baking", ["oven": 180], options: ["ovenlight": 1]),
        ]
        return rig
    }
}
