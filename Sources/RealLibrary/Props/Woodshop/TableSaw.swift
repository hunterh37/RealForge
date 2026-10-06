import simd
import Foundation

/// 10 in hybrid cabinet table saw, grey cabinet with yellow accents. Table 34 in (0.864 m) high, ground cast
/// iron main table 20 x 27 in with two 3/4 x 3/8 in miter slots and a red zero-clearance throat insert, two
/// 10 in cast iron wings (40 in across), Biesemeyer-style front rail tube with a printed rip scale (30 in to the
/// right of the blade) and rear angle rail, T-square rip fence with aluminum faces and a cam lock lever,
/// 40-tooth ATB carbide blade (gullets, four expansion slots), riving knife, clear two-leaf guard with
/// anti-kickback pawls on a rear support arm, front height and side bevel handwheels, bevel scale with a
/// pointer that follows the trunnion, paddle switch, miter gauge in the left slot, power cord, dust port.
///
/// Frame (game contract): operator stands at +Z, stock feeds toward -Z. The blade is centred at x = 0 in the
/// main table, blade plane YZ, arbor axis X. Rig parts and joints:
/// - `blade-bevel`: hinge about +Z through (0, `tableTopY`, `arborZ`), 0...45 degrees, positive tilts the blade
///   top toward -X (left tilt). Carries the bevel pointer and the guard support arm.
/// - `blade-height` (child of bevel): slide along the bevel frame's +Y, meters, `bladeHeightRange`. At 0 the blade
///   top sits `bladeDrop` (5 mm) below the table; the top gives 3-1/8 in exposure. Carries the riving knife.
/// - `blade` (child of height): hinge about +X through the arbor centre, 0...360 degrees (the game spins it).
/// - `guard` (child of bevel): hinge about -X through the rear hood pivot, 0...40 degrees, positive lifts the
///   hood front as stock passes under it.
/// - `fence`: slide along +X, meters of rip width, 0.02...0.75 (`fenceFaceX(fence:)` gives the face x).
/// - `miter-gauge`: slide along -Z in the left slot, meters pushed toward the blade, `miterGaugeRange`.
/// - `miter-angle` (child of miter-gauge): hinge about +Y through the head pivot, -60...60 degrees.
/// - `switch`: paddle hinge about -X at its top, 0 = off, `switchOnValue` = on (paddle pulled out).
/// States: `idle`, `raised`, `running`, `bevel-45`, `crosscut`.
public struct TableSaw: RealArticulated {
    public static let id = "table-saw"
    public static let summary = "10 in cabinet table saw: steel cabinet, cast iron table and wings, T-square fence, 40-tooth carbide blade, riving knife, guard, handwheels, miter gauge."
    public static let tags = ["prop", "workshop", "tool", "metal", "articulated"]
    public static let budget = 15_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 28, elevation: 28)

    /// Table surface height above the floor (m), 34 in.
    public var tableHeight: Float = 0.864
    /// Saw blade radius (m), 10 in blade.
    public var bladeRadius: Float = 0.127
    /// Kerf: carbide tip width (m), full-kerf 1/8 in.
    public var kerf: Float = 0.0032
    /// Blade top below the table surface at height 0 (m).
    public var bladeDrop: Float = 0.005
    /// Maximum blade exposure above the table at bevel 0 (m), 3-1/8 in.
    public var maxExposure: Float = 0.079
    /// Arbor z (m); the blade and throat are centred on it.
    public var arborZ: Float = 0
    /// Rip distance the fence sits at in every state (m), 6 in.
    public var restFence: Float = 0.1524
    /// Stock thickness the `raised` state is set for (m), 3/4 in; the blade clears it by 1/4 in.
    public var stockThickness: Float = 0.019
    /// Cabinet paint (sRGB hex).
    public var cabinetColor: UInt32 = 0x5C6166
    /// Accent paint for the fence head, handwheel spinners and switch box (sRGB hex).
    public var accentColor: UInt32 = 0xF2B705
    public init() {}

    // MARK: public geometry (game contract)

    /// Table surface height (m).
    public var tableTopY: Float { tableHeight }
    /// Main table half width (m); the table is 20 in wide, 27 in deep.
    public var mainHalfWidth: Float { 0.254 }
    /// Table half depth (m).
    public var tableHalfDepth: Float { 0.343 }
    /// Wing width (m), each side.
    public var wingWidth: Float { 0.254 }
    /// Centre x of the two miter slots (left, right), 3/4 in wide, 3/8 in deep.
    public var miterSlotX: [Float] { [-0.150, 0.160] }
    /// Usable cast iron + wing surface in XZ: min = (x, z), max = (x, z).
    public var tableBounds: (min: V2, max: V2) {
        (V2(-mainHalfWidth - wingWidth, -tableHalfDepth), V2(mainHalfWidth + wingWidth, tableHalfDepth))
    }
    /// Arbor depth below the table at height 0 (m).
    public var arborDepth: Float { bladeRadius + bladeDrop }
    /// Range of the `blade-height` slide (m).
    public var bladeHeightRange: ClosedRange<Float> { 0...(bladeDrop + maxExposure) }
    /// Range of the `fence` slide (m of rip width).
    public var fenceRange: ClosedRange<Float> { 0.02...0.75 }
    /// Range of the `miter-gauge` slide (m pushed toward -Z).
    public var miterGaugeRange: ClosedRange<Float> { 0...0.45 }
    /// `switch` joint value for ON (degrees); 0 is OFF.
    public var switchOnValue: Float { 18 }
    /// `blade-height` value of the `raised` state: blade top 1/4 in above `stockThickness`.
    public var raisedHeight: Float { bladeDrop + stockThickness + 0.00635 }

    /// Arbor centre in asset space for a `blade-height` value (m) and `blade-bevel` value (degrees).
    public func arborCenter(height: Float, bevel: Float) -> V3 {
        let d = arborDepth - height, a = bevel * .pi / 180
        return V3(d * sin(a), tableTopY - d * cos(a), arborZ)
    }
    /// Blade top above the table surface at bevel 0 for a `blade-height` value (m; negative = below the table).
    /// Monotonic: exposure = height - bladeDrop.
    public func bladeExposure(height: Float) -> Float { height - bladeDrop }
    /// X of the fence face nearest the blade for a `fence` value: the blade's right side plus the rip width.
    public func fenceFaceX(fence: Float) -> Float { kerf / 2 + fence }
    /// Z of the miter gauge's front face (the face that pushes the stock, facing -Z) for a `miter-gauge` value.
    public func miterGaugeFaceZ(slide: Float) -> Float { miterRestZ - 0.0085 - 0.012 - slide }
    /// Head pivot z of the miter gauge at slide 0 (m).
    public var miterRestZ: Float { 0.30 }

    // MARK: rig

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [6])
        let T = tableTopY, R = bladeRadius
        let hex = { (c: UInt32) in String(format: "%06X", c) }
        let iron: MaterialKey = "metal.table-saw-iron"
        let cab: MaterialKey = "metal.powdercoat:" + hex(cabinetColor)
        let dark: MaterialKey = "metal.powdercoat:2E3033"
        let accent: MaterialKey = "metal.powdercoat:" + hex(accentColor)
        let yellowPl: MaterialKey = "plastic.tool:" + hex(accentColor)
        let black: MaterialKey = "plastic.matte:1A1A1B"
        let ink: MaterialKey = "plastic.matte:121212"
        let alu: MaterialKey = "metal.aluminum-brushed"
        let steel: MaterialKey = "metal.steel"
        let az = arborZ, hd = tableHalfDepth, hw = mainHalfWidth
        let xs = miterSlotX

        func box(_ m: inout Model, _ size: V3, _ c: V3, _ mat: MaterialKey, r: Float = 0.003, seg: Int = 1) {
            m.add(Prim.roundedBox(size, radius: r, bevelSegments: seg, material: mat), Xform(translation: c))
        }
        var lodNow = 0
        func span(_ m: inout Model, _ lo: V3, _ hi: V3, _ mat: MaterialKey, r: Float = 0.003, seg: Int = 1) {
            if lodNow > 0 && min(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z) < 0.03 { m.add(cuboid(hi - lo, material: mat), Xform(translation: (lo + hi) / 2)); return }
            box(&m, hi - lo, (lo + hi) / 2, mat, r: r, seg: lodNow > 0 ? 1 : seg)
        }
        func slab(_ m: inout Model, _ lo: V3, _ hi: V3, _ mat: MaterialKey) {
            m.add(cuboid(hi - lo, material: mat), Xform(translation: (lo + hi) / 2))
        }
        func bolt(_ m: inout Model, at p: V3, normal n: V3, size: Float) {
            m.add(Prim.cylinder(radius: size * 0.55, height: size * 0.45, bevel: size * 0.08, segments: 6, bevelSegments: 1, material: steel),
                  Xform(translation: p, rotation: facing(n)))
        }
        // Flat quads: rects (x0, y0, x1, y1) in a local frame (origin, ux, uy), normal ux x uy.
        func quads(_ rects: [V4], origin o: V3, ux: V3, uy: V3, _ mat: MaterialKey) -> Surface {
            var s = Surface(material: mat)
            let n = simd_normalize(simd_cross(ux, uy))
            for r in rects {
                let p = [V2(r.x, r.y), V2(r.z, r.y), V2(r.z, r.w), V2(r.x, r.w)]
                let b = UInt32(s.positions.count)
                for q in p { _ = s.add(o + ux * q.x + uy * q.y, n, q) }
                s.quad(b, b + 1, b + 2, b + 3)
            }
            s.computeTangents()
            return s
        }
        // Seven-segment numerals as rects, glyph box w x h, stroke s, left-bottom at (x, y).
        func numeral(_ value: Int, x: Float, y: Float, w: Float, h: Float, s: Float) -> [V4] {
            let segs: [Character: [V4]] = [
                "a": [V4(0, h - s, w, h)], "b": [V4(w - s, h / 2, w, h)], "c": [V4(w - s, 0, w, h / 2)], "d": [V4(0, 0, w, s)],
                "e": [V4(0, 0, s, h / 2)], "f": [V4(0, h / 2, s, h)], "g": [V4(0, h / 2 - s / 2, w, h / 2 + s / 2)]]
            let map = ["abcdef", "bc", "abged", "abgcd", "fgbc", "afgcd", "afgedc", "abc", "abcdefg", "abcdfg"]
            let digits = String(value).compactMap { $0.wholeNumberValue }
            let total = Float(digits.count) * w + Float(digits.count - 1) * w * 0.45
            var out: [V4] = []
            for (i, d) in digits.enumerated() {
                let ox = x - total / 2 + Float(i) * w * 1.45
                for ch in map[d] { for r in segs[ch]! { out.append(r + V4(ox, y, ox, y)) } }
            }
            return out
        }
        // Handwheel in a local frame with axis +Y (rim at y = 0, dished hub toward +Y), placed at c facing n.
        func handwheel(_ m: inout Model, at c: V3, normal n: V3, spin: Float, l: Int) {
            let q = facing(n) * simd_quatf(angle: spin, axis: V3(0, 1, 0))
            let x = Xform(translation: c, rotation: q)
            let rr: Float = 0.085
            m.add(Prim.torus(major: rr, minor: 0.0085, segments: l == 0 ? 16 : 10, sides: l == 0 ? 5 : 4, material: dark), x)
            m.add(Prim.lathe([V2(0, -0.055), V2(0.011, -0.055), V2(0.011, 0.0), V2(0.024, 0.006), V2(0.025, 0.02), V2(0.016, 0.034), V2(0, 0.036)],
                             segments: l == 0 ? 10 : 6, seamTile: 0.05, material: dark), x)
            for k in 0..<3 {
                let a = Float(k) * 2 * .pi / 3
                let d = V3(cos(a), 0, sin(a))
                m.add(Prim.tube([d * 0.02 + V3(0, 0.016, 0), d * 0.055 + V3(0, 0.006, 0), d * (rr - 0.004)], radii: [0.0065, 0.0058, 0.0055],
                                sides: l == 0 ? 7 : 4, seamTile: 0.03, material: dark, capEnd: false), x)
            }
            // Revolving spinner handle on the rim.
            let a: Float = .pi / 3
            let hp = V3(cos(a) * rr, 0, sin(a) * rr)
            m.add(Prim.lathe([V2(0, 0.012), V2(0.009, 0.013), V2(0.012, 0.02), V2(0.011, 0.07), V2(0.012, 0.078), V2(0.007, 0.086), V2(0, 0.087)],
                             segments: l == 0 ? 8 : 5, seamTile: 0.04, material: yellowPl), Xform(translation: hp).then(x))
            // Centre lock knob.
            if l == 0 {
                m.add(Prim.lathe([V2(0, 0.034), V2(0.017, 0.035), V2(0.019, 0.042), V2(0.016, 0.05), V2(0, 0.052)], segments: 8, seamTile: 0.05, material: black), x)
            }
        }

        // Pivots.
        let bevelPivot = V3(0, T, az)
        let arbor0 = V3(0, T - arborDepth, az)
        let guardPivot = V3(0, T + 0.122, az - 0.205)
        let fx0 = kerf / 2
        let zh = miterRestZ
        let switchPivot = V3(-0.40, T - 0.083, 0.424)
        rig.part("blade-bevel", pivot: bevelPivot, joint: .hinge(axis: V3(0, 0, 1), 0...45, duration: 2.0))
        rig.part("blade-height", parent: "blade-bevel", pivot: arbor0, joint: .slide(axis: V3(0, 1, 0), bladeHeightRange, duration: 1.6))
        rig.part("blade", parent: "blade-height", pivot: arbor0, joint: .hinge(axis: V3(1, 0, 0), 0...360, duration: 0.3))
        rig.part("guard", parent: "blade-bevel", pivot: guardPivot, joint: .hinge(axis: V3(-1, 0, 0), 0...40, duration: 0.4))
        rig.part("fence", pivot: V3(fx0, T, 0), joint: .slide(axis: V3(1, 0, 0), fenceRange, duration: 1.0))
        rig.part("miter-gauge", pivot: V3(xs[0], T, zh), joint: .slide(axis: V3(0, 0, -1), miterGaugeRange, duration: 1.2))
        rig.part("miter-angle", parent: "miter-gauge", pivot: V3(xs[0], T, zh), joint: .hinge(axis: V3(0, 1, 0), -60...60, duration: 0.8))
        rig.part("switch", pivot: switchPivot, joint: .hinge(axis: V3(-1, 0, 0), 0...switchOnValue, duration: 0.25))

        let dustX = rng.float(-0.14 ... -0.08)

        for l in 0..<2 {
            let hi = l == 0
            lodNow = l
            var base = Model(name: Self.id)
            // MARK: plinth and cabinet
            span(&base, V3(-0.272, 0.012, -0.27), V3(0.272, 0.095, 0.27), dark, r: 0.006)
            for sx: Float in [-0.24, 0.24] { for sz: Float in [-0.24, 0.24] {
                slab(&base, V3(sx - 0.02, 0, sz - 0.02), V3(sx + 0.02, 0.0125, sz + 0.02), "rubber")
            }}
            span(&base, V3(-0.245, 0.094, -0.25), V3(0.245, T - 0.052, 0.25), cab, r: 0.006)
            // Top lip flange under the table.
            span(&base, V3(-0.252, T - 0.066, -0.256), V3(0.252, T - 0.051, 0.256), cab, r: 0.003)
            // Left motor access door with louvers and a latch.
            span(&base, V3(-0.2485, 0.30, -0.15), V3(-0.243, 0.66, 0.15), cab, r: 0.004, seg: 1)
            if hi {
                slab(&base, V3(-0.2487, 0.296, -0.152), V3(-0.2458, 0.2985, 0.152), ink)
                slab(&base, V3(-0.2487, 0.6615, -0.152), V3(-0.2458, 0.664, 0.152), ink)
                for i in 0..<6 {
                    let y = 0.50 + Float(i) * 0.022
                    slab(&base, V3(-0.2492, y - 0.006, -0.10), V3(-0.2484, y + 0.006, 0.10), ink)
                    slab(&base, V3(-0.2535, y + 0.001, -0.098), V3(-0.2475, y + 0.007, 0.098), cab)
                }
            }
            base.add(Prim.cylinder(radius: 0.012, height: 0.02, bevel: 0.003, segments: hi ? 14 : 8, bevelSegments: 1, material: black),
                     Xform(translation: V3(-0.248, 0.48, 0.12), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
            // Front: brand plate, bevel scale arc, height handwheel.
            span(&base, V3(-0.21, 0.70, 0.2495), V3(-0.05, 0.76, 0.253), yellowPl, r: 0.002)
            slab(&base, V3(-0.205, 0.718, 0.2525), V3(-0.055, 0.742, 0.2536), black)
            let rS0: Float = 0.205, rS1: Float = 0.24
            var arc: [V2] = []
            let n = hi ? 14 : 6
            for k in 0...n { let a = (-6 + 58 * Float(k) / Float(n)) * .pi / 180; arc.append(V2(rS1 * sin(a), -rS1 * cos(a))) }
            for k in (0...n).reversed() { let a = (-6 + 58 * Float(k) / Float(n)) * .pi / 180; arc.append(V2(rS0 * sin(a), -rS0 * cos(a))) }
            base.add(Prim.extrude(arc, depth: 0.002, bevel: 0.0006, bevelSegments: 1, material: alu), Xform(translation: V3(0, T, 0.2510)))
            var slotS = Surface(material: ink)
            for k in 0...n {
                let a = (-4 + 54 * Float(k) / Float(n)) * .pi / 180
                for r: Float in [0.189, 0.197] { _ = slotS.add(V3(r * sin(a), T - r * cos(a), 0.2502), V3(0, 0, 1), V2(a * r, r)) }
            }
            for k in 0..<UInt32(n) { slotS.quad(k * 2, k * 2 + 2, k * 2 + 3, k * 2 + 1) }
            slotS.computeTangents()
            base.add(slotS)
            if hi {
                var ticks = Surface(material: ink)
                for d in stride(from: 0, through: 45, by: 5) {
                    let a = Float(d) * .pi / 180, long = d % 15 == 0
                    let dir = V3(sin(a), -cos(a), 0), side = V3(cos(a), sin(a), 0)
                    let r0: Float = rS0 + 0.003, r1: Float = long ? rS0 + 0.016 : rS0 + 0.010
                    let w: Float = 0.0006
                    let o = V3(0, T, 0.2522)
                    let p = [o + dir * r0 - side * w, o + dir * r0 + side * w, o + dir * r1 + side * w, o + dir * r1 - side * w]
                    let b = UInt32(ticks.positions.count)
                    for q in p { _ = ticks.add(q, V3(0, 0, 1), V2(q.x, q.y)) }
                    ticks.quad(b, b + 3, b + 2, b + 1)
                    if long {
                        let c = o + dir * (rS0 + 0.0255)
                        let glyphs = numeral(d, x: 0, y: 0, w: 0.0045, h: 0.0075, s: 0.0011)
                        var g = quads(glyphs, origin: .zero, ux: V3(1, 0, 0), uy: V3(0, 1, 0), ink)
                        g = g.transformed(Xform(translation: c - V3(0, 0.00375, 0)))
                        ticks.append(g)
                    }
                }
                ticks.computeTangents()
                base.add(ticks)
            }
            handwheel(&base, at: V3(0, 0.47, 0.305), normal: V3(0, 0, 1), spin: 0.3, l: l)
            // Right side: bevel handwheel and lock knob.
            handwheel(&base, at: V3(0.30, 0.47, 0.05), normal: V3(1, 0, 0), spin: 1.1, l: l)
            base.add(Prim.lathe([V2(0, 0), V2(0.007, 0), V2(0.007, 0.02), V2(0.016, 0.024), V2(0.017, 0.034), V2(0.012, 0.04), V2(0, 0.041)],
                                segments: hi ? 10 : 6, seamTile: 0.05, material: black),
                     Xform(translation: V3(0.245, 0.62, 0.17), rotation: facing(V3(1, 0, 0))))
            // Rear: 4 in dust port.
            let port = Xform(translation: V3(0.08, 0.20, -0.25), rotation: facing(V3(0, 0, -1)))
            base.add(Prim.lathe([V2(0.07, -0.002), V2(0.07, 0.006), V2(0.054, 0.008), V2(0.051, 0.012), V2(0.051, 0.075), V2(0.0535, 0.078),
                                 V2(0.0535, 0.085), V2(0.046, 0.085), V2(0.046, 0.0)], segments: hi ? 12 : 8, seamTile: 0.1, material: dark), port)
            base.add(Prim.cylinder(radius: 0.047, height: 0.002, bevel: 0, segments: hi ? 16 : 8, bevelSegments: 1, material: ink),
                     Xform(translation: V3(0, 0.01, 0)).then(port))
            // Power cord: rear grommet, down to the floor, loose loop, plug.
            let g0 = V3(-0.16, 0.26, -0.25)
            base.add(Prim.cylinder(radius: 0.012, height: 0.012, bevel: 0.003, segments: hi ? 12 : 6, bevelSegments: 1, material: black),
                     Xform(translation: g0, rotation: facing(V3(0, 0, -1))))
            let cr: Float = 0.0045
            let cord = catmull([g0 + V3(0, 0, -0.01), g0 + V3(-0.01, -0.03, -0.06), V3(-0.19, 0.08, -0.33), V3(-0.22, cr, -0.38), V3(-0.30, cr, -0.43),
                                V3(-0.42, cr, -0.40), V3(-0.47, cr, -0.30), V3(-0.40, cr, -0.24)], per: hi ? 4 : 2)
            base.add(Prim.tube(cord, radii: cord.map { _ in cr }, sides: hi ? 6 : 4, seamTile: 0.03, material: "rubber", capEnd: false))
            let pe = cord[cord.count - 1], pd = simd_normalize(cord[cord.count - 1] - cord[cord.count - 2])
            let plugX = Xform(translation: pe + V3(0, 0.012 - cr, 0), rotation: simd_quatf(from: V3(0, 0, 1), to: pd))
            base.add(Prim.roundedBox(V3(0.032, 0.024, 0.045), radius: 0.005, bevelSegments: hi ? 2 : 1, material: black), Xform(translation: V3(0, 0, 0.0225)).then(plugX))
            if hi {
                for sx: Float in [-0.0065, 0.0065] {
                    base.add(cuboid(V3(0.0016, 0.006, 0.018), material: "metal.brass"), Xform(translation: V3(sx, 0, 0.052)).then(plugX))
                }
            }
            // Switch cord from the switch box to the cabinet.
            let sc = catmull([V3(-0.40, T - 0.17, 0.39), V3(-0.39, T - 0.24, 0.37), V3(-0.31, T - 0.20, 0.27), V3(-0.25, T - 0.17, 0.20)], per: hi ? 5 : 2)
            base.add(Prim.tube(sc, radii: sc.map { _ in 0.004 }, sides: hi ? 7 : 4, seamTile: 0.03, material: "rubber", capEnd: false))

            // MARK: cast iron table, slots, throat
            let tTop = T, tBot = T - 0.05
            let sw: Float = 0.0095, sd: Float = 0.0095
            let cx = xs
            let thr: Float = 0.0475, tz0 = az - 0.17, tz1 = az + 0.17
            span(&base, V3(-hw, tBot, -hd), V3(cx[0] - sw, tTop, hd), iron, r: 0.0015)
            span(&base, V3(cx[0] + sw, tBot, -hd), V3(-thr, tTop, hd), iron, r: 0.0015)
            span(&base, V3(thr, tBot, -hd), V3(cx[1] - sw, tTop, hd), iron, r: 0.0015)
            span(&base, V3(cx[1] + sw, tBot, -hd), V3(hw, tTop, hd), iron, r: 0.0015)
            span(&base, V3(-thr - 0.001, tBot, tz1), V3(thr + 0.001, tTop, hd), iron, r: 0.0015)
            span(&base, V3(-thr - 0.001, tBot, -hd), V3(thr + 0.001, tTop, tz0), iron, r: 0.0015)
            // Throat ledge (insert rests on it) and the slot floors.
            slab(&base, V3(-thr - 0.001, tTop - 0.022, tz0 - 0.001), V3(-thr + 0.008, tTop - 0.013, tz1 + 0.001), iron)
            slab(&base, V3(thr - 0.008, tTop - 0.022, tz0 - 0.001), V3(thr + 0.001, tTop - 0.013, tz1 + 0.001), iron)
            for x in cx {
                slab(&base, V3(x - sw - 0.001, tBot, -hd + 0.001), V3(x + sw + 0.001, tTop - sd, hd - 0.001), iron)
                // T-slot undercut shadow line.
                if hi { slab(&base, V3(x - sw - 0.0004, tTop - sd + 0.0002, -hd + 0.002), V3(x + sw + 0.0004, tTop - sd + 0.0008, hd - 0.002), ink) }
            }
            // Zero-clearance insert: two halves around the kerf slot plus end bridges.
            let ins: MaterialKey = "plastic.tool:C4241A"
            let iy0 = tTop - 0.0128, iy1 = tTop - 0.0002
            let ks: Float = 0.0018
            span(&base, V3(-thr + 0.0005, iy0, tz0 + 0.0005), V3(-ks, iy1, tz1 - 0.0005), ins, r: 0.0012)
            span(&base, V3(ks, iy0, tz0 + 0.0005), V3(thr - 0.0005, iy1, tz1 - 0.0005), ins, r: 0.0012)
            slab(&base, V3(-0.004, iy0, az + 0.135), V3(0.004, iy1 - 0.0002, tz1 - 0.0005), ins)
            slab(&base, V3(-0.004, iy0, tz0 + 0.0005), V3(0.004, iy1 - 0.0002, az - 0.162), ins)
            if hi {
                // Finger hole, leveling screws, sawdust packed in the kerf ends.
                base.add(Prim.cylinder(radius: 0.011, height: 0.0004, bevel: 0.0001, segments: 16, bevelSegments: 1, material: ink),
                         Xform(translation: V3(-0.022, iy1 - 0.00005, az + 0.12)))
                for (x, z) in [(Float(-0.035), tz0 + 0.02), (0.035, tz0 + 0.02), (-0.035, tz1 - 0.02), (0.035, tz1 - 0.02)] {
                    base.add(Prim.cylinder(radius: 0.003, height: 0.0004, bevel: 0.0001, segments: 8, bevelSegments: 1, material: ink),
                             Xform(translation: V3(x, iy1 - 0.00005, z)))
                }
            }
            // Wings: ground top plate, skirts and ribs.
            for side: Float in [-1, 1] {
                let x0 = side * (hw + 0.001), x1 = side * (hw + wingWidth)
                let lo = min(x0, x1), hiX = max(x0, x1)
                span(&base, V3(lo, T - 0.012, -hd), V3(hiX, T, hd), iron, r: 0.0015)
                slab(&base, V3(lo + 0.002, tBot, hd - 0.009), V3(hiX - 0.002, T - 0.011, hd - 0.001), dark)
                slab(&base, V3(lo + 0.002, tBot, -hd + 0.001), V3(hiX - 0.002, T - 0.011, -hd + 0.009), dark)
                let ox = side > 0 ? hiX - 0.009 : lo + 0.001
                slab(&base, V3(ox, tBot, -hd + 0.002), V3(ox + 0.008, T - 0.011, hd - 0.002), dark)
                let ix = side > 0 ? lo : hiX - 0.008
                slab(&base, V3(ix, tBot, -hd + 0.002), V3(ix + 0.008, T - 0.011, hd - 0.002), dark)
                if hi {
                    for rz: Float in [-0.115, 0.115] { slab(&base, V3(lo + 0.008, T - 0.045, rz - 0.003), V3(hiX - 0.008, T - 0.011, rz + 0.003), dark) }
                    slab(&base, V3((lo + hiX) / 2 - 0.003, T - 0.045, -hd + 0.009), V3((lo + hiX) / 2 + 0.003, T - 0.011, hd - 0.009), dark)
                }
            }

            // MARK: rails
            let railX0: Float = -0.58, railX1: Float = 0.90
            // Front angle iron and the rail tube.
            slab(&base, V3(railX0 + 0.01, T - 0.072, hd + 0.001), V3(railX1 - 0.01, T - 0.023, hd + 0.007), dark)
            span(&base, V3(railX0, T - 0.072, 0.352), V3(railX1, T - 0.0205, 0.402), dark, r: 0.004)
            for xe in [railX0 - 0.004, railX1 + 0.004] {
                slab(&base, V3(xe - 0.005, T - 0.0705, 0.3535), V3(xe + 0.005, T - 0.022, 0.4005), black)
            }
            if hi {
                for x: Float in [-0.45, -0.15, 0.15, 0.45, 0.78] { bolt(&base, at: V3(x, T - 0.046, 0.402), normal: V3(0, 0, 1), size: 0.011) }
                // Rip scale tape on the tube top: quarter-inch ticks, numbered inches, zero at the blade's right side.
                let ty = T - 0.0205 + 0.0006
                let x0s: Float = -0.05, x1s: Float = 0.885
                span(&base, V3(x0s, T - 0.0215, 0.357), V3(x1s, ty, 0.381), "plastic.matte:F2E7B6", r: 0.0003)
                var rects: [V4] = []
                let inch: Float = 0.0254
                var q = -8
                while true {
                    let x = fx0 + Float(q) * inch / 4
                    if x > x1s - 0.004 { break }
                    if x > x0s + 0.003 {
                        if q % 2 != 0 { q += 1; continue }
                        let len: Float = q % 4 == 0 ? 0.0105 : 0.0068
                        let w: Float = q % 4 == 0 ? 0.00045 : 0.0003
                        rects.append(V4(x - w, 0.0225 - len, x + w, 0.0225))
                        if q % 4 == 0 && q >= 0 { rects += numeral(q / 4, x: x, y: 0.0025, w: 0.0028, h: 0.0062, s: 0.0007) }
                    }
                    q += 1
                }
                // Local y runs from the tape's front edge toward the rear (-Z) so numerals read upright from the operator side.
                base.add(quads(rects, origin: V3(0, ty + 0.0001, 0.3805), ux: V3(1, 0, 0), uy: V3(0, 0, -1), ink))
            }
            // Rear angle rail.
            span(&base, V3(railX0 + 0.02, T - 0.065, -hd - 0.007), V3(railX1, T - 0.013, -hd - 0.001), dark, r: 0.0015)
            span(&base, V3(railX0 + 0.02, T - 0.018, -0.385), V3(railX1, T - 0.013, -hd - 0.001), dark, r: 0.0015)

            // MARK: sawdust
            if hi {
                let dust: MaterialKey = "wood.sawdust"
                var d1 = Prim.superellipsoid(V3(0.09, 0.010, 0.05), exponent: 2.3, subdivisions: 2, material: dust)
                d1.displace { p, _ in 0.0015 * sin(p.x * 140) * cos(p.z * 170) }
                base.add(d1, Xform(translation: V3(dustX, T - 0.002, az - 0.255), rotation: simd_quatf(degrees: 20, axis: V3(0, 1, 0))))
                for (k, c) in [V3(0.03, 0, 0.32), V3(0.13, 0, 0.35), V3(-0.05, 0, 0.36)].enumerated() {
                    let sz = V3(0.11, 0.012, 0.07) * (k == 0 ? 1 : 0.6)
                    var d = Prim.superellipsoid(sz, exponent: 2.2, subdivisions: 3, material: dust)
                    d.displace { p, _ in 0.002 * sin(p.x * 120 + Float(k)) * cos(p.z * 140) }
                    base.add(d, Xform(translation: c + V3(0, -0.002, 0), rotation: simd_quatf(degrees: Float(k) * 50 + 10, axis: V3(0, 1, 0))))
                }
                // Rust ring from a can left on the left wing, and a few drips.
                var ringR = Surface(material: "metal.table-saw-rust")
                let rc = V3(-0.40 + dustX * 0.2, T + 0.0002, -0.12)
                for k in 0...20 {
                    let a = Float(k) / 20 * 2 * .pi
                    for r: Float in [0.041, 0.0465] { _ = ringR.add(rc + V3(r * cos(a), 0, -r * sin(a)), V3(0, 1, 0), V2(r * cos(a), r * sin(a))) }
                }
                for k in 0..<UInt32(20) { ringR.quad(k * 2, k * 2 + 1, k * 2 + 3, k * 2 + 2) }
                ringR.computeTangents()
                base.add(ringR)
                for (x, z, r) in [(Float(-0.33), Float(-0.05), Float(0.006)), (-0.35, -0.02, 0.004), (-0.30, 0.02, 0.003)] {
                    base.add(Prim.cylinder(radius: r, height: 0.0002, bevel: 0, segments: 8, bevelSegments: 1, material: "metal.table-saw-rust"),
                             Xform(translation: V3(x, T, z)))
                }
            }
            rig.base[l] = base

            // MARK: blade-bevel: pointer and guard support
            var bev = Model(name: "blade-bevel")
            let ptr: [V2] = [V2(-0.004, -0.186), V2(0.004, -0.186), V2(0.0012, -0.222), V2(-0.0012, -0.222)]
            bev.add(Prim.extrude(ptr, depth: 0.0015, bevel: 0.0003, bevelSegments: 1, material: "plastic.tool:C4241A"), Xform(translation: V3(0, T, 0.2535)))
            bev.add(Prim.cylinder(radius: 0.0045, height: 0.004, bevel: 0.001, segments: hi ? 10 : 6, bevelSegments: 1, material: steel),
                    Xform(translation: V3(0, T - 0.193, 0.2505), rotation: facing(V3(0, 0, 1))))
            // Rear support: bracket under the table, post behind the rear rail, arm forward to the hood pivot.
            let pz: Float = -0.405
            slab(&bev, V3(-0.009, T - 0.108, pz - 0.006), V3(0.009, T - 0.092, -0.262), dark)
            span(&bev, V3(-0.009, T - 0.108, pz - 0.008), V3(0.009, guardPivot.y + 0.012, pz + 0.008), dark, r: 0.004)
            span(&bev, V3(-0.008, guardPivot.y - 0.002, pz), V3(0.008, guardPivot.y + 0.012, guardPivot.z - 0.004), dark, r: 0.004)
            bev.add(Prim.cylinder(radius: 0.009, height: 0.034, bevel: 0.002, segments: hi ? 14 : 8, bevelSegments: 1, material: steel),
                    Xform(translation: guardPivot + V3(-0.017, 0, 0), rotation: facing(V3(1, 0, 0))))
            rig.set(bev, part: "blade-bevel", lod: l)

            // MARK: blade-height: riving knife
            var ht = Model(name: "blade-height")
            let ri = R + 0.005
            var knife: [V2] = []
            let kn = hi ? 7 : 4
            for k in 0...kn { let a = (24 + 52 * Float(k) / Float(kn)) * .pi / 180; knife.append(V2(-ri * sin(a), ri * cos(a))) }
            knife += [V2(-0.08, -0.02), V2(-0.11, -0.045), V2(-0.175, 0.0)]
            for k in 0...kn {
                let t = Float(k) / Float(kn), a = (66 - 32 * t) * .pi / 180, r = ri + 0.034 - 0.024 * t * t
                knife.append(V2(-r * sin(a), r * cos(a)))
            }
            knife.append(V2(-0.064, 0.1225))
            let knifeS = Prim.extrude(Shape2D.rounded(knife, radius: 0.003, segments: 1), depth: 0.0025, bevel: 0.0005, bevelSegments: 1, material: "metal.stainless")
            ht.add(knifeS, Xform(translation: arbor0, rotation: simd_quatf(degrees: -90, axis: V3(0, 1, 0))))
            rig.set(ht, part: "blade-height", lod: l)

            // MARK: blade
            var bl = Model(name: "blade")
            let N = 40, dA = 2 * Float.pi / Float(N)
            // Blade 2D: (a, b) = (z, y) around the arbor; rotation direction is decreasing angle (top moves +Z).
            func polar(_ ang: Float, _ r: Float) -> V2 { V2(r * cos(ang), r * sin(ang)) }
            let toothPts: [(Float, Float)] = hi
                ? [(0.0, -0.0085), (0.10, -0.0148), (0.205, -0.0105), (0.215, -0.0068), (0.355, -0.0068),
                   (0.36, -0.0012), (0.42, -0.0013)]
                : [(0.0, -0.0085), (0.10, -0.0148), (0.205, -0.0105), (0.23, 0.0), (0.42, -0.0013)]
            var outline: [V2] = []
            for i in 0..<N {
                let a0 = Float(i) * dA
                for (j, tp) in toothPts.enumerated() {
                    outline.append(polar(a0 + tp.0 * dA, R + tp.1))
                    // Expansion slot from the gullet bottom of every tenth tooth.
                    if hi && i % 10 == 0 && j == 1 {
                        let ga = a0 + 0.10 * dA
                        let d = V2(cos(ga), sin(ga)), p = V2(-sin(ga), cos(ga))
                        let r0 = R - 0.0148, r1 = R - 0.040, sw2: Float = 0.0006, hr: Float = 0.0024
                        outline.removeLast()
                        outline.append(d * r0 - p * sw2)
                        outline.append(d * (r1 + hr * 0.9) - p * sw2)
                        let c = d * r1
                        for k in 0...8 {
                            let t = Float(k) / 8 * (.pi + 0.5) - 0.25
                            // circle around c starting at -p side, going round the far end
                            let ang = atan2(-p.y, -p.x) - t
                            outline.append(c + V2(cos(ang), sin(ang)) * hr)
                        }
                        outline.append(d * (r1 + hr * 0.9) + p * sw2)
                        outline.append(d * r0 + p * sw2)
                    }
                }
            }
            outline = Shape2D.deduped(outline)
            let plate = Prim.extrude(outline, depth: 0.0022, bevel: 0, bevelSegments: 0, material: "metal.sawblade")
            let toBlade = simd_quatf(degrees: -90, axis: V3(0, 1, 0))   // outline (z, y), depth -> x
            // Outline x is z: rotate about Y so outline x -> +Z.
            let bx = Xform(translation: arbor0, rotation: toBlade)
            bl.add(plate, bx)
            // Carbide tips (ATB, alternating top bevel).
            var tips = Surface(material: "metal.carbide")
            for i in 0..<N {
                let a0 = Float(i) * dA
                let ang0 = a0 + (hi ? 0.215 : 0.21) * dA, ang1 = a0 + 0.36 * dA
                let q: [V2] = [polar(ang0 - 0.04 * dA, R - 0.0069), polar(ang1, R - 0.0069), polar(ang1, R - 0.0006), polar(ang0 - 0.06 * dA, R + 0.0001)]
                var tip = Prim.extrude(q, depth: kerf, bevel: 0, bevelSegments: 0, material: "metal.carbide")
                let sgn: Float = i % 2 == 0 ? 1 : -1
                let k2 = kerf
                tip.deform { p in
                    let r = simd_length(V2(p.x, p.y))
                    guard r > R - 0.0015 else { return p }
                    let drop = (0.5 + sgn * p.z / k2) * 0.0008
                    let s = (r - drop) / r
                    return V3(p.x * s, p.y * s, p.z)
                }
                tips.append(tip)
            }
            tips.computeTangents()
            bl.add(tips, bx)
            // Printed label ring, both faces.
            for side: Float in [-1, 1] {
                var ring = Surface(material: black)
                let rn = hi ? 24 : 12
                for k in 0...rn {
                    let a = Float(k) / Float(rn) * 2 * .pi
                    for r: Float in [0.042, 0.074] { _ = ring.add(V3(side * 0.00112, r * sin(a), r * cos(a)), V3(side, 0, 0), V2(a * r, r)) }
                }
                for k in 0..<UInt32(rn) {
                    let b = k * 2
                    if side > 0 { ring.quad(b, b + 2, b + 3, b + 1) } else { ring.quad(b, b + 1, b + 3, b + 2) }
                }
                ring.computeTangents()
                bl.add(ring, Xform(translation: arbor0))
            }
            rig.set(bl, part: "blade", lod: l)

            // MARK: guard (clear leaves, spine, pawls)
            var gd = Model(name: "guard")
            let gy = T, gp = guardPivot
            // Leaf outline in (z, y) relative to the table, rear sloped up toward the pivot.
            let leaf: [V2] = Shape2D.rounded([V2(gp.z + 0.004, gy + 0.07), V2(gp.z + 0.09, gy + 0.004), V2(az + 0.16, gy + 0.004), V2(az + 0.20, gy + 0.03),
                                              V2(az + 0.19, gy + 0.112), V2(gp.z + 0.004, gy + 0.112)], radius: 0.012, segments: 1)
            for side: Float in [-1, 1] {
                let lf = Prim.extrude(leaf, depth: 0.003, bevel: 0.0008, bevelSegments: 1, material: "plastic.clear")
                gd.add(lf, Xform(translation: V3(side * 0.0395, 0, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 1, 0))))
                // Yellow edge band along the leaf top and a warning label.
                span(&gd, V3(side * 0.0395 - 0.0022, gy + 0.104, gp.z + 0.01), V3(side * 0.0395 + 0.0022, gy + 0.114, az + 0.17), yellowPl, r: 0.0012)
                if hi {
                    span(&gd, V3(side * 0.0395 - 0.0018 * side - 0.0002, gy + 0.072, az + 0.02), V3(side * 0.0395 + 0.0018 * side + 0.0002, gy + 0.092, az + 0.09),
                         "plastic.matte:F2B705", r: 0.0005)
                }
            }
            // Spine and hinge knuckle.
            span(&gd, V3(-0.04, gy + 0.112, gp.z - 0.006), V3(0.04, gy + 0.122, az + 0.18), black, r: 0.004)
            span(&gd, V3(-0.0095, gy + 0.112, gp.z - 0.012), V3(0.0095, gy + 0.132, gp.z + 0.03), black, r: 0.005)
            if hi {
                slab(&gd, V3(-0.03, gy + 0.1222, az - 0.02), V3(0.03, gy + 0.1226, az + 0.06), "plastic.matte:F2B705")
                slab(&gd, V3(-0.028, gy + 0.1224, az - 0.012), V3(0.028, gy + 0.1228, az - 0.004), black)
                slab(&gd, V3(-0.028, gy + 0.1224, az + 0.044), V3(0.028, gy + 0.1228, az + 0.052), black)
            }
            // Anti-kickback pawls: pin under the spine, toothed tips trailing toward -Z, resting on the table.
            let pinZ = gp.z + 0.075, pinY = gy + 0.085
            var pawl: [V2] = [V2(pinZ + 0.012, pinY + 0.008), V2(pinZ - 0.01, pinY + 0.01), V2(pinZ - 0.045, gy + 0.03)]
            let teeth = hi ? 5 : 2
            for k in 0...teeth {
                let t = Float(k) / Float(teeth)
                pawl.append(V2(pinZ - 0.05 + t * 0.03, gy + 0.0025 + (k % 2 == 0 ? 0 : 0.003)))
            }
            pawl.append(V2(pinZ + 0.004, gy + 0.03))
            for side: Float in [-1, 1] {
                gd.add(Prim.extrude(Shape2D.deduped(pawl), depth: 0.003, bevel: 0.0006, bevelSegments: 1, material: steel),
                       Xform(translation: V3(side * 0.0068, 0, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 1, 0))))
            }
            gd.add(Prim.cylinder(radius: 0.003, height: 0.022, bevel: 0.0008, segments: hi ? 10 : 6, bevelSegments: 1, material: steel),
                   Xform(translation: V3(-0.011, pinY, pinZ), rotation: facing(V3(1, 0, 0))))
            span(&gd, V3(-0.006, pinY - 0.004, pinZ - 0.006), V3(0.006, gy + 0.112, pinZ + 0.006), black, r: 0.002)
            rig.set(gd, part: "guard", lod: l)

            // MARK: fence
            var fe = Model(name: "fence")
            let fz0: Float = -0.383, fz1: Float = 0.352
            let fy0 = T + 0.0015, fy1 = T + 0.068
            // Aluminum faces with a T-track groove, steel core tube.
            for (a, b) in [(fx0, fx0 + 0.012), (fx0 + 0.062, fx0 + 0.074)] {
                span(&fe, V3(a, fy0, fz0 + 0.004), V3(b, T + 0.040, fz1 - 0.008), alu, r: 0.0015)
                span(&fe, V3(a, T + 0.046, fz0 + 0.004), V3(b, fy1, fz1 - 0.008), alu, r: 0.0015)
            }
            slab(&fe, V3(fx0 + 0.004, T + 0.039, fz0 + 0.006), V3(fx0 + 0.07, T + 0.047, fz1 - 0.01), ink)
            span(&fe, V3(fx0 + 0.011, T + 0.004, fz0), V3(fx0 + 0.063, T + 0.064, fz1), dark, r: 0.003)
            span(&fe, V3(fx0 + 0.010, T + 0.003, fz0 - 0.006), V3(fx0 + 0.064, T + 0.065, fz0 + 0.002), black, r: 0.004)
            span(&fe, V3(fx0 + 0.015, T - 0.012, -0.386), V3(fx0 + 0.06, T + 0.004, -0.356), black, r: 0.003)
            // Head: yellow block riding the rail tube, front lip, cam lever, cursor.
            span(&fe, V3(fx0 + 0.012, T - 0.019, 0.346), V3(fx0 + 0.104, T + 0.03, 0.434), accent, r: 0.008)
            span(&fe, V3(fx0 + 0.012, T - 0.078, 0.407), V3(fx0 + 0.104, T - 0.016, 0.434), accent, r: 0.006)
            slab(&fe, V3(fx0 + 0.011, T + 0.002, 0.30), V3(fx0 + 0.063, T + 0.064, 0.352), dark)
            let lp = V3(fx0 + 0.058, T + 0.018, 0.437)
            fe.add(Prim.cylinder(radius: 0.008, height: 0.06, bevel: 0.0015, segments: hi ? 12 : 6, bevelSegments: 1, material: steel),
                   Xform(translation: lp + V3(-0.03, 0, 0), rotation: facing(V3(1, 0, 0))))
            let lever = [lp + V3(0, 0, 0.004), lp + V3(0, -0.03, 0.022), lp + V3(0, -0.075, 0.03)]
            fe.add(Prim.tube(lever, radii: [0.0065, 0.006, 0.0055], sides: hi ? 8 : 5, seamTile: 0.03, material: steel, capEnd: false))
            fe.add(Prim.superellipsoid(V3(0.024, 0.042, 0.024), exponent: 2.4, subdivisions: hi ? 3 : 2, material: black),
                   Xform(translation: lp + V3(0, -0.092, 0.031)))
            span(&fe, V3(fx0 - 0.026, T - 0.0165, 0.355), V3(fx0 + 0.014, T - 0.0135, 0.388), "plastic.clear", r: 0.001)
            if hi {
                span(&fe, V3(fx0 - 0.0004, T - 0.0134, 0.356), V3(fx0 + 0.0004, T - 0.0131, 0.387), "plastic.tool:C4241A", r: 0.0001)
                for z: Float in [0.36, 0.383] {
                    fe.add(Prim.cylinder(radius: 0.0025, height: 0.0015, bevel: 0.0004, segments: 8, bevelSegments: 1, material: steel),
                           Xform(translation: V3(fx0 + 0.008, T - 0.0135, z)))
                }
            }
            rig.set(fe, part: "fence", lod: l)

            // MARK: miter gauge
            var mg = Model(name: "miter-gauge")
            let x0g = xs[0]
            span(&mg, V3(x0g - 0.0092, T - 0.0092, zh - 0.43), V3(x0g + 0.0092, T - 0.0004, zh + 0.03), steel, r: 0.0015)
            let ptrS = Prim.extrude([V2(-0.004, 0), V2(0.004, 0), V2(0.0015, -0.078), V2(-0.0015, -0.078)], depth: 0.0018, bevel: 0.0004, bevelSegments: 1,
                                    material: "plastic.tool:C4241A")
            mg.add(ptrS, Xform(translation: V3(x0g, T + 0.0175, zh), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
            mg.add(Prim.cylinder(radius: 0.007, height: 0.004, bevel: 0.001, segments: hi ? 12 : 6, bevelSegments: 1, material: steel),
                   Xform(translation: V3(x0g, T + 0.0175, zh)))
            rig.set(mg, part: "miter-gauge", lod: l)

            var ma = Model(name: "miter-angle")
            var head: [V2] = [V2(-0.076, -0.0085), V2(0.076, -0.0085)]
            let hn = hi ? 12 : 6
            for k in 0...hn { let a = Float(k) / Float(hn) * .pi; head.append(V2(0.074 * cos(a), 0.074 * sin(a) * 1.0)) }
            // Outline (x, w): w > 0 maps to +Z after the rotation below.
            let headS = Prim.extrude(Shape2D.rounded(Shape2D.deduped(head), radius: 0.003, segments: 2), depth: 0.0155, bevel: 0.0015,
                                     bevelSegments: 1, material: "metal.diecast")
            ma.add(headS, Xform(translation: V3(x0g, T + 0.0083, zh), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            // Fence face bar toward the blade.
            span(&ma, V3(x0g - 0.12, T + 0.001, zh - 0.0085 - 0.012), V3(x0g + 0.125, T + 0.046, zh - 0.0085), alu, r: 0.002)
            slab(&ma, V3(x0g - 0.119, T + 0.021, zh - 0.0085 - 0.0122), V3(x0g + 0.124, T + 0.025, zh - 0.0085 - 0.0115), ink)
            // Lock knob.
            ma.add(Prim.lathe([V2(0, 0), V2(0.005, 0), V2(0.005, 0.03), V2(0.016, 0.034), V2(0.019, 0.045), V2(0.015, 0.056), V2(0, 0.058)],
                              segments: hi ? 10 : 6, seamTile: 0.05, material: black), Xform(translation: V3(x0g + 0.03, T + 0.016, zh + 0.04)))
            if hi {
                var t = Surface(material: ink)
                for d in stride(from: -60, through: 60, by: 5) {
                    let a = Float(d) * .pi / 180, long = d % 15 == 0
                    let dir = V3(sin(a), 0, cos(a)), side = V3(cos(a), 0, -sin(a))
                    let r0: Float = long ? 0.058 : 0.063, r1: Float = 0.071, w: Float = 0.0004
                    let o = V3(x0g, T + 0.0163, zh)
                    let p = [o + dir * r0 - side * w, o + dir * r0 + side * w, o + dir * r1 + side * w, o + dir * r1 - side * w]
                    let b = UInt32(t.positions.count)
                    for q in p { _ = t.add(q, V3(0, 1, 0), V2(q.x, q.z)) }
                    t.quad(b, b + 3, b + 2, b + 1)
                    if long {
                        let c = o + dir * 0.050
                        var g = quads(numeral(abs(d), x: 0, y: -0.0025, w: 0.0026, h: 0.005, s: 0.0007), origin: .zero, ux: V3(1, 0, 0), uy: V3(0, 0, -1), ink)
                        g = g.transformed(Xform(translation: c))
                        t.append(g)
                    }
                }
                t.computeTangents()
                ma.add(t)
            }
            rig.set(ma, part: "miter-angle", lod: l)

            // MARK: switch box (static) and paddle
            span(&base, V3(-0.447, T - 0.172, 0.352), V3(-0.353, T - 0.074, 0.418), yellowPl, r: 0.006)
            rig.base[l] = base
            rig.base[l].add(Prim.cylinder(radius: 0.012, height: 0.008, bevel: 0.002, segments: hi ? 14 : 8, bevelSegments: 1, material: "plastic.tool:2E9E3E"),
                            Xform(translation: V3(-0.40, T - 0.112, 0.417), rotation: facing(V3(0, 0, 1))))
            var sw0 = Model(name: "switch")
            let pad = Shape2D.roundedRect(0.084, 0.078, radius: 0.012, segments: hi ? 4 : 2)
            sw0.add(Prim.extrude(pad, depth: 0.008, bevel: 0.002, bevelSegments: hi ? 2 : 1, material: "plastic.tool:C4241A"),
                    Xform(translation: switchPivot + V3(0, -0.042, 0.005)))
            if hi {
                sw0.add(Prim.extrude(Shape2D.roundedRect(0.07, 0.03, radius: 0.006, segments: 3), depth: 0.0016, bevel: 0.0005, bevelSegments: 1,
                                     material: "plastic.tool:A81E15"), Xform(translation: switchPivot + V3(0, -0.05, 0.0095)))
            }
            sw0.add(Prim.cylinder(radius: 0.005, height: 0.092, bevel: 0.001, segments: hi ? 10 : 6, bevelSegments: 1, material: steel),
                    Xform(translation: switchPivot + V3(-0.046, 0, 0), rotation: facing(V3(1, 0, 0))))
            rig.set(sw0, part: "switch", lod: l)
        }

        groundAO(&rig, height: 0.12, floor: 0.5)
        let raised = raisedHeight
        rig.states = [
            RigState("idle", ["fence": restFence]),
            RigState("raised", ["fence": restFence, "blade-height": raised]),
            RigState("running", ["fence": restFence, "blade-height": raised, "switch": switchOnValue]),
            RigState("bevel-45", ["fence": restFence, "blade-bevel": 45, "blade-height": 0.05, "guard": 25]),
            RigState("crosscut", ["fence": restFence, "blade-height": raised, "miter-gauge": 0.30]),
        ]
        return rig
    }
}
