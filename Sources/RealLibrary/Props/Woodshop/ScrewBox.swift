import simd
import Foundation

/// Hardware-store box of 100 #8 x 1-1/4 in wood screws, opened: 108 x 66 x 48 mm folding kraft
/// carton (1.2 mm board) with a reverse-tuck lid hinged on the back top edge and folded back about
/// 105 degrees, its tuck flap sticking forward, two end dust flaps splayed outward. A yellow printed label
/// band wraps the front and ends with print bars and a white size swatch. Inside, a heap of screws:
/// instanced copies of `WoodScrew` geometry (zigzag thread, plain heads) over a dark under-layer.
/// Front (label) faces +Z, lid at the back.
public struct ScrewBox: RealAsset {
    public static let id = "screw-box"
    public static let summary = "Small open kraft box of #8 x 1-1/4 in wood screws: folded cardboard, lid flap open, yellow label band, screw pile."
    public static let tags = ["prop", "workshop", "handheld", "metal", "paper"]
    public static let budget = 12_500
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 28, elevation: 34, distance: 0.42, studio: true)

    /// Outer box size (m): width X, height Y, depth Z.
    public var box = V3(0.108, 0.048, 0.066)
    /// Board thickness (m).
    public var board: Float = 0.0012
    /// Lid opening angle from closed (degrees).
    public var lidAngle: Float = 105
    /// Fill level of the screw heap above the box floor (m).
    public var fill: Float = 0.034
    /// Screws modelled on the visible top of the heap.
    public var visibleScrews = 25
    /// Carton board material.
    public var kraft: MaterialKey = "paper.screwbox-kraft"
    /// Label band color (sRGB hex).
    public var bandColor: UInt32 = 0xF2B705
    /// The screw the box holds.
    public var screw = WoodScrew().with { $0.packedFibres = false }
    /// Gap between the front wall and the one screw that fell out on the bench (m).
    public var looseScrewGap: Float = 0.012
    public init() {}

    // MARK: public frame

    /// Shift from the raw build frame (box centered at the origin) to asset space (bounds centered).
    var shift: V3 {
        let D = box.z, th = lidAngle * .pi / 180
        let lidLen = D - board, tuck: Float = 0.016
        let tip = V3(0, box.y + sin(th) * lidLen, -D / 2 + cos(th) * lidLen)
        let tuckEnd = tip + V3(0, -cos(th), sin(th)) * (-tuck)
        let zMin = min(-D / 2, min(tip.z, tuckEnd.z)) - 0.001, zMax = D / 2 + looseScrewGap + 0.0045
        return V3(0, 0, -(zMin + zMax) / 2)
    }
    /// Top center of the screw heap: where a hand reaches in to pick one screw.
    public var pickPoint: V3 { V3(0, board + fill + 0.003, 0) + shift }
    /// Hold point: middle of the box body.
    public var grip: V3 { V3(0, box.y * 0.5, 0) + shift }

    // MARK: build

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let W = box.x, H = box.y, D = box.z, t = board
        let band: MaterialKey = "paper.sheet:" + String(format: "%06X", bandColor)
        let ink: MaterialKey = "paper.sheet:1C1A17", swatch: MaterialKey = "paper.sheet"
        let red: MaterialKey = "paper.sheet:B3261E"

        func carton(_ m: inout Model, detail: Bool) {
            let r: Float = 0.0005, seg = detail ? 2 : 1
            // Floor and four walls (end walls inside the long walls, like a glued carton).
            m.add(Prim.roundedBox(V3(W - 2 * t, t, D - 2 * t), radius: r, bevelSegments: seg, material: kraft), Xform(translation: V3(0, t / 2, 0)))
            for s: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(W, H, t), radius: r, bevelSegments: seg, material: kraft), Xform(translation: V3(0, H / 2, s * (D - t) / 2)))
                m.add(Prim.roundedBox(V3(t, H - 0.0004, D - 2 * t + 0.0002), radius: r, bevelSegments: seg, material: kraft), Xform(translation: V3(s * (W - t) / 2, (H - 0.0004) / 2, 0)))
                // Glue flap seam on the ends: a second ply on the inside of each end wall, a little lower.
                m.add(Prim.roundedBox(V3(t * 0.8, H * 0.82, D - 2 * t - 0.002), radius: r * 0.8, bevelSegments: 1, material: kraft),
                      Xform(translation: V3(s * (W / 2 - t * 1.9), H * 0.41 + 0.0006, 0)))
            }
            // End dust flaps, splayed outward from the end-wall tops.
            let flapH: Float = 0.022
            for s: Float in [-1, 1] {
                let outline = Shape2D.rounded([V2(-(D - 2 * t) / 2, 0), V2((D - 2 * t) / 2, 0), V2((D - 2 * t) / 2 - 0.006, flapH), V2(-(D - 2 * t) / 2 + 0.010, flapH)], radius: 0.002, segments: 2)
                let flap = Prim.extrude(outline, depth: t * 0.9, bevel: 0.0003, bevelSegments: 1, material: kraft)
                let splay = rng.float(28...42)
                let q = simd_quatf(degrees: -s * splay, axis: V3(0, 0, 1)) * simd_quatf(degrees: 90, axis: V3(0, 1, 0))
                m.add(flap, Xform(translation: V3(s * (W - t) / 2, H - 0.0006, 0), rotation: q))
            }
            // Lid: hinged at the back top edge, opened back; tuck flap on its free end.
            let th = lidAngle * .pi / 180
            let lidLen = D - t
            let lid = Prim.roundedBox(V3(W - 0.0004, t, lidLen), radius: r, bevelSegments: seg, material: kraft)
            let qLid = simd_quatf(angle: -th, axis: V3(1, 0, 0))
            let hinge = V3(0, H + t / 2 - 0.0002, -D / 2 + t / 2)
            m.add(lid, Xform(translation: hinge + qLid.act(V3(0, 0, lidLen / 2)), rotation: qLid))
            // Tuck flap: rounded-corner tongue bent 90 degrees from the lid.
            let tuck: Float = 0.016
            let tongue = Shape2D.rounded([V2(-(W - 0.004) / 2, 0), V2((W - 0.004) / 2, 0), V2((W - 0.004) / 2 - 0.004, tuck), V2(-(W - 0.004) / 2 + 0.004, tuck)], radius: 0.004, segments: 3)
            let qT = qLid * simd_quatf(degrees: 180, axis: V3(1, 0, 0))
            let tipPt = hinge + qLid.act(V3(0, 0, lidLen))
            m.add(Prim.extrude(tongue, depth: t * 0.9, bevel: 0.0003, bevelSegments: 1, material: kraft),
                  Xform(translation: tipPt + qLid.act(V3(0, -t * 0.4, 0)), rotation: qT))
            // Crease line at the hinge: a slight rounded fold.
            m.add(Prim.cylinder(radius: t * 0.75, height: W - 0.001, bevel: 0.0002, segments: 8, bevelSegments: 1, material: kraft),
                  Xform(translation: V3(-(W - 0.001) / 2, H - 0.0002, -D / 2 + t / 2), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))

            // Label band: front and both ends, mid-height.
            let bh: Float = 0.022, by = H * 0.48, o: Float = 0.00015
            m.add(cuboid(V3(W + 2 * o, bh, 0.0002), material: band), Xform(translation: V3(0, by, D / 2 + o)))
            for s: Float in [-1, 1] {
                m.add(cuboid(V3(0.0002, bh, D * 0.72), material: band), Xform(translation: V3(s * (W / 2 + o), by, D * 0.14)))
            }
            if detail {
                let zf = D / 2 + 2 * o + 0.0001
                // Title print: "WOOD SCREWS" bar line, size line, count; size swatch with a drawn screw.
                func bar(_ x: Float, _ y: Float, _ w: Float, _ h: Float, _ mat: MaterialKey, z: Float = 0) {
                    m.add(cuboid(V3(w, h, 0.0002), material: mat), Xform(translation: V3(x, y, zf + z)))
                }
                bar(-0.018, by + 0.0055, 0.050, 0.0045, ink)
                bar(-0.026, by - 0.0010, 0.034, 0.0030, ink)
                bar(-0.031, by - 0.0062, 0.024, 0.0018, ink)
                bar(0.003, by - 0.0062, 0.010, 0.0018, red)
                bar(0.033, by, 0.030, 0.018, swatch)
                bar(0.033, by, 0.0262, 0.0010, ink, z: 0.0002)
                bar(0.0195, by, 0.0012, 0.0062, ink, z: 0.0002)
                for k in 0..<7 { bar(0.026 + Float(k) * 0.0028, by, 0.0006, 0.0034, ink, z: 0.0003) }
                // End print: a big "100" block.
                for s: Float in [-1, 1] {
                    m.add(cuboid(V3(0.0002, 0.006, 0.018), material: ink), Xform(translation: V3(s * (W / 2 + 2 * o + 0.0001), by + 0.003, D * 0.16)))
                    m.add(cuboid(V3(0.0002, 0.0022, 0.028), material: ink), Xform(translation: V3(s * (W / 2 + 2 * o + 0.0001), by - 0.0055, D * 0.16)))
                }
            }
        }

        // Screw heap.
        let L = screw.clampedLength
        let inner = V2(W / 2 - t - 0.002, D / 2 - t - 0.002)
        func heap(_ m: inout Model, screwModel: Model, count: Int, rng: inout SeededRNG) {
            // Dark under-layer: a lumpy bed of screws seen through the gaps.
            let bed = Prim.terrain(size: V2(W - 2 * t - 0.0006, D - 2 * t - 0.0006), segments: 10, material: "plastic.matte:4A4D50") { p in
                0.0012 * sin(p.x * 260 + 1.3) * cos(p.y * 210) + 0.0008 * sin(p.x * 610 + p.y * 400)
            }
            m.add(bed, Xform(translation: V3(0, t + fill - 0.0045, 0)))
            var placed = 0, tries = 0
            while placed < count && tries < 400 {
                tries += 1
                let yaw = rng.float(0...(2 * .pi))
                let lean = rng.chance(0.15) ? rng.float(18...38) : rng.float(-9...9)
                let dir = V3(cos(yaw), 0, sin(yaw))
                let half = L / 2 * cos(lean * .pi / 180)
                let cx = rng.float(-inner.x...inner.x), cz = rng.float(-inner.y...inner.y)
                let e1 = V2(cx, cz) + V2(dir.x, dir.z) * half, e2 = V2(cx, cz) - V2(dir.x, dir.z) * half
                guard abs(e1.x) < inner.x, abs(e2.x) < inner.x, abs(e1.y) < inner.y - 0.002, abs(e2.y) < inner.y - 0.002 else { continue }
                // Local screw: axis +Y, point at 0. Center it, lay it along +X, lean, roll, yaw.
                let roll = simd_quatf(angle: rng.float(0...(2 * .pi)), axis: V3(0, 1, 0))
                let lay = simd_quatf(degrees: -90 + lean, axis: V3(0, 0, 1))
                let q = simd_quatf(angle: -yaw, axis: V3(0, 1, 0)) * lay * roll
                let y = t + fill - 0.002 + rng.float(0...0.0035) + abs(sin(lean * .pi / 180)) * L * 0.3
                let x = Xform(translation: V3(cx, y, cz), rotation: q)
                m.add(screwModel.transformed(Xform(translation: V3(0, -L / 2, 0))), x)
                placed += 1
            }
        }

        var m0 = Model(name: Self.id), m1 = Model(name: Self.id)
        carton(&m0, detail: true)
        carton(&m1, detail: false)
        var hr = rng.fork(7)
        heap(&m0, screwModel: screw.screwModel(sides: 6, headSides: 12, rowsPerPitch: 2, recess: false), count: visibleScrews, rng: &hr)
        var hr1 = rng.fork(7)
        heap(&m1, screwModel: screw.screwModel(sides: 5, headSides: 6, rowsPerPitch: 1, recess: false), count: visibleScrews / 2, rng: &hr1)
        // Story detail: one screw fell out and lies on the bench in front of the label.
        let loose = screw.screwModel(sides: 8, headSides: 16, rowsPerPitch: 4, recess: true)
        let lp = screw.placement
        let yawL = simd_quatf(degrees: rng.float(-25...(-10)), axis: V3(0, 1, 0))
        let lx = Xform(translation: V3(-0.012, 0, D / 2 + looseScrewGap + 0.002), rotation: yawL)
        m0.add(loose.transformed(lp), lx)
        m1.add(screw.screwModel(sides: 5, headSides: 6, rowsPerPitch: 1, recess: false).transformed(lp), lx)
        let sh = Xform(translation: shift)
        var a = m0.transformed(sh), b = m1.transformed(sh)
        groundAO(&a, height: 0.03, floor: 0.55)
        groundAO(&b, height: 0.03, floor: 0.55)
        return LODModel(levels: [a, b], switchDistances: [1.2])
    }
}
