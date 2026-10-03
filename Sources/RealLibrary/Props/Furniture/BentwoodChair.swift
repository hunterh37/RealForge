import simd
import Foundation

/// Bentwood bistro chair after Thonet No. 14 (1859), 43 x 89 x 52 cm: one steam-bent beech rod forms
/// both back legs and the outer back hoop, an inner hoop inside it, a round seat band with a woven cane
/// panel, two tapered front legs, a leg ring below the seat, screws at every joint, felt glides.
/// Wood grain follows every bend.
public struct BentwoodChair: RealAsset {
    public static let id = "bentwood-chair"
    public static let summary = "Bentwood bistro chair after Thonet No. 14: steam-bent beech hoop back, splayed legs, leg ring, woven cane seat."
    public static let tags = ["prop", "furniture", "wood", "interior"]
    public static let budget = 8_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 34, elevation: 12, distance: 1.15, studio: true)

    public var wood: MaterialKey = "wood.beech-stained"
    public var backWood: MaterialKey = "wood.beech-stained:5C3018"
    public var seat: MaterialKey = "cane.woven"
    /// Seat height (m) and seat radius (m).
    public var seatHeight: Float = 0.46
    public var seatRadius: Float = 0.205
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let w = wood, sh = seatHeight, sr = seatRadius
        let cz: Float = -0.02   // seat center z
        func rod(_ pts: [V3], r0: Float, r1: Float, per: Int = 5, sides: Int = 12, caps: Bool = true) {
            let path = catmull(pts, per: per)
            let n = path.count
            let scales = (0..<n).map { i -> Float in let t = Float(i) / Float(n - 1); return 1 + (r1 / r0 - 1) * t }
            m.add(Prim.sweep(Shape2D.circle(r0, segments: sides), along: path, scales: scales, caps: caps, grainAlongPath: true, material: w))
        }
        // Seat band: bent beech hoop, taller than wide, cane panel set into its top.
        let band = (0..<40).map { k -> V3 in let a = Float(k) / 40 * 2 * .pi; return V3(cos(a) * sr, sh - 0.022, cz - sin(a) * sr) }
        m.add(Prim.sweep(Shape2D.superellipse(0.024, 0.042, exponent: 3.2, segments: 14), along: band, up: .up, closedPath: true, caps: false,
                         grainAlongPath: true, material: w))
        m.add(Prim.extrude(Shape2D.circle(sr - 0.006, segments: 40), depth: 0.003, bevel: 0.0005, bevelSegments: 1, material: seat),
              Xform(translation: V3(0, sh - 0.006, cz), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
        // Rattan binding bead around the cane panel.
        let bead = (0..<40).map { k -> V3 in let a = Float(k) / 40 * 2 * .pi; return V3(cos(a) * (sr - 0.012), sh - 0.002, cz - sin(a) * (sr - 0.012)) }
        m.add(Prim.sweep(Shape2D.circle(0.0035, segments: 6), along: bead, closedPath: true, caps: false, grainAlongPath: true, material: "wood.rattan"))
        // Back: one rod, floor to hoop top and back down, leaning back, tapering toward the top.
        let lx: Float = 0.165
        // Legs rise to the hoop shoulders; the hoop is a half-ellipse (no kinks at the shoulders).
        let left: [V3] = [V3(-lx - 0.012, 0, -0.26), V3(-lx + 0.004, 0.22, -0.215), V3(-lx + 0.01, sh - 0.03, cz - sr + 0.012),
                          V3(-lx + 0.006, 0.62, -0.245)]
        let hy: Float = 0.7, hrx = lx - 0.006, hry: Float = 0.19
        let topArc = (0...12).map { k -> V3 in
            let a = Float.pi * (1 - Float(k) / 12)
            return V3(cos(a) * hrx, hy + sin(a) * hry, -0.255 - 0.03 * sin(a))
        }
        let backPts = left.dropLast() + topArc + left.dropLast().reversed().map { V3(-$0.x, $0.y, $0.z) }
        let path = catmull(Array(backPts), per: 3)
        let n = path.count
        let scales = (0..<n).map { i -> Float in let t = abs(Float(i) / Float(n - 1) * 2 - 1); return 0.78 + 0.22 * t }
        // The back rod was steamed from a different billet: slightly different stain take-up.
        m.add(Prim.sweep(Shape2D.circle(0.0145, segments: 12), along: path, scales: scales, grainAlongPath: true, material: backWood))
        // Inner hoop: from the seat band up inside the outer hoop.
        let ix: Float = 0.09
        let innerPts: [V3] = [V3(-ix, sh - 0.01, cz - sr + 0.03), V3(-ix - 0.02, 0.6, -0.24), V3(-ix - 0.01, 0.72, -0.265), V3(-0.05, 0.775, -0.275),
                              V3(0, 0.785, -0.278), V3(0.05, 0.775, -0.275), V3(ix + 0.01, 0.72, -0.265), V3(ix + 0.02, 0.6, -0.24), V3(ix, sh - 0.01, cz - sr + 0.03)]
        rod(innerPts, r0: 0.0095, r1: 0.0095, per: 4, sides: 10)
        // Front legs: tapered, splayed, tops buried in the band.
        for s: Float in [-1, 1] {
            rod([V3(s * 0.135, sh - 0.01, cz + 0.15), V3(s * 0.15, 0.25, cz + 0.175), V3(s * 0.165, 0.0, cz + 0.205)], r0: 0.0165, r1: 0.0125, per: 4)
        }
        // Leg ring at 20 cm, slightly inside the legs.
        let ringY: Float = 0.2
        let ring = (0..<36).map { k -> V3 in let a = Float(k) / 36 * 2 * .pi; return V3(cos(a) * 0.147, ringY, cz - 0.022 - sin(a) * 0.168) }
        m.add(Prim.sweep(Shape2D.superellipse(0.016, 0.02, exponent: 2.4, segments: 10), along: ring, up: .up, closedPath: true, caps: false,
                         grainAlongPath: true, material: w))
        // Screws: ring to legs, band to back legs.
        for p in [V3(-0.152, ringY, cz + 0.155), V3(0.152, ringY, cz + 0.155), V3(-0.152, ringY, -0.205), V3(0.152, ringY, -0.205)] {
            let n = simd_normalize(V3(p.x, 0, p.z - cz))
            rivet(&m, at: p + n * 0.012, normal: n, radius: 0.0032, material: "metal.steel")
        }
        for s: Float in [-1, 1] { rivet(&m, at: V3(s * 0.172, sh - 0.022, cz - sr * 0.86), normal: V3(s, 0, -0.5), radius: 0.0035, material: "metal.steel") }
        // Felt glides.
        for p in [V3(-lx - 0.012, 0, -0.26), V3(lx + 0.012, 0, -0.26), V3(-0.165, 0, cz + 0.205), V3(0.165, 0, cz + 0.205)] {
            m.add(Prim.cylinder(radius: 0.012, height: 0.004, bevel: 0.0015, segments: 12, bevelSegments: 1, material: "fabric.wool:2A2622"), Xform(translation: p))
        }
        let lean = rng.float(-0.4...0.4)
        m = m.transformed(Xform(rotation: simd_quatf(degrees: lean, axis: .up)))
        let bb = m.bounds
        m = m.transformed(Xform(translation: V3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2)))
        groundAO(&m, height: 0.08, floor: 0.6)
        return LODModel(m)
    }
}
