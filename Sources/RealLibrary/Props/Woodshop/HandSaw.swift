import simd
import Foundation

/// 20 in crosscut panel saw lying flat on the bench: taper-ground 0.9 mm steel plate (125 mm deep at
/// the heel, 45 mm at the toe) with 8 PPI crosscut teeth set alternately 0.18 mm per side, a closed
/// apple-wood tote (22 mm thick, hand hole, top and bottom horns) fixed with three slotted brass split
/// nuts, lacquer worn through where the palm rides. The saw rests on the tote cheek and the toe.
///
/// Authored in a tool frame (tooth line along +X from heel x = 0 to toe, plate in XY, teeth at y = 0
/// pointing -Y, thickness along Z), then laid down by `rest`. Points are in asset space.
public struct HandSaw: RealAsset {
    public static let id = "hand-saw"
    public static let summary = "20 in crosscut panel saw: taper-ground steel plate with set 8 PPI teeth, apple tote with three brass split nuts and a hand-worn grip."
    public static let tags = ["prop", "workshop", "tool", "handheld", "metal", "wood"]
    public static let budget = 7_200
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 18, elevation: 44, distance: 0.95)

    /// Tooth-line length heel to toe (m), 20 in.
    public var length: Float = 0.508
    /// Plate depth at the heel and toe (m).
    public var heelDepth: Float = 0.125
    public var toeDepth: Float = 0.045
    /// Teeth per inch (points per inch).
    public var ppi: Float = 8
    /// Tooth set per side (m).
    public var set: Float = 0.00018
    public var plate: MaterialKey = "metal.saw-plate"
    public var tote: MaterialKey = "wood.saw-tote"
    public var nuts: MaterialKey = "metal.brass-aged"
    public init() {}

    static let plateT: Float = 0.0009, toteT: Float = 0.022
    static let holeC = V2(-0.085, 0.072), holeAngle: Float = 70 * .pi / 180
    static let toteOutline: [V2] = [
        V2(0.004, 0.006), V2(0.012, 0.040), V2(0.006, 0.085), V2(-0.004, 0.118), V2(-0.026, 0.140), V2(-0.064, 0.150),
        V2(-0.104, 0.156), V2(-0.126, 0.150), V2(-0.124, 0.136), V2(-0.112, 0.124), V2(-0.118, 0.100), V2(-0.134, 0.060),
        V2(-0.150, 0.026), V2(-0.150, 0.008), V2(-0.128, 0.002), V2(-0.080, 0.003), V2(-0.030, 0.004),
    ]

    var pitch: Float { 0.0254 / ppi }

    /// Tool frame -> asset space: tilt about the tote's front edge until the toe touches the bench, lay the
    /// plate flat (tool +Z up, teeth toward +Z), lift onto y = 0, center on X/Z.
    func rest() -> Xform {
        let T = Self.toteT, xf: Float = 0.006
        let phi = atan((T / 2 - Self.plateT / 2) / (length - xf))
        let tilt = simd_quatf(angle: phi, axis: V3(0, 1, 0))
        let lay = simd_quatf(angle: -.pi / 2, axis: V3(1, 0, 0))
        let q = lay * tilt
        // Pivot (xf, *, -T/2) stays put through the tilt; after laying it sits at y = -T/2 -> lift by T/2.
        let pivot = V3(xf, 0, -T / 2)
        let tPivot = pivot - tilt.act(pivot)
        let xMin: Float = -0.150, xMax = length + 0.002, yMin: Float = 0, yMax: Float = 0.156
        var x = Xform(translation: lay.act(tPivot) + V3(0, T / 2, 0), rotation: q)
        let c = x.point(V3((xMin + xMax) / 2, (yMin + yMax) / 2, 0))
        x.translation += V3(-c.x, 0, -c.z)
        return x
    }

    /// Toe end of the tooth line (last tooth tip), asset space.
    public var toe: V3 { rest().point(V3(length - 0.0025, 0, 0)) }
    /// Heel end of the tooth line (first tooth tip next to the tote), asset space.
    public var heel: V3 { rest().point(V3(0.6 * pitch, 0, 0)) }
    /// Center of the hand hold: the middle of the tote's grip bar behind the hand hole, mid-thickness.
    public var grip: V3 {
        let across = V2(-sin(Self.holeAngle), cos(Self.holeAngle)) * -1
        let g = Self.holeC + across * 0.030
        return rest().point(V3(g.x, g.y, 0))
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let p = pitch, depth = p * 0.55
        let L = length, t = Self.plateT

        // MARK: plate (gullet line at y = depth; heel end hidden in the tote) and teeth
        let n = Int((L - 0.004) / p)
        var outline: [V2] = [V2(-0.045, depth), V2(L, depth)]
        outline += [V2(L + 0.0015, toeDepth * 0.5), V2(L, toeDepth - 0.001), V2(L - 0.003, toeDepth)]
        // Back edge: slight breasting (convex) from toe to heel.
        for k in 1...8 {
            let u = Float(k) / 9, x = L - 0.003 - (L - 0.003 + 0.02) * u
            let y = toeDepth + (heelDepth - toeDepth) * u + 0.004 * sin(u * .pi)
            outline.append(V2(x, y))
        }
        outline += [V2(-0.02, heelDepth), V2(-0.045, heelDepth)]
        var blade = HTKit.plate(outer: outline, depth: t, bevel: 0.0002, segments: 1, material: plate)
        // Taper grind: thinner toward the back and the toe.
        blade.deform { q in
            let back = max(0, min(1, (q.y - depth) / heelDepth)), toeward = max(0, min(1, q.x / L))
            return V3(q.x, q.y, q.z * (1 - 0.22 * back - 0.08 * toeward))
        }
        m.add(blade)
        // Teeth: crosscut points leaning toward the toe, alternately set to each side, filed bright at the tips.
        var teeth = Surface(material: plate)
        for k in 0..<n {
            let x0 = Float(k) * p
            let s: Float = k % 2 == 0 ? 1 : -1
            let tri = [V2(x0, depth + 0.0003), V2(x0 + 0.6 * p, 0), V2(x0 + p, depth + 0.0003)]
            var tooth = Prim.extrude(tri, depth: t * 0.96, bevel: 0, material: plate)
            let setAmt = set, d0 = depth
            tooth.deform { q in V3(q.x, q.y, q.z + s * setAmt * max(0, 1 - q.y / d0)) }
            teeth.append(tooth)
        }
        teeth.recomputeNormals(weldSeams: false); teeth.computeTangents()
        m.add(teeth)

        // MARK: tote
        let outer = HTKit.chaikin(Self.toteOutline, 3)
        let hole = HTKit.ellipse(Self.holeC, a: 0.043, b: 0.0165, angle: Self.holeAngle, n: 40)
        var wood = HTKit.plate(outer: outer, holes: [hole], depth: Self.toteT, bevel: 0.0055, segments: 3, material: tote)
        // Hand wear: palm on the grip bar and under the top horn, thumb on the cheek.
        let gripDir = V2(cos(Self.holeAngle), sin(Self.holeAngle))
        let wearC = Self.holeC + V2(-sin(Self.holeAngle), cos(Self.holeAngle)) * -0.03
        let jitter = rng.float(0...1)
        wood.paintSplat { q in
            let d = V2(q.x, q.y) - wearC
            let along = abs(simd_dot(d, gripDir)), across = abs(simd_dot(d, V2(-gripDir.y, gripDir.x)))
            let palm = (1 - smoothstep(0.03, 0.05, along)) * (1 - smoothstep(0.012, 0.022, across))
            let thumb = (1 - smoothstep(0.006, 0.016, simd_distance(V2(q.x, q.y), V2(-0.048, 0.118 + 0.004 * jitter)))) * (q.z > 0 ? 1 : 0)
            return max(palm, thumb * 0.8)
        }
        m.add(wood)

        // MARK: split nuts (slotted domes on top, plain domes on the underside, sunk flush)
        let nutPos: [V2] = [V2(-0.013, 0.030), V2(-0.020, 0.106), V2(-0.044, 0.068)]
        for (i, c) in nutPos.enumerated() {
            let r: Float = 0.0072
            let spin = rng.float(-40...40) + Float(i) * 25
            for half in HTKit.splitNut(radius: r, height: 0.0018, slot: 0.0011, material: nuts) {
                m.add(half, Xform(translation: V3(c.x, c.y, Self.toteT / 2 - 0.0006), rotation: simd_quatf(degrees: spin, axis: V3(0, 0, 1))))
            }
            let under = Prim.cylinder(radius: r * 0.95, height: 0.0012, bevel: 0.0005, segments: 20, bevelSegments: 1, material: nuts)
            m.add(under, Xform(translation: V3(c.x, c.y, -Self.toteT / 2 + 0.0006), rotation: simd_quatf(angle: -.pi / 2, axis: V3(1, 0, 0))))
        }

        // MARK: plate markings on the upper face: stamped tooth count at the heel, worn etched banner
        let hd = heelDepth, ln = L
        var etch = HTInk(material: "plastic.matte:4A4D52", normal: V3(0, 0, 1)) { q in
            let back = max(0, min(1, (q.y - depth) / hd)), toeward = max(0, min(1, q.x / ln))
            return V3(q.x, q.y, t / 2 * (1 - 0.22 * back - 0.08 * toeward) + 0.00003)
        }
        etch.digit(Int(ppi.rounded()), at: V2(0.010, 0.090), u: V2(1, 0), v: V2(0, 1), h: 0.0045, w: 0.0006)
        // Banner: double oval outline with ribbon tails, partly polished away.
        let ec = V2(0.085, 0.072)
        for (ra, rb) in [(Float(0.030), Float(0.0115)), (0.027, 0.0092)] {
            let n = 36
            for k in 0..<n where !(k > 22 && k < 27) {
                let a0 = Float(k) / Float(n) * 2 * .pi, a1 = Float(k + 1) / Float(n) * 2 * .pi
                etch.bar(ec + V2(cos(a0) * ra, sin(a0) * rb), ec + V2(cos(a1) * ra, sin(a1) * rb), 0.0004)
            }
        }
        for sx: Float in [-1, 1] {
            let a = ec + V2(sx * 0.030, 0.002)
            etch.bar(a, a + V2(sx * 0.010, 0.004), 0.0004); etch.bar(a + V2(sx * 0.010, 0.004), a + V2(sx * 0.008, -0.004), 0.0004)
            etch.bar(a + V2(sx * 0.008, -0.004), a + V2(0, -0.004), 0.0004)
        }
        for k in 0..<3 { let y = ec.y - 0.004 + Float(k) * 0.004; etch.bar(V2(ec.x - 0.016, y), V2(ec.x + 0.016 - Float(k) * 0.004, y), 0.0005) }
        m.add(etch.finished())

        let x = rest()
        var out = Model(name: Self.id)
        for s in m.surfaces { out.add(s, x) }
        groundAO(&out, height: 0.02, floor: 0.55)
        return LODModel(out)
    }
}
