import simd
import Foundation

/// Kitchen joinery helpers shared by cabinets, counters and appliances (RealityHD 6).
public enum KitchenFit {
    /// A rounded rectangle in the XZ plane (top view): points with outward normals, `n` arc steps per
    /// corner (n + 1 points per corner), wound counter-clockwise seen from +Y.
    static func rrect(center c: V2, size: V2, radius: Float, n: Int) -> [(p: V2, n: V2)] {
        let r = max(1e-4, min(radius, min(size.x, size.y) / 2 - 1e-4))
        let hx = size.x / 2 - r, hz = size.y / 2 - r
        // Corner centers in CCW order seen from +Y (x right, z toward the viewer = down the screen):
        // +x-z, -x-z, -x+z, +x+z; start angles 0, 90, 180, 270 (angle measured from +x toward -z).
        let corners: [(V2, Float)] = [(V2(hx, -hz), 0), (V2(-hx, -hz), 90), (V2(-hx, hz), 180), (V2(hx, hz), 270)]
        var out: [(V2, V2)] = []
        for (cc, a0) in corners {
            for i in 0...n {
                let a = (a0 + 90 * Float(i) / Float(n)) * .pi / 180
                let d = V2(cos(a), -sin(a))
                out.append((c + cc + d * r, d))
            }
        }
        return out.map { (p: $0.0, n: $0.1) }
    }

    /// Stone counter slab, top at y = `thickness`, bottom at 0, centered on X/Z: eased top and bottom
    /// edges (`ease` radius), slightly rounded plan corners, and an optional rounded-rect cutout
    /// (undermount sink) with a polished, eased inner edge. UVs in meters (top: x, z).
    public static func counterSlab(width: Float, depth: Float, thickness: Float, ease: Float = 0.003, corner: Float = 0.003,
                                   hole: (center: V2, size: V2, radius: Float)? = nil, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let n = 4, steps = 3
        let outerTop = rrect(center: .zero, size: V2(width - 2 * ease, depth - 2 * ease), radius: max(0.0005, corner - ease), n: n)
        // Side walls: profile rings from bottom to top (inset d, height y, normal mix).
        var rings: [(inset: Float, y: Float, nh: Float, ny: Float)] = []
        let eb = ease * 0.5
        for i in 0...steps { let a = Float(i) / Float(steps) * .pi / 2; rings.append((eb * (1 - sin(a)), eb * (1 - cos(a)), sin(a), -cos(a))) }
        for i in 0...steps { let a = Float(i) / Float(steps) * .pi / 2; rings.append((ease * (1 - cos(a)), thickness - ease + ease * sin(a), cos(a), sin(a))) }
        let count = outerTop.count
        var ringIdx: [[UInt32]] = []
        var pv: [Float] = [0]
        for j in 1..<rings.count { pv.append(pv[j - 1] + simd_length(V2(rings[j].inset - rings[j - 1].inset, rings[j].y - rings[j - 1].y))) }
        var arc: [Float] = [0]
        for i in 1..<count { arc.append(arc[i - 1] + simd_distance(outerTop[i].p, outerTop[i - 1].p)) }
        arc.append(arc[count - 1] + simd_distance(outerTop[0].p, outerTop[count - 1].p))
        for (j, r) in rings.enumerated() {
            var row: [UInt32] = []
            for i in 0...count {
                let k = i % count
                let o = outerTop[k]
                let p2 = o.p + o.n * (ease - r.inset)
                let nn = simd_normalize(V3(o.n.x * r.nh, r.ny, o.n.y * r.nh))
                row.append(s.add(V3(p2.x, r.y, p2.y), nn, V2(arc[i], pv[j])))
            }
            ringIdx.append(row)
        }
        for j in 0..<(ringIdx.count - 1) { for i in 0..<count {
            let a = ringIdx[j][i], b = ringIdx[j][i + 1], c = ringIdx[j + 1][i + 1], d = ringIdx[j + 1][i]
            // CCW seen from outside: along the ring (CCW from +Y), then up.
            s.quad(a, b, c, d)
        }}
        // Top and bottom faces.
        let topOuter = outerTop.map { $0.p }
        let botOuter = outerTop.map { $0.p + $0.n * (ease - eb) }
        if let h = hole {
            let he = min(0.002, ease)
            let inner = rrect(center: h.center, size: h.size + V2(2 * he, 2 * he), radius: h.radius + he, n: n)
            let innerBot = rrect(center: h.center, size: h.size, radius: h.radius, n: n)
            func capRing(_ outer: [V2], _ inner: [V2], y: Float, up: Bool) {
                let nn = V3(0, up ? 1 : -1, 0)
                let o = outer.map { s.add(V3($0.x, y, $0.y), nn, $0) }
                let i = inner.map { s.add(V3($0.x, y, $0.y), nn, $0) }
                for k in 0..<o.count {
                    let k1 = (k + 1) % o.count
                    if up { s.quad(o[k], o[k1], i[k1], i[k]) } else { s.quad(o[k], i[k], i[k1], o[k1]) }
                }
            }
            capRing(topOuter, inner.map { $0.p }, y: thickness, up: true)
            capRing(botOuter, innerBot.map { $0.p }, y: 0, up: false)
            // Cutout wall (faces inward) with an eased top lip.
            var hr: [[UInt32]] = []
            let lip: [(Float, Float, Float, Float)] = (0...steps).map { i in
                let a = Float(i) / Float(steps) * .pi / 2
                return (he * (1 - cos(a)), thickness - he + he * sin(a), cos(a), sin(a))
            }
            let wall: [(Float, Float, Float, Float)] = [(0, 0, 1, 0)] + lip
            let hp = innerBot
            var harc: [Float] = [0]
            for i in 1..<hp.count { harc.append(harc[i - 1] + simd_distance(hp[i].p, hp[i - 1].p)) }
            harc.append(harc[hp.count - 1] + simd_distance(hp[0].p, hp[hp.count - 1].p))
            var wv: [Float] = [0]
            for j in 1..<wall.count { wv.append(wv[j - 1] + simd_length(V2(wall[j].0 - wall[j - 1].0, wall[j].1 - wall[j - 1].1))) }
            for (j, (inset, y, nh, ny)) in wall.enumerated() {
                var row: [UInt32] = []
                for i in 0...hp.count {
                    let q = hp[i % hp.count]
                    let p2 = q.p + q.n * inset
                    row.append(s.add(V3(p2.x, y, p2.y), simd_normalize(V3(-q.n.x * nh, ny, -q.n.y * nh)), V2(harc[i], wv[j])))
                }
                hr.append(row)
            }
            for j in 0..<(hr.count - 1) { for i in 0..<hp.count {
                s.quad(hr[j][i], hr[j + 1][i], hr[j + 1][i + 1], hr[j][i + 1])
            }}
        } else {
            for (pts, y, up) in [(topOuter, thickness, true), (botOuter, Float(0), false)] {
                let nn = V3(0, up ? 1 : -1, 0)
                let c = s.add(V3(0, y, 0), nn, .zero)
                let idx = pts.map { s.add(V3($0.x, y, $0.y), nn, $0) }
                for k in 0..<idx.count {
                    let k1 = (k + 1) % idx.count
                    if up { s.tri(c, idx[k], idx[k1]) } else { s.tri(c, idx[k1], idx[k]) }
                }
            }
        }
        s.computeTangents()
        return s
    }

    /// Five-piece shaker door or drawer front, front face at z = 0 facing +Z, centered on X/Y:
    /// stiles full height, rails between them (hairline joints), a recessed flat center panel.
    /// `frame` stile/rail width, `t` thickness. Stile grain runs vertical (rotated boards).
    public static func shakerFront(_ m: inout Model, width w: Float, height h: Float, t: Float = 0.019, frame: Float = 0.07,
                                   railFrame: Float? = nil, at c: V3, material: MaterialKey, bottomRail: MaterialKey? = nil, panel: MaterialKey? = nil, lite: Bool = false) {
        let rf = railFrame ?? frame
        let fz = c.z - t / 2
        let edge: Float = 0.0028
        let seg = lite ? 1 : 2
        if lite {
            m.add(Prim.roundedBox(V3(w, h, t), radius: edge, bevelSegments: 1, material: material), Xform(translation: V3(c.x, c.y, fz)))
            return
        }
        for sx: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(h, frame, t), radius: edge, bevelSegments: seg, material: material),
                  Xform(translation: V3(c.x + sx * (w / 2 - frame / 2), c.y, fz), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        }
        for sy: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(w - 2 * frame - 0.0006, rf, t), radius: edge, bevelSegments: seg, material: sy < 0 ? (bottomRail ?? material) : material),
                  Xform(translation: V3(c.x, c.y + sy * (h / 2 - rf / 2), fz)))
        }
        // Recessed flat panel, 9 mm back from the frame face.
        let pw = w - 2 * frame + 0.004, ph = h - 2 * rf + 0.004
        if let glass = panel {
            m.add(cuboid(V3(pw, ph, 0.004), material: glass), Xform(translation: V3(c.x, c.y, c.z - 0.012)))
        } else {
            m.add(Prim.roundedBox(V3(pw, ph, 0.007), radius: 0.001, bevelSegments: 1, material: material),
                  Xform(translation: V3(c.x, c.y, c.z - 0.009 - 0.0035)))
        }
        // Inner square edge of the frame: thin fillet strips where the panel meets the frame (shadow line).
        _ = rf
    }

    /// Concealed cup hinge (Euro hinge): cup plate on the door back, arm to the mounting plate on the side.
    /// Door back face at z = 0, hinge side toward -X (mirror with `side`).
    public static func cupHinge(_ m: inout Model, at p: V3, side: Float, material: MaterialKey) {
        // Cup 35 mm, centred 22.5 mm in from the door edge; arm straight back to the side-panel plate.
        m.add(Prim.cylinder(radius: 0.0175, height: 0.003, bevel: 0.0008, segments: 14, bevelSegments: 1, material: material),
              Xform(translation: p + V3(-side * 0.0225, 0, 0), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
        m.add(Prim.roundedBox(V3(0.014, 0.018, 0.05), radius: 0.002, bevelSegments: 1, material: material),
              Xform(translation: p + V3(-side * 0.03, 0, -0.026)))
        m.add(Prim.roundedBox(V3(0.004, 0.05, 0.03), radius: 0.001, bevelSegments: 1, material: material),
              Xform(translation: p + V3(-side * 0.0185, 0, -0.04)))
    }

    /// Moves a whole rig (base, parts, pivots, lights) by `o` in asset space.
    public static func shift(_ rig: inout Rig, by o: V3) {
        let x = Xform(translation: o)
        rig.base = rig.base.map { $0.transformed(x) }
        for i in rig.parts.indices {
            rig.parts[i].levels = rig.parts[i].levels.map { $0.transformed(x) }
            rig.parts[i].alternates = rig.parts[i].alternates.map { $0.map { $0.transformed(x) } }
            rig.parts[i].pivot.translation += o
        }
        for i in rig.lights.indices { rig.lights[i].position += o }
    }
}
