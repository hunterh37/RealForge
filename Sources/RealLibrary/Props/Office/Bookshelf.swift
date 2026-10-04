import simd
import Foundation

/// Open bookcase, 90 x 190 x 32 cm, 18 mm oak-veneered board: sides, top, recessed 70 mm plinth, bottom
/// shelf, four shelves and a 6 mm back panel in a rebate. Filled the way an office shelf is used: runs of
/// cloth-bound books (board covers, rounded spines, page blocks visible at the top, some leaning), flat
/// stacks, lever-arch binders with spine labels, steel bookends, gaps and a stoneware vase and bowl.
public struct Bookshelf: RealAsset {
    public static let id = "bookshelf"
    public static let summary = "Open oak-veneer bookcase with five shelves of cloth-bound books, leaning and stacked, binders, bookends and stoneware decor."
    public static let tags = ["prop", "office", "furniture", "wood", "book"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 10, distance: 1.05, studio: true)

    public var width: Float = 0.9
    public var height: Float = 1.9
    public var depth: Float = 0.32
    /// Carcass veneer (`wood.veneer-walnut` for the dark version).
    public var wood: MaterialKey = "wood.veneer-oak"
    /// Book cloth palette, four tints (one draw call each).
    public var bookColors = ["6B2220", "203A57", "2F4A36", "CDBF9F"]
    /// Binders and bookends.
    public var binder: MaterialKey = "plastic.matte:2A2B2D"
    public var decor: MaterialKey = "ceramic.stoneware"
    public init() {}

    /// A book or binder: size (x thickness, y height, z depth) and placement of its local frame
    /// (bottom center of the spine block at the origin, spine toward +Z).
    struct Book { var size: V3; var x: Xform; var tint: Int; var binder: Bool; var label: Bool }

    public func build(seed: UInt64) -> LODModel {
        let (books, extras) = layout(seed: seed)
        return LODModel(levels: [model(books, extras, seed: seed, detail: true), model(books, extras, seed: seed, detail: false)],
                        switchDistances: [6])
    }

    var panel: Float { 0.018 }
    var plinth: Float { 0.07 }
    /// Interior clear height of each of the five compartments.
    var bay: Float { (height - panel - (plinth + panel) - 4 * panel) / 5 }
    func floorY(_ i: Int) -> Float { plinth + panel + Float(i) * (bay + panel) }

    enum Extra { case bookend(V3, Float), vase(V3), bowl(V3) }

    func layout(seed: UInt64) -> ([Book], [Extra]) {
        var rng = SeededRNG(seed: seed)
        var books: [Book] = []
        var extras: [Extra] = []
        let inner = width - 2 * panel
        let front = depth / 2 - 0.018
        for shelf in 0..<5 {
            var r = rng.fork(shelf * 31 + 7)
            let y0 = floorY(shelf)
            var x = -inner / 2 + 0.001
            let right = inner / 2 - 0.002
            var placedVase = false
            func standing(_ t: Float, _ h: Float, _ d: Float, at xr: Float, lean: Float, tint: Int, binder: Bool = false) {
                // Book stands on its bottom-right corner at xr when leaning (lean > 0 tilts the top to -X).
                let q = simd_quatf(degrees: lean, axis: V3(0, 0, 1))
                let pivot = V3(xr, y0, front - r.float(0...0.008))
                let local = V3(-t / 2, 0, -d / 2)
                books.append(Book(size: V3(t, h, d), x: Xform(translation: pivot + q.act(local), rotation: q).jittered(&r, deg: 0.3, offset: 0.0003),
                                  tint: tint, binder: binder, label: binder || r.chance(0.35)))
            }
            if shelf == 0 {
                // Lever-arch binders, A4: 32 x 28.5 cm, 50 or 80 mm spines.
                let n = r.int(5...7)
                for _ in 0..<n {
                    let t: Float = r.chance(0.6) ? 0.08 : 0.05
                    standing(t, 0.318, 0.285, at: x + t, lean: 0, tint: 0, binder: true)
                    x += t + 0.0015
                }
                extras.append(.bookend(V3(x + 0.001, y0, front - 0.07), 1))
                x += 0.06
            }
            var lastH: Float = 0
            var runOpen = false
            while x < right - 0.04 {
                let roll = r.float()
                let room = right - x
                if shelf == 3 && !placedVase && (roll < 0.25 || room < 0.32) && room > 0.15 {
                    // Vase on its own with air around it.
                    x += 0.03
                    extras.append(.vase(V3(x + 0.055, y0, 0.01)))
                    x += 0.13
                    placedVase = true
                    runOpen = false
                    continue
                }
                if roll < 0.14 && runOpen && room > 0.12 {
                    // Gap: lean the last book into it or stop the run with a bookend.
                    if r.chance(0.5), let last = books.last, !last.binder {
                        books.removeLast()
                        let t = last.size.x, h = last.size.y, d = last.size.z
                        let th: Float = r.float(9...18), a = th * .pi / 180
                        let s = (lastH - t * sin(a)) / cos(a)
                        let prevRight = x - t - 0.001
                        let xr = prevRight + t * cos(a) + s * sin(a)
                        if h * cos(a) + t * sin(a) < bay - 0.01, lastH > 0.1 {
                            standing(t, h, d, at: xr, lean: th, tint: last.tint)
                            x = xr + 0.002
                        } else { books.append(last) }
                    } else {
                        extras.append(.bookend(V3(x + 0.001, y0, front - 0.07), 1))
                        x += 0.004
                    }
                    x += r.float(0.05...0.12)
                    runOpen = false
                    continue
                }
                if roll < 0.3 && room > 0.3 {
                    // Flat stack, largest at the bottom, spines out.
                    let n = r.int(2...5)
                    var sizes: [V3] = (0..<n).map { _ in V3(r.float(0.016...0.04), r.float(0.2...0.28), r.float(0.15...0.21)) }
                    sizes.sort { $0.y > $1.y }
                    var yy = y0
                    let cx = x + 0.15
                    for s in sizes where yy + s.x < y0 + bay - 0.02 {
                        let q = simd_quatf(degrees: r.float(-3...3), axis: .up) * simd_quatf(degrees: 90, axis: V3(0, 0, 1))
                        let c = V3(cx + r.float(-0.008...0.008), yy + s.x / 2, front - s.z / 2 - r.float(0...0.01))
                        // Lying book: local +X (thickness) maps to +Y, local Y (height) to -X.
                        books.append(Book(size: s, x: Xform(translation: c - q.act(V3(0, s.y / 2, 0)), rotation: q),
                                          tint: r.int(0...3), binder: false, label: r.chance(0.3)))
                        yy += s.x
                    }
                    if shelf == 1 && extras.allSatisfy({ if case .bowl = $0 { return false }; return true }) && yy < y0 + bay - 0.08 {
                        extras.append(.bowl(V3(cx, yy, 0.02)))
                    }
                    x += 0.3 + r.float(0.01...0.04)
                    runOpen = false
                    continue
                }
                // Standing run: a matched set or a mixed run.
                let set = r.chance(0.35)
                let n = r.int(set ? 3...6 : 4...11)
                let setT = r.float(0.022...0.034), setH = min(bay - 0.03, r.float(0.21...0.27)), setTint = r.int(0...3)
                if !runOpen && x > -inner / 2 + 0.05 {
                    extras.append(.bookend(V3(x + 0.001, y0, front - 0.07), -1))
                    x += 0.004
                }
                for _ in 0..<n {
                    let t = set ? setT : r.float(0.014...0.048)
                    guard x + t < right else { break }
                    let h = set ? setH : min(bay - 0.025, r.float(0.17...0.3))
                    let d = min(depth - 0.05, max(0.12, h * r.float(0.62...0.78)))
                    standing(t, h, d, at: x + t, lean: 0, tint: set ? setTint : r.int(0...3))
                    x += t + 0.001
                    lastH = h
                }
                runOpen = true
            }
        }
        return (books, extras)
    }

    func model(_ books: [Book], _ extras: [Extra], seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed &+ 99)
        var m = Model(name: Self.id)
        let W = width, H = height, D = depth, p = panel
        let seg = detail ? 2 : 1
        let backT: Float = 0.006, backZ = -D / 2 + 0.008
        // Sides: grain vertical.
        for s: Float in [-1, 1] {
            let (b, x) = board(from: V3(s * (W / 2 - p / 2), 0, 0), to: V3(s * (W / 2 - p / 2), H, 0), width: D, thick: p, up: V3(1, 0, 0),
                               bevel: 0.0015, material: wood)
            m.add(b, x.jittered(&rng, deg: 0.03, offset: 0.0002))
        }
        m.add(Prim.roundedBox(V3(W - 0.0004, p, D), radius: 0.0015, bevelSegments: seg, material: wood), Xform(translation: V3(0, H - p / 2, 0)))
        // Plinth kick board recessed 15 mm, bottom shelf and four shelves.
        let (k, kx) = board(from: V3(-W / 2 + p, plinth / 2, D / 2 - 0.015 - p / 2), to: V3(W / 2 - p, plinth / 2, D / 2 - 0.015 - p / 2),
                            width: plinth - 0.002, thick: p, up: V3(0, 0, 1), bevel: 0.0015, material: wood)
        m.add(k, kx)
        let shelfD = D - 0.011
        for i in 0..<5 {
            let y = i == 0 ? plinth + p / 2 : floorY(i) - p / 2
            m.add(Prim.roundedBox(V3(W - 2 * p - 0.001, p, shelfD), radius: 0.0015, bevelSegments: seg, material: wood),
                  Xform(translation: V3(0, y, D / 2 - shelfD / 2)).jittered(&rng, deg: 0.04, offset: 0.0002))
            if detail && i > 0 {
                // Shelf pins (5 mm) under each corner.
                for sx: Float in [-1, 1] { for z in [D / 2 - 0.05, -D / 2 + 0.06] {
                    m.add(cuboid(V3(0.006, 0.005, 0.005), material: binder), Xform(translation: V3(sx * (W / 2 - p - 0.003), y - p / 2 - 0.0025, z)))
                }}
            }
        }
        m.add(Prim.roundedBox(V3(W - 2 * p + 0.012, H - p - 0.003, backT), radius: 0.001, bevelSegments: 1, material: wood),
              Xform(translation: V3(0, (H - p) / 2, backZ)))

        let cloth = bookColors.map { MaterialKey("book.cloth:\($0)") }
        let label = cloth[3]
        for b in books {
            let t = b.size.x, h = b.size.y, d = b.size.z
            if !detail {
                m.add(cuboid(V3(t, h, d), material: b.binder ? binder : cloth[b.tint]), Xform(translation: b.x.point(V3(0, h / 2, 0)), rotation: b.x.rotation))
                continue
            }
            func put(_ s: Surface, _ c: V3, _ r: simd_quatf = .identity) { m.add(s, Xform(translation: b.x.point(c), rotation: b.x.rotation * r)) }
            if b.binder {
                // Lever-arch binder: two boards, rounded spine, label pocket and finger hole.
                put(cuboid(V3(0.0025, h, d - 0.004), material: binder), V3(-t / 2 + 0.00125, h / 2, -0.002))
                put(cuboid(V3(0.0025, h, d - 0.004), material: binder), V3(t / 2 - 0.00125, h / 2, -0.002))
                put(Prim.extrude(Shape2D.roundedRect(t, 0.008, radius: 0.0035, segments: 2), depth: h, bevel: 0, material: binder), V3(0, h / 2, d / 2 - 0.004),
                    simd_quatf(degrees: -90, axis: V3(1, 0, 0)))
                put(cuboid(V3(t * 0.62, 0.12, 0.0006), material: label), V3(0, h * 0.62, d / 2 + 0.0002))
                put(Prim.torus(major: 0.011, minor: 0.0022, segments: 12, sides: 4, material: binder), V3(0, h * 0.24, d / 2 + 0.0004),
                    simd_quatf(degrees: 90, axis: V3(1, 0, 0)))
                put(cuboid(V3(d * 0.85, h * 0.94, t * 0.6), material: "paper.pages"), V3(0, h / 2, -0.01), simd_quatf(degrees: 90, axis: .up))
                continue
            }
            let mat = cloth[b.tint]
            let board: Float = 0.0024
            // Cover (boards and rounded spine in one), page block standing 0.6 mm proud at the head and fore-edge
            // between the boards. Rotated so the page lines run front to back on top.
            let section = Shape2D.roundedRect(t, d, radius: min(0.0022, t * 0.25), segments: 1)
            put(Prim.extrude(section, depth: h - 0.0012, bevel: 0, material: mat), V3(0, h / 2 - 0.0006, 0), simd_quatf(degrees: -90, axis: V3(1, 0, 0)))
            put(cuboid(V3(d - 0.006, h - 0.004, t - 2 * board), material: "paper.pages"), V3(0, h / 2 + 0.0014, -0.0036), simd_quatf(degrees: 90, axis: .up))
            if b.label && b.tint != 3 {
                put(cuboid(V3(t * 0.7, min(0.05, h * 0.18), 0.0006), material: label), V3(0, h * 0.78, d / 2 + 0.0001))
            }
        }

        for e in extras {
            switch e {
            case let .bookend(p, side):
                // Folded steel bookend: base plate under the books, upright toward +X (side 1) or -X (-1).
                m.add(Prim.roundedBox(V3(0.0015, 0.16, 0.13), radius: 0.0006, bevelSegments: 1, material: binder),
                      Xform(translation: p + V3(0, 0.08, 0)))
                let bx = max(-width / 2 + panel + 0.06, min(width / 2 - panel - 0.06, p.x - side * 0.055))
                m.add(cuboid(V3(0.11, 0.0012, 0.12), material: binder), Xform(translation: V3(bx, p.y + 0.0006, p.z)))
            case let .vase(p):
                let prof: [V2] = Profile.smooth([V2(0, 0), V2(0.04, 0), V2(0.05, 0.03), V2(0.056, 0.08), V2(0.045, 0.15), V2(0.026, 0.19), V2(0.024, 0.21), V2(0.028, 0.222)], per: 3)
                m.add(Prim.lathe(Profile.shell(prof, wall: 0.004), segments: detail ? 28 : 14, seamTile: 0.1, material: decor), Xform(translation: p))
            case let .bowl(p):
                let prof: [V2] = Profile.smooth([V2(0, 0), V2(0.03, 0), V2(0.055, 0.02), V2(0.07, 0.05), V2(0.072, 0.055)], per: 3)
                m.add(Prim.lathe(Profile.shell(prof, wall: 0.004), segments: detail ? 28 : 14, seamTile: 0.1, material: decor), Xform(translation: p))
            }
        }
        groundAO(&m, height: 0.1, floor: 0.6)
        return m
    }
}
