import simd
import Foundation

/// Wall-mounted cantilever lumber rack, back against the wall plane z = `wallZ` and facing +Z: three powder-
/// coated steel tube uprights lag-bolted to the studs at 900 mm centers, five levels of 450 mm arms with
/// sleeve brackets, upturned end stops and rubber caps, loaded with stacks of SPF 2x4s, 1x6s, 2x6s, trim
/// 1x4s and 1x2s and a shelf of planed oak, maple and walnut boards in mixed widths and lengths (all built
/// with `Lumber`, so ends show sawn end grain and some stock carries grade stamps), plus two plywood
/// offcuts leaning on the uprights below the bottom arms.
public struct LumberRack: RealAsset {
    public static let id = "lumber-rack"
    public static let summary = "Wall cantilever lumber rack: three steel uprights, five arm levels of 2x4s, 1x6s, 2x6s, trim and hardwood, plywood offcuts leaning below."
    public static let tags = ["prop", "workshop", "wood", "metal", "industrial"]
    public static let budget = 15_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 24, elevation: 14, distance: 1.0, studio: true)

    /// Upright X positions, meters (before the whole rack is shifted on X to center its loaded bounds).
    public var uprights: [Float] = [-0.9, 0, 0.9]
    /// Arm heights (top of the arm tube), meters.
    public var levels: [Float] = [0.62, 0.95, 1.28, 1.61, 1.94]
    /// Arm reach from the wall, meters.
    public var armLength: Float = 0.45
    /// Upright height (top), meters; uprights run down to `uprightBase` (0 = floor-bearing with foot plates).
    public var uprightTop: Float = 2.14
    /// Upright bottom, meters.
    public var uprightBase: Float = 0
    /// Steel finish.
    public var steel: MaterialKey = "metal.rack-powdercoat"
    public init() {}

    enum Stock { case board(String, MaterialKey), hard(Float, MaterialKey) }

    /// Z of the wall plane (the uprights' back faces) in asset space; place the rack at wall z - wallZ.
    public var wallZ: Float { -armLength / 2 }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let layout = boards(&rng)
        var levelsOut: [Model] = []
        for l in 0..<2 {
            let lite = l == 1
            var m = Model(name: Self.id)
            hardware(&m, lite: lite)
            for (b, x, s) in layout { m.add(b.model(seed: s, lite: lite), x) }
            plywood(&m, seed: seed, lite: lite)
            groundAO(&m, height: 0.25, floor: 0.55)
            levelsOut.append(m)
        }
        // Center the loaded rack's bounds on X (boards overhang unevenly) and the arm reach on Z; the wall
        // plane ends up at `wallZ`.
        let b = levelsOut[0].bounds
        let shift = Xform(translation: V3(-(b.min.x + b.max.x) / 2, 0, wallZ))
        return LODModel(levels: levelsOut.map { $0.transformed(shift) }, switchDistances: [7])
    }

    /// Uprights, arms, brackets, end stops, caps and lag bolts.
    func hardware(_ m: inout Model, lite: Bool) {
        let seg = lite ? 1 : 2
        func box(_ size: V3, _ c: V3, _ r: Float = 0.003) {
            if lite { m.add(cuboid(size, material: steel), Xform(translation: c)) }
            else { m.add(Prim.roundedBox(size, radius: r, bevelSegments: 1, material: steel), Xform(translation: c)) }
        }
        let uw: Float = 0.05, ud: Float = 0.04
        for ux in uprights {
            // Upright tube against the wall, with a top cap plate and a base foot plate.
            box(V3(uw, uprightTop - uprightBase, ud), V3(ux, (uprightTop + uprightBase) / 2, 0.001 + ud / 2), 0.004)
            box(V3(uw + 0.008, 0.006, ud + 0.006), V3(ux, uprightTop + 0.002, 0.001 + ud / 2 + 0.002), 0.002)
            if uprightBase < 0.01 {
                // Floor foot plate with two anchor bolts.
                box(V3(0.1, 0.008, 0.09), V3(ux, 0.004, 0.046), 0.002)
                if !lite {
                    for dx: Float in [-0.035, 0.035] {
                        let hex = Prim.extrude(Shape2D.polygon(sides: 6, radius: 0.0075), depth: 0.006, bevel: 0.0006, bevelSegments: 1,
                                               material: "metal.galvanized")
                        m.add(hex, Xform(translation: V3(ux + dx, 0.008 + 0.003, 0.06), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
                    }
                }
            }
            // Wall bracket plates with lag bolts above and below the tube run.
            for y in [max(uprightBase, 0.2) + 0.06, (uprightTop + uprightBase) / 2 - 0.08, uprightTop - 0.07] {
                m.add(cuboid(V3(0.11, 0.06, 0.005), material: steel), Xform(translation: V3(ux, y, 0.0035)))
                if !lite {
                    // Lag screw heads (hex, chamfered) with flat washers.
                    for dx: Float in [-0.04, 0.04] {
                        let p = V3(ux + dx, y, 0.006)
                        m.add(Prim.lathe([V2(0, 0), V2(0.0095, 0), V2(0.0095, 0.0012), V2(0.009, 0.0016), V2(0, 0.0016)], segments: 10,
                                         seamTile: 0.05, material: "metal.galvanized"),
                              Xform(translation: p, rotation: facing(V3(0, 0, 1))))
                        let hex = Prim.extrude(Shape2D.polygon(sides: 6, radius: 0.0064), depth: 0.0055, bevel: 0.0006, bevelSegments: 1,
                                               material: "metal.galvanized")
                        m.add(hex, Xform(translation: p + V3(0, 0, 0.0015 + 0.00275)))
                    }
                }
            }
            for (k, ly) in levels.enumerated() {
                let ah: Float = 0.035, aw: Float = 0.035
                let ay = ly - ah / 2
                // Sleeve bracket clamped around the upright.
                box(V3(uw + 0.012, 0.09, ud + 0.01), V3(ux, ay - 0.015, 0.001 + ud / 2 + 0.003), 0.003)
                // Arm tube, gusset under it, upturned end stop with a rubber cap.
                let z0 = 0.001 + ud + 0.008, z1 = armLength
                box(V3(aw, ah, z1 - z0), V3(ux, ay, (z0 + z1) / 2), 0.003)
                let gusset = Shape2D.rounded([V2(0, 0), V2(0.11, 0), V2(0, -0.07)], radius: 0.004, segments: seg)
                m.add(Prim.extrude(gusset, depth: 0.006, bevel: 0.001, bevelSegments: 1, material: steel),
                      Xform(translation: V3(ux, ay - ah / 2, z0 - 0.001), rotation: simd_quatf(degrees: -90, axis: V3(0, 1, 0))))
                box(V3(aw, 0.05, 0.012), V3(ux, ly + 0.02, z1 - 0.006), 0.003)
                if !lite || k == 0 {
                    m.add(Prim.superellipsoid(V3(aw + 0.004, 0.018, 0.016), exponent: 4, subdivisions: 2, material: "rubber"),
                          Xform(translation: V3(ux, ly + 0.046, z1 - 0.006)))
                }
            }
        }
    }

    /// Board placements: (board, transform, seed).
    func boards(_ rng: inout SeededRNG) -> [(Lumber, Xform, UInt64)] {
        var out: [(Lumber, Xform, UInt64)] = []
        let zStart: Float = 0.058, zEnd = armLength - 0.016
        let feet: [Float] = [1.8288, 2.1336, 2.4384]
        let spans = zip(uprights, uprights.dropFirst()).map { ($0, $1) }
        func centerX(_ len: Float, _ r: inout SeededRNG) -> Float {
            if len > (uprights.last! - uprights.first!) + 0.2 { return r.float(-0.12...0.12) }
            let (lo, hi) = r.pick(spans)
            let a = hi - len / 2 + 0.06, b = lo + len / 2 - 0.06
            return a < b ? r.float(a...b) : (lo + hi) / 2
        }
        // Each level: columns across Z (stock and stack height).
        let plan: [[(Stock, Int)]] = [
            [(.board("2x4", "wood.lumber-pine"), 3), (.board("2x4", "wood.lumber-pine"), 4), (.board("2x4", "wood.lumber-pine"), 3), (.board("2x4", "wood.lumber-pine"), 2)],
            [(.board("1x6", "wood.lumber-pine"), 5), (.board("1x6", "wood.lumber-pine"), 4)],
            [(.hard(0.13, "wood.lumber-oak"), 2), (.hard(0.11, "wood.lumber-walnut"), 2), (.hard(0.085, "wood.lumber-maple"), 1)],
            [(.board("2x6", "wood.lumber-pine"), 3), (.board("2x6", "wood.lumber-pine"), 2), (.board("2x4", "wood.lumber-pine"), 2)],
            [(.board("1x4", "wood.lumber-pine"), 4), (.board("1x2", "wood.lumber-pine"), 3), (.board("1x4", "wood.lumber-pine"), 3)],
        ]
        var serial: UInt64 = 100
        for (li, cols) in plan.enumerated() where li < levels.count {
            var z = zStart
            for (stock, count) in cols {
                var proto = Lumber()
                var hardwood = false
                switch stock {
                case .board(let n, let mat):
                    let d = Lumber.nominal(n)!
                    proto.width = d.width; proto.thickness = d.thickness; proto.material = mat
                case .hard(let w, let mat):
                    proto.width = w * rng.float(0.9...1.05); proto.thickness = 0.0206; proto.material = mat
                    proto.easedEdges = false; proto.stamp = false; hardwood = true
                    // Hardwood from the yard: ends sealed with colored wax (green oak, red walnut, blue maple).
                    if mat.hasSuffix("walnut") { proto.endMaterial = "plastic.matte:8E2A22" }
                    else if mat.hasSuffix("oak") { proto.endMaterial = "plastic.matte:3E7A45" }
                    else { proto.endMaterial = "plastic.matte:2F5C9A" }
                }
                guard z + proto.width <= zEnd else { break }
                let cz = z + proto.width / 2
                var y = levels[li]
                for _ in 0..<count {
                    var b = proto
                    b.length = hardwood ? rng.float(1.15...2.2) : rng.pick(feet) - rng.float(0...0.004)
                    b.stamp = !hardwood && rng.chance(0.35)
                    if !hardwood {
                        // SPF mixes species: whiter spruce and yellower pine sticks in one stack.
                        let tone = rng.int(0...2)
                        if tone > 0 { b.material = proto.material + (tone == 1 ? ":EEDCB6" : ":DDBE88") }
                    }
                    if li == levels.count - 1 && !hardwood && rng.chance(0.4) {
                        // Old stock left up top: oxidized and grey.
                        b.material = "wood.pine-aged"; b.endMaterial = "wood.endgrain-fresh:A08E70"; b.stamp = false
                    }
                    serial += 1
                    // Stamps are anchored to the grain offset: keep stamped boards' offsets where the stamp lands.
                    if b.stamp {
                        let half = b.length / 2 - 0.15
                        b.grainOffset = V2(Lumber.anchors(seed: serial).stampX + rng.float(-half...half), rng.float(-0.006...0.006))
                    } else {
                        b.grainOffset = V2(rng.float(0...8), rng.float(0...3))
                    }
                    // Mill ends are rarely square: a few degrees of miter on some trimmed boards.
                    if rng.chance(0.25) { b.miterRight = rng.float(-4...4) }
                    let cx = centerX(b.length, &rng)
                    let yaw = rng.float(-0.12...0.12)
                    out.append((b, Xform(translation: V3(cx, y + 0.0004, cz), rotation: simd_quatf(degrees: yaw, axis: .up)), serial))
                    y += b.thickness + 0.0008
                }
                z += proto.width + rng.float(0.005...0.012)
            }
        }
        return out
    }

    /// Two plywood offcuts standing on the floor, leaning back against the uprights.
    func plywood(_ m: inout Model, seed: UInt64, lite: Bool) {
        let tilt: Float = 9 * .pi / 180
        let n = V3(0, sin(tilt), cos(tilt)), down = V3(0, -cos(tilt), sin(tilt))
        let rot = simd_quatf(simd_float3x3(V3(1, 0, 0), n, down))
        let sheets: [(Float, Float, Float)] = [(1.12, 0.5, -0.12), (0.78, 0.41, 0.2)]
        let sheetsMaxWidth = sheets[0].1
        var zFloor: Float = 0.001 + 0.04 + 0.002 + sin(tilt) * sheetsMaxWidth   // first sheet leans on the upright fronts
        for (i, (len, wid, cx)) in sheets.enumerated() {
            var p = PlywoodSheet()
            p.length = len; p.width = wid
            p.grainOffset = V2(Float(i) * 1.7, Float(i) * 0.9)
            let t = p.thickness
            let zBack = zFloor - sin(tilt) * wid
            // Back-top edge (local y = 0, z = -w/2) touches zBack; bottom-front edge rests on the floor.
            let T = V3(cx, cos(tilt) * wid / 2 + 0.0005, zBack + sin(tilt) * wid / 2)
            m.add(p.model(seed: seed &+ UInt64(i), lite: lite), Xform(translation: T, rotation: rot))
            zFloor += t / cos(tilt) + 0.0015
        }
    }
}
