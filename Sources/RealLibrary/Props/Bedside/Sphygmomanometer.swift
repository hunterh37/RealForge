import simd
import Foundation

/// Handheld aneroid sphygmomanometer kit (Welch Allyn DS44 / ADC Prosphyg 760 class) as it lies on a
/// table: 2.25 in (57 mm) dial in a 64 mm satin steel case with a chrome bezel and domed lens, printed
/// 0-300 mmHg scale (2 mmHg minor ticks, numerals every 20, zero box), black needle on a chrome hub;
/// adult nylon cuff (53 x 14.5 cm) loosely rolled with its spiral ends and tail flap showing; two 7 mm
/// PVC tubes, one coiled on the table; 55 x 92 mm rubber bulb with a chrome air-release valve
/// (knurled thumbscrew) and an inlet valve. The needle turns about the dial center (330 degrees for
/// 300 mmHg); the thumbscrew turns about the valve axis.
public struct Sphygmomanometer: RealArticulated {
    public static let id = "sphygmomanometer"
    public static let summary = "Handheld aneroid sphygmomanometer: 2.25 in chrome gauge with printed mmHg dial and needle, rolled nylon adult cuff, coiled tubing, rubber bulb with release valve."
    public static let tags = ["prop", "medical", "articulated", "handheld", "hospital", "fabric", "rubber", "metal"]
    public static let budget = 5200
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 18, elevation: 30, distance: 0.5, studio: true)

    /// Cuff fabric (tint the suffix for other colors: navy default).
    public var cuff: MaterialKey = "fabric.cuff-navy"
    /// Cuff width (m): adult 14.5 cm, large adult 17.5 cm.
    public var cuffWidth: Float = 0.145
    /// Gauge case material.
    public var gaugeCase: MaterialKey = "metal.surgical"
    /// Needle reading in the inflated and releasing states (mmHg).
    public var inflatedPressure: Float = 180
    public var releasingPressure: Float = 120
    public init() {}

    /// Degrees of needle travel per mmHg (0-300 over 330 degrees).
    static let degPerMmHg: Float = 1.1

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [2.5])
        let print: MaterialKey = "plastic.matte:141414", face: MaterialKey = "plastic.medical:F4F3EE"
        let tubeMat: MaterialKey = "rubber.tubing", bulbMat: MaterialKey = "rubber"
        let qYZ = simd_quatf(degrees: 90, axis: V3(1, 0, 0))      // lathe +Y -> gauge +Z

        // MARK: cuff roll (spiral strip extruded along X)
        let W = cuffWidth, cx: Float = -0.045, zr: Float = -0.035
        let t: Float = 0.0026, r0: Float = 0.0095, turns: Float = 3, pitch: Float = 0.0062, squash: Float = 0.86
        let rOut = r0 + pitch * turns
        let yr = rOut * squash + t / 2
        func spiralR(_ th: Float) -> Float { r0 + pitch * (th - (-Float.pi / 2)) / (2 * .pi) }   // th from -pi/2 + 2pi*turns down to -pi/2
        func spiralP(_ th: Float) -> V2 {   // (z, y), radius grows as th decreases toward -pi/2
            let thIn = -Float.pi / 2 + 2 * .pi * turns
            let r = r0 + pitch * (thIn - th) / (2 * .pi)
            return V2(zr + r * cos(th), yr + r * sin(th) * squash)
        }
        for l in 0..<2 {
            let perTurn = l == 0 ? 14 : 7
            let thIn = -Float.pi / 2 + 2 * .pi * turns
            var center: [V2] = []
            let n = Int(turns * Float(perTurn))
            for k in 0...n { center.append(spiralP(thIn - (thIn + .pi / 2) * Float(k) / Float(n))) }
            // Tail flap lying on the table toward the back, slight lift at its end.
            let end = center.last!
            center.append(V2(end.x - 0.02, t / 2))
            center.append(V2(end.x - 0.042, t / 2 + 0.0004))
            center.append(V2(end.x - 0.058, t / 2 + 0.0018))
            var outer: [V2] = [], inner: [V2] = []
            for i in center.indices {
                let a = center[max(0, i - 1)], b = center[min(center.count - 1, i + 1)]
                let d = simd_normalize(b - a), nn = V2(-d.y, d.x)
                outer.append(center[i] + nn * t / 2); inner.append(center[i] - nn * t / 2)
            }
            let outline = (outer + inner.reversed()).map { V2(-$0.x, $0.y) }
            let roll = Prim.extrude(outline, depth: W, bevel: l == 0 ? 0.0007 : 0, bevelSegments: 1, material: cuff)
            rig.base[l].add(roll, Xform(translation: V3(cx, 0, 0), rotation: simd_quatf(degrees: 90, axis: .up)))
        }
        // Index / range label printed on the outer wrap, curved with it.
        do {
            var s = Surface(material: "label.bedside-cuff")
            let thIn = -Float.pi / 2 + 2 * .pi * turns
            let lw: Float = 0.036, segs = 4
            let a0: Float = 1.15, a1: Float = 1.95          // angles on the last turn (radians, mod 2 pi)
            for k in 0...segs {
                let f = Float(k) / Float(segs)
                let th = a0 + (a1 - a0) * f
                // Last turn: th in [-pi/2, 3pi/2]; outer radius there.
                let r = r0 + pitch * (thIn - th) / (2 * .pi) + t / 2 + 0.0003
                let p = V2(zr + r * cos(th), yr + r * sin(th) * squash)
                let nrm = simd_normalize(V3(0, sin(th), cos(th) * squash))
                _ = s.add(V3(cx - 0.036 - lw / 2, p.y, p.x), nrm, V2(0, f) * BedsideKit.uvSpan("label.bedside-cuff"))
                _ = s.add(V3(cx - 0.036 + lw / 2, p.y, p.x), nrm, V2(1, f) * BedsideKit.uvSpan("label.bedside-cuff"))
            }
            for k in 0..<UInt32(segs) { let a = k * 2; s.quad(a, a + 1, a + 3, a + 2) }
            s.computeTangents()
            rig.base[0].add(s); rig.base[1].add(s)
            // Artery index arrow and range line printed in white on top of the roll (flat where the wrap is level).
            let topR = r0 + pitch * (thIn - .pi / 2) / (2 * .pi) + t / 2 + 0.0002
            let yTop = yr + topR * squash
            var ink = Surface(material: "plastic.matte:E6E7E2")
            let o = V3(cx + 0.006, yTop, zr), u = V3(1, 0, 0), v = V3(0, 0, -1)
            BedsideKit.bar(&ink, o, u, v, -0.004, -0.0009, 0.034, 0.0009)
            BedsideKit.quad2(&ink, o, u, v, V2(0.034, -0.0035), V2(0.046, 0), V2(0.046, 0), V2(0.034, 0.0035))
            BedsideKit.bar(&ink, o, u, v, -0.014, -0.0042, -0.011, 0.0042)
            ink.computeTangents()
            rig.base[0].add(ink)
        }
        _ = spiralR

        // MARK: bulb frame: lathe +Y along the bulb axis, yawed so the valve points back toward the cuff
        let bR: Float = 0.026
        let qB = simd_quatf(degrees: 10, axis: .up) * simd_quatf(degrees: 90, axis: V3(1, 0, 0))
        let BX = Xform(translation: V3(0.1, bR - 0.0012, -0.004), rotation: qB)
        let bAxis = qB.act(V3(0, 1, 0))

        // MARK: gauge
        let tilt: Float = 38, spin: Float = rng.float(52...62), yaw: Float = rng.float(-14 ... -8)
        let qG = simd_quatf(degrees: yaw, axis: .up) * simd_quatf(degrees: -tilt, axis: V3(1, 0, 0)) * simd_quatf(degrees: spin, axis: V3(0, 0, 1))
        let stemLocal = V3(0, -0.0445, -0.0095)
        var samples: [V3] = [stemLocal + V3(0, 0, -0.0035)]
        for k in 0..<24 {
            let a = Float(k) / 24 * 2 * .pi
            samples.append(V3(cos(a) * 0.0322, sin(a) * 0.0322, -0.002))
            samples.append(V3(cos(a) * 0.0300, sin(a) * 0.0300, -0.016))
            samples.append(V3(cos(a) * 0.0225, sin(a) * 0.0225, -0.0205))
        }
        let minY = samples.map { qG.act($0).y }.min()!
        let gc = V3(cx + 0.002, -minY, 0.016)
        let G = Xform(translation: gc, rotation: qG)
        func gx(_ x: Xform) -> Xform { x.then(G) }
        let nrm = qG.act(V3(0, 0, 1))
        for l in 0..<2 {
            let sg = l == 0 ? 28 : 14
            var m = Model(name: Self.id)
            // Case: closed back, shallow shoulder, straight wall under the bezel.
            m.add(Prim.lathe([V2(0, -0.0205), V2(0.019, -0.0205), V2(0.0245, -0.0195), V2(0.0285, -0.017), V2(0.0303, -0.0135),
                              V2(0.0308, -0.008), V2(0.0308, -0.001)], segments: sg, material: gaugeCase), gx(Xform(rotation: qYZ)))
            // Chrome bezel: rolled lip over the lens.
            m.add(Prim.lathe([V2(0.0303, -0.0035), V2(0.0323, -0.0022), V2(0.0322, 0.0030), V2(0.0300, 0.0045), V2(0.0284, 0.0030)], segments: sg, material: "metal.chrome"), gx(Xform(rotation: qYZ)))
            // Dial face.
            m.add(Prim.lathe([V2(0.0289, -0.0050), V2(0.0289, -0.0030), V2(0, -0.0030)], segments: sg, material: face), gx(Xform(rotation: qYZ)))
            // Domed lens.
            m.add(Prim.lathe([V2(0.0289, 0.0027), V2(0.022, 0.0034), V2(0.012, 0.0040), V2(0, 0.0043)], segments: sg, material: "glass.gauge-lens"),
                  gx(Xform(rotation: qYZ)))
            // Stem at 6 o'clock with a hose barb.
            m.add(Prim.cylinder(radius: 0.0036, height: 0.0125, bevel: 0.0006, segments: l == 0 ? 12 : 8, bevelSegments: 1, material: "metal.chrome"),
                  gx(Xform(translation: V3(0, -0.0300, -0.0095), rotation: simd_quatf(degrees: 180, axis: V3(0, 0, 1)))))
            m.add(Prim.lathe([V2(0.0024, 0), V2(0.0029, 0.003), V2(0.0022, 0.0034), V2(0.0026, 0.006), V2(0.0019, 0.0065)], segments: 8, material: "metal.chrome"),
                  gx(Xform(translation: stemLocal, rotation: simd_quatf(degrees: 180, axis: V3(0, 0, 1)))))
            // Hub boss under the needle.
            m.add(Prim.cylinder(radius: 0.0028, height: 0.0010, bevel: 0.0003, segments: 12, bevelSegments: 1, material: print),
                  gx(Xform(translation: V3(0, 0, -0.0031), rotation: qYZ)))
            // Printed scale.
            var ticks = Surface(material: print)
            let zf: Float = -0.0028
            for p in stride(from: 0, through: 300, by: l == 0 ? 2 : 10) {
                let major = p % 20 == 0, mid = p % 10 == 0
                let a = Float(p) * Self.degPerMmHg * .pi / 180
                let d = V2(sin(a), cos(a)), side = V2(d.y, -d.x)
                let r1: Float = 0.0262, r0t: Float = r1 - (major ? 0.0042 : mid ? 0.0032 : 0.0019)
                let hw: Float = (major ? 0.00034 : mid ? 0.00026 : 0.0002)
                BedsideKit.quad2(&ticks, V3(0, 0, zf), V3(1, 0, 0), V3(0, 1, 0), d * r0t - side * hw, d * r0t + side * hw, d * r1 + side * hw, d * r1 - side * hw)
            }
            if l == 0 {
                // Zero box around the rest position, numerals every 20 mmHg, "mmHg" and maker caption.
                for (x0, y0, x1, y1) in [(-0.0021, 0.0216, 0.0021, 0.0220), (-0.0021, 0.0268, 0.0021, 0.0272), (-0.0021, 0.0216, -0.0017, 0.0272), (0.0017, 0.0216, 0.0021, 0.0272)] as [(Float, Float, Float, Float)] {
                    BedsideKit.bar(&ticks, V3(0, 0, zf), V3(1, 0, 0), V3(0, 1, 0), x0, y0, x1, y1)
                }
                for p in stride(from: 20, through: 300, by: 20) {
                    let a = Float(p) * Self.degPerMmHg * .pi / 180
                    let h: Float = 0.0029
                    let c = V2(sin(a), cos(a)) * 0.0186
                    ticks.append(BedsideKit.segments(String(p), origin: V3(c.x, c.y - h / 2, zf), u: V3(1, 0, 0), v: V3(0, 1, 0), height: h, stroke: 0.15, shear: 0, centered: true, material: print))
                }
                ticks.append(BedsideKit.segments("0", origin: V3(0, 0.0172, zf), u: V3(1, 0, 0), v: V3(0, 1, 0), height: 0.0029, stroke: 0.15, shear: 0, centered: true, material: print))
                ticks.append(BedsideKit.caption([4], origin: V3(-0.0032, -0.0105, zf), u: V3(1, 0, 0), v: V3(0, 1, 0), height: 0.0024, material: print))
                ticks.append(BedsideKit.caption([3, 4], origin: V3(-0.0058, 0.0085, zf), u: V3(1, 0, 0), v: V3(0, 1, 0), height: 0.0016, material: "plastic.matte:2A4F8C"))
            }
            m.add(ticks, G)

            // MARK: bulb and valves (lying on the table, valve end toward the cuff)
            let bulbProf: [V2] = [V2(0.0064, 0), V2(0.0066, 0.005), V2(0.011, 0.011), V2(0.018, 0.019), V2(0.0232, 0.029), V2(bR, 0.043),
                                  V2(0.0252, 0.056), V2(0.0222, 0.067), V2(0.0168, 0.077), V2(0.0108, 0.084), V2(0.0072, 0.088), V2(0.0064, 0.093)]
            m.add(Prim.lathe(bulbProf, segments: l == 0 ? 16 : 8, seamTile: 0.05, material: bulbMat), BX)
            // Release valve body (between tube barb and bulb neck) and inlet valve at the tail.
            m.add(Prim.lathe([V2(0.0024, -0.034), V2(0.0029, -0.031), V2(0.0023, -0.0305), V2(0.0027, -0.028), V2(0.0045, -0.0275), V2(0.0058, -0.026),
                              V2(0.0058, -0.004), V2(0.0072, -0.003), V2(0.0072, 0.004), V2(0.0058, 0.005)], segments: l == 0 ? 10 : 6, material: "metal.chrome"), BX)
            m.add(Prim.lathe([V2(0.0058, 0.089), V2(0.0068, 0.090), V2(0.0068, 0.099), V2(0.0058, 0.1005), V2(0.0035, 0.101), V2(0, 0.101)],
                             segments: l == 0 ? 10 : 6, material: "metal.chrome"), BX)
            rig.base[l].add(m)
        }

        // MARK: tubes
        let stemTip = G.point(stemLocal + V3(0, -0.006, 0))
        let stemDir = qG.act(V3(0, -1, 0))
        let tr: Float = 0.0034
        let faceX = cx + W / 2
        let barb = BX.point(V3(0, -0.0335, 0))
        func floorY(_ p: V3) -> V3 { V3(p.x, max(p.y, tr), p.z) }
        let pathA = catmull([V3(faceX - 0.012, yr + 0.006, zr + 0.012), V3(faceX + 0.004, yr + 0.006, zr + 0.012), V3(faceX + 0.022, tr + 0.004, zr + 0.026),
                             V3(faceX + 0.024, tr, gc.z + 0.02), stemTip + stemDir * 0.03 + V3(0, 0, 0), stemTip + stemDir * 0.012, stemTip], per: 4).map(floorY)
        // Tube B: out of the roll, a loose coil on the table behind the bulb (spiral, one pass rides over the
        // other), then into the release valve barb from behind.
        let cc = V2(0.066, -0.084)
        var bPts = [V3(faceX - 0.012, yr - 0.008, zr - 0.010), V3(faceX + 0.004, yr - 0.008, zr - 0.010), V3(faceX + 0.016, tr + 0.002, -0.062)]
        let nCoil = 18
        for k in 0...nCoil {
            let f = Float(k) / Float(nCoil)
            let a = (150 + 480 * f) * .pi / 180, r = 0.016 + 0.01 * f
            var p = V3(cc.x + cos(a) * r, tr, cc.y + sin(a) * r)
            let over = abs(f * 480 - 360)       // degrees from the crossing over the entry
            if over < 45 { p.y += 2 * tr * 0.95 * (1 - over / 45) }
            bPts.append(p)
        }
        bPts += [V3(barb.x - 0.004, tr, -0.096), V3(barb.x - 0.002, tr + 0.002, barb.z - 0.03), barb - bAxis * 0.012 + V3(0, -0.003, 0), barb + bAxis * 0.004]
        let pathB = catmull(bPts, per: 3)
        for l in 0..<2 {
            let sides = l == 0 ? 6 : 4
            for path in [l == 0 ? pathA : stride(from: 0, to: pathA.count, by: 2).map { pathA[$0] } + [pathA.last!], l == 0 ? pathB : stride(from: 0, to: pathB.count, by: 2).map { pathB[$0] } + [pathB.last!]] {
                rig.base[l].add(Prim.tube(path, radii: path.map { _ in tr }, sides: sides, seamTile: 0.022, material: tubeMat, capEnd: false))
            }
        }

        // MARK: needle (part)
        rig.part("needle", pivot: gc, joint: .hinge(axis: nrm, -330...0, duration: 0.8))
        let needle = Shape2D.deduped([V2(-0.0007, -0.0075), V2(0.0007, -0.0075), V2(0.00055, 0), V2(0.00012, 0.0256), V2(-0.00012, 0.0256), V2(-0.00055, 0)])
        rig.add(Prim.extrude(needle, depth: 0.0003, bevel: 0, material: "plastic.matte:0E0E0E"), gx(Xform(translation: V3(0, 0, -0.0018))), to: "needle")
        rig.add(Prim.cylinder(radius: 0.0017, height: 0.0009, bevel: 0.0003, segments: 10, bevelSegments: 1, material: "metal.chrome"),
                gx(Xform(translation: V3(0, 0, -0.0019), rotation: qYZ)), to: "needle")

        // MARK: release valve thumbscrew (part, turns about the valve axis)
        let vc = BX.point(V3(0, -0.016, 0))
        rig.part("valve", pivot: vc, joint: .hinge(axis: -bAxis, 0...300, duration: 0.6))
        var knurl: [V2] = []
        for k in 0..<28 { let a = Float(k) / 28 * 2 * .pi; let r: Float = k % 2 == 0 ? 0.0095 : 0.0089; knurl.append(V2(cos(a), sin(a)) * r) }
        rig.add(Prim.extrude(knurl, depth: 0.0055, bevel: 0.0004, bevelSegments: 1, material: "metal.chrome"),
                Xform(translation: vc, rotation: qB * simd_quatf(degrees: -90, axis: V3(1, 0, 0))), to: "valve", lods: 0...0)
        rig.add(Prim.cylinder(radius: 0.0092, height: 0.0055, bevel: 0.0005, segments: 12, bevelSegments: 1, material: "metal.chrome"),
                Xform(translation: BX.point(V3(0, -0.01875, 0)), rotation: qB), to: "valve", lods: 1...1)
        // Index flat on the wheel so the turn reads.
        rig.add(Prim.roundedBox(V3(0.0012, 0.0056, 0.0016), radius: 0.0003, bevelSegments: 1, material: "metal.surgical"),
                Xform(translation: BX.point(V3(0, -0.016, -0.0094)), rotation: qB), to: "valve", lods: 0...0)

        groundAO(&rig, height: 0.02, floor: 0.55)
        rig.states = [
            RigState("deflated"),
            RigState("inflated", ["needle": -inflatedPressure * Self.degPerMmHg]),
            RigState("releasing", ["needle": -releasingPressure * Self.degPerMmHg, "valve": 180]),
        ]
        return rig
    }
}
