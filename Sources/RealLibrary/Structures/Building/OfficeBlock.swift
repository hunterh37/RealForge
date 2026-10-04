import simd
import Foundation

/// Mid-rise office block, 30 x 18 m footprint, ground floor 4.6 m plus five 3.8 m floors: unitized
/// curtain wall (vision glass, opaque spandrel bands, black anodized mullions and transoms), concrete slab
/// edges and lit ceilings visible through the glass, stone plinth, recessed glazed entrance with a
/// cantilevered canopy, parapet and rooftop plant. Three LODs.
public struct OfficeBlock: RealAsset {
    public static let id = "office-block"
    public static let summary = "Mid-rise curtain-wall office block: glass and spandrel bands on black mullions, lit floors behind, stone plinth, entrance canopy, rooftop plant."
    public static let tags = ["structure", "building", "glass", "metal", "urban"]
    public static let budget = 30_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 8, distance: 1.05, fog: 0.001)

    public var width: Float = 30
    public var depth: Float = 18
    public var floors = 6
    public var groundHeight: Float = 4.6
    public var floorHeight: Float = 3.8
    /// Mullion spacing (m).
    public var bay: Float = 1.5
    /// Lit ceilings behind the glass (office lights on).
    public var lit = true
    public init() {}

    public var height: Float { groundHeight + Float(floors - 1) * floorHeight + 1.2 }

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, lod: 0), model(seed: seed, lod: 1), model(seed: seed, lod: 2)], switchDistances: [70, 180])
    }

    func model(seed: UInt64, lod: Int) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, D = depth
        let mull: MaterialKey = "metal.anodized-black", glass: MaterialKey = "glass.curtain", slabMat: MaterialKey = "concrete.smooth"
        let levels = (0..<floors).map { $0 == 0 ? 0 : groundHeight + Float($0 - 1) * floorHeight }   // floor levels
        let roofY = groundHeight + Float(floors - 1) * floorHeight
        let plinth: Float = 0.6
        func box(_ size: V3, _ c: V3, _ mat: MaterialKey, bevel: Float = 0) -> Void {
            if bevel > 0 && lod == 0 { m.add(Prim.roundedBox(size, radius: bevel, bevelSegments: 1, material: mat), Xform(translation: c)) }
            else { m.add(cuboid(size, material: mat), Xform(translation: c)) }
        }
        func quad(_ c: V3, _ u: V3, _ v: V3, _ mat: MaterialKey) {
            var s = Surface(material: mat)
            let n = simd_normalize(simd_cross(u, v)), ud = simd_normalize(u), vd = simd_normalize(v)
            let hu: V3 = u * 0.5, hv: V3 = v * 0.5
            let pts: [V3] = [c - hu - hv, c + hu - hv, c + hu + hv, c - hu + hv]
            for p in pts { s.add(p, n, V2(simd_dot(p, ud), simd_dot(p, vd))) }
            s.quad(0, 1, 2, 3)
            s.computeTangents()
            m.add(s)
        }
        // Facades: (center line point at ground, tangent, outward normal, length).
        let sides: [(V3, V3, V3, Float)] = [(V3(0, 0, D / 2), V3(1, 0, 0), V3(0, 0, 1), W), (V3(0, 0, -D / 2), V3(-1, 0, 0), V3(0, 0, -1), W),
                                            (V3(W / 2, 0, 0), V3(0, 0, -1), V3(1, 0, 0), D), (V3(-W / 2, 0, 0), V3(0, 0, 1), V3(-1, 0, 0), D)]
        let entranceW: Float = 6
        for (k, (o, t, n, L)) in sides.enumerated() {
            let isFront = k == 0
            // Vision glass: one sheet per side above the plinth (ground floor in front: recessed entrance gap).
            let gTop = roofY
            if isFront {
                let sideW = (L - entranceW) / 2
                for sgn: Float in [-1, 1] {
                    quad(o + t * sgn * (entranceW / 2 + sideW / 2) + V3(0, (plinth + groundHeight) / 2, 0) + n * 0.02, t * sideW, V3(0, groundHeight - plinth, 0), glass)
                }
                quad(o + V3(0, (groundHeight + gTop) / 2, 0) + n * 0.02, t * L, V3(0, gTop - groundHeight, 0), glass)
            } else {
                quad(o + V3(0, (plinth + gTop) / 2, 0) + n * 0.02, t * L, V3(0, gTop - plinth, 0), glass)
            }
            // Spandrel bands behind the glass at each upper slab (opaque, dark).
            for y in levels.dropFirst() {
                quad(o + V3(0, y + 0.25, 0) - n * 0.12, t * L, V3(0, 1.3, 0), "metal.anodized-black")
            }
            // Mullions.
            let bays = Int((L / bay).rounded())
            let step = L / Float(bays)
            if lod < 2 {
                for b in 0...bays {
                    let s = -L / 2 + Float(b) * step
                    if isFront && abs(s) < entranceW / 2 - 0.01 {
                        box(V3(0.065, gTop - groundHeight, 0.16), o + t * s + n * 0.06 + V3(0, (groundHeight + gTop) / 2, 0), mull, bevel: 0.008)
                    } else {
                        box(V3(0.065, gTop - plinth, 0.16), o + t * s + n * 0.06 + V3(0, (plinth + gTop) / 2, 0), mull, bevel: 0.008)
                    }
                }
                for y in levels.dropFirst() + [plinth] {
                    for dy: Float in y == plinth ? [0.03] : [-0.4, 0.95] {
                        let size = abs(t.x) > 0.5 ? V3(L, 0.07, 0.14) : V3(0.14, 0.07, L)
                        box(size, o + n * 0.05 + V3(0, y + dy, 0), mull, bevel: 0.006)
                    }
                }
            }
            // Corner fins.
            box(V3(0.2, gTop + 0.6, 0.2), o + t * (L / 2) + n * 0.02 + V3(0, (gTop + 0.6) / 2, 0), mull)
            // Stone plinth.
            let pl = abs(t.x) > 0.5 ? V3(L + 0.1, plinth, 0.12) : V3(0.12, plinth, L + 0.1)
            if isFront {
                let sideW = (L - entranceW) / 2
                for sgn: Float in [-1, 1] {
                    box(V3(sideW, plinth, 0.12), o + t * sgn * (entranceW / 2 + sideW / 2) + n * 0.02 + V3(0, plinth / 2, 0), "rock.granite-bare", bevel: 0.01)
                }
            } else {
                box(pl, o + n * 0.02 + V3(0, plinth / 2, 0), "rock.granite-bare", bevel: 0.01)
            }
        }
        // Floor slabs, a service core and lit ceilings visible through the glass.
        for (i, y) in levels.enumerated() {
            box(V3(W - 0.3, 0.3, D - 0.3), V3(0, max(0.15, y - 0.15), 0), slabMat)
            if lod == 0 && lit {
                let ceil = (i + 1 < levels.count ? levels[i + 1] : roofY) - 0.32
                var z = -D / 2 + 1.6
                while z < D / 2 - 1.2 {
                    let on = rng.chance(0.9)
                    quad(V3(0, ceil, z), V3(W - 2.4, 0, 0), V3(0, 0, -0.18), on ? "emissive.panel" : "plastic.diffuser")
                    z += 2.4
                }
                quad(V3(0, ceil + 0.005, 0), V3(W - 0.4, 0, 0), V3(0, 0, -(D - 0.4)), "ceiling.acoustic")
            }
        }
        // Interior zone 4 m behind the glass: partitions and the core stop the view through the building.
        for (i, y) in levels.enumerated() {
            let top = (i + 1 < levels.count ? levels[i + 1] : roofY) - 0.3
            box(V3(W - 8, top - y - 0.0, D - 8), V3(0, y + (top - y) / 2, 0), "paint.wall:8C877E")
        }
        // Roof slab, parapet coping, rooftop plant behind a louvred screen.
        box(V3(W - 0.2, 0.4, D - 0.2), V3(0, roofY + 0.2, 0), slabMat)
        for (o, t, _, L) in sides {
            let size = abs(t.x) > 0.5 ? V3(L + 0.2, 1.2, 0.25) : V3(0.25, 1.2, L + 0.2)
            box(size, o + V3(0, roofY + 0.6, 0), mull, bevel: 0.01)
            let cap = abs(t.x) > 0.5 ? V3(L + 0.3, 0.06, 0.35) : V3(0.35, 0.06, L + 0.3)
            box(cap, o + V3(0, roofY + 1.23, 0), "metal.anodized", bevel: 0.005)
        }
        if lod < 2 {
            box(V3(10, 2.6, 6), V3(2, roofY + 0.4 + 1.3, -2), "metal.galvanized", bevel: 0.02)
            box(V3(3, 1.8, 2.4), V3(-9, roofY + 0.4 + 0.9, 3), "metal.galvanized", bevel: 0.02)
            if lod == 0 {
                for i in 0..<14 {
                    box(V3(10.2, 0.05, 0.1), V3(2, roofY + 0.55 + Float(i) * 0.17, 1.05), "metal.galvanized-aged")
                }
                for x: Float in [-1.5, 2, 5.5] {
                    m.add(Prim.cylinder(radius: 0.9, height: 0.5, bevel: 0.03, segments: 20, material: "metal.galvanized"), Xform(translation: V3(x, roofY + 0.4 + 2.6, -2)))
                    m.add(Prim.cylinder(radius: 0.8, height: 0.06, bevel: 0.01, segments: 20, material: "plastic.black"), Xform(translation: V3(x, roofY + 0.4 + 3.08, -2)))
                }
            }
        }
        // Entrance: recessed glass vestibule, revolving-door drum, cantilevered canopy, mat.
        let fz = D / 2
        box(V3(entranceW, groundHeight, 0.2), V3(0, groundHeight / 2, fz - 2.2), "paint.wall:CFCAC0")
        quad(V3(0, groundHeight / 2 + 0.05, fz - 1.4), V3(entranceW - 0.2, 0, 0), V3(0, groundHeight - 0.1, 0), "glass.clear")
        for sx: Float in [-1, 1] {
            box(V3(0.2, groundHeight, 1.6), V3(sx * (entranceW / 2 - 0.1), groundHeight / 2, fz - 0.8 - 0.6), "rock.granite-bare", bevel: 0.01)
        }
        if lod < 2 {
            for sx in stride(from: -entranceW / 2 + 0.75, through: entranceW / 2 - 0.7, by: 1.5) {
                box(V3(0.06, groundHeight - 0.2, 0.12), V3(sx, groundHeight / 2, fz - 1.4), mull, bevel: 0.005)
            }
            box(V3(entranceW, 0.08, 0.12), V3(0, 2.4, fz - 1.4), mull, bevel: 0.005)
            if lod == 0 {
                for sx: Float in [-0.25, 0.25] {
                    m.add(Prim.cylinder(radius: 0.015, height: 1.4, bevel: 0.005, segments: 10, material: "metal.stainless"), Xform(translation: V3(sx, 0.4, fz - 1.3)))
                }
            }
        }
        box(V3(entranceW + 2, 0.35, 3.0), V3(0, groundHeight - 0.2, fz + 0.2), "metal.anodized", bevel: 0.02)
        box(V3(entranceW + 1.6, 0.02, 2.6), V3(0, groundHeight - 0.385, fz + 0.2), lit ? "emissive.panel" : "plastic.diffuser")
        box(V3(entranceW - 1, 0.02, 1.8), V3(0, 0.01, fz - 0.5), "carpet.tile:2A2A2C")
        box(V3(entranceW + 0.6, 0.15, 2.6), V3(0, 0.075, fz - 1), "rock.granite-bare", bevel: 0.01)
        // Building sits a hair into the ground.
        for i in m.surfaces.indices { m.surfaces[i].bakeCavityAO(strength: 0.4, floor: 0.7) }
        return m
    }
}
