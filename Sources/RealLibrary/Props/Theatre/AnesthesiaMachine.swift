import simd
import Foundation

/// Anesthesia workstation (Draeger Fabius / GE Aisys class), 0.84 x 1.72 x 0.80 m: grey base on four 100 mm
/// casters with brakes, warm white lower cabinet with three drawers, grey work surface with accessory rails,
/// upper tower with a three-tube flowmeter bank and flow knobs, a sevoflurane vaporizer on a Selectatec bar
/// with a concentration dial, an ascending bellows in a clear dome, a breathing-system block with valve domes
/// and an APL valve, a CO2 absorber with purple-white granules, corrugated blue breathing hoses joined at a
/// Y-piece, a 3 L reservoir bag, O2 and N2O E-cylinders and pipeline hoses at the back, and a monitor on an
/// arm. Drawers slide, the bellows drops while ventilating, the dial turns and the screen shows vitals.
public struct AnesthesiaMachine: RealArticulated {
    public static let id = "anesthesia-machine"
    public static let summary = "Anesthesia workstation: cart body with three drawers, flowmeters, vaporizer, bellows in a clear dome, breathing circuit and a monitor arm."
    public static let tags = ["prop", "medical", "surgical", "articulated", "electronics", "plastic", "metal"]
    public static let budget = 15000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 12, distance: 2.1, studio: true)

    /// Vaporizer agent color (sRGB hex): sevoflurane E2B637, isoflurane 8A5AA8, desflurane 3A74B8.
    public var agent: UInt32 = 0xE2B637
    /// Breathing hose tint (sRGB hex).
    public var hose: UInt32 = 0x4F86C6
    /// Bellows travel while ventilating (m).
    public var bellowsTravel: Float = 0.12
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        let L = 3
        var rig = Rig(name: Self.id, lods: L, switchDistances: [4, 10])
        let shell: MaterialKey = "plastic.medical-worn", grey: MaterialKey = "plastic.medical-grey-worn", dark: MaterialKey = "plastic.matte:2A2B2D"
        let chrome: MaterialKey = "metal.chrome", clear: MaterialKey = "plastic.clear"
        let vap: MaterialKey = "plastic.gloss:" + String(format: "%06X", agent)
        let hoseMat: MaterialKey = "rubber.tubing:" + String(format: "%06X", hose)
        func pick<T>(_ l: Int, _ a: T, _ b: T, _ c: T) -> T { l == 0 ? a : (l == 1 ? b : c) }
        func rbox(_ size: V3, _ r: Float, _ l: Int, _ mat: MaterialKey, big: Bool = false) -> Surface {
            l == 2 || (l == 1 && !big) ? cuboid(size, material: mat) : Prim.roundedBox(size, radius: r, bevelSegments: big && l == 0 ? 2 : 1, material: mat)
        }
        let yb: Float = 0.12, yc0: Float = 0.17, yw: Float = 0.83   // base top, cabinet bottom, work surface underside
        let cabZ: Float = -0.02, cabD: Float = 0.6, cabW: Float = 0.72
        let face = cabZ + cabD / 2                                  // cabinet front face
        let tz: Float = -0.13, tD: Float = 0.4, tTop: Float = 1.36   // tower
        let tFace = tz + tD / 2

        // MARK: static body
        for l in 0..<L {
            var m = Model(name: Self.id)
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                theatreCaster(&m, at: V3(sx * 0.33, 0, sz * 0.28), height: yb, wheelRadius: 0.05, width: 0.034, yaw: sz > 0 ? 0 : 180,
                              brake: sz > 0 && l == 0, detail: min(l, 1), frame: chrome, wheel: "rubber.tubing:3A3B3D", hub: grey)
            }}
            m.add(rbox(V3(0.8, 0.05, 0.7), 0.02, l, grey, big: true), Xform(translation: V3(0, yb + 0.025, 0)))
            m.add(rbox(V3(cabW, yw - yc0, cabD), 0.025, l, shell, big: true), Xform(translation: V3(0, (yc0 + yw) / 2, cabZ)))
            // Work surface with a rounded front edge and accessory rails on the sides.
            m.add(rbox(V3(0.84, 0.035, 0.7), 0.015, l, grey, big: true), Xform(translation: V3(0, yw + 0.0175, 0)))
            for sx: Float in [-1, 1] where l < 2 {
                m.add(rbox(V3(0.01, 0.025, 0.5), 0.003, l, "metal.casework"), Xform(translation: V3(sx * 0.432, yw - 0.02, 0.0)))
            }
            // Tower and top shelf.
            m.add(rbox(V3(0.68, tTop - yw - 0.035, tD), 0.025, l, shell, big: true), Xform(translation: V3(0, (yw + 0.035 + tTop) / 2, tz)))
            m.add(rbox(V3(0.74, 0.03, 0.46), 0.012, l, grey, big: true), Xform(translation: V3(0, tTop + 0.015, tz)))
            // Flowmeter recess on the tower front.
            m.add(rbox(V3(0.24, 0.3, 0.012), 0.008, l, dark), Xform(translation: V3(0.0, 1.105, tFace + 0.002)))
            // Dark panels behind the drawers (show when a drawer is out).
            m.add(cuboid(V3(0.49, 0.47, 0.004), material: dark), Xform(translation: V3(0.06, 0.565, face + 0.001)))
            // Kick panel and left breathing-system mount.
            m.add(rbox(V3(0.2, 0.5, 0.012), 0.006, l, grey), Xform(translation: V3(-0.26, 0.55, face + 0.004)))
            // Back: E-cylinders on yokes (O2 green, N2O blue) and pipeline hoses.
            for (k, cx) in [Float(-0.16), Float(0.16)].enumerated() {
                let cr: Float = 0.052, c0: Float = 0.3, c1: Float = 0.92
                var prof: [V2] = [V2(0, c0), V2(cr - 0.008, c0), V2(cr, c0 + 0.01), V2(cr, c1 - 0.05)]
                for j in 1...pick(l, 5, 3, 1) { let a = Float(j) / Float(pick(l, 5, 3, 1)) * .pi / 2; prof.append(V2(0.012 + (cr - 0.012) * cos(a), c1 - 0.05 + 0.05 * sin(a))) }
                prof.append(V2(0, c1))
                let cz = cabZ - cabD / 2 - 0.054
                m.add(Prim.lathe(prof, segments: pick(l, 14, 10, 6), material: k == 0 ? "metal.powdercoat:2E7D4F" : "metal.powdercoat:2E5FA8"), Xform(translation: V3(cx, 0, cz)))
                m.add(rbox(V3(0.07, 0.06, 0.06), 0.008, l, chrome), Xform(translation: V3(cx, c1 + 0.03, cz)))
                m.add(rbox(V3(0.12, 0.04, 0.04), 0.006, l, grey), Xform(translation: V3(cx, 0.5, cz + 0.05)))
            }
            rig.base[l] = m
        }
        // Pipeline hoses from the back panel down and out (LOD0, LOD1).
        for (k, col) in [(0, "rubber.tubing:E8E8E4"), (1, "rubber.tubing:2E8B57")] {
            let x0: Float = 0.24 + Float(k) * 0.05, zb = cabZ - cabD / 2
            let path = catmull([V3(x0, 1.0, tz - tD / 2), V3(x0 + 0.02, 0.9, zb - 0.08), V3(x0 + 0.03, 0.55, zb - 0.12), V3(x0 + 0.05, 0.35, zb - 0.05),
                                V3(x0 + 0.08, 0.3, zb + 0.1)], per: 4)
            for l in 0..<2 {
                rig.base[l].add(Prim.tube(path, radii: path.map { _ in 0.008 }, sides: pick(l, 8, 5, 4), seamTile: 0.05, material: col))
            }
        }

        // Flowmeter tubes, floats, scales and flow knobs.
        let knobCols: [MaterialKey] = ["metal.powdercoat:2E7D4F", "metal.powdercoat:2E5FA8", "plastic.matte:E8E6E0"]
        for (i, fx) in [Float(-0.06), Float(0.0), Float(0.06)].enumerated() {
            for l in 0..<2 {
                rig.base[l].add(rbox(V3(0.03, 0.2, 0.002), 0.001, 2, "paper.sheet"), Xform(translation: V3(fx, 1.14, tFace + 0.009)))
                rig.base[l].add(Prim.cylinder(radius: 0.009, height: 0.21, bevel: 0.002, segments: pick(l, 12, 8, 6), bevelSegments: 1, material: clear),
                                Xform(translation: V3(fx, 1.035, tFace + 0.022)))
                // Flow knob with flutes (O2 knob is fluted and larger by standard).
                rig.base[l].add(Prim.cylinder(radius: i == 0 ? 0.018 : 0.015, height: 0.03, bevel: 0.004, segments: pick(l, 14, 8, 6), bevelSegments: 1, material: knobCols[i]),
                                Xform(translation: V3(fx, 1.0, tFace + 0.008), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            }
            rig.base[0].add(Prim.lathe([V2(0, 0), V2(0.0065, 0.004), V2(0.0065, 0.008), V2(0, 0.012)], segments: 8, material: chrome),
                            Xform(translation: V3(fx, 1.06 + Float(i) * 0.025 + rng.float(0...0.02), tFace + 0.022)))
        }
        // Main switch with standby LED, small status LCD.
        rig.base[0].add(Prim.cylinder(radius: 0.012, height: 0.01, bevel: 0.002, segments: 12, bevelSegments: 1, material: dark),
                        Xform(translation: V3(-0.27, 1.3, tFace + 0.005), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        rig.base[0].add(Prim.cylinder(radius: 0.003, height: 0.003, bevel: 0.001, segments: 8, bevelSegments: 1, material: "emissive.led-green"),
                        Xform(translation: V3(-0.245, 1.3, tFace + 0.008), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Panel seams (split lines) on the cabinet and tower sides, vent slots on the tower sides.
        var seams = Surface(material: dark)
        for sx: Float in [-1, 1] {
            seams.append(cuboid(V3(0.002, yw - yc0 - 0.06, 0.003), material: dark), Xform(translation: V3(sx * (cabW / 2 + 0.0004), (yc0 + yw) / 2, face - 0.12)))
            seams.append(cuboid(V3(0.002, 0.003, cabD - 0.06), material: dark), Xform(translation: V3(sx * (cabW / 2 + 0.0004), yc0 + 0.1, cabZ)))
            for k in 0..<7 {
                seams.append(cuboid(V3(0.002, 0.006, 0.12), material: dark), Xform(translation: V3(sx * (0.34 + 0.0004), 1.1 + Float(k) * 0.018, tz - 0.05)))
            }
        }
        seams.append(cuboid(V3(0.68 - 0.04, 0.003, 0.002), material: dark), Xform(translation: V3(0, 1.27, tFace + 0.0004)))
        rig.base[0].add(seams)
        // Daily check sticker on the tower side.
        do {
            var st = Surface(material: "label.iv")
            let x = 0.3405 as Float, y0: Float = 0.92, y1: Float = 1.04, z0 = tz + 0.05, z1 = tz + 0.15
            let n = V3(1, 0, 0)
            let a = st.add(V3(x, y1, z0), n, V2(0, 0)), b = st.add(V3(x, y1, z1), n, V2(1, 0))
            let c = st.add(V3(x, y0, z1), n, V2(1, 1)), d = st.add(V3(x, y0, z0), n, V2(0, 1))
            st.quad(a, d, c, b); st.computeTangents()
            rig.base[0].add(st); rig.base[1].add(st)
        }
        // Ventilator control panel left of the flowmeters: dark bezel, LCD, soft keys, rotary encoder.
        let vpx: Float = -0.2, vpy: Float = 1.12
        for l in 0..<2 {
            rig.base[l].add(rbox(V3(0.2, 0.2, 0.012), 0.01, l, dark), Xform(translation: V3(vpx, vpy, tFace + 0.004)))
        }
        do {
            var lcd = Surface(material: "screen.off")
            let w: Float = 0.15, h: Float = 0.09, cy = vpy + 0.04, z = tFace + 0.0105
            let n = V3(0, 0, 1)
            let a = lcd.add(V3(vpx - w / 2, cy + h / 2, z), n, V2(0, 0)), b = lcd.add(V3(vpx + w / 2, cy + h / 2, z), n, V2(1, 0))
            let c = lcd.add(V3(vpx + w / 2, cy - h / 2, z), n, V2(1, 1)), d = lcd.add(V3(vpx - w / 2, cy - h / 2, z), n, V2(0, 1))
            lcd.quad(d, c, b, a)
            for l in 0..<L { rig.base[l].add(lcd) }
            var keys = Surface(material: "plastic.matte:E8E6E0")
            for k in 0..<5 {
                keys.append(cuboid(V3(0.022, 0.012, 0.006), material: "plastic.matte:E8E6E0"),
                            Xform(translation: V3(vpx - 0.075 + Float(k) * 0.03 + 0.015, vpy - 0.035, tFace + 0.012)))
            }
            rig.base[0].add(keys)
            rig.base[0].add(Prim.cylinder(radius: 0.016, height: 0.014, bevel: 0.003, segments: 14, bevelSegments: 1, material: "metal.chrome"),
                            Xform(translation: V3(vpx + 0.06, vpy - 0.07, tFace + 0.008), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }
        // O2 flush button on the work-surface front edge.
        rig.base[0].add(Prim.cylinder(radius: 0.013, height: 0.012, bevel: 0.003, segments: 12, bevelSegments: 1, material: "metal.powdercoat:2E7D4F"),
                        Xform(translation: V3(0.2, yw + 0.0175, 0.35), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Brand strip and serial label on the tower.
        rig.base[0].add(rbox(V3(0.14, 0.022, 0.002), 0.001, 2, grey), Xform(translation: V3(-0.2, 1.33, tFace + 0.001)))

        // Selectatec bar and vaporizer (right of the flowmeters).
        let vx: Float = 0.22, vy0: Float = 0.97, vz = tFace + 0.1
        for l in 0..<L {
            rig.base[l].add(rbox(V3(0.24, 0.04, 0.05), 0.006, l, chrome), Xform(translation: V3(0.22, vy0 + 0.02, tFace + 0.025)))
            rig.base[l].add(rbox(V3(0.11, 0.22, 0.16), 0.018, l, vap), Xform(translation: V3(vx, vy0 + 0.04 + 0.11, vz)))
            rig.base[l].add(rbox(V3(0.11, 0.05, 0.05), 0.01, l, grey), Xform(translation: V3(vx, vy0 + 0.065, vz + 0.095)))
        }
        // Dial scale ring on top of the vaporizer and filler block.
        rig.base[0].add(Prim.lathe([V2(0.044, 0), V2(0.046, 0.004), V2(0.043, 0.006), V2(0, 0.006)], segments: 24, material: "paper.sheet"),
                        Xform(translation: V3(vx, vy0 + 0.26, vz + 0.0)))
        // Story: a strip of white tape with the refill date on the vaporizer front.
        do {
            var tape = Surface(material: "label.rx")
            let x0 = vx - 0.045, x1 = vx + 0.045, y0 = vy0 + 0.17, y1 = vy0 + 0.2, z = vz + 0.0805
            let n = V3(0, 0, 1)
            let a = tape.add(V3(x0, y1, z), n, V2(0, 0)), b = tape.add(V3(x1, y1 + 0.003, z), n, V2(1, 0))
            let c = tape.add(V3(x1, y0 + 0.003, z), n, V2(1, 1)), d = tape.add(V3(x0, y0, z), n, V2(0, 1))
            tape.quad(d, c, b, a); tape.computeTangents()
            rig.base[0].add(tape); rig.base[1].add(tape)
        }
        rig.part("vaporizer-dial", pivot: V3(vx, vy0 + 0.266, vz), joint: .hinge(axis: V3(0, 1, 0), -300...0, duration: 0.8))
        for l in 0..<L {
            rig.add(Prim.cylinder(radius: 0.04, height: 0.026, bevel: 0.004, segments: pick(l, 18, 10, 8), bevelSegments: 1, material: vap),
                    Xform(translation: V3(vx, vy0 + 0.266, vz)), to: "vaporizer-dial", lods: l...l)
        }
        rig.add(rbox(V3(0.07, 0.014, 0.014), 0.005, 0, vap), Xform(translation: V3(vx, vy0 + 0.298, vz)), to: "vaporizer-dial", lods: 0...1)
        rig.add(cuboid(V3(0.004, 0.0015, 0.02), material: dark), Xform(translation: V3(vx, vy0 + 0.2925, vz + 0.025)), to: "vaporizer-dial", lods: 0...0)

        // MARK: bellows in a clear dome (left of the work surface)
        let bx: Float = -0.27, bz: Float = 0.17, by0 = yw + 0.035
        let pedH: Float = 0.06, domeR: Float = 0.08, domeH: Float = 0.26
        for l in 0..<L {
            rig.base[l].add(rbox(V3(0.2, pedH, 0.2), 0.02, l, grey), Xform(translation: V3(bx, by0 + pedH / 2, bz)))
            var dome: [V2] = [V2(domeR + 0.006, 0), V2(domeR + 0.006, 0.012), V2(domeR, 0.014), V2(domeR, domeH - 0.04)]
            for j in 1...pick(l, 5, 3, 2) { let a = Float(j) / Float(pick(l, 5, 3, 2)) * .pi / 2; dome.append(V2(domeR * cos(a), domeH - 0.04 + 0.04 * sin(a))) }
            rig.base[l].add(Prim.lathe(dome, segments: pick(l, 18, 12, 8), material: clear), Xform(translation: V3(bx, by0 + pedH, bz)))
        }
        rig.part("bellows", pivot: V3(bx, by0 + pedH, bz), joint: .slide(axis: V3(0, 1, 0), -bellowsTravel...0, duration: 1.6))
        for l in 0..<2 {
            var acc: [V2] = [V2(0, by0 + pedH + 0.2), V2(0.06, by0 + pedH + 0.2)]
            let folds = l == 0 ? 7 : 4
            for j in 0..<folds {
                let y = by0 + pedH + 0.19 - Float(j) * 0.2 / Float(folds)
                acc.append(V2(0.068, y)); acc.append(V2(0.056, y - 0.1 / Float(folds)))
            }
            acc.append(V2(0.06, by0 + pedH - 0.03))
            rig.add(Prim.lathe(acc.reversed(), segments: l == 0 ? 16 : 10, material: "rubber.silicone:5E86B0"), Xform(translation: V3(bx, 0, bz)), to: "bellows", lods: l...l)
        }
        rig.add(Prim.cylinder(radius: 0.064, height: 0.008, bevel: 0.002, segments: 16, bevelSegments: 1, material: "plastic.matte:E8E6E0"),
                Xform(translation: V3(bx, by0 + pedH + 0.2, bz)), to: "bellows", lods: 0...1)

        // MARK: breathing system block, valves, APL, absorber, bag arm and bag
        let blk = V3(-0.07, yw + 0.035 + 0.03, 0.24)
        for l in 0..<L {
            rig.base[l].add(rbox(V3(0.24, 0.06, 0.13), 0.012, l, grey), Xform(translation: blk))
        }
        let ports: [Float] = [-0.13, -0.03]
        for px in ports {
            for l in 0..<2 {
                // Valve dome on top, hose port toward the front.
                rig.base[l].add(Prim.lathe([V2(0.028, 0), V2(0.028, 0.012), V2(0.022, 0.024), V2(0, 0.026)], segments: pick(l, 16, 10, 6), material: clear),
                                Xform(translation: V3(px, blk.y + 0.03, blk.z - 0.02)))
                rig.base[l].add(Prim.cylinder(radius: 0.012, height: 0.04, bevel: 0.002, segments: pick(l, 12, 8, 6), bevelSegments: 1, material: clear),
                                Xform(translation: V3(px, blk.y, blk.z + 0.06), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            }
        }
        // APL valve: yellow cap.
        for l in 0..<2 {
            rig.base[l].add(Prim.cylinder(radius: 0.02, height: 0.03, bevel: 0.004, segments: pick(l, 16, 8, 6), bevelSegments: 1, material: vap),
                            Xform(translation: V3(0.02, blk.y + 0.03, blk.z)))
        }
        // Absorber canister on the left face: clear shell, purple-white granules.
        let ax: Float = -cabW / 2 - 0.075, ay0: Float = 0.42, az: Float = 0.06
        for l in 0..<L {
            rig.base[l].add(Prim.cylinder(radius: 0.068, height: 0.26, bevel: 0.006, segments: pick(l, 16, 10, 8), bevelSegments: 1, material: clear),
                            Xform(translation: V3(ax, ay0, az)))
            rig.base[l].add(Prim.cylinder(radius: 0.062, height: 0.24, bevel: 0.004, segments: pick(l, 16, 10, 6), bevelSegments: 1, material: "plastic.matte:C9B8E0"),
                            Xform(translation: V3(ax, ay0 + 0.01, az)))
            rig.base[l].add(rbox(V3(0.16, 0.035, 0.16), 0.008, l, grey), Xform(translation: V3(ax, ay0 + 0.278, az)))
            rig.base[l].add(rbox(V3(0.08, 0.04, 0.1), 0.006, l, grey), Xform(translation: V3(-cabW / 2 - 0.02, ay0 + 0.278, az)))
        }
        // Granule exhaustion: a violet band at the bottom (spent absorbent).
        rig.base[0].add(Prim.cylinder(radius: 0.0625, height: 0.06, bevel: 0.002, segments: 16, bevelSegments: 1, material: "plastic.matte:7A4FA8"),
                        Xform(translation: V3(ax, ay0 + 0.012, az)))
        // Bag arm and reservoir bag.
        let bagTop = V3(-0.43, 0.82, 0.26)
        let arm = [V3(blk.x - 0.12, blk.y, blk.z), V3(-0.3, blk.y, blk.z + 0.01), V3(-0.4, blk.y - 0.01, 0.26), V3(-0.43, blk.y - 0.03, 0.26), bagTop]
        for l in 0..<L {
            let pts = catmull(arm, per: pick(l, 3, 2, 1))
            rig.base[l].add(Prim.tube(pts, radii: pts.map { _ in 0.011 }, sides: pick(l, 10, 6, 4), seamTile: 0.05, material: grey))
            var bag = Prim.superellipsoid(V3(0.15, 0.28, 0.13), exponent: 2.3, subdivisions: pick(l, 6, 4, 2), material: "rubber.tubing:202224") { d in
                1 - 0.35 * max(0, d.y) * max(0, d.y) * max(0, d.y)
            }
            bag = bag.transformed(Xform(translation: bagTop + V3(0, -0.16, 0)))
            rig.base[l].add(bag)
            rig.base[l].add(Prim.cylinder(radius: 0.014, height: 0.03, bevel: 0.002, segments: pick(l, 10, 6, 4), bevelSegments: 1, material: "plastic.matte:2E5FA8"),
                            Xform(translation: bagTop + V3(0, -0.03, 0)))
        }
        // Corrugated breathing hoses from the ports, looping down the left front to a Y-piece and elbow.
        let yPiece = V3(-0.28, 0.5, 0.4)
        for (k, px) in ports.enumerated() {
            let ctrl = [V3(px, blk.y, blk.z + 0.08), V3(px - 0.01, blk.y + 0.02, 0.38), V3(px - 0.05 - Float(k) * 0.03, 0.82, 0.43),
                        V3(-0.2 - Float(k) * 0.04, 0.68, 0.44 + Float(k) * 0.02), yPiece + V3(Float(k) * 0.03 - 0.015, 0.03, 0)]
            let smooth = catmull(ctrl, per: 8)
            let dense = resample(smooth, spacing: 0.013)
            var corr = Prim.tube(dense, radii: dense.map { _ in 0.0115 }, sides: 6, seamTile: 0.05, material: hoseMat, capEnd: false) { _, v in
                1 + 0.12 * sin(v / 0.013 * .pi)
            }
            corr.recomputeNormals(weldSeams: true)
            rig.base[0].add(corr)
            let lite = resample(smooth, spacing: 0.06)
            for l in 1..<L {
                rig.base[l].add(Prim.tube(lite, radii: lite.map { _ in 0.012 }, sides: pick(l, 7, 6, 4), seamTile: 0.05, material: hoseMat, capEnd: false))
            }
            // Cuffs at the ports.
            rig.base[0].add(Prim.cylinder(radius: 0.0145, height: 0.025, bevel: 0.002, segments: 10, bevelSegments: 1, material: hoseMat),
                            Xform(translation: V3(px, blk.y, blk.z + 0.07), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }
        for l in 0..<L {
            rig.base[l].add(rbox(V3(0.05, 0.05, 0.03), 0.012, l, clear), Xform(translation: yPiece + V3(0, 0.0, 0)))
            let elbow = catmull([yPiece + V3(0, -0.02, 0), yPiece + V3(0, -0.07, 0.01), yPiece + V3(0.02, -0.1, 0.04)], per: 3)
            rig.base[l].add(Prim.tube(elbow, radii: elbow.map { _ in 0.011 }, sides: pick(l, 10, 6, 4), seamTile: 0.05, material: clear))
        }
        // Hook the Y-piece hangs from.
        rig.base[0].add(rbox(V3(0.03, 0.06, 0.02), 0.006, 0, grey), Xform(translation: V3(-0.28, 0.55, face + 0.012)))

        // MARK: drawers
        let dW: Float = 0.48, dx: Float = 0.06, reveal: Float = 0.006
        var top: Float = 0.795
        for (k, h) in [Float(0.13), Float(0.13), Float(0.2)].enumerated() {
            let name = "drawer\(k + 1)", cy = top - h / 2
            top -= h + reveal
            rig.part(name, pivot: V3(dx, cy, face), joint: .slide(axis: V3(0, 0, 1), 0...0.36, duration: 0.6))
            for l in 0..<L {
                rig.add(rbox(V3(dW, h, 0.02), 0.008, l, shell), Xform(translation: V3(dx, cy, face + 0.01)), to: name, lods: l...l)
            }
            // Recessed grip along the top edge.
            rig.add(rbox(V3(0.2, 0.014, 0.008), 0.004, 1, grey), Xform(translation: V3(dx, top + h + reveal - 0.016, face + 0.021)), to: name, lods: 0...1)
            let bw = dW - 0.04, bd: Float = 0.42, bh = h - 0.03
            for sx: Float in [-1, 1] {
                rig.add(cuboid(V3(0.008, bh, bd), material: grey), Xform(translation: V3(dx + sx * bw / 2, cy - 0.005, face - bd / 2)), to: name, lods: 0...1)
            }
            rig.add(cuboid(V3(bw, 0.006, bd), material: grey), Xform(translation: V3(dx, cy - h / 2 + 0.012, face - bd / 2)), to: name, lods: 0...1)
            // Contents: airway kits, syringes, a laryngoscope box.
            var drng = rng.fork(40 + k)
            var x = dx - bw / 2 + 0.015
            while x < dx + bw / 2 - 0.06 {
                let w = drng.float(0.04...0.1), hh = min(bh - 0.01, drng.float(0.025...0.07)), dz = drng.float(0.12...0.3)
                rig.add(cuboid(V3(w - 0.006, hh, dz), material: drng.chance(0.5) ? "paper.sheet" : "plastic.matte:3A72B8"),
                        Xform(translation: V3(x + w / 2, cy - h / 2 + 0.015 + hh / 2, face - 0.03 - dz / 2)), to: name, lods: 0...0)
                x += w
            }
        }

        // MARK: monitor on an arm above the shelf
        let post = V3(0.28, tTop + 0.03, tz - 0.12)
        for l in 0..<L {
            rig.base[l].add(Prim.cylinder(radius: 0.018, height: 0.17, bevel: 0.003, segments: pick(l, 14, 8, 6), bevelSegments: 1, material: grey), Xform(translation: post))
            let armPts = [post + V3(0, 0.16, 0), post + V3(-0.08, 0.16, 0.08), post + V3(-0.2, 0.16, 0.1)]
            rig.base[l].add(Prim.tube(armPts, radii: [0.018, 0.018, 0.018], sides: pick(l, 10, 6, 4), seamTile: 0.05, material: grey))
        }
        let mc = V3(0.06, 1.585, -0.08)
        let mW: Float = 0.4, mH: Float = 0.29
        for l in 0..<L {
            rig.base[l].add(rbox(V3(mW, mH, 0.055), 0.012, l, grey), Xform(translation: mc))
            rig.base[l].add(rbox(V3(0.1, 0.1, 0.04), 0.01, l, grey), Xform(translation: mc + V3(0, 0, -0.045)))
        }
        rig.base[0].add(rbox(V3(0.08, 0.008, 0.004), 0.002, 0, dark), Xform(translation: mc + V3(0.14, -mH / 2 + 0.012, 0.0285)))
        rig.part("screen", pivot: mc, joint: .fixed, options: 2)
        func panel(_ mat: MaterialKey) -> Surface {
            var s = Surface(material: mat)
            let w: Float = 0.36, h: Float = 0.225, z = mc.z + 0.0285, cy = mc.y + 0.01
            let n = V3(0, 0, 1)
            let a = s.add(V3(mc.x - w / 2, cy + h / 2, z), n, V2(0, 0)), b = s.add(V3(mc.x + w / 2, cy + h / 2, z), n, V2(1, 0))
            let c = s.add(V3(mc.x + w / 2, cy - h / 2, z), n, V2(1, 1)), d = s.add(V3(mc.x - w / 2, cy - h / 2, z), n, V2(0, 1))
            s.quad(d, c, b, a); s.computeTangents()
            return s
        }
        rig.add(panel("screen.off"), to: "screen")
        rig.add(panel("screen.vitals"), to: "screen", option: 1)
        rig.lights = [RigLight(name: "monitor-glow", kind: .point, part: "screen", option: 1, position: mc + V3(0, 0, 0.3),
                               color: V3(0.75, 0.85, 1.0), intensity: 40, attenuationRadius: 1.2)]

        groundAO(&rig, height: 0.15, floor: 0.55)
        rig.states = [
            RigState("parked"),
            RigState("running", ["bellows": -bellowsTravel, "vaporizer-dial": -80], options: ["screen": 1]),
            RigState("drawers-open", ["drawer1": 0.3, "drawer2": 0.24, "drawer3": 0.18]),
        ]
        return rig
    }
}
