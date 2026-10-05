import simd
import Foundation

/// 2 cup tempered-glass measuring cup: 3.5 mm walls tapering out to a rounded rim, a thick base, a pour
/// spout toward -X, an open D handle along +X, and fired-on red graduations (cups and quarters facing
/// +Z, milliliters facing -Z) placed at the true fill heights. Axis at the asset origin; the inner floor
/// is its own surface.
public struct MeasuringCup: RealAsset {
    public static let id = "measuring-cup"
    public static let summary = "2 cup glass measuring cup: thick tapered body, pour spout, D handle, red cup and milliliter graduations."
    public static let tags = ["prop", "kitchen", "cookware", "glass", "container", "handheld"]
    public static let budget = 13_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 22, distance: 0.45, studio: true)

    /// Top of the inner floor (m).
    public var floorY: Float = 0.0065
    /// Radius of the flat inner floor (m).
    public var innerRadius: Float = 0.041
    /// Height of the rim top (m).
    public var rimY: Float = 0.108
    /// Inner radius at the rim (m).
    public var rimRadius: Float = 0.0515
    /// Glass wall thickness (m).
    public var wall: Float = 0.0035
    public var glass: MaterialKey = "glass.measuring"
    public var marking: MaterialKey = "paint.measure-red"
    /// Dried milk line inside at the 1 cup mark.
    public var residue: MaterialKey = "decal.soap-residue"
    public init() {}

    /// Inner radius at height `y`, ignoring the floor fillet.
    func r(_ y: Float) -> Float {
        let r0 = innerRadius + 0.006
        return r0 + (rimRadius - r0) * max(0, min(1, (y - floorY) / (rimY - floorY)))
    }

    /// Liquid surface height (asset space) for a volume in milliliters.
    public func levelY(milliliters ml: Float) -> Float {
        var v: Float = 0, y = floorY
        let target = ml * 1e-6, dy: Float = 0.0002
        while v < target && y < rimY { v += .pi * r(y + dy / 2) * r(y + dy / 2) * dy; y += dy }
        return y
    }

    func vessel() -> Vessel {
        let f = floorY, R = innerRadius, top = rimY - wall * 0.5
        let curve = Profile.smooth([V2(R - 0.006, f), V2(R, f), V2(R + 0.0045, f + 0.0015), V2(r(f + 0.008), f + 0.008), V2(r(top - 0.02), top - 0.02),
                                    V2(rimRadius, top)], per: 3)
        return Vessel(inner: [V2(0, f)] + curve, wall: wall, floorRadius: R, rim: .cut)
    }

    func model(segments: Int, detail: Bool) -> Model {
        let v = vessel()
        let top = v.rimTop
        // Pour spout toward -X: the upper wall bulges out and the rim dips.
        func spouted(_ p: V3) -> V3 {
            let rr = simd_length(V2(p.x, p.z))
            guard rr > 0.02 else { return p }
            let a = atan2(p.z, p.x)
            let d = Float.pi - abs(a)
            let w = exp(-(d * d) / (2 * 0.22 * 0.22))
            let h = max(0, (p.y - top + 0.03) / 0.03)
            let s = (rr + 0.012 * w * h * h) / rr
            return V3(p.x * s, p.y - 0.004 * w * h * h, p.z * s)
        }
        var m = Model(name: Self.id)
        var floorSurface: Surface?
        for (role, var s) in v.surfaces(segments: segments, interior: glass, exterior: glass, seamTile: 0.2) {
            if role == .floor { floorSurface = s; continue }
            s.deform(spouted)
            m.add(s)
        }
        // Open D handle on +X.
        let ro = { (y: Float) in v.outerRadius(at: y) }
        let ctrl = [V3(ro(0.094) - 0.002, 0.094, 0), V3(ro(0.094) + 0.026, 0.097, 0), V3(ro(0.07) + 0.04, 0.078, 0),
                    V3(ro(0.04) + 0.038, 0.042, 0), V3(ro(0.025) + 0.022, 0.024, 0), V3(ro(0.022) - 0.002, 0.022, 0)]
        let path = catmull(ctrl, per: detail ? 6 : 3)
        m.add(Prim.sweep(Shape2D.superellipse(0.012, 0.015, exponent: 2.4, segments: detail ? 16 : 8), along: path, up: V3(0, 0, 1),
                         grainAlongPath: true, material: glass))
        // Graduations: cup scale facing +Z, milliliters facing -Z, at true fill heights.
        func mark(_ y: Float, span: Float, facing: Float) {
            let rad = v.outerRadius(at: y) + 0.0002
            m.add(Prim.torus(major: rad, minor: 0.00055, segments: detail ? 14 : 6, sides: 4, arc: span, minorY: 0.00012, material: marking),
                  Xform(translation: V3(0, y, 0), rotation: simd_quatf(angle: facing - span / 2, axis: .up)))
        }
        let cupLabels = [2: "1/2", 4: "1 CUP", 6: "1 1/2", 8: "2 CUPS"]
        for q in 1...8 {
            let y = levelY(milliliters: Float(q) * 59.15)
            let span: Float = q % 4 == 0 ? 0.62 : (q % 2 == 0 ? 0.42 : 0.26)
            mark(y, span: span, facing: -.pi / 2)
            if detail, let t = cupLabels[q] { label(&m, t, y: y, angle: -.pi / 2 + span / 2 + 0.06, radius: v.outerRadius(at: y)) }
        }
        for k in 1...10 {
            let y = levelY(milliliters: Float(k) * 50)
            mark(y, span: k % 2 == 0 ? 0.4 : 0.22, facing: .pi / 2)
            if detail && k % 2 == 0 { label(&m, k == 10 ? "500 ML" : String(k * 50), y: y, angle: .pi / 2 + 0.26, radius: v.outerRadius(at: y)) }
        }
        // Story: a dried milk line inside at the 1 cup level, thicker at the bottom edge.
        let yl = levelY(milliliters: 236.6)
        let band = (0...4).map { k -> V2 in let t = Float(k) / 4; return V2(v.innerRadius(at: yl - 0.0006 + 0.0012 * t) - 0.0002, yl - 0.0006 + 0.0012 * t) }
        m.add(Prim.lathe(band.reversed(), segments: segments, seamTile: 0.1, material: residue))
        if let fs = floorSurface { m.surfaces.append(fs) }
        groundAO(&m, height: 0.02, floor: 0.7)
        return m
    }

    /// Stroke glyphs on a 3 x 5 grid (seven-segment style), enough for the printed scale.
    static let glyphs: [Character: [[V2]]] = [
        "0": [[V2(0, 0), V2(3, 0), V2(3, 5), V2(0, 5), V2(0, 0)]],
        "1": [[V2(1.5, 0), V2(1.5, 5), V2(0.4, 3.9)]],
        "2": [[V2(0, 5), V2(3, 5), V2(3, 2.5), V2(0, 2.5), V2(0, 0), V2(3, 0)]],
        "3": [[V2(0, 5), V2(3, 5), V2(3, 0), V2(0, 0)], [V2(0.6, 2.5), V2(3, 2.5)]],
        "4": [[V2(0, 5), V2(0, 2.5), V2(3, 2.5)], [V2(3, 5), V2(3, 0)]],
        "5": [[V2(3, 5), V2(0, 5), V2(0, 2.5), V2(3, 2.5), V2(3, 0), V2(0, 0)]],
        "/": [[V2(0, 0), V2(3, 5)]],
        "C": [[V2(3, 5), V2(0, 5), V2(0, 0), V2(3, 0)]],
        "U": [[V2(0, 5), V2(0, 0), V2(3, 0), V2(3, 5)]],
        "P": [[V2(0, 0), V2(0, 5), V2(3, 5), V2(3, 2.5), V2(0, 2.5)]],
        "S": [[V2(3, 5), V2(0, 5), V2(0, 2.5), V2(3, 2.5), V2(3, 0), V2(0, 0)]],
        "M": [[V2(0, 0), V2(0, 5), V2(1.5, 2.6), V2(3, 5), V2(3, 0)]],
        "L": [[V2(0, 5), V2(0, 0), V2(3, 0)]],
    ]

    /// Fired-on red text wrapped around the wall, starting at `angle`, centered on height `y`.
    func label(_ m: inout Model, _ text: String, y: Float, angle: Float, radius: Float) {
        let cell: Float = 0.001, adv: Float = 0.0046, R = radius + 0.0002
        var u: Float = 0
        for ch in text {
            defer { u += ch == " " ? adv * 0.6 : adv }
            guard let strokes = Self.glyphs[ch] else { continue }
            for stroke in strokes {
                var pts: [V3] = []
                for i in 0..<(stroke.count - 1) {
                    for k in 0..<3 {
                        let q = stroke[i] + (stroke[i + 1] - stroke[i]) * (Float(k) / 3)
                        let a = angle + (u + q.x * cell) / R
                        pts.append(V3(R * cos(a), y - 0.0025 + q.y * cell, -R * sin(a)))
                    }
                }
                let last = stroke[stroke.count - 1], a = angle + (u + last.x * cell) / R
                pts.append(V3(R * cos(a), y - 0.0025 + last.y * cell, -R * sin(a)))
                let radial = simd_normalize(V3(pts[0].x, 0, pts[0].z))
                m.add(Prim.sweep(Shape2D.rect(0.00012, 0.0007), along: pts, up: radial, material: marking))
            }
        }
    }

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(segments: 72, detail: true), model(segments: 32, detail: false)], switchDistances: [2])
    }
}
