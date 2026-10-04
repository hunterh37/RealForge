import simd
import Foundation

/// Mayo instrument stand (Pedigo / Blickman class): 25 mm stainless tube U-base on four 50 mm casters, 38 mm
/// outer column with a lock collar and black four-lobe knob, 30 mm inner column that telescopes 400 mm, a
/// cantilever bracket and rod frame carrying a removable 320 x 490 x 20 mm stainless tray with a rolled rim.
/// A blue SMS drape lines the tray and hangs over the front; on it lie a curved Mayo scissors, three
/// hemostats, a needle holder, tissue forceps, a #3 scalpel and a towel clip pinning the drape edge.
/// The column slides (low 0.92 m, high 1.32 m tray height); the knob turns to unlock.
public struct MayoStand: RealArticulated {
    public static let id = "mayo-stand"
    public static let summary = "Mayo instrument stand: stainless U-base on casters, telescoping column with a lock knob, draped stainless tray with instruments."
    public static let tags = ["prop", "medical", "surgical", "articulated", "metal", "furniture"]
    public static let budget = 10000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 22, distance: 1.6, studio: true)

    /// Tray size (x width, z length) and depth (m).
    public var tray = V2(0.32, 0.49)
    public var trayDepth: Float = 0.02
    /// Column travel (m) from the low to the high position.
    public var travel: Float = 0.4
    /// Drape material key.
    public var drape: MaterialKey = "drape.surgical"
    /// Front drape overhang (m).
    public var overhang: Float = 0.17
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [6])
        let steel: MaterialKey = "metal.casework", polished: MaterialKey = "metal.surgical-mirror"
        let black: MaterialKey = "plastic.black"
        let casterH: Float = 0.068, tubeR: Float = 0.0127
        let yb = casterH + tubeR                    // base tube center height
        let bx: Float = 0.21, zf: Float = 0.27, zb: Float = -0.24, bend: Float = 0.07
        let colZ = zb, colX: Float = 0

        // MARK: base
        for l in 0..<2 {
            var m = Model(name: Self.id)
            // U-base: one bent tube, open toward +Z, with plugged ends.
            var path: [V3] = [V3(-bx, yb, zf), V3(-bx, yb, zb + bend)]
            let arcN = l == 0 ? 6 : 3
            for k in 1...arcN { let a = Float(k) / Float(arcN) * .pi / 2; path.append(V3(-bx + bend - bend * cos(a), yb, zb + bend - bend * sin(a))) }
            for k in 0...arcN { let a = Float(k) / Float(arcN) * .pi / 2; path.append(V3(bx - bend + bend * sin(a), yb, zb + bend - bend * cos(a))) }
            path.append(V3(bx, yb, zf))
            m.add(Prim.tube(path, radii: path.map { _ in tubeR }, sides: l == 0 ? 14 : 8, seamTile: 0.08, material: steel))
            for sx: Float in [-1, 1] {
                m.add(Prim.cylinder(radius: tubeR + 0.0008, height: 0.012, bevel: 0.003, segments: l == 0 ? 14 : 8, bevelSegments: 1, material: black),
                      Xform(translation: V3(sx * bx, yb, zf - 0.004), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            }
            // Casters under the four corners (front pair under the plugs, back pair on the bends).
            for sx: Float in [-1, 1] {
                theatreCaster(&m, at: V3(sx * bx, 0, zf - 0.03), height: yb - tubeR, wheelRadius: 0.025, width: 0.02, yaw: 180, detail: l)
                theatreCaster(&m, at: V3(sx * (bx - 0.02), 0, zb + 0.02), height: yb - tubeR, wheelRadius: 0.025, width: 0.02, yaw: 180, detail: l)
            }
            // Column socket welded on the back bar, outer column, lock collar.
            m.add(Prim.cylinder(radius: 0.028, height: 0.05, bevel: 0.004, segments: l == 0 ? 24 : 12, bevelSegments: l == 0 ? 2 : 1, material: steel),
                  Xform(translation: V3(colX, yb - 0.022, colZ)))
            m.add(Prim.cylinder(radius: 0.019, height: 0.6 - yb, bevel: 0.001, segments: l == 0 ? 24 : 12, bevelSegments: 1, material: polished),
                  Xform(translation: V3(colX, yb, colZ)))
            m.add(Prim.lathe([V2(0.0185, 0.585), V2(0.025, 0.588), V2(0.0255, 0.592), V2(0.0255, 0.618), V2(0.025, 0.622), V2(0.0165, 0.624)],
                             segments: l == 0 ? 24 : 12, material: steel), Xform(translation: V3(colX, 0, colZ)))
            // Ownership tape wrapped on the outer column ("OR 4").
            m.add(Prim.lathe([V2(0.0194, 0.5), V2(0.0194, 0.535)], segments: l == 0 ? 24 : 12, material: "paper.sheet:ECE9DC"), Xform(translation: V3(colX, 0, colZ)))
            // Knob boss on +X.
            m.add(Prim.cylinder(radius: 0.008, height: 0.012, bevel: 0.001, segments: l == 0 ? 12 : 8, bevelSegments: 1, material: steel),
                  Xform(translation: V3(colX + 0.024, 0.605, colZ), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
            rig.base[l] = m
        }

        // MARK: knob (turns about X to loosen the collar)
        let kx = colX + 0.036
        rig.part("knob", pivot: V3(kx, 0.605, colZ), joint: .hinge(axis: V3(1, 0, 0), -270...0, duration: 0.5))
        for l in 0..<2 {
            let lobes = Shape2D.rounded((0..<8).map { k -> V2 in
                let a = Float(k) * .pi / 4 + .pi / 8
                return V2(cos(a), sin(a)) * (k % 2 == 0 ? 0.022 : 0.012)
            }, radius: 0.005, segments: l == 0 ? 3 : 1)
            rig.add(Prim.extrude(lobes, depth: 0.014, bevel: 0.003, bevelSegments: l == 0 ? 2 : 1, material: black),
                    Xform(translation: V3(kx + 0.007, 0.605, colZ), rotation: simd_quatf(degrees: 90, axis: V3(0, 1, 0))), to: "knob", lods: l...l)
        }
        rig.add(Prim.cylinder(radius: 0.005, height: 0.008, bevel: 0.001, segments: 10, bevelSegments: 1, material: steel),
                Xform(translation: V3(kx + 0.014, 0.605, colZ), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))), to: "knob", lods: 0...0)

        // MARK: column (inner tube, bracket, tray, drape, instruments)
        rig.part("column", pivot: V3(colX, 0.6, colZ), joint: .slide(axis: V3(0, 1, 0), 0...travel, duration: 1.2))
        let innerTop: Float = 0.865
        for l in 0..<2 {
            rig.add(Prim.cylinder(radius: 0.0148, height: innerTop - 0.17, bevel: 0.001, segments: l == 0 ? 20 : 10, bevelSegments: 1, material: polished),
                    Xform(translation: V3(colX, 0.17, colZ)), to: "column", lods: l...l)
        }
        // Bracket: clamp block on the column top, flat bar forward under the tray.
        let ty0 = innerTop + 0.02                  // tray bottom
        let hx = tray.x / 2, hz = tray.y / 2, tzc = colZ + 0.035 + hz
        for l in 0..<2 {
            rig.add(Prim.roundedBox(V3(0.044, 0.03, 0.05), radius: 0.006, bevelSegments: 2 - l, material: steel),
                    Xform(translation: V3(colX, innerTop - 0.005, colZ + 0.008)), to: "column", lods: l...l)
            rig.add(Prim.roundedBox(V3(0.03, 0.008, 0.11), radius: 0.003, bevelSegments: 1, material: steel),
                    Xform(translation: V3(colX, ty0 - 0.009, colZ + 0.06)), to: "column", lods: l...l)
        }
        // Rod frame the tray rim rests on.
        let fr = Shape2D.roundedRect(tray.x + 0.006, tray.y + 0.006, radius: 0.03, segments: 4).map { V3($0.x, ty0 + trayDepth - 0.012, tzc - $0.y) }
        rig.add(Prim.sweep(Shape2D.circle(0.0045, segments: 8), along: fr, closedPath: true, caps: false, material: steel), to: "column", lods: 0...0)
        rig.add(Prim.sweep(Shape2D.circle(0.0045, segments: 5), along: fr, closedPath: true, caps: false, material: steel), to: "column", lods: 1...1)
        for sx: Float in [-1, 1] {
            // Struts from the bracket bar out to the rear frame rod, below the pan.
            let fy = ty0 + trayDepth - 0.012, fz = tzc - hz - 0.003
            rig.add(Prim.tube([V3(sx * 0.01, ty0 - 0.009, colZ + 0.03), V3(sx * hx * 0.45, ty0 - 0.006, fz - 0.004), V3(sx * hx * 0.7, fy, fz)],
                              radii: [0.0042, 0.0042, 0.0042], sides: 8, seamTile: 0.05, material: steel), to: "column")
        }
        // Tray: pressed stainless pan with a rolled rim.
        for l in 0..<2 {
            let sg = l == 0 ? 5 : 2
            func ring(_ dx: Float, _ y: Float, _ r: Float) -> [V3] {
                Prim.ring(Shape2D.roundedRect(tray.x + dx, tray.y + dx, radius: r, segments: sg), y: y, offset: V3(0, 0, tzc))
            }
            let d = trayDepth
            let rings = [ring(-0.03, ty0, 0.02), ring(-0.012, ty0 + 0.002, 0.026), ring(-0.004, ty0 + d * 0.7, 0.028), ring(0.004, ty0 + d, 0.03),
                         ring(0.008, ty0 + d - 0.003, 0.032), ring(0.002, ty0 + d - 0.004, 0.03), ring(-0.006, ty0 + d - 0.002, 0.028),
                         ring(-0.014, ty0 + 0.0035, 0.024), ring(-0.03, ty0 + 0.0015, 0.02)]
            rig.add(Prim.loft(rings, capStart: true, capEnd: true, material: steel), to: "column", lods: l...l)
        }
        // Drape: lines the pan, rolls over the rim and hangs at the sides and front.
        let floorY = ty0 + 0.0028, rimY = ty0 + trayDepth + 0.0025
        let drapePhase = rng.float(0...6)
        for l in 0..<2 {
            var sheet = drapeSheet(hx: hx, hz: hz, floorY: floorY, rimY: rimY, side: 0.075, back: 0.03, front: overhang,
                                   dense: l == 0, phase: drapePhase, material: drape)
            sheet = sheet.transformed(Xform(translation: V3(0, 0, tzc)))
            rig.add(sheet, to: "column", lods: l...l)
            rig.add(sheet.flipped(), to: "column", lods: l...l)
        }
        // Instruments on the drape, handles toward the front edge (+Z), tips toward the column.
        let set: [(TheatreInstrument, Float)] = [(.scissors, 0.17), (.curvedHemostat, 0.16), (.hemostat, 0.14), (.hemostat, 0.14),
                                                 (.needleHolder, 0.18), (.forceps, 0.15), (.scalpel, 0.135)]
        var x = -hx + 0.034
        var irng = rng.fork(11)
        for (kind, len) in set {
            let w: Float = kind == .forceps || kind == .scalpel ? 0.014 : 0.04
            let inst = theatreInstrument(kind, length: len)
            let z0 = tzc + hz - 0.05 - irng.float(0...0.03)
            rig.add(inst, Xform(translation: V3(x + w / 2 - 0.012, floorY + 0.0006, z0),
                                rotation: simd_quatf(degrees: 180 + irng.float(-6...6), axis: .up)), to: "column", lods: 0...0)
            x += w + 0.004
        }
        // LOD1: the instrument set reads as a few slim bars.
        var bars = Surface(material: "metal.surgical")
        for k in 0..<6 {
            bars.append(cuboid(V3(0.012, 0.004, 0.15), material: "metal.surgical"),
                        Xform(translation: V3(-hx + 0.04 + Float(k) * 0.045, floorY + 0.002, tzc + hz - 0.13)))
        }
        rig.add(bars, to: "column", lods: 1...1)
        // Saline splash soaked into the drape beside the instruments (darker, irregular).
        var wet = Surface(material: "drape.surgical:2C6488")
        let wc = V2(hx - 0.07, tzc - 0.02)
        let wetOutline = (0..<14).map { k -> V2 in
            let a = Float(k) / 14 * 2 * .pi
            let rr: Float = 0.032 * (1 + 0.25 * sin(a * 3 + 1) + 0.12 * sin(a * 5))
            return V2(cos(a) * rr * 1.3, sin(a) * rr)
        }
        let wetTris = Shape2D.triangulate(wetOutline)
        for p in wetOutline { _ = wet.add(V3(wc.x + p.x, floorY + 0.0004, wc.y - p.y), V3(0, 1, 0), V2(p.x, p.y)) }
        wet.indices = wetTris
        wet.computeTangents()
        rig.add(wet, to: "column", lods: 0...0)
        // Towel clip pinning the drape at the front corner.
        rig.add(theatreInstrument(.towelClip, length: 0.11), Xform(translation: V3(hx - 0.02, rimY + 0.001, tzc + hz - 0.01),
                                                                     rotation: simd_quatf(degrees: 150, axis: .up)), to: "column", lods: 0...0)

        groundAO(&rig, height: 0.08, floor: 0.6)
        rig.states = [RigState("low"), RigState("high", ["column": travel]), RigState("adjusting", ["column": travel * 0.45, "knob": -180])]
        return rig
    }
}

/// Fabric sheet laid in a tray of half size (hx, hz) centered at the origin: flat on `floorY`, up the pan wall,
/// over the rim at `rimY`, then hanging straight down by `side`, `back` (-Z) and `front` (+Z). UVs in meters
/// of unfolded cloth; folds ripple the hanging part.
func drapeSheet(hx: Float, hz: Float, floorY: Float, rimY: Float, side: Float, back: Float, front: Float,
                dense: Bool, phase: Float, material: MaterialKey) -> Surface {
    let wall: Float = 0.014, over: Float = 0.01
    func samples(_ h: Float, _ hangLo: Float, _ hangHi: Float) -> [Float] {
        var a: [Float] = []
        let hang = { (len: Float, n: Int) -> [Float] in (1...n).map { h + over + len * Float($0) / Float(n) } }
        let edge: [Float] = dense ? [h - wall, h - wall * 0.5, h, h + over * 0.5, h + over] : [h - wall, h, h + over]
        let inner: [Float] = dense ? [0, 0.33, 0.66].map { (h - wall) * $0 } : [0, 0.5].map { (h - wall) * $0 }
        let nLo = max(1, Int(hangLo / (dense ? 0.04 : 0.1)) + 1), nHi = max(1, Int(hangHi / (dense ? 0.04 : 0.1)) + 1)
        a += hang(hangLo, nLo).reversed().map { -$0 }
        a += edge.reversed().map { -$0 }
        a += inner.reversed().dropLast().map { -$0 }
        a += inner
        a += edge
        a += hang(hangHi, nHi)
        return a
    }
    let xs = samples(hx, side, side), zs = samples(hz, back, front)
    var s = Surface(material: material)
    func place(_ x: Float, _ z: Float) -> V3 {
        // Per axis: distance past the rim edge (negative inside).
        func axis(_ v: Float, _ h: Float) -> (pos: Float, drop: Float, rise: Float) {
            let e = abs(v) - h
            if e <= -wall { return (v, 0, 0) }
            if e <= 0 { return (v, 0, (e + wall) / wall) }
            if e <= over { return (v, 0, 1) }
            let d = e - over
            return (copysign(h + over + 0.006 * (1 - exp(-d / 0.03)) + d * 0.04, v), d, 1)
        }
        let ax = axis(x, hx), az = axis(z, hz)
        // Rounded pan corners (radius 30 mm) lift the cloth earlier than the straight walls.
        let rc: Float = 0.03, qx = abs(x) - (hx - rc), qz = abs(z) - (hz - rc)
        let cornerRise: Float = qx > 0 && qz > 0 ? min(1, max(0, (sqrt(qx * qx + qz * qz) - rc + wall * 1.3) / wall)) : 0
        let rise = max(ax.rise, az.rise, cornerRise), drop = max(ax.drop, az.drop)
        var y = floorY + (rimY - floorY) * (rise < 1 ? rise * rise * (3 - 2 * rise) : 1)
        if rise >= 1 && drop == 0 {
            let e = max(abs(x) - hx, abs(z) - hz)
            y += 0.003 * sin(min(1, max(0, e / over)) * .pi)
        }
        y -= drop
        var p = V3(ax.pos, y, az.pos)
        if drop > 0 {
            // Soft vertical folds in the hanging fabric.
            let along = abs(x) > hx ? z : x
            let w = 0.011 * sin(along * 38 + phase) * min(1, drop / 0.05) + 0.004 * sin(along * 97 + phase * 1.7) * min(1, drop / 0.08) + 0.012 * drop
            if az.drop >= ax.drop { p.z += copysign(w, z) } else { p.x += copysign(w, x) }
        }
        return p
    }
    var idx: [[UInt32]] = []
    for (j, z) in zs.enumerated() {
        var row: [UInt32] = []
        for (i, x) in xs.enumerated() {
            row.append(s.add(place(x, z), V3(0, 1, 0), V2(x, z)))
            _ = i; _ = j
        }
        idx.append(row)
    }
    for j in 0..<(zs.count - 1) { for i in 0..<(xs.count - 1) {
        s.quad(idx[j][i], idx[j + 1][i], idx[j + 1][i + 1], idx[j][i + 1])
    }}
    s.recomputeNormals(weldSeams: false)
    s.computeTangents()
    return s
}
