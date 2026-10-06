import simd
import Foundation

/// 16 fl oz squeeze bottle of yellow PVA wood glue, standing: off-white HDPE body with a 74 x 48 mm
/// superelliptic footprint, rounded heel, 125 mm straight wall, ribbed shoulder blending to a 31 mm round
/// neck with a transfer bead; orange twist-open spout cap (24-rib skirt, domed top, conical nozzle with a
/// pointed tip). Generic wrap label: yellow band with brown edge stripes and a white front panel carrying
/// print bars. Story detail: a dried glue drip running from the cap down the shoulder and onto the label.
/// The cap is an option part: 0 closed, 1 open (nozzle twisted up 4.5 mm, white stem showing, wet bead).
public struct WoodGlue: RealArticulated {
    public static let id = "wood-glue"
    public static let summary = "16 oz squeeze bottle of yellow PVA wood glue: oval body, ribbed shoulder, orange twist-open spout cap, generic label, dried drip."
    public static let tags = ["prop", "workshop", "handheld", "articulated", "plastic"]
    public static let budget = 6_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 28, elevation: 16, distance: 0.55, studio: true)

    /// Footprint (m): width X, depth Z.
    public var footprint = V2(0.074, 0.048)
    /// Height of the straight wall before the shoulder (m).
    public var wallHeight: Float = 0.125
    /// Neck radius (m).
    public var neckRadius: Float = 0.0155
    /// Bottle plastic.
    public var bottle: MaterialKey = "plastic.matte:EEEAE0"
    /// Cap plastic.
    public var capMaterial: MaterialKey = "plastic.tool:E25A17"
    /// Label band color (sRGB hex).
    public var labelColor: UInt32 = 0xF2B705
    /// Label stripe color (sRGB hex).
    public var stripeColor: UInt32 = 0x6B3A1E
    /// Nozzle lift when open (m).
    public var nozzleLift: Float = 0.0045
    public init() {}

    // Heights.
    var yShoulderTop: Float { wallHeight + 0.033 }
    var yCap0: Float { yShoulderTop + 0.003 }
    var yTip: Float { yCap0 + 0.044 }

    // MARK: public points

    /// Nozzle tip with the cap closed (asset space).
    public var nozzleTip: V3 { nozzleTip(open: false) }
    /// Nozzle tip, closed or open (the open nozzle rides up `nozzleLift`).
    public func nozzleTip(open: Bool) -> V3 { V3(0, yTip + (open ? nozzleLift : 0), 0) }
    /// Squeeze point: middle of the body (asset space).
    public var grip: V3 { V3(0, wallHeight * 0.55, 0) }

    // MARK: shape

    /// Superellipse point on the footprint at parameter t (radians), unit scale = footprint half size.
    func oval(_ t: Float) -> V2 {
        let n: Float = 2.9, c = cos(t), s = sin(t)
        return V2(footprint.x / 2 * copysign(pow(abs(c), 2 / n), c), footprint.y / 2 * copysign(pow(abs(s), 2 / n), s))
    }

    /// Body section at height y and parameter t: oval scaled by the heel, blending to the neck circle
    /// over the shoulder, with shoulder ribs.
    func section(_ y: Float, _ t: Float) -> V2 {
        let heel: Float = y < 0.008 ? 0.9 + 0.1 * sqrt(max(0, 1 - pow((0.008 - y) / 0.008, 2))) : 1
        let f = smoothstep(wallHeight, yShoulderTop - 0.004, y)
        var p = oval(t) * heel * (1 - f) + V2(cos(t), sin(t)) * neckRadius * f
        // Four ribs across the shoulder.
        let ys = (y - (wallHeight + 0.004)) / 0.024
        if ys > 0 && ys < 1 {
            let rib = pow(max(0, sin(ys * 4 * .pi)), 2) * 0.0026 * (1 - f * 0.4)
            p += simd_normalize(p) * rib
        }
        return p
    }

    public func rig(seed: UInt64) -> Rig {
        let rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [1.5])
        let hex = { (c: UInt32) in String(format: "%06X", c) }
        let band: MaterialKey = "paper.sheet:" + hex(labelColor), stripe: MaterialKey = "paper.sheet:" + hex(stripeColor)
        let white: MaterialKey = "paper.sheet", ink: MaterialKey = "paper.sheet:1C1A17"

        for l in 0..<2 {
            let pts = l == 0 ? 44 : 24
            var m = Model(name: Self.id)
            // Body loft: heel, wall, ribbed shoulder, neck.
            var ys: [Float] = l == 0 ? [0, 0.0006, 0.002, 0.004, 0.0065, 0.009, 0.03, 0.07, 0.11, wallHeight] : [0, 0.002, 0.006, 0.01, wallHeight]
            let shoulderSteps = l == 0 ? 22 : 8
            for k in 1...shoulderSteps { ys.append(wallHeight + (yShoulderTop - wallHeight) * Float(k) / Float(shoulderSteps)) }
            var rings: [[V3]] = []
            for y in ys {
                let ring = (0..<pts).map { k -> V2 in section(y, Float(k) / Float(pts) * 2 * .pi) }
                rings.append(Prim.ring(ring, y: y))
            }
            m.add(Prim.loft(rings, capStart: true, material: bottle))
            // Neck with a transfer bead below the cap.
            let sg = l == 0 ? 32 : 16
            m.add(Prim.lathe([V2(neckRadius - 0.0004, yShoulderTop - 0.002), V2(neckRadius, yShoulderTop), V2(neckRadius, yCap0 + 0.002)], segments: sg, seamTile: 0.1, material: bottle))
            m.add(Prim.lathe([V2(neckRadius, yShoulderTop - 0.0006), V2(neckRadius + 0.0028, yShoulderTop + 0.0002), V2(neckRadius + 0.003, yShoulderTop + 0.0012),
                              V2(neckRadius + 0.0026, yShoulderTop + 0.002), V2(neckRadius, yShoulderTop + 0.0024)], segments: sg, seamTile: 0.1, material: bottle))

            // Wrap label: bands lofted 0.25 mm proud of the wall.
            func labelBand(_ y0: Float, _ y1: Float, _ mat: MaterialKey, _ off: Float) {
                let r0 = (0..<pts).map { k -> V2 in let p = section(y0, Float(k) / Float(pts) * 2 * .pi); return p + simd_normalize(p) * off }
                let r1 = (0..<pts).map { k -> V2 in let p = section(y1, Float(k) / Float(pts) * 2 * .pi); return p + simd_normalize(p) * off }
                m.add(Prim.loft([Prim.ring(r0, y: y0), Prim.ring(r1, y: y1)], material: mat))
            }
            labelBand(0.022, 0.030, stripe, 0.00028)
            labelBand(0.030, 0.104, band, 0.00025)
            labelBand(0.104, 0.112, stripe, 0.00028)
            // Front panel and print bars: patches on the +Z face (outline t near -pi/2 maps to +Z).
            func patch(_ y0: Float, _ y1: Float, _ t0: Float, _ t1: Float, _ mat: MaterialKey, _ off: Float, cols: Int) {
                var s = Surface(material: mat)
                for (j, y) in [y0, y1].enumerated() {
                    for c in 0...cols {
                        let t = t0 + (t1 - t0) * Float(c) / Float(cols)
                        let p = section(y, t), q = p + simd_normalize(p) * off
                        s.add(V3(q.x, y, -q.y), V3(0, 0, 1), V2(Float(c) / Float(cols) * (t1 - t0) * 0.03, Float(j) * (y1 - y0)))
                    }
                }
                let row = UInt32(cols + 1)
                for c in 0..<UInt32(cols) { s.quad(c, c + 1, c + row + 1, c + row) }
                s.recomputeNormals(weldSeams: false)
                if simd_dot(s.normals[0], V3(0, 0, 1)) < 0 { s = s.flipped() }
                s.computeTangents()
                m.add(s)
            }
            let tc: Float = -.pi / 2
            let cols = l == 0 ? 10 : 4
            patch(0.046, 0.092, tc - 0.62, tc + 0.62, white, 0.00034, cols: cols)
            if l == 0 {
                patch(0.080, 0.087, tc - 0.48, tc + 0.48, ink, 0.0004, cols: 8)        // product name
                patch(0.073, 0.0765, tc - 0.40, tc + 0.30, ink, 0.0004, cols: 8)      // subtitle
                patch(0.061, 0.068, tc - 0.44, tc + 0.06, stripe, 0.0004, cols: 6)    // wood-grain swatch
                patch(0.0615, 0.063, tc + 0.12, tc + 0.46, ink, 0.0004, cols: 4)
                patch(0.065, 0.0665, tc + 0.12, tc + 0.40, ink, 0.0004, cols: 4)
                patch(0.050, 0.0535, tc - 0.10, tc + 0.50, ink, 0.0004, cols: 6)      // net contents
                patch(0.036, 0.040, tc - 0.55, tc - 0.05, ink, 0.0004, cols: 4)       // back-panel style fine print on the yellow
                // Back label fine print blocks.
                for k in 0..<5 { patch(0.05 + Float(k) * 0.009, 0.0535 + Float(k) * 0.009, .pi / 2 - 0.5, .pi / 2 + 0.5 - Float(k % 2) * 0.2, ink, 0.0004, cols: 6) }
            }

            // Story detail: dried glue drip from the cap down the shoulder onto the label.
            if l == 0 {
                var dr = rng.fork(5)
                let t0: Float = -.pi / 2 + 0.55
                var path: [V3] = [], radii: [Float] = []
                let steps = 18
                for i in 0...steps {
                    let u = Float(i) / Float(steps)
                    let y = yCap0 + 0.001 - u * (yCap0 + 0.001 - 0.109)
                    let t = t0 + 0.05 * sin(u * 4) + dr.float(-0.006...0.006)
                    let p = section(y, t)
                    let r: Float = 0.0017 + 0.0011 * u + (u > 0.84 ? 0.0016 * sin((u - 0.84) / 0.16 * .pi * 0.5) : 0)
                    let q = p - simd_normalize(p) * (r * 0.35)
                    path.append(V3(q.x, y, -q.y)); radii.append(r)
                }
                m.add(Prim.tube(path, radii: radii, sides: 7, seamTile: 0.02, material: "plastic.glue-dried"))
                // Crust ring where the drip starts.
                m.add(Prim.torus(major: neckRadius + 0.0021, minor: 0.0007, segments: 20, sides: 5, arc: 1.4, material: "plastic.glue-dried"),
                      Xform(translation: V3(0, yCap0 + 0.0006, 0), rotation: simd_quatf(angle: -t0 - 0.7, axis: V3(0, 1, 0))))
            }
            rig.base[l] = m
        }

        // MARK: cap (option 0 closed, 1 open)
        rig.part("cap", pivot: V3(0, yCap0, 0), joint: .fixed, options: 2)
        for l in 0..<2 {
            let pts = l == 0 ? 48 : 24, sg = l == 0 ? 28 : 14
            for opt in 0..<2 {
                // Ribbed skirt.
                let rS: Float = 0.0188
                var rings: [[V3]] = []
                for (y, sc) in [(Float(0), Float(0.985)), (0.0008, 1), (0.0155, 1), (0.0165, 0.985)] {
                    let o = (0..<pts).map { k -> V2 in
                        let a = Float(k) / Float(pts) * 2 * .pi
                        let rib: Float = l == 0 ? (k % 2 == 0 ? 0.0006 : 0) : 0
                        return V2(cos(a), sin(a)) * (rS + rib) * sc
                    }
                    rings.append(Prim.ring(o, y: yCap0 + y))
                }
                rig.add(Prim.loft(rings, material: capMaterial), to: "cap", option: opt, lods: l...l)
                // Dome top up to the nozzle base.
                let y1 = yCap0 + 0.0165
                rig.add(Prim.lathe([V2(rS * 0.985, y1), V2(0.0172, y1 + 0.0035), V2(0.0145, y1 + 0.0075), V2(0.0098, y1 + 0.0105), V2(0.0072, y1 + 0.0115)],
                                   segments: sg, seamTile: 0.1, material: capMaterial), to: "cap", option: opt, lods: l...l)
                // Nozzle: twists up when open, exposing the white stem.
                let lift: Float = opt == 1 ? nozzleLift : 0
                let yn = y1 + 0.0108 + lift
                if opt == 1 {
                    rig.add(Prim.lathe([V2(0.0052, y1 + 0.0105), V2(0.0052, yn + 0.002)], segments: sg, seamTile: 0.05, material: "plastic.matte:F2F0EA"), to: "cap", option: opt, lods: l...l)
                }
                rig.add(Prim.lathe([V2(0.0068, yn), V2(0.0071, yn + 0.0008), V2(0.0071, yn + 0.0042), V2(0.0058, yn + 0.0056), V2(0.0040, yn + 0.0105),
                                    V2(0.0024, yn + 0.0148), V2(0.0014, yTip - y1 - 0.0108 + yn - 0.0004), V2(0.0006, yTip - y1 - 0.0108 + yn)],
                                   segments: sg, seamTile: 0.05, material: capMaterial), to: "cap", option: opt, lods: l...l)
                // Grip flats on the nozzle collar.
                if l == 0 {
                    for k in 0..<6 {
                        let a = Float(k) / 6 * 2 * .pi
                        rig.add(Prim.roundedBox(V3(0.0012, 0.0036, 0.0022), radius: 0.0004, bevelSegments: 1, material: capMaterial),
                                Xform(translation: V3(cos(a) * 0.0072, yn + 0.0024, -sin(a) * 0.0072), rotation: simd_quatf(angle: a, axis: V3(0, 1, 0))),
                                to: "cap", option: opt, lods: l...l)
                    }
                }
                if opt == 1 && l == 0 {
                    // Wet glue bead at the open tip.
                    rig.add(Prim.superellipsoid(V3(0.0026, 0.0022, 0.0026), exponent: 2, subdivisions: 4, material: "plastic.glue-dried"),
                            Xform(translation: V3(0, yTip + lift + 0.0004, 0)), to: "cap", option: opt, lods: l...l)
                }
            }
        }
        groundAO(&rig, height: 0.03, floor: 0.6)
        rig.states = [RigState("closed"), RigState("open", options: ["cap": 1])]
        return rig
    }
}
