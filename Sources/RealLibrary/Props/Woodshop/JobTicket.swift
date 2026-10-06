import simd
import Foundation

/// In-shop mission ticket: a letter-size hardboard clipboard holding a printed blueprint, lying flat.
/// Real specs: 9 x 12-1/2 in (229 x 318 mm) tempered hardboard, 1/8 in (3.2 mm) thick, 3/8 in corner
/// radius; a 1 mm pencil dent across the foot sized for a carpenter pencil (13 mm wide); a 4 in (102 mm)
/// low-profile steel clip riveted 9 mm below the head edge (base plate, rolled spring barrel, jaw with an
/// upturned lip, lever with a rolled thumb end). Sheet: 8-1/2 x 11 in blueprint paper (white lines on
/// diazo blue) with a border, a plan of a small deck frame with joists, dimension lines and a section
/// bubble, and a title block in the lower right; the lower left corner curls up about 12 mm.
/// Story detail: graphite check marks beside the title block and sawdust in the pencil dent.
/// Frame: board on y = 0, clip (head) toward -Z, reader at +Z, centered on X/Z.
public struct JobTicket: RealAsset {
    public static let id = "job-ticket"
    public static let summary = "Hardboard clipboard with a steel clip holding a blueprint job sheet: title block, plan lines, curled corner, pencil dent."
    public static let tags = ["prop", "workshop", "handheld", "paper", "wood"]
    public static let budget = 4_200
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 0, elevation: 62, distance: 0.8, studio: true)

    /// Board size (m): width X, length Z.
    public var boardSize = V2(0.2286, 0.3175)
    /// Board thickness (m).
    public var boardThickness: Float = 0.0032
    /// Sheet size (m): width X, length Z (8-1/2 x 11 in).
    public var sheetSize = V2(0.2159, 0.2794)
    /// Blueprint ground color (sRGB hex).
    public var blueprintColor: UInt32 = 0x1F4E8C
    /// Line color on the blueprint (sRGB hex).
    public var lineColor: UInt32 = 0xE8EEF5
    /// Board material.
    public var board: MaterialKey = "wood.hardboard"
    /// Clip steel.
    public var clipMaterial: MaterialKey = "metal.chrome"
    /// Height the curled sheet corner lifts (m).
    public var curl: Float = 0.012
    public init() {}

    // MARK: layout

    var zHead: Float { -boardSize.y / 2 }
    var zFoot: Float { boardSize.y / 2 }
    /// Sheet top edge (just under the clip barrel) and its rectangle.
    var sheetZ0: Float { clipZ + 0.0055 }
    var sheetX0: Float { -sheetSize.x / 2 }
    var paperY: Float { boardThickness + 0.0001 }
    /// Pencil dent center line (z) and width.
    var dentZ: Float { zFoot - 0.0095 }
    var dentWidth: Float { 0.012 }
    var clipZ: Float { zHead + 0.0145 }

    /// Sheet lift at a point: zero except near the lower left corner, rising with a soft roll.
    func lift(_ x: Float, _ z: Float) -> Float {
        let cx = sheetX0, cz = sheetZ0 + sheetSize.y
        let d = (x - cx) + (cz - z) // distance from the corner along the diagonal-ish band
        let r: Float = 0.055
        guard d < r else { return 0 }
        let u = 1 - max(0, d) / r
        return curl * u * u
    }
    func sheetPoint(_ x: Float, _ z: Float, _ off: Float = 0) -> V3 { V3(x, paperY + lift(x, z) + off, z) }

    // MARK: public frame

    /// Thumb press on the clip lever (asset space).
    public var clipPress: V3 { V3(0, boardThickness + 0.0157, clipZ - 0.015) }
    /// Clip jaw lip where the sheet is held (asset space).
    public var clipJaw: V3 { V3(0, paperY + 0.0006, clipZ + 0.021) }
    /// Center of the sheet (asset space).
    public var sheetCenter: V3 { V3(0, paperY, sheetZ0 + sheetSize.y / 2) }
    /// Center of the title block (asset space).
    public var titleBlockCenter: V3 { sheetPoint(sheetX0 + sheetSize.x - 0.042, sheetZ0 + sheetSize.y - 0.025) }
    /// Tip of the curled corner (asset space).
    public var curledCorner: V3 { sheetPoint(sheetX0, sheetZ0 + sheetSize.y) }
    /// Center of the pencil dent floor and its axis (along X).
    public var pencilSlot: (center: V3, axis: V3) { (V3(0, boardThickness - 0.001, dentZ), V3(1, 0, 0)) }
    /// Edge grip: middle of the right long edge (asset space).
    public var grip: V3 { V3(boardSize.x / 2, boardThickness / 2, 0) }

    // MARK: geometry

    /// Thickened polyline in the side (z, y) plane, extruded across X: a bent strip of steel.
    func bentStrip(_ path: [V2], thick: Float, width: Float, material: MaterialKey) -> Surface {
        var a: [V2] = [], b: [V2] = []
        for i in path.indices {
            let p = path[i]
            let d0 = i > 0 ? simd_normalize(p - path[i - 1]) : simd_normalize(path[1] - p)
            let d1 = i < path.count - 1 ? simd_normalize(path[i + 1] - p) : d0
            let d = simd_normalize(d0 + d1), n = V2(-d.y, d.x)
            a.append(p + n * thick / 2); b.append(p - n * thick / 2)
        }
        let outline = a + b.reversed()
        // Outline x = z, y = y; extrude depth along local Z, then turn local Z to +X.
        return Prim.extrude(outline, depth: width, bevel: min(0.0003, thick * 0.3), bevelSegments: 1, material: material)
            .transformed(Xform(rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 1, 0))))
    }

    /// A white line on the sheet from a to b (sheet x, z), `w` wide, following the curl.
    func line(_ s: inout Surface, _ a: V2, _ b: V2, _ w: Float, _ off: Float) {
        let len = simd_distance(a, b)
        guard len > 1e-5 else { return }
        let d = (b - a) / len, n = V2(-d.y, d.x) * w / 2
        let segs = max(1, Int(len / 0.012))
        let base = UInt32(s.positions.count)
        for i in 0...segs {
            let p = a + (b - a) * Float(i) / Float(segs)
            for q in [p - n, p + n] { s.add(sheetPoint(q.x, q.y, off), .up, V2(q.x, q.y)) }
        }
        for i in 0..<UInt32(segs) {
            let k = base + 2 * i
            s.quad(k, k + 1, k + 3, k + 2)
        }
    }

    func rect(_ s: inout Surface, _ x0: Float, _ z0: Float, _ x1: Float, _ z1: Float, _ w: Float, _ off: Float) {
        line(&s, V2(x0, z0), V2(x1, z0), w, off); line(&s, V2(x1, z0 - w / 2), V2(x1, z1 + w / 2), w, off)
        line(&s, V2(x1, z1), V2(x0, z1), w, off); line(&s, V2(x0, z1 + w / 2), V2(x0, z0 - w / 2), w, off)
    }

    func finish(_ s: Surface) -> Surface {
        var s = s
        s.recomputeNormals(weldSeams: false)
        if s.normals.reduce(V3.zero, +).y < 0 { s = s.flipped() }
        s.computeTangents()
        return s
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let W = boardSize.x, t = boardThickness, rc: Float = 0.0095
        let hex = { (c: UInt32) in String(format: "%06X", c) }
        var levels: [Model] = []
        for l in 0..<2 {
            var m = Model(name: Self.id)
            // Board: head section, thinner floor under the pencil dent, foot strip.
            let toFlat = simd_quatf(angle: -.pi / 2, axis: V3(1, 0, 0)) // outline y -> -z, depth -> +y
            let d0 = dentZ - dentWidth / 2, d1 = dentZ + dentWidth / 2
            let arc = l == 0 ? 6 : 2
            func corner(_ c: V2, _ a0: Float) -> [V2] { (0...arc).map { k in let a = a0 + Float(k) / Float(arc) * .pi / 2; return c + V2(cos(a), sin(a)) * rc } }
            // Outline coordinates (x, -z).
            let head: [V2] = [V2(-W / 2, -d0), V2(W / 2, -d0)] + corner(V2(W / 2 - rc, -zHead - rc), 0) + corner(V2(-W / 2 + rc, -zHead - rc), .pi / 2)
            m.add(Prim.extrude(head, depth: t, bevel: 0.0006, bevelSegments: 1, material: board), Xform(translation: V3(0, t / 2, 0), rotation: toFlat))
            let floorT = t - 0.001
            m.add(Prim.extrude([V2(-W / 2, -d1 - 0.0003), V2(W / 2, -d1 - 0.0003), V2(W / 2, -d0 + 0.0003), V2(-W / 2, -d0 + 0.0003)],
                               depth: floorT, bevel: 0.0002, bevelSegments: 1, material: board), Xform(translation: V3(0, floorT / 2, 0), rotation: toFlat))
            let foot: [V2] = corner(V2(-W / 2 + rc, -zFoot + rc), .pi) + corner(V2(W / 2 - rc, -zFoot + rc), 1.5 * .pi) + [V2(W / 2, -d1), V2(-W / 2, -d1)]
            m.add(Prim.extrude(foot, depth: t, bevel: 0.0006, bevelSegments: 1, material: board), Xform(translation: V3(0, t / 2, 0), rotation: toFlat))

            // Blueprint sheet: grid that follows the curl, with an underside where the corner lifts.
            let nx = l == 0 ? 18 : 6, nz = l == 0 ? 22 : 8
            var top = Surface(material: "paper.sheet:" + hex(blueprintColor)), under = Surface(material: "paper.sheet:DCE2EA")
            for j in 0...nz { for i in 0...nx {
                let x = sheetX0 + sheetSize.x * Float(i) / Float(nx), z = sheetZ0 + sheetSize.y * Float(j) / Float(nz)
                top.add(sheetPoint(x, z), .up, V2(x, z)); under.add(sheetPoint(x, z, -0.00008), .up, V2(x, z))
            }}
            let row = UInt32(nx + 1)
            for j in 0..<UInt32(nz) { for i in 0..<UInt32(nx) {
                let a = j * row + i
                top.quad(a, a + row, a + row + 1, a + 1); under.quad(a, a + 1, a + row + 1, a + row)
            }}
            top.recomputeNormals(weldSeams: false); top.computeTangents(); m.add(top)
            under.recomputeNormals(weldSeams: false); under.computeTangents(); m.add(under)

            // Line work.
            var ink = Surface(material: "paper.sheet:" + hex(lineColor))
            let X0 = sheetX0, Z0 = sheetZ0, SW = sheetSize.x, SL = sheetSize.y
            let off: Float = 0.00012
            rect(&ink, X0 + 0.010, Z0 + 0.014, X0 + SW - 0.010, Z0 + SL - 0.010, 0.0009, off)            // border
            // Title block, lower right: frame, rows, label bars.
            let tx0 = X0 + SW - 0.084, tx1 = X0 + SW - 0.010, tz0 = Z0 + SL - 0.046, tz1 = Z0 + SL - 0.010
            rect(&ink, tx0, tz0, tx1, tz1, 0.0007, off)
            for k in 1...3 { let z = tz0 + Float(k) * 0.009; line(&ink, V2(tx0, z), V2(tx1, z), 0.0004, off) }
            line(&ink, V2(tx0 + 0.030, tz0), V2(tx0 + 0.030, tz1), 0.0004, off)
            if l == 0 {
                for k in 0..<4 {
                    let z = tz0 + 0.0045 + Float(k) * 0.009
                    line(&ink, V2(tx0 + 0.004, z), V2(tx0 + 0.022 - Float(k % 2) * 0.006, z), 0.0018, off)            // labels
                    line(&ink, V2(tx0 + 0.034, z), V2(tx1 - 0.006 - Float((k * 7) % 3) * 0.008, z), 0.0022, off)  // entries
                }
                // Job number, large, top left.
                line(&ink, V2(X0 + 0.018, Z0 + 0.026), V2(X0 + 0.074, Z0 + 0.026), 0.0042, off)
                line(&ink, V2(X0 + 0.018, Z0 + 0.034), V2(X0 + 0.050, Z0 + 0.034), 0.0018, off)
                // Plan: deck frame, rim joists and 16 in o.c. joists at 1:24.
                let px0 = X0 + 0.040, px1 = X0 + SW - 0.040, pz0 = Z0 + 0.060, pz1 = Z0 + 0.170
                rect(&ink, px0, pz0, px1, pz1, 0.0012, off)
                let joists = 7
                for k in 1..<joists { let x = px0 + (px1 - px0) * Float(k) / Float(joists); line(&ink, V2(x, pz0), V2(x, pz1), 0.0006, off) }
                line(&ink, V2(px0, (pz0 + pz1) / 2), V2(px1, (pz0 + pz1) / 2), 0.0004, off)   // blocking line
                // Dimension lines with ticks.
                let dz = pz1 + 0.010
                line(&ink, V2(px0, dz), V2(px1, dz), 0.0004, off)
                for x in [px0, px1] { line(&ink, V2(x - 0.002, dz + 0.002), V2(x + 0.002, dz - 0.002), 0.0004, off); line(&ink, V2(x, pz1 + 0.003), V2(x, dz + 0.003), 0.0003, off) }
                line(&ink, V2((px0 + px1) / 2 - 0.010, dz - 0.004), V2((px0 + px1) / 2 + 0.010, dz - 0.004), 0.0018, off)
                let dx = px0 - 0.010
                line(&ink, V2(dx, pz0), V2(dx, pz1), 0.0004, off)
                for z in [pz0, pz1] { line(&ink, V2(dx - 0.002, z - 0.002), V2(dx + 0.002, z + 0.002), 0.0004, off) }
                // Posts at the corners.
                for (x, z) in [(px0, pz0), (px1, pz0), (px0, pz1), (px1, pz1)] { rect(&ink, x - 0.003, z - 0.003, x + 0.003, z + 0.003, 0.0005, off) }
                // Section bubble and leader.
                var bubble: [V2] = []
                for k in 0...16 { let a = Float(k) / 16 * 2 * .pi; bubble.append(V2(px1 - 0.012 + 0.007 * cos(a), pz1 + 0.032 + 0.007 * sin(a))) }
                for k in 0..<16 { line(&ink, bubble[k], bubble[k + 1], 0.0005, off) }
                line(&ink, V2(px1 - 0.019, pz1 + 0.032), V2(px1 - 0.005, pz1 + 0.032), 0.0004, off)
                line(&ink, V2(px1 - 0.012, pz1 + 0.025), V2(px1 - 0.02, pz1 + 0.006), 0.0004, off)
                // Notes block: cut list bars.
                for k in 0..<5 {
                    let z = pz1 + 0.026 + Float(k) * 0.0065
                    line(&ink, V2(X0 + 0.020, z), V2(X0 + 0.020 + 0.06 + Float((k * 5) % 4) * 0.008, z), 0.0016, off)
                }
            }
            m.add(finish(ink))

            // Graphite check marks beside the title block (LOD0 story detail).
            if l == 0 {
                var g = Surface(material: "graphite.pencil")
                var pr = rng.fork(4)
                for k in 0..<3 {
                    let z = tz0 + 0.0045 + Float(k) * 0.009, x = tx0 - 0.010 + pr.float(-0.001...0.001)
                    line(&g, V2(x - 0.003, z - 0.001), V2(x - 0.0012, z + 0.0015), 0.0007, off * 2)
                    line(&g, V2(x - 0.0012, z + 0.0015), V2(x + 0.004, z - 0.003), 0.0007, off * 2)
                }
                m.add(finish(g))
                // Sawdust caught in the pencil dent.
                var sd = rng.fork(6)
                for _ in 0..<7 {
                    let s = sd.float(0.0012...0.0026)
                    m.add(Prim.superellipsoid(V3(s, s * 0.35, s * 0.8), exponent: 2.5, subdivisions: 2, material: "wood.sawdust"),
                          Xform(translation: V3(sd.float(-W / 2 + 0.01...W / 2 - 0.01), floorT + 0.0002, dentZ + sd.float(-0.004...0.004)),
                                rotation: simd_quatf(angle: sd.float(0...3), axis: .up)))
                }
            }

            // MARK: clip
            let cw: Float = 0.102, steel = clipMaterial, yb = t
            // Base plate under the barrel, riveted to the board.
            m.add(bentStrip([V2(clipZ - 0.0115, yb + 0.0005), V2(clipZ + 0.004, yb + 0.0005)], thick: 0.001, width: cw * 0.9, material: steel))
            if l == 0 {
                for x in [-0.03, 0.03] as [Float] {
                    rivet(&m, at: V3(x, yb + 0.001, clipZ - 0.005), normal: .up, radius: 0.0032, segments: 10, material: steel)
                }
            }
            // Spring barrel (rolled steel) along X.
            let rB: Float = 0.0042, yc = yb + 0.001 + rB
            m.add(Prim.cylinder(radius: rB, height: cw * 0.94, bevel: 0.0008, segments: l == 0 ? 20 : 10, bevelSegments: 1, material: steel),
                  Xform(translation: V3(-cw * 0.47, yc, clipZ), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))))
            // Jaw: from the barrel top, forward and down to the paper, lip turned up.
            let jaw: [V2] = [V2(clipZ, yc + rB - 0.0002), V2(clipZ + 0.008, yc + rB - 0.0012), V2(clipZ + 0.019, paperY + 0.0012),
                             V2(clipZ + 0.023, paperY + 0.0008), V2(clipZ + 0.0265, paperY + 0.0022)]
            m.add(bentStrip(jaw, thick: 0.0009, width: cw, material: steel))
            // Lever: back from the barrel, rising, with a rolled thumb end.
            let lever: [V2] = [V2(clipZ, yc + rB - 0.0002), V2(clipZ - 0.006, yc + rB + 0.0018), V2(clipZ - 0.0135, yb + 0.0125)]
            m.add(bentStrip(lever, thick: 0.0009, width: cw * 0.86, material: steel))
            m.add(Prim.cylinder(radius: 0.0022, height: cw * 0.86, bevel: 0.0005, segments: l == 0 ? 12 : 6, bevelSegments: 1, material: steel),
                  Xform(translation: V3(-cw * 0.43, yb + 0.0135, clipZ - 0.015), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))))
            groundAO(&m, height: 0.01, floor: 0.6)
            levels.append(m)
        }
        return LODModel(levels: levels, switchDistances: [1.2])
    }
}
