import simd
import Foundation

/// Mesh helpers shared by the utility truck assets (bucket truck, cab interior, aerial bucket).
enum VK {
    /// Prism from a side outline given in (z, y) and extruded `width` along X, centered on `x`.
    static func side(_ outline: [V2], width: Float, x: Float = 0, bevel: Float = 0.01, seg: Int = 2, mat: MaterialKey) -> Surface {
        Prim.extrude(outline, depth: width, bevel: bevel, bevelSegments: seg, material: mat)
            .transformed(Xform(translation: V3(x, 0, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 1, 0))))
    }

    /// Box spanning two corners.
    static func span(_ a: V3, _ b: V3, _ mat: MaterialKey, r: Float = 0.004, seg: Int = 1) -> Surface {
        HK.box(simd_abs(b - a), (a + b) / 2, mat, r: r, seg: seg)
    }

    /// Fiberglass one-man bucket, 0.6 x 0.6 x 1.07 m, outer floor at `o` (center of the bottom).
    /// Gelcoat shell with a rolled top lip, dark polyethylene liner with flange, molded side step on +Z,
    /// boom mounting plate with bolts on -Z, two tool hooks on +X, lanyard D-ring.
    static func bucket(_ o: V3, lod: Int, shell: MaterialKey = "fiberglass.bucket", liner: MaterialKey = "plastic.matte:3A3D40") -> [Surface] {
        var out: [Surface] = []
        let segs = lod == 0 ? 4 : 2
        func rr(_ w: Float, _ r: Float) -> [V2] { Shape2D.roundedRect(w, w, radius: r, segments: segs) }
        // Outer shell: slight taper (0.56 base to 0.60 at the top), rolled lip to 0.63.
        let outer: [(Float, Float, Float)] = [(0.54, 0.0, 0.06), (0.56, 0.03, 0.08), (0.6, 1.0, 0.1), (0.63, 1.03, 0.11), (0.63, 1.06, 0.11), (0.6, 1.07, 0.1), (0.57, 1.07, 0.085)]
        out.append(Prim.loft(outer.map { Prim.ring(rr($0.0, $0.2), y: $0.1, offset: o) }, capStart: true, material: shell))
        // Liner: flange on the lip, walls down to the floor (rings run down so normals face the cavity).
        let lin: [(Float, Float, Float)] = [(0.615, 1.072, 0.105), (0.6, 1.078, 0.1), (0.565, 1.078, 0.085), (0.555, 1.065, 0.08), (0.505, 0.07, 0.06)]
        out.append(Prim.loft(lin.map { Prim.ring(rr($0.0, $0.2), y: $0.1, offset: o) }, material: liner))
        out.append(HK.rect(liner, center: o + V3(0, 0.07, 0), right: V3(1, 0, 0), up: V3(0, 0, -1), w: 0.49, h: 0.49))
        // Molded step pocket on +Z (lower third) and a horizontal reinforcing band.
        out.append(HK.box(V3(0.34, 0.05, 0.07), o + V3(0, 0.36, 0.3), shell, r: 0.02, seg: segs / 2))
        out.append(HK.box(V3(0.36, 0.012, 0.09), o + V3(0, 0.335, 0.3), "rubber.plate", r: 0.004, seg: 1))
        // Molded stiffening rib below the lip and warning decals (hazard on +X, capacity plate on +Z).
        out.append(Prim.loft([(0.596, 0.88), (0.606, 0.89), (0.606, 0.92), (0.597, 0.93)].map { Prim.ring(rr($0.0, 0.1), y: $0.1, offset: o) }, material: shell))
        out.append(HK.rect("label.hazard", center: o + V3(0.2975, 0.72, 0), right: V3(0, 0, -1), up: .up, w: 0.2, h: 0.14, unit: true))
        out.append(HK.rect("label.inspection", center: o + V3(0, 0.75, 0.2985), right: V3(1, 0, 0), up: .up, w: 0.16, h: 0.09, unit: true))
        // Boom mounting plate (galvanized) with eight bolts on the -Z face.
        out.append(HK.box(V3(0.36, 0.46, 0.022), o + V3(0, 0.62, -0.3), "metal.galvanized-aged", r: 0.006, seg: 1))
        if lod == 0 {
            for i in 0..<4 { for j in 0..<2 {
                out.append(HK.cyl(r: 0.012, len: 0.014, at: o + V3(Float(j) * 0.28 - 0.14, 0.45 + Float(i) * 0.115, -0.316), axis: V3(0, 0, -1), mat: "metal.galvanized", seg: 6, bevel: 0.002))
            }}
            // Tool hooks: bent steel rod on +X near the rim.
            for dz: Float in [-0.12, 0.12] {
                out.append(HK.pipe([o + V3(0.31, 0.98, dz), o + V3(0.37, 0.98, dz), o + V3(0.38, 1.02, dz), o + V3(0.39, 1.06, dz)], r: 0.006, sides: 6, mat: "metal.powdercoat:202020"))
            }
            // Lanyard D-ring on the inside of the -Z wall.
            out.append(Prim.torus(major: 0.03, minor: 0.005, segments: 12, sides: 6, material: "metal.chrome")
                .transformed(Xform(translation: o + V3(0.15, 0.95, -0.27), rotation: simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0)))))
        }
        return out
    }

    /// Upper control console housing that hangs on the -Z rim, top at `o.y + 1.07 + 0.14`.
    static func consoleHousing(_ o: V3, lod: Int) -> [Surface] {
        var out: [Surface] = []
        let c = o + V3(0, 1.12, -0.19)
        out.append(HK.box(V3(0.42, 0.14, 0.2), c, "plastic.matte:2B2D30", r: 0.012, seg: lod == 0 ? 2 : 1))
        out.append(HK.box(V3(0.4, 0.008, 0.18), c + V3(0, 0.072, 0), "plastic.yellow:D9A514", r: 0.003, seg: 1))
        // Mounting bracket: two galvanized straps hooked over the rim.
        for dx: Float in [-0.15, 0.15] {
            out.append(HK.box(V3(0.04, 0.012, 0.09), c + V3(dx, 0.02, -0.075), "metal.galvanized-aged", r: 0.003, seg: 1))
            out.append(HK.box(V3(0.04, 0.12, 0.008), c + V3(dx, -0.035, -0.118), "metal.galvanized-aged", r: 0.003, seg: 1))
        }
        if lod == 0 {
            // Control labels (white decal strips) on the yellow top plate.
            for dx: Float in [-0.15, -0.02, 0.1] {
                out.append(HK.box(V3(0.07, 0.002, 0.03), c + V3(dx, 0.077, 0.06), "label.inspection", r: 0.0008, seg: 1))
            }
        }
        return out
    }
}
