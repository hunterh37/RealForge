import simd
import Foundation

/// Home woodshop pegboard wall, 4 x 4 ft (1.22 m square): 1/4 in tempered hardboard with 1/4 in holes on a
/// 1 in grid (`wood.pegboard`) screwed to three horizontal 1x2 pine furring strips (19 x 38 mm). Zinc
/// plated 3/16 in wire hooks (single straight with brace, double prong, J loop) hold a coiled orange
/// extension cord, a coil of three-strand manila rope, two spare circular saw blades (7-1/4 and 6-1/2 in) and a steel
/// parts shelf with four open-front bins of screws.
///
/// Frame: the back plane (wall side of the furring) sits at z = 0 and the board faces +Z; the bottom edge
/// is at y = 0 and the sheet is centered on X. Scenes lift it onto a wall (typically y = 0.9 m).
/// Hole (i, j) centre: `PegboardWall.hole(i, j)` with i from the left edge, j from the bottom edge.
public struct PegboardWall: RealAsset {
    public static let id = "pegboard-wall"
    public static let summary = "4 x 4 ft hardboard pegboard on furring strips with steel hooks holding an extension cord, a rope coil, a parts-bin shelf and spare saw blades."
    public static let tags = ["prop", "workshop", "wood", "metal", "tool"]
    public static let budget = 15_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 20, elevation: 8, distance: 1.25, studio: true)

    /// Hole pitch (m): 1 in.
    public static let pitch: Float = 0.0254
    /// Sheet width and height (m). 1.22 = 4 ft; hung items keep their place as fractions of the sheet.
    public var width: Float = 1.22
    public var height: Float = 1.22
    /// Hardboard thickness (m): 1/4 in.
    public var thickness: Float = 0.0064
    /// Furring strip depth behind the sheet (m): 1x2 actual 3/4 in.
    public var furring: Float = 0.019
    /// Face material (holes come from the texture program; map from the sheet corner in meters).
    public var face: MaterialKey = "wood.pegboard"
    /// Extension cord jacket color (sRGB hex).
    public var cordColor: UInt32 = 0xE0601C
    /// Hang the cord, rope, blades and parts shelf (false = bare board with empty hooks).
    public var stocked = true
    public init() {}

    /// Board face plane z (m) for the default thickness and furring.
    public var faceZ: Float { furring + thickness }

    /// Centre of hole (i, j) on the face, i counted from the left edge, j from the bottom edge.
    public func hole(_ i: Int, _ j: Int) -> V3 {
        V3(-width / 2 + (Float(i) + 0.5) * Self.pitch, (Float(j) + 0.5) * Self.pitch, faceZ)
    }

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [4])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, H = height, zf = faceZ, p = Self.pitch
        let nx = Int(W / p), ny = Int(H / p)
        let steel: MaterialKey = "metal.galvanized"
        let wire: Float = 0.0024
        func snap(_ fx: Float, _ fy: Float) -> (Int, Int) { (max(1, min(nx - 2, Int(fx * Float(nx)))), max(2, min(ny - 2, Int(fy * Float(ny))))) }

        // MARK: board and furring
        m.add(Prim.roundedBox(V3(W, H, thickness - 0.0005), radius: 0.0018, bevelSegments: detail ? 2 : 1, material: "wood.hardboard"),
              Xform(translation: V3(0, H / 2, furring + (thickness - 0.0005) / 2)))
        var faceQuad = Surface(material: face)
        let e: Float = 0.0012
        let a = faceQuad.add(V3(-W / 2 + e, e, zf), V3(0, 0, 1), V2(e, e)), b = faceQuad.add(V3(W / 2 - e, e, zf), V3(0, 0, 1), V2(W - e, e))
        let c = faceQuad.add(V3(W / 2 - e, H - e, zf), V3(0, 0, 1), V2(W - e, H - e)), d = faceQuad.add(V3(-W / 2 + e, H - e, zf), V3(0, 0, 1), V2(e, H - e))
        faceQuad.quad(a, b, c, d)
        faceQuad.computeTangents()
        m.add(faceQuad)
        let strips: [Float] = [0.045, H / 2, H - 0.045]
        for sy in strips {
            m.add(Prim.roundedBox(V3(W - 0.004, 0.038, furring - 0.0005), radius: 0.003, bevelSegments: 1, material: "wood.lumber-pine"),
                  Xform(translation: V3(0, sy, (furring - 0.0005) / 2)).jittered(&rng, deg: 0.1, offset: 0.0006))
            // Pan-head screws with washers between holes, into the strip.
            for fx: Float in [-0.47, 0, 0.47] {
                let sx = (fx * W / p).rounded() * p
                let at = V3(sx, sy, zf)
                if detail {
                    rivet(&m, at: at, normal: V3(0, 0, 1), radius: 0.0052, height: 0.0022, segments: 8, material: steel)
                    let slot = simd_quatf(degrees: rng.float(0...180), axis: V3(0, 0, 1))
                    m.add(cuboid(V3(0.0068, 0.0009, 0.0012), material: "plastic.matte:2A2620"), Xform(translation: at + V3(0, 0, 0.0024), rotation: slot))
                }
            }
        }

        // MARK: hooks (wire from the hole, bent tail inside the board)
        func socket(_ h: V3) {
            // The wire disappears into the hole: dark collar so the joint reads as inserted.
            _ = h
        }
        func wireTube(_ pts: [V3], per: Int = 2) {
            let path = catmull(pts, per: per)
            m.add(Prim.tube(path, radii: path.map { _ in wire }, sides: detail ? 5 : 4, seamTile: 0.03, material: steel))
        }
        /// Straight hook with brace, arm up `deg`; returns the arm's tip and the arm direction.
        @discardableResult
        func straightHook(_ i: Int, _ j: Int, length: Float, deg: Float = 10) -> (V3, V3) {
            let h = hole(i, j), dir = V3(0, sin(deg * .pi / 180), cos(deg * .pi / 180))
            let tip = h + V3(0, 0, 0.004) + dir * length
            wireTube([h - V3(0, 0, 0.006), h + V3(0, 0, 0.003), h + V3(0, 0, 0.004) + dir * (length * 0.5), tip, tip + V3(0, 0.012, 0.004)])
            // Brace: from the hole below, rising to meet the arm.
            let hb = hole(i, j - 1)
            wireTube([hb - V3(0, 0, 0.006), hb + V3(0, 0, 0.004), h + V3(0, -0.002, 0.004) + dir * 0.028], per: 2)
            socket(h); socket(hb)
            return (tip, dir)
        }
        func doubleHook(_ i: Int, _ j: Int, length: Float) {
            // Two arms 2 in apart joined by a cross bar flush on the face.
            let l = hole(i, j), r = hole(i + 2, j)
            wireTube([l + V3(0, -0.006, 0.0035), r + V3(0, -0.006, 0.0035)], per: 1)
            for h in [l, r] {
                let dir = V3(0, 0.17, 0.985)
                let tip = h + V3(0, 0, 0.004) + dir * length
                wireTube([h - V3(0, 0, 0.006), h + V3(0, 0, 0.003), h + V3(0, -0.004, 0.006), h + V3(0, 0, 0.004) + dir * (length * 0.5), tip, tip + V3(0, 0.01, 0.004)])
                socket(h)
            }
        }
        /// J loop hook: arm out, then a curl up at the end; returns the seat point (inside the curve bottom).
        func jHook(_ i: Int, _ j: Int, reach: Float, curl: Float) -> V3 {
            let h = hole(i, j)
            let z0 = h.z + 0.004, zEnd = z0 + reach
            var pts = [h - V3(0, 0, 0.006), h + V3(0, 0, 0.003), V3(h.x, h.y - 0.003, z0 + reach * 0.45), V3(h.x, h.y - 0.004, zEnd - curl)]
            for k in 1...6 {
                let t = Float(k) / 6 * Float.pi * 0.62
                pts.append(V3(h.x, h.y - 0.004 + curl * (1 - cos(t)), zEnd - curl + sin(t) * curl))
            }
            wireTube(pts, per: 2)
            let hb = hole(i, j - 1)
            wireTube([hb - V3(0, 0, 0.006), hb + V3(0, 0, 0.004), V3(h.x, h.y - 0.004, z0 + 0.024)], per: 2)
            socket(h); socket(hb)
            return V3(h.x, h.y - 0.004, z0 + reach * 0.55)
        }

        // Cord and rope loops: closed hanging loops in planes parallel to the board.
        func hangingLoops(seat: V3, zSpread: Float, count: Int, width w0: Float, drop h0: Float, radius r: Float,
                          material: MaterialKey, sides: Int, rope: Bool, rng: inout SeededRNG) -> [V3] {
            var bottoms: [V3] = []
            for k in 0..<count {
                let w = rng.vary(w0, 0.08), hgt = rng.vary(h0, 0.06)
                let z = seat.z - zSpread / 2 + zSpread * (Float(k) + 0.5) / Float(count)
                let sway = rng.float(-0.012...0.012), tilt = rng.float(-0.025...0.025)
                let top = V3(seat.x, seat.y + wire + r, z)
                let n = detail ? 18 : 12
                var path: [V3] = []
                for q in 0..<n {
                    let th = Float(q) / Float(n) * 2 * .pi
                    let pinch = 0.55 + 0.45 * (1 - cos(th)) / 2
                    let x = w / 2 * sin(th) * pinch
                    let y = -hgt / 2 * (1 - cos(th))
                    let zz = tilt * y / hgt * 2 + 0.006 * sin(th * 2 + Float(k))
                    path.append(top + V3(x + sway * (1 - cos(th)) / 2, y, zz))
                }
                bottoms.append(top + V3(sway, -hgt, 0))
                if rope {
                    var s = Prim.tube(path + [path[0]], radii: Array(repeating: r, count: n + 1), sides: sides, seamTile: 0.02, material: material,
                                      capEnd: false) { t, v in 1 + 0.14 * cos(3 * (t * 2 * .pi) - v * 2 * .pi / 0.028) }
                    s.computeTangents()
                    m.add(s)
                } else {
                    m.add(Prim.sweep(Shape2D.circle(r, segments: sides), along: path, closedPath: true, caps: false, material: material))
                }
            }
            return bottoms
        }

        // MARK: layout
        let (ci, cj) = snap(0.24, 0.89)
        let cordSeat = jHook(ci, cj, reach: 0.105, curl: 0.022)
        let (ri, rj) = snap(0.76, 0.9)
        let ropeSeat = jHook(ri, rj, reach: 0.1, curl: 0.02)
        let (bi, bj) = snap(0.5, 0.8)
        let (bladeTip, bladeDir) = straightHook(bi, bj, length: 0.085, deg: 8)
        let (di, dj) = snap(0.13, 0.42)
        doubleHook(di, dj, length: 0.1)
        let (si, sj) = snap(0.86, 0.6)
        let (squareTip, squareDir) = straightHook(si, sj, length: 0.07, deg: 12)
        let (ti, tj) = snap(0.36, 0.62)
        straightHook(ti, tj, length: 0.11, deg: 10)
        // Marker outline of the tool that lives on this hook (a screwdriver, out on the bench): shadow-board story.
        if detail {
            let o = hole(ti, tj) + V3(0, -0.012, 0.0001)
            var pts: [V3] = []
            let profile: [(Float, Float)] = [(0.0, 0.006), (0.012, 0.016), (0.02, 0.018), (0.09, 0.016), (0.105, 0.012), (0.11, 0.004), (0.25, 0.0035), (0.262, 0.0045), (0.268, 0.0)]
            for (d, w) in profile { pts.append(o + V3(w, -d, 0)) }
            for (d, w) in profile.reversed().dropFirst() { pts.append(o + V3(-w, -d, 0)) }
            let line = catmull(pts, per: 3)
            m.add(Prim.tube(line, radii: line.map { _ in 0.0007 }, sides: 4, seamTile: 0.01, material: "plastic.matte:1C1C1E", capEnd: false))
        }
        let (ki, kj) = snap(0.32, 0.22)
        _ = jHook(ki, kj, reach: 0.06, curl: 0.016)

        if stocked {
            // Orange extension cord, 16/3 SJTW (8.5 mm), coiled over-under.
            var crng = rng.fork(1)
            let cord: MaterialKey = "plastic.tool:" + String(format: "%06X", cordColor)
            let cordR: Float = 0.0043
            let bottoms = hangingLoops(seat: cordSeat, zSpread: 0.06, count: 6, width: 0.25, drop: 0.36, radius: cordR, material: cord,
                                       sides: 5, rope: false, rng: &crng)
            // Ends hanging below the coil: male plug and socket with a molded strain relief.
            for (k, end) in [bottoms[1], bottoms[4]].enumerated() {
                let sx: Float = k == 0 ? -0.03 : 0.035
                let tail = catmull([end + V3(sx * 0.3, 0.02, 0), end + V3(sx, -0.03, 0.006), end + V3(sx * 1.3, -0.085, 0.01)], per: 4)
                m.add(Prim.tube(tail, radii: tail.map { _ in cordR }, sides: 7, seamTile: 0.02, material: cord, capEnd: false))
                let q = tail[tail.count - 1]
                let dir = simd_normalize(tail[tail.count - 1] - tail[tail.count - 2])
                let rot = simd_quatf(from: V3(0, 1, 0), to: dir)
                m.add(Prim.lathe([V2(0, 0), V2(0.0062, 0.0), V2(0.0072, 0.012), V2(0.0085, 0.02), V2(0, 0.02)], segments: 12, seamTile: 0.03, material: cord),
                      Xform(translation: q, rotation: rot))
                m.add(Prim.roundedBox(V3(0.03, 0.038, 0.022), radius: 0.006, bevelSegments: 2, material: cord),
                      Xform(translation: q + rot.act(V3(0, 0.038, 0)), rotation: rot))
                if k == 0 {
                    // Male plug: two flat blades and a round ground pin.
                    for bx: Float in [-0.0063, 0.0063] {
                        m.add(cuboid(V3(0.0016, 0.016, 0.0064), material: "metal.brass"), Xform(translation: q + rot.act(V3(bx, 0.064, 0.002)), rotation: rot))
                    }
                    m.add(Prim.cylinder(radius: 0.0024, height: 0.018, bevel: 0.0008, segments: 8, bevelSegments: 1, material: "metal.brass"),
                          Xform(translation: q + rot.act(V3(0, 0.055, -0.006)), rotation: rot))
                } else {
                    // Socket face: three dark slots.
                    for (sx2, sz) in [(Float(-0.0063), Float(0.003)), (0.0063, 0.003), (0, -0.006)] {
                        m.add(cuboid(V3(sz < 0 ? 0.004 : 0.0018, 0.0012, sz < 0 ? 0.004 : 0.0068), material: "plastic.matte:151515"),
                              Xform(translation: q + rot.act(V3(sx2, 0.0573, sz)), rotation: rot))
                    }
                }
            }

            // Three-strand manila rope, 3/8 in, coiled and hung.
            var rrng = rng.fork(2)
            let rope: MaterialKey = "sack.jute"
            let rb = hangingLoops(seat: ropeSeat, zSpread: 0.05, count: 5, width: 0.21, drop: 0.31, radius: 0.0052, material: rope,
                                  sides: 5, rope: true, rng: &rrng)
            // Tail: hanging end with a taped (whipped) tip.
            let t0 = rb[2]
            let tail = catmull([t0 + V3(0.01, 0.03, 0.002), t0 + V3(0.035, -0.02, 0.012), t0 + V3(0.045, -0.1, 0.018)], per: 5)
            m.add(Prim.tube(tail, radii: tail.map { _ in 0.0052 }, sides: 9, seamTile: 0.02, material: rope, capEnd: false) { t, v in
                1 + 0.14 * cos(3 * (t * 2 * .pi) - v * 2 * .pi / 0.028)
            })
            let tipDir = simd_normalize(tail[tail.count - 1] - tail[tail.count - 2])
            m.add(Prim.cylinder(radius: 0.0062, height: 0.022, bevel: 0.0015, segments: 10, bevelSegments: 1, material: "plastic.matte:2A2A2C"),
                  Xform(translation: tail[tail.count - 1] - tipDir * 0.018, rotation: simd_quatf(from: V3(0, 1, 0), to: tipDir)))
            // A few turns binding the coil just below the hook.
            for k in 0..<2 {
                let y = ropeSeat.y - 0.04 - Float(k) * 0.011
                m.add(Prim.torus(major: 0.031, minor: 0.0052, segments: detail ? 12 : 8, sides: 5, minorY: nil, material: rope),
                      Xform(translation: V3(ropeSeat.x, y, ropeSeat.z), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)) * simd_quatf(degrees: Float(k) * 9, axis: .up),
                            scale: V3(1.0, 1, 0.55)))
            }

            // Spare blades on one hook through the 5/8 in arbor hole: coated 7-1/4 in (184 mm) 36T behind, bare 6-1/2 in (165 mm) 24T in front.
            for k in 0..<2 {
                let along: Float = 0.032 + Float(k) * 0.007
                let hook = hole(bi, bj) + V3(0, 0, 0.004) + bladeDir * along
                let center = hook + V3(rng.float(-0.001...0.001), -(0.0079 - wire), 0)
                let spin = rng.float(0...30)
                addBlade(&m, center: center, coated: k == 0, radius: k == 0 ? 0.092 : 0.0825, teeth: k == 0 ? 36 : 24, spin: spin, detail: detail)
            }
            _ = bladeTip

            // Claw hammer on the double hook: head across both prongs, hickory handle hanging between them.
            let dl = hole(di, dj), dr = hole(di + 2, dj)
            let headC = V3((dl.x + dr.x) / 2 + 0.012, dl.y + 0.016 + wire + 0.0125, zf + 0.055)
            m.add(Prim.roundedBox(V3(0.075, 0.025, 0.025), radius: 0.004, bevelSegments: 2, material: "metal.steel"), Xform(translation: headC))
            m.add(Prim.cylinder(radius: 0.0135, height: 0.012, bevel: 0.003, segments: 14, bevelSegments: 1, material: "metal.steel"),
                  Xform(translation: headC + V3(0.0375, 0, 0), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
            let claw = Shape2D.rounded([V2(0, -0.012), V2(0.02, -0.01), V2(0.045, -0.002), V2(0.055, 0.006), V2(0.04, 0.004), V2(0.015, 0.008), V2(0, 0.012)], radius: 0.003, segments: 1)
            for cz: Float in [-1, 1] {
                m.add(Prim.extrude(claw, depth: 0.009, bevel: 0.0015, bevelSegments: 1, material: "metal.steel"),
                      Xform(translation: headC + V3(-0.0375, 0, cz * 0.0065), rotation: simd_quatf(degrees: 180, axis: .up)))
            }
            m.add(turned([(0, 0), (0.012, 0.004), (0.0145, 0.03), (0.013, 0.12), (0.011, 0.22), (0.0125, 0.27), (0.0115, 0.3), (0.006, 0.315), (0, 0.316)], segments: detail ? 12 : 8,
                         material: "wood.lumber-oak", grainVertical: true),
                  Xform(translation: headC + V3(-0.005, 0.015, 0), rotation: simd_quatf(degrees: 180, axis: V3(0, 0, 1))))
            // Aluminum 7 in speed square hung by its corner hole on the short hook.
            let sq = Shape2D.rounded([V2(0, 0), V2(0.178, 0), V2(0, 0.178)], radius: 0.004, segments: 2)
            let sqAt = hole(si, sj) + V3(0, 0, 0.004) + squareDir * 0.045
            _ = squareTip
            let sqRot = simd_quatf(degrees: -135 + 2, axis: V3(0, 0, 1))
            m.add(Prim.extrude(sq, depth: 0.0025, bevel: 0.0006, bevelSegments: 1, material: "metal.aluminum-brushed"),
                  Xform(translation: sqAt + sqRot.act(V3(-0.014, -0.014, 0)) + V3(0, -0.006, 0), rotation: sqRot))
            // Fence lip along one leg.
            m.add(Prim.roundedBox(V3(0.178, 0.006, 0.014), radius: 0.0015, bevelSegments: 1, material: "metal.aluminum-brushed"),
                  Xform(translation: sqAt + sqRot.act(V3(0.089 - 0.014, -0.014 - 0.003, 0)) + V3(0, -0.006, 0), rotation: sqRot))

            // Parts shelf: 18 ga steel shelf with front lip on two wire brackets, four open-front bins.
            let (pi0, pj0) = snap(0.47, 0.37)
            let left = hole(pi0, pj0), shelfW: Float = 0.46, shelfD: Float = 0.13
            let x0 = left.x + 0.02, y0 = left.y - 0.06
            let shelfC = V3(x0 + shelfW / 2 - 0.03, y0, zf + shelfD / 2 + 0.004)
            let paint: MaterialKey = "metal.powdercoat:3B3F44"
            m.add(Prim.roundedBox(V3(shelfW, 0.0016, shelfD), radius: 0.0007, bevelSegments: 1, material: paint), Xform(translation: shelfC))
            m.add(Prim.roundedBox(V3(shelfW, 0.022, 0.0016), radius: 0.0007, bevelSegments: 1, material: paint),
                  Xform(translation: shelfC + V3(0, 0.011, shelfD / 2)))
            m.add(Prim.roundedBox(V3(shelfW, 0.03, 0.0016), radius: 0.0007, bevelSegments: 1, material: paint),
                  Xform(translation: V3(shelfC.x, y0 + 0.015, zf + 0.0045)))
            for bx in [pi0 + 1, pi0 + 15] {
                let h = hole(bx, pj0), hb = hole(bx, pj0 - 3)
                let bxp = h.x
                wireTube([h - V3(0, 0, 0.006), h + V3(0, 0, 0.004), V3(bxp, y0 - 0.002, zf + 0.012), V3(bxp, y0 - 0.003, zf + shelfD - 0.004)], per: 2)
                wireTube([hb - V3(0, 0, 0.006), hb + V3(0, 0, 0.004), V3(bxp, y0 - 0.004, zf + shelfD * 0.75)], per: 2)
                socket(h); socket(hb)
            }
            let tints: [UInt32] = [0x2C5FA0, 0xD9A21B, 0x2C5FA0, 0xB8261C]
            for k in 0..<4 {
                let bw: Float = 0.104
                let bxc = shelfC.x - shelfW / 2 + 0.008 + bw / 2 + Float(k) * (bw + 0.006)
                addBin(&m, at: V3(bxc, y0 + 0.0008, zf + 0.008), width: bw, depth: 0.118, tint: tints[k], rng: &rng, detail: detail, fill: k != 2 ? 0.6 : 0.25)
            }
        }
        groundAO(&m, height: 0.06, floor: 0.75)
        return m
    }

    /// Circular saw blade (radius `R`) in the XY plane at `center`, plate facing +Z.
    func addBlade(_ m: inout Model, center: V3, coated: Bool, radius R: Float, teeth: Int, spin: Float, detail: Bool) {
        let gullet: Float = R - (teeth > 30 ? 0.0065 : 0.011), t: Float = 0.0016
        var outline: [V2] = []
        for k in 0..<teeth {
            let a0 = Float(k) / Float(teeth) * 2 * .pi
            let da = 2 * .pi / Float(teeth)
            func pt(_ a: Float, _ r: Float) -> V2 { V2(cos(a) * r, sin(a) * r) }
            outline.append(pt(a0, R - 0.0005))
            outline.append(pt(a0 + da * 0.12, R))
            outline.append(pt(a0 + da * 0.2, R - 0.004))
            outline.append(pt(a0 + da * 0.55, gullet))
            outline.append(pt(a0 + da * 0.85, gullet + 0.002))
        }
        let plate: MaterialKey = coated ? "metal.powdercoat:A8321F" : "metal.sawblade"
        let rot = simd_quatf(degrees: spin, axis: V3(0, 0, 1))
        m.add(Prim.extrude(outline, depth: t, bevel: 0, bevelSegments: 0, material: plate), Xform(translation: center, rotation: rot))
        // Bright ground band at the tooth line on the coated blade (coating ends below the gullets).
        if coated {
            m.add(Prim.lathe([V2(gullet - 0.001, -t / 2 - 0.0001), V2(gullet + 0.0005, -t / 2 - 0.0001), V2(gullet + 0.0005, t / 2 + 0.0001), V2(gullet - 0.001, t / 2 + 0.0001)],
                             segments: 24, seamTile: 0.05, material: "metal.sawblade"), Xform(translation: center, rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }
        // Carbide tips brazed on each tooth face.
        for k in 0..<teeth {
            let a = (Float(k) / Float(teeth) + 0.12 / Float(teeth)) * 2 * .pi + spin * .pi / 180
            let p = center + V3(cos(a) * (R - 0.0022), sin(a) * (R - 0.0022), 0)
            m.add(cuboid(V3(0.0045, 0.0018, t + 0.0012), material: "metal.carbide"),
                  Xform(translation: p, rotation: simd_quatf(angle: a + .pi / 2 - 0.25, axis: V3(0, 0, 1))))
        }
        // Arbor hole (dark through-hole disc on both faces) and four laser-cut expansion slots.
        for s: Float in [-1, 1] {
            m.add(Prim.lathe([V2(0, 0.0003), V2(0.0079, 0.0003), V2(0.0079, 0)], segments: 14, seamTile: 0.02, material: "plastic.matte:121212"),
                  Xform(translation: center + V3(0, 0, s * (t / 2 + 0.00005) - (s < 0 ? 0.0003 : 0)), rotation: facing(V3(0, 0, 1))))
            if detail {
                for k in 0..<4 {
                    let a = Float(k) / 4 * 2 * .pi + spin * .pi / 180 + 0.4
                    let p = center + V3(cos(a) * (gullet - 0.014), sin(a) * (gullet - 0.014), s * (t / 2 + 0.0001))
                    m.add(cuboid(V3(0.022, 0.0011, 0.0002), material: "plastic.matte:121212"),
                          Xform(translation: p, rotation: simd_quatf(angle: a, axis: V3(0, 0, 1))))
                }
                // Printed hub ring on the front face (generic brand-free marking).
                if s > 0 {
                    m.add(Prim.lathe([V2(0.024, 0), V2(0.032, 0), V2(0.032, 0.0002), V2(0.024, 0.0002)], segments: 20, seamTile: 0.05,
                                     material: coated ? "plastic.matte:E8E4DA" : "plastic.matte:2B2B2E"),
                          Xform(translation: center + V3(0, 0, t / 2), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
                }
            }
        }
    }

    /// Open-front stacking bin (polypropylene), back against the board, base at `at.y`, front toward +Z.
    func addBin(_ m: inout Model, at: V3, width w: Float, depth d: Float, tint: UInt32, rng: inout SeededRNG, detail: Bool, fill: Float) {
        let mat: MaterialKey = "plastic.tool:" + String(format: "%06X", tint)
        let hb: Float = 0.075, hf: Float = 0.04, wall: Float = 0.0022
        // Side wall profile (z, y): tall back, sloped top falling to a low front with a hopper lip.
        let side = Shape2D.rounded([V2(0, 0), V2(d, 0), V2(d, hf), V2(d - 0.012, hf + 0.004), V2(d * 0.45, hb), V2(0, hb)], radius: 0.003, segments: 1)
        for s: Float in [-1, 1] {
            m.add(Prim.extrude(side, depth: wall, bevel: 0.0006, bevelSegments: 1, material: mat),
                  Xform(translation: V3(at.x + s * (w / 2 - wall / 2), at.y, at.z), rotation: simd_quatf(degrees: -90, axis: .up)))
        }
        m.add(Prim.roundedBox(V3(w - 0.001, wall, d), radius: 0.0008, bevelSegments: 1, material: mat), Xform(translation: V3(at.x, at.y + wall / 2, at.z + d / 2)))
        m.add(Prim.roundedBox(V3(w - 0.001, hb, wall), radius: 0.0008, bevelSegments: 1, material: mat), Xform(translation: V3(at.x, at.y + hb / 2, at.z + wall / 2)))
        m.add(Prim.roundedBox(V3(w - 0.001, hf, wall), radius: 0.0008, bevelSegments: 1, material: mat), Xform(translation: V3(at.x, at.y + hf / 2, at.z + d - wall / 2)))
        // Label window on the front lip.
        m.add(cuboid(V3(w * 0.6, 0.016, 0.0006), material: "paper.sheet"),
              Xform(translation: V3(at.x, at.y + hf * 0.55, at.z + d + 0.0002)))
        // Screws: a low heap plus loose ones on top.
        let heapH = 0.03 * fill
        var heap = Prim.superellipsoid(V3(w - 0.012, heapH * 2, d - 0.03), exponent: 2.6, subdivisions: detail ? 3 : 2, material: "metal.galvanized") { dir in
            1 + 0.06 * sin(dir.x * 31 + dir.z * 17) * cos(dir.z * 23)
        }
        heap.deform { p in V3(p.x, max(0, p.y), p.z) }
        m.add(heap, Xform(translation: V3(at.x, at.y + wall, at.z + d * 0.48)))
        if detail {
            for _ in 0..<2 {
                let p = V3(at.x + rng.float(-w * 0.32...w * 0.32), at.y + wall + heapH * 0.8, at.z + d * 0.48 + rng.float(-0.03...0.03))
                let q = simd_quatf(degrees: rng.float(0...360), axis: .up) * simd_quatf(degrees: 90 + rng.float(-15...15), axis: V3(0, 0, 1))
                m.add(Prim.lathe([V2(0, 0), V2(0.0018, 0.0), V2(0.0018, 0.03), V2(0.0042, 0.031), V2(0.0042, 0.0335), V2(0, 0.0345)], segments: 6, seamTile: 0.02,
                                 material: "metal.galvanized"), Xform(translation: p, rotation: q))
            }
        }
    }
}
