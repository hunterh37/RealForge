import simd
import Foundation

/// Heavy woodworking bench, 1.8 x 0.6 m with the work surface at 864 mm (34 in): a 70 mm laminated
/// hard-maple butcher-block top (edge-glued strips with staggered butt joints, end grain at both ends, a
/// row of 20 mm square dog holes 107 mm from the front edge, one bench dog raised), a front face vise at
/// the left end (maple chop with a leather liner, 1 in steel screw, two guide rods, painted cast-iron hub
/// and a sliding steel handle bar), a base of laminated maple legs with tenoned end rails (wedged through
/// tenons on the lower rails), bench-bolted long stretchers, and a lower pine shelf holding offcuts and a
/// little sawdust.
///
/// Rig: part `vise` slides along +Z (0...0.2 m; the chop, screw, guide rods and handle move together).
/// States `closed` (default) and `open` (150 mm).
public struct Workbench: RealArticulated {
    public static let id = "workbench"
    public static let summary = "Maple workbench, 1.8 x 0.6 m: butcher-block top with dog holes, front vise with wooden chop, laminated legs with through tenons, lower shelf with offcuts."
    public static let tags = ["prop", "workshop", "furniture", "wood", "articulated"]
    public static let budget = 14_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 28, elevation: 20, distance: 1.0, studio: true)

    /// Overall length along X, meters.
    public var length: Float = 1.8
    /// Overall depth along Z, meters.
    public var depth: Float = 0.6
    /// Height of the work surface, meters (34 in).
    public var height: Float = 0.864
    /// Top thickness, meters.
    public var topThickness: Float = 0.07
    /// Top material (grain along X).
    public var topMaterial: MaterialKey = "wood.butcher-block"
    /// Strip tone tints cycled with the plain top material so the laminations read (sRGB hex).
    public var stripTints: [UInt32] = [0xD3B68C, 0xE6D2AE]
    /// End-grain material for the top strips, legs and chop.
    public var endMaterial: MaterialKey = "wood.endgrain-fresh:D9C8A6"
    /// Base, apron and chop material.
    public var frameMaterial: MaterialKey = "wood.lumber-maple"
    /// Painted cast-iron vise hardware.
    public var castIron: MaterialKey = "metal.powdercoat:2E3236"
    /// Screw, guide rods and handle bar.
    public var steel: MaterialKey = "metal.steel"
    /// Vise centerline X, meters (left end of the front edge).
    public var viseX: Float = -0.45
    /// Vise screw height, meters.
    public var viseY: Float = 0.735
    /// Maximum vise opening, meters.
    public var viseTravel: Float = 0.2
    public init() {}

    /// Work-surface height (y of the top face), meters.
    public var topY: Float { height }

    /// The top surface rectangle at `topY` (local frame).
    public var topBounds: (min: V3, max: V3) { (V3(-length / 2, height, -depth / 2), V3(length / 2, height, depth / 2)) }

    /// Z of the chop's clamping face (leather liner) when the vise is closed.
    var jawZ: Float { depth / 2 + 0.0005 }
    var chopSize: V3 { V3(0.46, 0.25, 0.055) }

    /// The moving jaw's clamping face for an opening of `open` meters (clamped to 0...viseTravel): face
    /// center and unit normal (pointing -Z, toward the bench's front edge, which is the fixed jaw at
    /// z = depth / 2).
    public func viseJawFace(open: Float) -> (center: V3, normal: V3) {
        let o = max(0, min(viseTravel, open))
        let top = height - 0.002
        return (V3(viseX, top - chopSize.y / 2, jawZ + o), V3(0, 0, -1))
    }

    /// Wood piece as a model in Lumber's frame (X length, Y thickness from 0, Z width centered).
    func wood(_ len: Float, _ w: Float, _ t: Float, mat: MaterialKey, ease: Float, grain: V2, pith: V2,
              sawn: Lumber.SawnSides = [], miterL: Float = 0, miterR: Float = 0, end: MaterialKey? = nil, lite: Bool) -> Model {
        var b = Lumber()
        b.length = len; b.width = w; b.thickness = t; b.material = mat; b.endMaterial = end ?? endMaterial
        b.easedEdges = ease > 0; b.easeRadius = ease; b.stamp = false; b.grainOffset = grain; b.endGrainCenter = pith
        b.sawnSides = sawn; b.miterLeft = miterL; b.miterRight = miterR
        return b.model(seed: 1, lite: lite)
    }

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [7])
        let L = length, D = depth, H = height, T = topThickness
        let yb = H - T
        let rotZ = simd_quatf(degrees: 90, axis: V3(0, 0, 1))     // board X -> Y (vertical)
        let rotY = simd_quatf(degrees: 90, axis: V3(0, 1, 0))     // board X -> -Z
        let rotX = simd_quatf(degrees: 90, axis: V3(1, 0, 0))     // board Y -> Z (on edge, face toward +Z)

        // Top strip widths: front strip, second strip, 20 mm dog-hole strip, then the rest.
        var rng = SeededRNG(seed: seed)
        var widths: [Float] = [0.045, 0.042, 0.02]
        var rest: [Float] = (0..<11).map { _ in rng.float(0.038...0.05) }
        let scale = (D - widths.reduce(0, +)) / rest.reduce(0, +)
        rest = rest.map { $0 * scale }
        widths += rest
        let dogXs: [Float] = (0..<11).map { -0.75 + Float($0) * 0.15 }
        let dogGap: Float = 0.02
        let legX = L / 2 - 0.2, legZ = D / 2 - 0.031 - 0.045, legW: Float = 0.09
        let shelfY: Float = 0.2

        for l in 0..<2 {
            let lite = l == 1
            var m = Model(name: Self.id)
            var r = rng.fork(100)
            // Top: edge-glued strips, front (+Z) to back.
            var z = D / 2
            for (i, w) in widths.enumerated() {
                let cz = z - w / 2
                z -= w
                let outer = i == 0 || i == widths.count - 1
                let ease: Float = outer ? 0.004 : 0.0007
                let sawn: Lumber.SawnSides = i == 0 ? [.back] : (i == widths.count - 1 ? [.front] : [])
                let pith = V2(r.float(-0.08...0.08), (r.chance(0.5) ? 1 : -1) * r.float(0.05...0.1))
                // Segments: dog strip between holes; others with staggered butt joints.
                var cuts: [(Float, Float)] = []
                if i == 2 {
                    var x0 = -L / 2
                    for dx in dogXs { cuts.append((x0, dx - dogGap / 2)); x0 = dx + dogGap / 2 }
                    cuts.append((x0, L / 2))
                } else if outer {
                    cuts = [(-L / 2, L / 2)]
                } else {
                    let j1 = r.float(-0.55 ... -0.1), j2 = r.float(0.25...0.65)
                    cuts = r.chance(0.5) ? [(-L / 2, j1), (j1, L / 2)] : [(-L / 2, j1), (j1, j2), (j2, L / 2)]
                }
                for (a, b) in cuts {
                    let len = b - a - (cuts.count > 1 && i != 2 ? 0.0003 : 0)
                    let g = V2(r.float(0...3), r.float(0...3))
                    let tone = (i * 7 + cuts.count) % (stripTints.count + 1)
                    let mat = tone == 0 ? topMaterial : topMaterial + ":" + String(format: "%06X", stripTints[tone - 1])
                    m.add(wood(len, w - 0.0002, T, mat: mat, ease: ease, grain: g, pith: pith, sawn: sawn, lite: !outer || lite),
                          Xform(translation: V3((a + b) / 2, yb, cz)))
                }
            }
            // Bench dog raised in the fourth hole.
            let dogZ = D / 2 - 0.045 - 0.042 - 0.01
            m.add(wood(0.1, 0.0194, 0.0194, mat: frameMaterial, ease: 0.0015, grain: V2(0.3, 0.1), pith: V2(0.03, 0.04), lite: lite),
                  Xform(translation: V3(dogXs[3] + 0.0097, H + 0.026 - 0.1 / 2, dogZ), rotation: rotZ))

            // Aprons under the front and back edges (the front one is the vise's fixed jaw).
            let apronH: Float = 0.13, apronT: Float = 0.031
            for (sz, z0) in [(Float(1), D / 2 - 0.0005 - apronT), (-1, -D / 2 + 0.0005)] {
                m.add(wood(L - 0.004, apronH, apronT, mat: frameMaterial, ease: 0.003, grain: V2(sz * 1.3, 0.2),
                           pith: V2(0.05, 0.09), lite: lite),
                      Xform(translation: V3(0, yb - apronH / 2 - 0.0005, z0), rotation: rotX))
            }

            // Legs: two 45 mm laminations each, full height to the underside of the top.
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                for k: Float in [-1, 1] {
                    let cx = sx * legX + k * legW / 4
                    m.add(wood(yb - 0.0005, legW, legW / 2 - 0.0003, mat: frameMaterial, ease: 0.0025,
                               grain: V2(r.float(0...2), r.float(0...2)), pith: V2(r.float(-0.06...0.06), 0.07), lite: lite),
                          Xform(translation: V3(cx + legW / 4 - 0.00015, (yb - 0.0005) / 2, sz * legZ), rotation: rotZ))
                }
            }}

            // End rails (along Z between the legs): upper under the top, lower with wedged through tenons.
            let inner = legZ - legW / 2
            for sx: Float in [-1, 1] {
                m.add(wood(2 * inner + 0.002, 0.05, 0.085, mat: frameMaterial, ease: 0.003, grain: V2(sx, 0.4), pith: V2(0.02, 0.08), lite: lite),
                      Xform(translation: V3(sx * legX, yb - 0.0855, 0), rotation: rotY))
                m.add(wood(2 * inner + 0.002, 0.05, 0.08, mat: frameMaterial, ease: 0.003, grain: V2(sx * 2, 0.7), pith: V2(-0.02, 0.08), lite: lite),
                      Xform(translation: V3(sx * legX, 0.12, 0), rotation: rotY))
                for sz: Float in [-1, 1] {
                    // Through tenon end proud of the leg face, with a walnut wedge across it.
                    let face = legZ + legW / 2
                    m.add(wood(0.012, 0.025, 0.05, mat: frameMaterial, ease: 0.0012, grain: V2(0.2, 0.1), pith: V2(0.03, 0.05), lite: lite),
                          Xform(translation: V3(sx * legX, 0.135, sz * face), rotation: rotY))
                    m.add(wood(0.002, 0.0035, 0.044, mat: "wood.lumber-walnut", ease: 0, grain: V2(0.1, 0.3), pith: V2(0.02, 0.04),
                               end: "wood.endgrain-fresh:6B4A30", lite: lite),
                          Xform(translation: V3(sx * legX, 0.138, sz * (face + 0.0058)), rotation: rotY))
                }
            }
            // Long stretchers between the legs, bench-bolted through the leg ends.
            let stretchW: Float = 0.045
            for sz: Float in [-1, 1] {
                m.add(wood(2 * (legX - legW / 2) + 0.002, 0.11, stretchW, mat: frameMaterial, ease: 0.003, grain: V2(0.6 * sz, 1.1),
                           pith: V2(0.04, 0.09), lite: lite),
                      Xform(translation: V3(0, 0.12 + 0.055, sz * legZ - stretchW / 2), rotation: rotX))
                if !lite {
                    for sx: Float in [-1, 1] {
                        hexBolt(&m, at: V3(sx * (legX + legW / 2), 0.175, sz * legZ), normal: V3(sx, 0, 0), size: 0.017, material: steel)
                    }
                }
            }

            // Shelf: four ripped 1x4 pine boards on the lower end rails, nailed at the ends.
            let shelfZs: [Float] = [-0.1305, -0.0435, 0.0435, 0.1305]
            for (i, sz) in shelfZs.enumerated() {
                var b = Lumber()
                b.length = 2 * legX + 0.04; b.width = 0.085; b.thickness = 0.019
                b.stamp = i == 1; b.sawnSides = i % 2 == 0 ? [.front] : []; b.grainOffset = V2(Float(i) * 2.1, 0)
                m.add(b.model(seed: seed &+ UInt64(i), lite: lite), Xform(translation: V3(0, shelfY + 0.0005, sz)))
                if !lite {
                    for sx: Float in [-1, 1] { for dz: Float in [-0.025, 0.025] {
                        rivet(&m, at: V3(sx * legX, shelfY + 0.0195, sz + dz), normal: .up, radius: 0.003, height: 0.0008, segments: 6,
                              material: "metal.steel")
                    }}
                }
            }
            // Offcuts on the shelf: a mitered 2x4 end, a 1x6 drop with a walnut scrap on it, a plywood corner.
            let sy = shelfY + 0.0195
            var o1 = Lumber(nominal: "2x4", length: 0.36)!; o1.miterRight = 45; o1.stamp = false; o1.grainOffset = V2(5.2, 0.01)
            m.add(o1.model(seed: seed &+ 11, lite: lite), Xform(translation: V3(0.02, sy, 0.085), rotation: simd_quatf(degrees: 7, axis: .up)))
            var o2 = Lumber(nominal: "1x6", length: 0.48)!; o2.stamp = true; o2.grainOffset = V2(0.12, 0)
            m.add(o2.model(seed: seed &+ 12, lite: lite), Xform(translation: V3(-0.42, sy, -0.06), rotation: simd_quatf(degrees: -4, axis: .up)))
            var o3 = Lumber(); o3.length = 0.24; o3.width = 0.09; o3.thickness = 0.019; o3.material = "wood.lumber-walnut"
            o3.endMaterial = "wood.endgrain-fresh:6B4A30"; o3.easedEdges = false; o3.stamp = false; o3.grainOffset = V2(0.7, 0.2)
            m.add(o3.model(seed: seed &+ 13, lite: lite), Xform(translation: V3(-0.40, sy + 0.019, -0.045), rotation: simd_quatf(degrees: 11, axis: .up)))
            var o4 = PlywoodSheet(); o4.length = 0.27; o4.width = 0.2; o4.grainOffset = V2(0.4, 0.3)
            m.add(o4.model(), Xform(translation: V3(0.47, sy, -0.03), rotation: simd_quatf(degrees: -9, axis: .up)))
            if !lite {
                m.add(Prim.superellipsoid(V3(0.13, 0.012, 0.07), exponent: 2.4, subdivisions: 6, material: "wood.sawdust"),
                      Xform(translation: V3(0.2, sy - 0.003, -0.12)))
                m.add(Prim.superellipsoid(V3(0.05, 0.007, 0.035), exponent: 2.4, subdivisions: 4, material: "wood.sawdust"),
                      Xform(translation: V3(0.31, sy - 0.002, -0.14)))
            }

            // Fixed vise hardware behind the apron: rear guide block, guide tubes, front mounting plate.
            let vx = viseX, vy = viseY, rodDX: Float = 0.16
            let plateZ = D / 2 - 0.0005 - apronT
            m.add(Prim.roundedBox(V3(0.4, 0.115, 0.01), radius: 0.003, bevelSegments: lite ? 1 : 2, material: castIron),
                  Xform(translation: V3(vx, vy, plateZ - 0.005)))
            m.add(Prim.roundedBox(V3(0.42, 0.09, 0.06), radius: 0.008, bevelSegments: lite ? 1 : 2, material: castIron),
                  Xform(translation: V3(vx, yb - 0.046, -0.02)))
            for dx in [-rodDX, 0, rodDX] {
                m.add(Prim.cylinder(radius: dx == 0 ? 0.024 : 0.017, height: plateZ - 0.01 - 0.01, bevel: 0.002, segments: lite ? 10 : 16,
                                    bevelSegments: 1, material: castIron),
                      Xform(translation: V3(vx + dx, vy, 0.01), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            }
            // Shop wear on the top: pencil layout and tally marks, dried glue drips, a little sawdust by the vise.
            if !lite {
                var w = r.fork(300)
                var pen = Surface(material: "wood.plywood-pencil")
                func stroke(_ a: V2, _ b: V2, _ width: Float) {
                    let d = simd_normalize(b - a), n = V2(-d.y, d.x) * width / 2
                    let base = UInt32(pen.positions.count)
                    for p in [a - n, b - n, b + n, a + n] { pen.add(V3(p.x, H + 0.00025, p.y), .up, p) }
                    pen.quad(base, base + 3, base + 2, base + 1)
                }
                for _ in 0..<7 {
                    let c = V2(w.float(-0.2...0.75), w.float(-0.22...0.18)), a = w.float(0...Float.pi), len = w.float(0.04...0.16)
                    let d = V2(cos(a), sin(a)) * len / 2
                    stroke(c - d, c + d, 0.0008)
                }
                let tally = V2(w.float(0.3...0.6), w.float(-0.25 ... -0.15))
                for k in 0..<4 { let x = tally.x + Float(k) * 0.006; stroke(V2(x, tally.y), V2(x + 0.001, tally.y + 0.022), 0.0008) }
                stroke(V2(tally.x - 0.004, tally.y + 0.016), V2(tally.x + 0.022, tally.y + 0.006), 0.0008)
                pen.computeTangents()
                m.add(pen)
                for k in 0..<6 {
                    let p = V2(w.float(-0.7...0.8), w.float(-0.27...0.2)), sz = w.float(0.006...0.018)
                    m.add(Prim.superellipsoid(V3(sz, 0.0016, sz * w.float(0.6...1.0)), exponent: 2.2, subdivisions: 3, material: "plastic.amber"),
                          Xform(translation: V3(p.x, H + 0.0002, p.y), rotation: simd_quatf(degrees: Float(k) * 41, axis: .up)))
                }
                m.add(Prim.superellipsoid(V3(0.09, 0.006, 0.05), exponent: 2.3, subdivisions: 5, material: "wood.sawdust"),
                      Xform(translation: V3(viseX + 0.12, H - 0.0015, D / 2 - 0.05)))
            }
            rig.base[l] = m
        }

        // Vise: chop, liner, screw, guide rods, hub and sliding bar, all moving along +Z.
        rig.part("vise", pivot: V3(viseX, viseY, jawZ), joint: .slide(axis: V3(0, 0, 1), 0...viseTravel, duration: 0.8))
        let cs = chopSize
        let chopTop = H - 0.002
        let chopZ0 = jawZ + 0.002
        let hubZ0 = chopZ0 + cs.z
        for l in 0..<2 {
            let lite = l == 1
            var v = Model(name: "vise")
            // Chop: maple slab on edge with eased edges and chamfered top corners (two mitered ends).
            v.add(wood(cs.x, cs.y, cs.z, mat: frameMaterial, ease: 0.004, grain: V2(2.4, 0.3), pith: V2(0.06, 0.1), lite: lite),
                  Xform(translation: V3(viseX, chopTop - cs.y / 2, chopZ0), rotation: rotX))
            // Leather jaw liner on the clamping face.
            v.add(Prim.roundedBox(V3(cs.x - 0.03, 0.11, 0.002), radius: 0.0008, bevelSegments: 1, material: "leather.tan"),
                  Xform(translation: V3(viseX, chopTop - 0.065, jawZ + 0.001)))
            // Screw: plain shank inside, Acme-style thread on the exposed length.
            let screwBack: Float = -0.1, screwR: Float = 0.0115
            v.add(Prim.cylinder(radius: screwR, height: hubZ0 + 0.04 - screwBack, bevel: 0.002, segments: lite ? 10 : 16, bevelSegments: 1,
                                material: steel),
                  Xform(translation: V3(viseX, viseY, screwBack), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            if !lite {
                let pitch: Float = 0.0064, z0 = jawZ - viseTravel - 0.01
                let turns = (chopZ0 - z0) / pitch
                v.add(Prim.helix(radius: screwR, pitch: pitch, turns: turns, wire: 0.0022, perTurn: 9, sides: 4, material: steel),
                      Xform(translation: V3(viseX, viseY, z0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            }
            // Guide rods.
            for dx: Float in [-0.16, 0.16] {
                v.add(Prim.cylinder(radius: 0.0105, height: chopZ0 + 0.02 - (screwBack + 0.03), bevel: 0.0015, segments: lite ? 8 : 14,
                                    bevelSegments: 1, material: steel),
                      Xform(translation: V3(viseX + dx, viseY, screwBack + 0.03), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            }
            // Hub: flanged cast boss on the chop face with a cross bore for the bar.
            v.add(Prim.lathe([V2(0, 0), V2(0.042, 0), V2(0.044, 0.004), V2(0.042, 0.008), V2(0.03, 0.012), V2(0.028, 0.05),
                              V2(0.024, 0.054), V2(0, 0.055)], segments: lite ? 12 : 24, seamTile: 0.1, material: castIron),
                  Xform(translation: V3(viseX, viseY, hubZ0 - 0.0005), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            // Sliding handle bar, dropped to hang almost vertical, ball stops on both ends.
            var hr = SeededRNG(seed: seed).fork(7)
            let tilt = hr.float(70...86) * .pi / 180, slideOff = hr.float(0.08...0.11)
            let dir = V3(cos(tilt), -sin(tilt), 0)
            let barC = V3(viseX, viseY, hubZ0 + 0.03) + dir * slideOff
            let barLen: Float = 0.32
            let a = barC - dir * barLen / 2
            v.add(Prim.cylinder(radius: 0.0095, height: barLen, bevel: 0.001, segments: lite ? 8 : 14, bevelSegments: 1, material: steel),
                  Xform(translation: a, rotation: simd_quatf(from: .up, to: dir)))
            for e in [a, a + dir * barLen] {
                v.add(Prim.superellipsoid(V3(0.03, 0.03, 0.03), exponent: 2, subdivisions: lite ? 3 : 5, material: steel), Xform(translation: e))
            }
            rig.add(v, to: "vise", lod: l)
        }

        groundAO(&rig, height: 0.3, floor: 0.5)
        rig.states = [RigState("closed"), RigState("open", ["vise": 0.15])]
        return rig
    }
}
