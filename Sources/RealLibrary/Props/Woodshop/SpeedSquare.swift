import simd
import Foundation

/// 7 in aluminum rafter (speed) square lying on the bench: 3.5 mm cast plate, a right triangle with 178 mm
/// legs; a lipped fence 19 mm deep along one leg that tips the plate so it rests on the fence and the far
/// corner; a triangular lightening window and a scribing slot with notches every 1/4 in; engraved and
/// black-filled inch scale (1/8 in ticks) along the leg square to the fence, degree scale (0-90, every
/// degree, labels every 10) along the hypotenuse, pivot mark at the fence's square corner.
///
/// Tool frame: the plate in XY with the square corner (pivot) at the origin, fence leg along +X, ruler leg
/// along +Y, fence bearing face at y = -`lip`, plate thickness along Z (markings on +Z).
public struct SpeedSquare: RealAsset {
    public static let id = "speed-square"
    public static let summary = "7 in aluminum rafter square: lipped fence, pivot corner, engraved inch and degree scales, cut-out window and scribing slot."
    public static let tags = ["prop", "workshop", "tool", "handheld", "metal"]
    public static let budget = 7_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 12, elevation: 52, distance: 0.42)

    /// Leg length (m), 7 in.
    public var leg: Float = 0.1778
    public var body: MaterialKey = "metal.diecast"
    public var ink: MaterialKey = "plastic.matte:1C1C1E"
    public init() {}

    static let plateT: Float = 0.0035, lipW: Float = 0.0064, lipD: Float = 0.019

    /// Tilt about the fence's lower inner edge until the far corner touches, lay flat (tool +Z up), center.
    func rest() -> Xform {
        let L = leg, hz = Self.lipD / 2, pz = Self.plateT / 2
        let beta = atan((hz - pz) / (L - 0.004))
        let tilt = simd_quatf(angle: -beta, axis: V3(1, 0, 0))
        let lay = simd_quatf(angle: -.pi / 2, axis: V3(1, 0, 0))
        let pivotLine = V3(0, 0, -hz)
        var x = Xform(translation: lay.act(pivotLine - tilt.act(pivotLine)) + V3(0, hz, 0), rotation: lay * tilt)
        let c = x.point(V3(L / 2, (L - Self.lipW) / 2, 0))
        x.translation += V3(-c.x, 0, -c.z)
        return x
    }

    /// Pivot point: the square corner at the end of the fence, on the bearing face, mid-thickness.
    public var pivot: V3 { rest().point(V3(0, -Self.lipW, 0)) }
    /// Midpoint of the fence bearing face (the edge held against the stock), mid-depth.
    public var fenceEdge: V3 { rest().point(V3(leg / 2, -Self.lipW, 0)) }
    /// Unit direction along the fence bearing face, from the pivot toward the far end.
    public var fenceEdgeDirection: V3 { rest().direction(V3(1, 0, 0)) }
    /// Center of the hand hold: the plate just above the fence, middle of its length.
    public var grip: V3 { rest().point(V3(leg * 0.42, 0.03, 0)) }

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let L = leg, t = Self.plateT

        // MARK: plate with the window and the scribing slot
        let outer = Shape2D.rounded([V2(-0.0005, 0), V2(L, 0), V2(0, L)], radius: 0.004, segments: 4)
        let win = Shape2D.rounded([V2(0.052, 0.024), V2(L - 0.062, 0.024), V2(0.052, L - 0.086)], radius: 0.007, segments: 5)
        // Scribing slot parallel to the ruler leg, notched every 1/4 in on its outer side.
        var slot: [V2] = []
        let sx0: Float = 0.026, sx1: Float = 0.0325, sy0: Float = 0.024, sy1: Float = 0.1265
        slot.append(V2(sx0, sy0)); slot.append(V2(sx1, sy0)); slot.append(V2(sx1, sy1)); slot.append(V2(sx0, sy1))
        var notched: [V2] = []
        for (i, p) in slot.enumerated() {
            notched.append(p)
            if i == 3 {
                var y = sy1 - 0.00635
                while y > sy0 + 0.004 {
                    notched += [V2(sx0, y + 0.0011), V2(sx0 - 0.0016, y + 0.0007), V2(sx0 - 0.0016, y - 0.0007), V2(sx0, y - 0.0011)]
                    y -= 0.00635
                }
            }
        }
        var plate = HTKit.plate(outer: outer, holes: [win, Shape2D.rounded(notched, radius: 0.0003, segments: 1)], depth: t, bevel: 0.0003,
                                segments: 2, material: body)
        plate.recomputeNormals(weldSeams: false)
        m.add(plate)
        // Fence lip: full length, protruding both faces.
        m.add(Prim.roundedBox(V3(L + 0.0005, Self.lipW, Self.lipD), radius: 0.0018, bevelSegments: 3, material: body),
              Xform(translation: V3(L / 2 - 0.0003, -Self.lipW / 2 + 0.0004, 0)))

        // MARK: engraved, ink-filled markings on the top face (+Z)
        var ink = Surface(material: self.ink)
        let zTop = t / 2 + 0.00004
        func bar(_ a: V2, _ b: V2, _ w: Float) {
            let d = simd_normalize(b - a), n = V2(-d.y, d.x) * (w / 2)
            let i0 = ink.add(V3(a.x - n.x, a.y - n.y, zTop), V3(0, 0, 1), a - n)
            let i1 = ink.add(V3(b.x - n.x, b.y - n.y, zTop), V3(0, 0, 1), b - n)
            let i2 = ink.add(V3(b.x + n.x, b.y + n.y, zTop), V3(0, 0, 1), b + n)
            let i3 = ink.add(V3(a.x + n.x, a.y + n.y, zTop), V3(0, 0, 1), a + n)
            ink.quad(i0, i1, i2, i3)
        }
        // Seven-segment stroke digits, height h, lower-left at o, along direction u (up = v).
        let masks = [63, 6, 91, 79, 102, 109, 125, 7, 127, 111]
        func digit(_ dgt: Int, at o: V2, u: V2, v: V2, h: Float, w: Float) {
            let gw = h * 0.5
            func P(_ a: Float, _ b: Float) -> V2 { o + u * (a * gw) + v * (b * h) }
            if dgt == 1 { bar(P(0.55, 0), P(0.55, 1), w); return }
            let segs: [(Float, Float, Float, Float)] = [(0, 1, 1, 1), (1, 1, 1, 0.5), (1, 0.5, 1, 0), (0, 0, 1, 0), (0, 0.5, 0, 0), (0, 1, 0, 0.5), (0, 0.5, 1, 0.5)]
            for (k, s) in segs.enumerated() where masks[dgt] & (1 << k) != 0 { bar(P(s.0, s.1), P(s.2, s.3), w) }
        }
        func number(_ n: Int, center c: V2, u: V2, v: V2, h: Float, w: Float) {
            let ds = String(n).compactMap { Int(String($0)) }
            let gw = h * 0.5, gap = h * 0.28
            let total = Float(ds.count) * gw + Float(ds.count - 1) * gap
            var o = c - u * (total / 2) - v * (h / 2)
            for d in ds { digit(d, at: o, u: u, v: v, h: h, w: w); o += u * (gw + gap) }
        }
        // Inch scale along the ruler leg (x = 0 edge): 1/8 in ticks.
        let inch: Float = 0.0254
        var k = 1
        while Float(k) * inch / 8 < L - 0.012 {
            let y = Float(k) * inch / 8
            let len: Float = k % 8 == 0 ? 0.0085 : (k % 4 == 0 ? 0.0062 : (k % 2 == 0 ? 0.0046 : 0.0032))
            bar(V2(0.0012, y), V2(0.0012 + len, y), k % 8 == 0 ? 0.00042 : 0.0003)
            if k % 8 == 0 { number(k / 8, center: V2(0.0155, y), u: V2(0, 1), v: V2(-1, 0), h: 0.0046, w: 0.00042) }
            k += 1
        }
        // Degree scale along the hypotenuse: rays from the pivot, 1 degree ticks, labels every 10.
        for deg in 1..<90 {
            let a = Float(deg) * .pi / 180
            let dir = V2(cos(a), sin(a))
            let r = L / (cos(a) + sin(a))                       // ray from the pivot hits x + y = L
            let len: Float = deg % 10 == 0 ? 0.0095 : (deg % 5 == 0 ? 0.0068 : 0.0042)
            let edge = r - 0.0016 * 1.414 / (cos(a) + sin(a)) * (cos(a) + sin(a))
            bar(V2(dir.x * (edge - len), dir.y * (edge - len)), V2(dir.x * edge, dir.y * edge), deg % 5 == 0 ? 0.0004 : 0.00028)
            if deg % 10 == 0 {
                let c = dir * (edge - len - 0.0055)
                number(deg, center: c, u: V2(-dir.y, dir.x) * -1, v: dir, h: 0.0042, w: 0.0004)
            }
        }
        // Pivot mark: small filled triangle at the square corner, and the rafter-scale rule line.
        let pv = [V2(0.003, 0.003), V2(0.009, 0.003), V2(0.003, 0.009)]
        let i0 = ink.add(V3(pv[0].x, pv[0].y, zTop), V3(0, 0, 1), pv[0]), i1 = ink.add(V3(pv[1].x, pv[1].y, zTop), V3(0, 0, 1), pv[1])
        let i2 = ink.add(V3(pv[2].x, pv[2].y, zTop), V3(0, 0, 1), pv[2])
        ink.tri(i0, i1, i2)
        bar(V2(0.012, 0.0145), V2(L - 0.03, 0.0145), 0.00035)
        ink.computeTangents()
        m.add(ink)
        // Story detail: soft graphite marks from marking out (a tally and a crow's-foot near the fence).
        var rng = SeededRNG(seed: seed)
        var marks = Surface(material: "plastic.matte:5A5C60")
        func stroke(_ pts: [V2], _ w: Float) {
            for k in 0..<(pts.count - 1) {
                let a = pts[k], b = pts[k + 1], d = simd_normalize(b - a), n = V2(-d.y, d.x) * (w / 2)
                let z = t / 2 + 0.00003
                let i0 = marks.add(V3(a.x - n.x, a.y - n.y, z), V3(0, 0, 1), a), i1 = marks.add(V3(b.x - n.x, b.y - n.y, z), V3(0, 0, 1), b)
                let i2 = marks.add(V3(b.x + n.x, b.y + n.y, z), V3(0, 0, 1), b), i3 = marks.add(V3(a.x + n.x, a.y + n.y, z), V3(0, 0, 1), a)
                marks.quad(i0, i1, i2, i3)
            }
        }
        let mx = rng.float(0.095...0.11), my: Float = 0.006
        for k in 0..<4 { let x = mx + Float(k) * 0.0028; stroke([V2(x, my), V2(x + 0.0004, my + 0.0055 + rng.float(-0.0006...0.0006))], 0.0005) }
        stroke([V2(mx - 0.001, my + 0.001), V2(mx + 0.0105, my + 0.0048)], 0.0005)
        let cx = rng.float(0.062...0.07)
        stroke([V2(cx, 0.004), V2(cx, 0.0105)], 0.00055)
        stroke([V2(cx - 0.0028, 0.0105), V2(cx, 0.0072), V2(cx + 0.0028, 0.0105)], 0.0005)
        marks.computeTangents()
        m.add(marks)

        let x = rest()
        var out = Model(name: Self.id)
        for s in m.surfaces { out.add(s, x) }
        groundAO(&out, height: 0.012, floor: 0.6)
        return LODModel(out)
    }
}
