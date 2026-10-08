import simd
import Foundation

/// Standing-seam metal roof section, 2.4 m along the eave: painted steel pans with 38 mm raised
/// seams every 400 mm and a slight oil-canning in each pan, on a plywood deck, eave drip edge over
/// a painted fascia, rake trim at both ends and a vented ridge cap. One slope at `pitch`; the eave
/// faces +Z and the ridge runs along X at the back. Base y = 0 is the bottom of the fascia.
public struct StandingSeamRoof: RealAsset {
    public static let id = "standing-seam-roof"
    public static let summary = "Standing-seam metal roof section, 2.4 m: painted steel pans with raised seams at 400 mm, ridge cap, eave drip and fascia."
    public static let tags = ["structure", "architecture", "roof", "metal"]
    public static let budget = 8_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 22, distance: 1.0, studio: true)

    /// Length along the eave (m).
    public var width: Float = 2.4
    /// Slope length from eave to ridge (m).
    public var slopeLength: Float = 2.4
    /// Roof pitch (degrees).
    public var pitch: Float = 25
    /// Seam spacing (m).
    public var seamSpacing: Float = 0.4
    public var panMaterial: MaterialKey = "metal.roofing"
    public var trimMaterial: MaterialKey = "wood.painted-exterior"
    public var deckMaterial: MaterialKey = "wood.plywood"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, L = slopeLength
        let fasciaH: Float = 0.19
        // Roof plane frame: local x across, local z up the slope (toward -Z world), local y normal.
        let rot = simd_quatf(degrees: pitch, axis: V3(1, 0, 0)) * simd_quatf(degrees: 180, axis: .up)
        let origin = V3(0, fasciaH, 0)
        let run = L * cos(pitch * .pi / 180), rise = L * sin(pitch * .pi / 180)
        let center = V3(0, 0, run / 2)
        func place(_ s: Surface) { m.add(s, Xform(translation: origin + center * 0 , rotation: rot).jittered(&rng, deg: 0, offset: 0)) }
        // Deck.
        place(HK.box(V3(W, 0.018, L), V3(0, -0.012, L / 2), deckMaterial, r: 0.002, seg: 1))
        // Pans with oil-canning: thin grids bowed slightly between seams.
        let n = max(1, Int((W / seamSpacing).rounded()))
        let pw = W / Float(n)
        for i in 0..<n {
            let x0 = -W / 2 + Float(i) * pw
            var s = Surface(material: panMaterial)
            let ax = 4, az = 12
            let bow = rng.float(0.0015...0.003)
            for a in 0...az { for c in 0...ax {
                let u = Float(c) / Float(ax), v = Float(a) / Float(az)
                let y = bow * sin(u * .pi) * (0.6 + 0.4 * sin(v * 9 + Float(i)))
                _ = s.add(V3(x0 + pw * u, y, L * v), .up, V2(x0 + pw * u, L * v))
            }}
            let row = UInt32(ax + 1)
            for a in 0..<az { for c in 0..<ax {
                let k = UInt32(a) * row + UInt32(c)
                s.quad(k, k + row, k + row + 1, k + 1)
            }}
            s.recomputeNormals(weldSeams: false); s.computeTangents()
            place(s)
            // Seam at the left edge of each pan (and the last one at the right edge).
            for x in (i == n - 1 ? [x0, x0 + pw] : [x0]) where abs(x) < W / 2 - 0.01 || i == n - 1 {
                if abs(abs(x) - W / 2) < 0.01 { continue }
                place(HK.box(V3(0.012, 0.038, L), V3(x, 0.019, L / 2), panMaterial, r: 0.005, seg: 2))
                place(HK.box(V3(0.02, 0.008, L), V3(x, 0.036, L / 2), panMaterial, r: 0.003, seg: 1))
            }
        }
        // Rake trim at both ends, eave drip edge, ridge cap with vent gap.
        for sx: Float in [-1, 1] {
            place(HK.box(V3(0.05, 0.07, L + 0.02), V3(sx * (W / 2 + 0.01), 0.005, L / 2), panMaterial, r: 0.006))
        }
        place(HK.box(V3(W + 0.06, 0.012, 0.06), V3(0, -0.004, -0.02), panMaterial, r: 0.004))
        let ridge = HK.box(V3(W + 0.06, 0.03, 0.26), V3(0, 0.06, L - 0.06), panMaterial, r: 0.01)
        place(ridge)
        place(HK.box(V3(W + 0.02, 0.03, 0.03), V3(0, 0.035, L - 0.12), "plastic.black", r: 0.004))
        // Fascia and gable-end barge boards (vertical, world space).
        m.add(HK.box(V3(W + 0.08, fasciaH, 0.025), V3(0, fasciaH / 2, 0.015), trimMaterial, r: 0.004))
        m.add(HK.box(V3(W + 0.04, 0.02, 0.3), V3(0, 0.01, -0.13), trimMaterial, r: 0.003))
        _ = rise
        groundAO(&m, height: 0.15, floor: 0.75)
        // Center the section on X/Z.
        let b = m.bounds
        return LODModel(m.transformed(Xform(translation: V3(0, -b.min.y, -(b.min.z + b.max.z) / 2))))
    }
}
