import simd
import Foundation

/// Joinery and glazing helpers shared by the Facade structures. Box, cylinder and pipe helpers come
/// from `HK` (Hospital kit); this adds stile-and-rail leaves, sashes, casings and door hardware.
/// All helpers return surfaces in a local frame: X across, Y up from 0, Z out of the face.
enum FK {
    /// Box whose grain runs along Y (stiles, jambs): built lying along X and stood up.
    static func vbox(_ size: V3, _ c: V3, _ mat: MaterialKey, r: Float = 0.002) -> Surface {
        Prim.roundedBox(V3(size.y, size.x, size.z), radius: min(r, size.min() * 0.49), bevelSegments: 2, material: mat)
            .transformed(Xform(translation: c, rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
    }

    /// Fielded (raised) panel centered at `c`: flat ground with a chamfered raise on both faces.
    static func raisedPanel(w: Float, h: Float, t: Float, at c: V3, mat: MaterialKey, raise: Float = 0.035) -> [Surface] {
        let ground = HK.box(V3(w, h, t * 0.42), c, mat, r: 0.001, seg: 1)
        let fw = max(0.02, w - 2 * raise), fh = max(0.02, h - 2 * raise)
        var field = Prim.extrude(Shape2D.rect(fw + 2 * raise * 0.8, fh + 2 * raise * 0.8), depth: t * 0.62,
                                 bevel: raise * 0.8, bevelSegments: 1, material: mat)
        field = field.transformed(Xform(translation: c))
        return [ground, field]
    }

    /// Stile-and-rail leaf, base at y = 0, centered on X and Z. `rows` lists panel heights bottom up
    /// (fractions, normalized); `cols` panels per row. Rows whose index is in `glazed` get glass lites
    /// with `muntins` (cols x rows) instead of raised panels. Mid rails sit between rows.
    static func panelLeaf(w: Float, h: Float, t: Float, rows: [Float], cols: Int, stile: Float = 0.12,
                          bottomRail: Float = 0.24, topRail: Float = 0.12, midRail: Float = 0.11,
                          mat: MaterialKey, glazed: Set<Int> = [], glass: MaterialKey = "glass.pane",
                          muntins: (Int, Int) = (1, 1), mullion: Float = 0.1) -> [Surface] {
        var out: [Surface] = []
        for sx: Float in [-1, 1] { out.append(vbox(V3(stile, h, t), V3(sx * (w / 2 - stile / 2), h / 2, 0), mat, r: 0.003)) }
        let innerW = w - 2 * stile
        let free = h - bottomRail - topRail - midRail * Float(rows.count - 1)
        let total = rows.reduce(0, +)
        out.append(HK.box(V3(innerW + 0.002, bottomRail, t - 0.002), V3(0, bottomRail / 2, 0), mat, r: 0.003))
        out.append(HK.box(V3(innerW + 0.002, topRail, t - 0.002), V3(0, h - topRail / 2, 0), mat, r: 0.003))
        var y = bottomRail
        for (ri, frac) in rows.enumerated() {
            let ph = free * frac / total
            let colW = (innerW - mullion * Float(cols - 1)) / Float(cols)
            for ci in 0..<cols {
                let cx = -innerW / 2 + colW / 2 + Float(ci) * (colW + mullion)
                if glazed.contains(ri) {
                    out += lite(w: colW, h: ph, t: t, at: V3(cx, y + ph / 2, 0), mat: mat, glass: glass, muntins: muntins)
                } else {
                    out += raisedPanel(w: colW + 0.004, h: ph + 0.004, t: t, at: V3(cx, y + ph / 2, 0), mat: mat)
                }
                if ci < cols - 1 {
                    out.append(vbox(V3(mullion + 0.002, ph + 0.002, t - 0.003), V3(cx + colW / 2 + mullion / 2, y + ph / 2, 0), mat, r: 0.003))
                }
            }
            y += ph
            if ri < rows.count - 1 {
                out.append(HK.box(V3(innerW + 0.002, midRail, t - 0.002), V3(0, y + midRail / 2, 0), mat, r: 0.003))
                y += midRail
            }
        }
        return out
    }

    /// Glass lite in an opening of a leaf or sash: pane, glazing beads both faces, muntin grid.
    static func lite(w: Float, h: Float, t: Float, at c: V3, mat: MaterialKey, glass: MaterialKey,
                     muntins: (Int, Int) = (1, 1), bead: Float = 0.012, muntinW: Float = 0.02) -> [Surface] {
        var out: [Surface] = [HK.box(V3(w + 0.006, h + 0.006, 0.006), c, glass, r: 0.001, seg: 1)]
        for sz: Float in [-1, 1] {
            let z = c.z + sz * (0.003 + bead / 2)
            for sy: Float in [-1, 1] { out.append(HK.box(V3(w, bead, bead), V3(c.x, c.y + sy * (h / 2 - bead / 2), z), mat, r: 0.003, seg: 1)) }
            for sx: Float in [-1, 1] { out.append(vbox(V3(bead, h - 2 * bead + 0.002, bead), V3(c.x + sx * (w / 2 - bead / 2), c.y, z), mat, r: 0.003)) }
        }
        let (mc, mr) = muntins
        for i in 1..<max(1, mc) {
            let x = c.x - w / 2 + w * Float(i) / Float(mc)
            out.append(vbox(V3(muntinW, h, t * 0.7), V3(x, c.y, c.z), mat, r: 0.004))
        }
        for j in 1..<max(1, mr) {
            let y = c.y - h / 2 + h * Float(j) / Float(mr)
            out.append(HK.box(V3(w, muntinW, t * 0.68), V3(c.x, y, c.z), mat, r: 0.004, seg: 1))
        }
        return out
    }

    /// Window sash (rectangular frame with glass and muntins), base y = 0, centered.
    static func sash(w: Float, h: Float, t: Float, stile: Float = 0.055, top: Float = 0.055, bottom: Float = 0.07,
                     mat: MaterialKey, glass: MaterialKey = "glass.pane", muntins: (Int, Int) = (1, 1), meetingRail: Float? = nil) -> [Surface] {
        var out: [Surface] = []
        for sx: Float in [-1, 1] { out.append(vbox(V3(stile, h, t), V3(sx * (w / 2 - stile / 2), h / 2, 0), mat, r: 0.003)) }
        let iw = w - 2 * stile
        out.append(HK.box(V3(iw + 0.002, bottom, t - 0.002), V3(0, bottom / 2, 0), mat, r: 0.003))
        let tr = meetingRail ?? top
        out.append(HK.box(V3(iw + 0.002, tr, t - 0.002), V3(0, h - tr / 2, 0), mat, r: 0.003))
        let ih = h - bottom - tr
        out += lite(w: iw, h: ih, t: t, at: V3(0, bottom + ih / 2, 0), mat: mat, glass: glass, muntins: muntins, bead: 0.01, muntinW: 0.018)
        return out
    }

    /// Flat casing around an opening on the face plane z (outward normal +Z): two legs and a head
    /// with a back band step. `head` overhangs the legs by `ears`.
    static func casing(openW: Float, openH: Float, width: Float, thick: Float, z: Float, y0: Float = 0,
                       mat: MaterialKey, headHeight: Float? = nil, ears: Float = 0.015) -> [Surface] {
        var out: [Surface] = []
        for sx: Float in [-1, 1] {
            out.append(vbox(V3(width, openH, thick), V3(sx * (openW / 2 + width / 2), y0 + openH / 2, z + thick / 2), mat, r: 0.003))
            // Back band: a thicker bead on the outer edge.
            out.append(vbox(V3(0.02, openH + (headHeight ?? width), thick + 0.012), V3(sx * (openW / 2 + width + 0.01), y0 + (openH + (headHeight ?? width)) / 2, z + (thick + 0.012) / 2), mat, r: 0.004))
        }
        let hh = headHeight ?? width
        out.append(HK.box(V3(openW + 2 * width + 0.04 + 2 * ears, hh, thick + 0.014), V3(0, y0 + openH + hh / 2, z + (thick + 0.014) / 2), mat, r: 0.004))
        // Drip cap over the head.
        out.append(HK.box(V3(openW + 2 * width + 0.06 + 2 * ears, 0.022, thick + 0.045), V3(0, y0 + openH + hh + 0.011, z + (thick + 0.045) / 2), mat, r: 0.006))
        return out
    }

    /// Exterior knob on a round rose, axis along `n` (unit ±Z), face plane at `c`.
    static func knob(at c: V3, n: V3, mat: MaterialKey, r: Float = 0.029) -> Surface {
        let profile = [V2(0, 0), V2(0.027, 0), V2(0.027, 0.004), V2(0.022, 0.008), V2(0.008, 0.012), V2(0.008, 0.035),
                       V2(r * 0.75, 0.045), V2(r, 0.058), V2(r * 0.95, 0.068), V2(r * 0.6, 0.075), V2(0, 0.077)]
        return Prim.lathe(profile, segments: 24, seamTile: 0.05, material: mat).transformed(Xform(translation: c, rotation: facing(n)))
    }

    /// Mortise lock escutcheon plate with keyhole, center `c`, face normal `n`.
    static func escutcheon(at c: V3, n: V3, mat: MaterialKey) -> [Surface] {
        let q = facing(n)
        let plate = Prim.extrude(Shape2D.roundedRect(0.045, 0.16, radius: 0.012), depth: 0.004, bevel: 0.0015, bevelSegments: 1, material: mat)
            .transformed(Xform(translation: c + n * 0.002, rotation: simd_quatf(from: V3(0, 0, 1), to: n)))
        let key = Prim.cylinder(radius: 0.005, height: 0.002, bevel: 0.0005, segments: 12, bevelSegments: 1, material: "plastic.black")
            .transformed(Xform(translation: c + n * 0.0035 + V3(0, -0.045, 0), rotation: q))
        return [plate, key]
    }

    /// Butt hinge knuckle split in five: alternate segments go to `frame` (even) and `leaf` (odd).
    static func hingeKnuckles(at p: V3, length: Float = 0.1, r: Float = 0.007, mat: MaterialKey) -> (frame: [Surface], leaf: [Surface]) {
        var f: [Surface] = [], l: [Surface] = []
        let seg = length / 5
        for k in 0..<5 {
            let s = Prim.cylinder(radius: r, height: seg - 0.0008, bevel: 0.0008, segments: 14, bevelSegments: 1, material: mat)
                .transformed(Xform(translation: V3(p.x, p.y - length / 2 + Float(k) * seg + 0.0004, p.z)))
            if k % 2 == 0 { f.append(s) } else { l.append(s) }
        }
        return (f, l)
    }

    /// Repeating corrugation helper: a strip of `n` boxes along X between x0 and x1.
    static func slats(n: Int, x0: Float, x1: Float, size: V3, y: Float, z: Float, mat: MaterialKey) -> [Surface] {
        (0..<n).map { i in
            let x = x0 + (x1 - x0) * (Float(i) + 0.5) / Float(n)
            return HK.box(size, V3(x, y, z), mat, r: min(0.003, size.min() * 0.4), seg: 1)
        }
    }
}

extension Model {
    mutating func add(_ ss: [Surface]) { for s in ss { add(s) } }
}

extension Rig {
    mutating func add(_ ss: [Surface], to part: String, lods: ClosedRange<Int>? = nil) { for s in ss { add(s, .identity, to: part, lods: lods) } }
    /// Adds surfaces to every base LOD (or `lods`).
    mutating func addBase(_ ss: [Surface], lods: ClosedRange<Int>? = nil) {
        let r = lods ?? 0...(base.count - 1)
        for l in r where l < base.count { for s in ss { base[l].add(s) } }
    }
}

extension FK {
    /// Moves a whole rig (static base, every part, pivots and lights) by `d`; used to center wall
    /// openings whose stoop or cornice projects far in front of the wall plane.
    static func shift(_ rig: inout Rig, by d: V3) {
        let x = Xform(translation: d)
        for l in rig.base.indices { rig.base[l] = rig.base[l].transformed(x) }
        for p in rig.parts.indices {
            rig.parts[p].levels = rig.parts[p].levels.map { $0.transformed(x) }
            rig.parts[p].alternates = rig.parts[p].alternates.map { $0.map { $0.transformed(x) } }
            if rig.parts[p].parent == nil { rig.parts[p].pivot.translation += d }
        }
        for i in rig.lights.indices { rig.lights[i].position += d }
    }
}
