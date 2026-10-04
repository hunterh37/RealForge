import simd
import Foundation

/// Two-station stainless surgical scrub sink (Steris / Willoughby class), 1.52 m wide x 0.66 m deep, rim at
/// 0.915 m: 14 ga type 304 casework with a toe recess, one deep basin across both stations (260 mm deep)
/// with a rolled marine front edge and two drains, a 550 mm splash back carrying per station a chrome
/// gooseneck spout with aerator and a wall soap dispenser, and in the center a stainless scrub-brush
/// dispenser under a red LED scrub timer. Knee-operated valve paddles under the front rim swing in about
/// their top bracket (hinge); each spout has a running-water option and the timer lights when scrubbing.
/// A dried soap run streaks the splash back under the left dispenser. Base y = 0, centered, front +Z.
public struct ScrubSink: RealArticulated {
    public static let id = "scrub-sink"
    public static let summary = "Two-station stainless surgical scrub sink: deep basin, splash back with gooseneck spouts, soap and brush dispensers, LED scrub timer and knee-valve paddles."
    public static let tags = ["structure", "medical", "hospital", "surgical", "interior", "metal", "articulated"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 16, distance: 1.0, studio: true)

    public var width: Float = 1.52
    public var depth: Float = 0.66
    /// Rim height above the floor (m).
    public var rimHeight: Float = 0.915
    public var basinDepth: Float = 0.26
    public var splashHeight: Float = 0.55
    public var steel: MaterialKey = "metal.casework"
    public var polished: MaterialKey = "metal.chrome"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [8])
        let W = width, D = depth, rim = rimHeight
        let hw = W / 2, zf = D / 2, zb = -D / 2
        let floorY = rim - basinDepth                  // basin bottom
        let bx = hw - 0.06                             // basin half width
        let bzf: Float = 0.2, bzb: Float = -0.24       // basin front and back walls
        let splashT: Float = 0.05, zs = zb + splashT   // splash back front face
        let toe: Float = 0.1
        let stations: [Float] = [-0.37, 0.37]

        // MARK: casework, basin, splash back (static)
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let r: Float = l == 0 ? 0.006 : 0.003, sg = l == 0 ? 2 : 1
            // Side panels: one welded piece from the toe line to the rim, full depth.
            let sideW = hw - bx, bodyD = D - splashT
            for sx: Float in [-1, 1] {
                m.add(HK.box(V3(sideW, rim - toe, bodyD), V3(sx * (hw - sideW / 2), toe + (rim - toe) / 2, zs + bodyD / 2), steel, r: r, seg: sg))
            }
            // Body below the basin floor between the side panels, recessed toe base.
            m.add(HK.box(V3(2 * bx + 0.004, floorY - toe, bodyD - 0.002), V3(0, toe + (floorY - toe) / 2, zs + bodyD / 2), steel, r: 0.002, seg: 1))
            m.add(HK.box(V3(W - 0.04, toe, D - 0.09), V3(0, toe / 2, -0.035), steel, r: 0.003, seg: 1))
            // Front and back basin walls whose inner faces form the bowl; basin floor plate.
            let wallH = rim - floorY
            m.add(HK.box(V3(2 * bx + 0.004, wallH + 0.03, zf - bzf), V3(0, floorY - 0.03 + (wallH + 0.03) / 2, (zf + bzf) / 2), steel, r: 0.003, seg: sg))
            m.add(HK.box(V3(2 * bx + 0.004, wallH, bzb - zs), V3(0, floorY + wallH / 2, (bzb + zs) / 2), steel, r: 0.003, seg: sg))
            m.add(HK.box(V3(2 * bx + 0.004, 0.01, bzf - bzb + 0.004), V3(0, floorY + 0.002, (bzf + bzb) / 2), "metal.surgical", r: 0.003, seg: 1))
            // Rolled marine edge along the front rim.
            m.add(HK.cyl(r: 0.014, len: W - 0.01, at: V3(0, rim - 0.004, zf - 0.012), axis: V3(1, 0, 0), mat: steel, seg: l == 0 ? 16 : 8, bevel: 0.006))
            // Splash back with a rolled top cap.
            m.add(HK.box(V3(W, rim + splashHeight - toe, splashT), V3(0, toe + (rim + splashHeight - toe) / 2, zb + splashT / 2), steel, r: r, seg: sg))
            m.add(HK.cyl(r: 0.03, len: W, at: V3(0, rim + splashHeight, zb + splashT / 2), axis: V3(1, 0, 0), mat: steel, seg: l == 0 ? 16 : 8, bevel: 0.008))
            // Drains: strainer rings and dark outlets.
            for sx in stations {
                m.add(HK.cyl(r: 0.045, len: 0.004, at: V3(sx, floorY + 0.008, -0.12), axis: .up, mat: "metal.surgical", seg: l == 0 ? 24 : 12, bevel: 0.0015))
                m.add(HK.cyl(r: 0.03, len: 0.003, at: V3(sx, floorY + 0.0095, -0.12), axis: .up, mat: "plastic.black", seg: l == 0 ? 20 : 10, bevel: 0.001))
            }
            if l == 0 {
                // Front access panel seams and screws.
                for sx: Float in [-1, 0, 1] {
                    m.add(cuboid(V3(0.003, floorY - toe - 0.06, 0.002), material: "plastic.black"), Xform(translation: V3(sx * (hw - 0.03) * (sx == 0 ? 0 : 1), toe + (floorY - toe) / 2, zf + 0.0002)))
                    for sy: Float in [0.16, floorY - 0.05] {
                        m.add(HK.cyl(r: 0.005, len: 0.0015, at: V3(sx * (hw - 0.05) + (sx == 0 ? 0.025 : 0), sy, zf + 0.0006), axis: V3(0, 0, 1), mat: steel, seg: 8, bevel: 0.0005))
                    }
                }
            }
            rig.base[l] = m
        }

        // MARK: fixtures on the splash back (static)
        let spoutY: Float = rim + 0.3
        var tipZ: Float = 0
        for l in 0..<2 {
            var m = Model(name: "fixtures")
            for (i, sx) in stations.enumerated() {
                // Gooseneck: escutcheon, arched spout, aerator.
                m.add(HK.cyl(r: 0.03, len: 0.01, at: V3(sx, spoutY, zs + 0.005), axis: V3(0, 0, 1), mat: polished, seg: l == 0 ? 24 : 12, bevel: 0.003))
                let ctrl = [V3(sx, spoutY, zs), V3(sx, spoutY, zs + 0.05), V3(sx, spoutY + 0.1, zs + 0.11), V3(sx, spoutY + 0.13, zs + 0.18),
                            V3(sx, spoutY + 0.09, zs + 0.25), V3(sx, spoutY + 0.02, zs + 0.27)]
                let path = catmull(ctrl, per: l == 0 ? 6 : 3)
                m.add(HK.pipe(path, r: 0.011, sides: l == 0 ? 16 : 8, mat: polished))
                let tip = path.last!
                tipZ = tip.z
                m.add(HK.cyl(r: 0.013, len: 0.022, at: tip + V3(0, -0.006, 0), axis: .up, mat: polished, seg: l == 0 ? 16 : 8, bevel: 0.003))
                // Wall soap dispenser outboard of the spout: white body, amber level window, grey nozzle.
                let dx = sx + (sx < 0 ? -0.24 : 0.24), dy = rim + 0.33
                m.add(HK.box(V3(0.11, 0.2, 0.09), V3(dx, dy, zs + 0.045), "plastic.medical", r: 0.012, seg: l == 0 ? 2 : 1))
                m.add(HK.box(V3(0.03, 0.09, 0.004), V3(dx, dy + 0.02, zs + 0.0905), "plastic.amber", r: 0.0015, seg: 1))
                m.add(HK.box(V3(0.07, 0.02, 0.05), V3(dx, dy - 0.11, zs + 0.06), "plastic.medical-grey", r: 0.006, seg: 1))
                m.add(HK.cyl(r: 0.005, len: 0.014, at: V3(dx, dy - 0.124, zs + 0.075), axis: .up, mat: "plastic.medical-grey:5C6369", seg: 8, bevel: 0.001))
                if l == 0 {
                    m.add(HK.box(V3(0.06, 0.012, 0.004), V3(dx, dy + 0.085, zs + 0.0905), "label.rx", r: 0.001, seg: 1))
                    if i == 0 {
                        // Story: dried soap runs down the splash back under the left dispenser.
                        var run = Surface(material: "decal.soap-residue")
                        for k in 0..<3 {
                            let len = rng.float(0.1...0.26), xo = rng.float(-0.012...0.012) + Float(k - 1) * 0.008
                            HK.rect(&run, center: V3(dx + xo, dy - 0.13 - len / 2, zs + 0.0006), right: V3(1, 0, 0), up: .up, w: rng.float(0.006...0.014), h: len)
                        }
                        m.add(run)
                    }
                }
            }
            // Scrub-brush dispenser: stainless box with a window on the brush stack and a dispensing slot.
            let by = rim + 0.2
            m.add(HK.box(V3(0.2, 0.3, 0.1), V3(0, by, zs + 0.05), steel, r: 0.008, seg: l == 0 ? 2 : 1))
            m.add(HK.box(V3(0.12, 0.15, 0.004), V3(0, by + 0.04, zs + 0.1), "plastic.clear", r: 0.002, seg: 1))
            m.add(HK.box(V3(0.15, 0.012, 0.03), V3(0, by - 0.135, zs + 0.09), "plastic.black", r: 0.004, seg: 1))
            if l == 0 {
                for k in 0..<5 {
                    m.add(HK.box(V3(0.1, 0.022, 0.06), V3(0, by - 0.02 + Float(k) * 0.024, zs + 0.06), k % 2 == 0 ? "drape.green" : "paper.exam", r: 0.004, seg: 1))
                }
            }
            // Timer housing above the brush dispenser.
            m.add(HK.box(V3(0.16, 0.08, 0.04), V3(0, rim + 0.42, zs + 0.02), "plastic.medical-grey:3A3F44", r: 0.006, seg: 1))
            for s in m.surfaces { rig.base[l].add(s) }
        }

        // MARK: timer (options), water streams (options), knee-valve paddles (hinges)
        let tz = zs + 0.0405, ty = rim + 0.42
        rig.part("timer", pivot: V3(0, ty, tz), joint: .fixed, options: 2)
        rig.add(HK.rect("plastic.gloss:0B0C0E", center: V3(0, ty, tz), right: V3(1, 0, 0), up: .up, w: 0.13, h: 0.05), to: "timer")
        rig.add(HK.rect("plastic.gloss:0B0C0E", center: V3(0, ty, tz), right: V3(1, 0, 0), up: .up, w: 0.13, h: 0.05), to: "timer", option: 1)
        var digits = Surface(material: "emissive.led-red")
        func seg(_ c: V3, _ w: Float, _ h: Float) { HK.rect(&digits, center: c + V3(0, 0, 0.0008), right: V3(1, 0, 0), up: .up, w: w, h: h) }
        func digit(_ x: Float, _ segs: String) {
            let dw: Float = 0.016, dh: Float = 0.03, t: Float = 0.0032
            for ch in segs {
                switch ch {
                case "a": seg(V3(x, ty + dh / 2, tz), dw, t)
                case "g": seg(V3(x, ty, tz), dw, t)
                case "d": seg(V3(x, ty - dh / 2, tz), dw, t)
                case "f": seg(V3(x - dw / 2, ty + dh / 4, tz), t, dh / 2)
                case "b": seg(V3(x + dw / 2, ty + dh / 4, tz), t, dh / 2)
                case "e": seg(V3(x - dw / 2, ty - dh / 4, tz), t, dh / 2)
                case "c": seg(V3(x + dw / 2, ty - dh / 4, tz), t, dh / 2)
                default: break
                }
            }
        }
        digit(-0.036, "afgcd"); digit(0.012, "abcdef"); digit(0.04, "abcdef")
        seg(V3(-0.012, ty + 0.007, tz), 0.004, 0.004); seg(V3(-0.012, ty - 0.007, tz), 0.004, 0.004)
        rig.add(digits, to: "timer", option: 1)

        for (i, sx) in stations.enumerated() {
            let n = i + 1
            // Water: a clear column from the aerator to the basin floor with a splash ring.
            rig.part("water\(n)", pivot: V3(sx, spoutY, tipZ), joint: .fixed, options: 2)
            let top = spoutY + 0.003, bottom = floorY + 0.012
            let col = (0...6).map { k in V3(sx, top - (top - bottom) * Float(k) / 6, tipZ) }
            let radii = (0...6).map { k in 0.0075 - 0.0025 * Float(k) / 6 }
            rig.add(Prim.tube(col, radii: radii, sides: 12, seamTile: 0.05, material: "fluid.tap-water"), to: "water\(n)", option: 1)
            rig.add(Prim.torus(major: 0.022, minor: 0.004, segments: 20, sides: 6, material: "fluid.tap-water"), Xform(translation: V3(sx, bottom, tipZ)), to: "water\(n)", option: 1, lods: 0...0)
            // Knee paddle: bracket on the front panel, lever arm, stainless paddle hanging below the rim.
            let py: Float = floorY - 0.03, pz = zf + 0.045
            for l in 0..<2 {
                rig.base[l].add(HK.box(V3(0.06, 0.05, 0.045), V3(sx, py, zf + 0.022), steel, r: 0.006, seg: 1))
                rig.base[l].add(HK.cyl(r: 0.012, len: 0.07, at: V3(sx, py, pz), axis: V3(1, 0, 0), mat: polished, seg: l == 0 ? 14 : 8, bevel: 0.003))
            }
            rig.part("knee\(n)", pivot: V3(sx, py, pz), joint: .hinge(axis: V3(1, 0, 0), 0...12, duration: 0.4))
            rig.add(HK.box(V3(0.02, 0.06, 0.012), V3(sx, py - 0.03, pz), "metal.surgical", r: 0.004, seg: 1), to: "knee\(n)")
            let paddle = Prim.extrude(Shape2D.roundedRect(0.15, 0.17, radius: 0.025, segments: 3), depth: 0.006, bevel: 0.002, bevelSegments: 1, material: "metal.surgical")
            rig.add(paddle, Xform(translation: V3(sx, py - 0.06 - 0.085, pz + 0.006)), to: "knee\(n)")
        }

        groundAO(&rig, height: 0.12, floor: 0.6)
        rig.states = [
            RigState("off"),
            RigState("left-running", ["knee1": 12], options: ["water1": 1, "timer": 1]),
            RigState("both-running", ["knee1": 12, "knee2": 12], options: ["water1": 1, "water2": 1, "timer": 1]),
        ]
        return rig
    }
}
