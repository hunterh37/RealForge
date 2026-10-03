import simd
import Foundation

/// Chesterfield club armchair, 105 x 78 x 90 cm: deep-buttoned oxblood leather on the inside back and
/// inside arms (diamond grid, pleated), scroll-rolled arms level with the back, plain base rail with a
/// row of antique brass nailheads that also outlines both arm fronts, loose seat cushion with piped
/// edges and a sitting sag, four turned mahogany bun feet.
public struct ChesterfieldArmchair: RealAsset {
    public static let id = "chesterfield-armchair"
    public static let summary = "Chesterfield club armchair: button-tufted oxblood leather, rolled arms level with the back, nailhead trim, turned mahogany feet."
    public static let tags = ["prop", "furniture", "leather", "interior", "antique"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 14, distance: 1.12, studio: true)

    public var leather: MaterialKey = "leather.oxblood"
    /// Seat cushion leather (more worn than the frame).
    public var seatLeather: MaterialKey = "leather.oxblood-worn"
    public var wood: MaterialKey = "wood.mahogany"
    public var nails: MaterialKey = "metal.brass-aged"
    public var width: Float = 1.05
    public var depth: Float = 0.9
    public var height: Float = 0.78
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [5])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = leather, W = width, D = depth, H = height
        let foot: Float = 0.1, seatY: Float = 0.43, armW: Float = 0.2
        let inner = W / 2 - armW
        let backD: Float = 0.2
        // Base under the seat and the plain front rail.
        m.add(Prim.roundedBox(V3(inner * 2 + 0.02, seatY - foot, D - backD), radius: 0.03, bevelSegments: 3, material: L),
              Xform(translation: V3(0, (foot + seatY) / 2, backD / 2)))
        // Back: full width behind the arms, rolled top.
        m.add(Prim.roundedBox(V3(W - 0.01, H - foot, backD), radius: 0.07, bevelSegments: 4, material: L),
              Xform(translation: V3(0, (foot + H) / 2, -D / 2 + backD / 2)))
        // Arms: scroll profile extruded front to back; the flat cap is the arm front.
        var prof: [V2] = [V2(0, 0), V2(armW - 0.03, 0), V2(armW - 0.03, H - foot - 0.2)]
        let rc = V2(armW - 0.075, H - foot - 0.1), rr: Float = 0.1
        for k in 0...10 { let a = -Float.pi * 0.25 + Float(k) / 10 * Float.pi * 1.2; prof.append(rc + V2(cos(a), sin(a)) * rr) }
        prof += [V2(0.0, H - foot - 0.2), V2(0, 0.0)]
        let armOutline = Shape2D.rounded(prof, radius: 0.02, segments: 2)
        let armDepth = D - backD + 0.02
        for s: Float in [-1, 1] {
            let pts = s > 0 ? armOutline : armOutline.map { V2(-$0.x, $0.y) }
            let x = Xform(translation: V3(s * inner, foot, -D / 2 + backD - 0.02 + armDepth / 2))
            m.add(Prim.extrude(pts, depth: armDepth, bevel: 0.03, bevelSegments: 3, material: L), x)
            if detail {
                // Nailheads around the arm front scroll.
                let ring = Shape2D.offset(pts, -0.03)
                let path = (ring + [ring[0]]).map { x.point(V3($0.x, $0.y, armDepth / 2 + 0.001)) }
                for p in resample(path, spacing: 0.03) where p.y > foot + 0.03 { nailhead(&m, at: p, normal: V3(0, 0, 1)) }
            }
        }
        // Tufted inside back and inside arms.
        let backPanelW = inner * 2, backPanelH = H - seatY - 0.06
        let (back, backButtons) = tuftedPanel(width: backPanelW, height: backPanelH, spacing: V2(0.13, 0.11), puff: 0.04, edgeTuck: 0.03,
                                              cell: detail ? 0.019 : 0.03, material: L)
        let backX = Xform(translation: V3(0, seatY + 0.03 + backPanelH / 2, -D / 2 + backD - 0.004))
        m.add(back, backX)
        let armPanelD = D - backD - 0.1, armPanelH = H - seatY - 0.09
        let (armP, armButtons) = tuftedPanel(width: armPanelD, height: armPanelH, spacing: V2(0.12, 0.1), puff: 0.03, edgeTuck: 0.025,
                                             cell: detail ? 0.021 : 0.034, material: L)
        var armXs: [Xform] = []
        for s: Float in [-1, 1] {
            let ax = Xform(translation: V3(s * (inner - 0.004), seatY + 0.02 + armPanelH / 2, -D / 2 + backD + armPanelD / 2 + 0.01),
                           rotation: simd_quatf(degrees: -s * 90, axis: .up))
            m.add(armP, ax); armXs.append(ax)
        }
        if detail {
            buttons(&m, backButtons, backX, material: L)
            for ax in armXs { buttons(&m, armButtons, ax, material: L) }
        }
        // Seat cushion with sag where people sit, piping around the top and bottom edges.
        let cw = inner * 2 - 0.012, cd = D - backD - 0.03, ch: Float = 0.13
        let sag = rng.float(0.012...0.02)
        var cushion = Prim.superellipsoid(V3(cw, ch, cd), exponent: 7, subdivisions: detail ? 14 : 8, material: seatLeather)
        cushion.deform { p in
            let fx = p.x / (cw / 2), fz = p.z / (cd / 2)
            let dip = max(0, 1 - fx * fx) * max(0, 1 - pow(fz - 0.1, 2)) * (p.y > 0 ? 1 : 0.3)
            return p - V3(0, dip * sag, 0)
        }
        let cy = seatY + ch / 2
        m.add(cushion, Xform(translation: V3(0, cy, -D / 2 + backD + cd / 2 + 0.005)))
        if detail {
            for yy in [ch / 2 - 0.02] {
                // Superellipsoid half-extent at this height (n = 7), so the welt sits on the surface.
                let k = pow(max(0, 1 - pow(abs(yy) / (ch / 2), 7)), 1.0 / 7)
                let ring = Shape2D.roundedRect(cw * k - 0.002, cd * k - 0.002, radius: 0.04, segments: 4).map { V3($0.x, cy + yy - (yy > 0 ? sag * 0.15 : 0), -D / 2 + backD + cd / 2 + 0.005 - $0.y) }
                m.add(Prim.sweep(Shape2D.circle(0.0042, segments: 6), along: ring, closedPath: true, caps: false, material: seatLeather))
            }
            // Nailheads along the base rail.
            for x in stride(from: -inner + 0.01, through: inner - 0.01, by: 0.03) { nailhead(&m, at: V3(x, foot + 0.035, D / 2 + 0.0005), normal: V3(0, 0, 1)) }
        }
        // Turned bun feet with brass caps.
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
            m.add(turned([(0, 0), (0.026, 0), (0.03, 0.006), (0.04, 0.03), (0.042, 0.05), (0.036, 0.075), (0.03, 0.09), (0.034, foot + 0.005), (0, foot + 0.005)],
                         segments: 20, material: wood, grainVertical: true),
                  Xform(translation: V3(sx * (W / 2 - 0.07), 0, sz * (D / 2 - 0.07))))
            m.add(Prim.cylinder(radius: 0.026, height: 0.004, bevel: 0.0015, segments: 16, bevelSegments: 1, material: nails),
                  Xform(translation: V3(sx * (W / 2 - 0.07), 0, sz * (D / 2 - 0.07))))
        }}
        groundAO(&m, height: 0.18, floor: 0.5)
        return m
    }

    /// Low-poly upholstery nailhead (11 mm dome).
    func nailhead(_ m: inout Model, at p: V3, normal n: V3) {
        let r: Float = 0.0055
        m.add(Prim.lathe([V2(0, -0.0006), V2(r, -0.0006), V2(r * 0.85, 0.0025), V2(0, 0.0036)], segments: 6, seamTile: 0.04, material: nails),
              Xform(translation: p, rotation: facing(n)))
    }
}
