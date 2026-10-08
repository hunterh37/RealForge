import simd
import Foundation

/// Brick chimney stack above a roof, 0.8 x 0.5 m: running-bond brick shaft, three corbelled courses,
/// sloped concrete crown with a drip edge (cracked), two clay flue liners, a galvanized rain cap on
/// legs over them, soot at the flue mouths and lead step flashing with an apron at the roof line.
/// Base y = 0 is the roof surface at the downhill face; centered on X/Z.
public struct BrickChimney: RealAsset {
    public static let id = "brick-chimney"
    public static let summary = "Brick chimney stack, 0.8 x 0.5 m: running bond brick, corbelled top course, concrete crown, two clay flue liners and a rain cap."
    public static let tags = ["structure", "architecture", "roof", "brick", "concrete"]
    public static let budget = 8_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 14, distance: 1.0, studio: true)

    /// Stack plan size (m).
    public var width: Float = 0.8
    public var depth: Float = 0.5
    /// Height of the shaft above the roof (m).
    public var height: Float = 1.6
    /// Number of flue liners.
    public var flues: Int = 2
    /// Galvanized rain cap over the flues.
    public var rainCap = true
    public var brickMaterial: MaterialKey = "brick.red"
    public var crownMaterial: MaterialKey = "concrete.smooth"
    public var flueMaterial: MaterialKey = "ceramic.terracotta"
    public var capMaterial: MaterialKey = "metal.galvanized-aged"
    public var flashingMaterial: MaterialKey = "metal.galvanized"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, D = depth, H = height
        // Shaft and corbel courses (each 65 mm, stepping out 25 mm).
        m.add(HK.box(V3(W, H, D), V3(0, H / 2, 0), brickMaterial, r: 0.006))
        var y = H
        for k in 1...3 {
            let o = Float(k) * 0.025, h: Float = 0.065
            m.add(HK.box(V3(W + 2 * o, h, D + 2 * o), V3(0, y + h / 2, 0), brickMaterial, r: 0.005))
            y += h
        }
        // Two plain courses back to the shaft line above the corbel.
        m.add(HK.box(V3(W + 0.05, 0.13, D + 0.05), V3(0, y + 0.065, 0), brickMaterial, r: 0.005))
        y += 0.13
        // Concrete crown: overhang with drip, sloped top (wash) up to the flues.
        let cw = W + 0.17, cd = D + 0.17
        m.add(HK.box(V3(cw, 0.05, cd), V3(0, y + 0.025, 0), crownMaterial, r: 0.008))
        let wash = Prim.loft([Prim.ring(Shape2D.roundedRect(cw - 0.02, cd - 0.02, radius: 0.01), y: 0),
                              Prim.ring(Shape2D.roundedRect(cw * 0.55, cd * 0.6, radius: 0.01), y: 0.05)], capEnd: true, material: crownMaterial)
        m.add(wash, Xform(translation: V3(0, y + 0.05, 0)))
        // Crack across the crown.
        m.add(HK.box(V3(0.25, 0.004, 0.006), V3(0.18, y + 0.08, 0.12), "plastic.black", r: 0.001, seg: 1), Xform(rotation: simd_quatf(degrees: 18, axis: .up)))
        let yc = y + 0.1
        // Flue liners: hollow square clay tiles, soot inside the mouth.
        let fs: Float = 0.2, wall: Float = 0.018
        let fx: [Float] = flues == 1 ? [0] : (0..<flues).map { -W * 0.22 + W * 0.44 * Float($0) / Float(max(1, flues - 1)) }
        let fh: Float = 0.16
        for x in fx {
            for s: Float in [-1, 1] {
                m.add(HK.box(V3(fs, fh, wall), V3(x, yc + fh / 2 - 0.04, s * (fs / 2 - wall / 2)), flueMaterial, r: 0.003))
                m.add(HK.box(V3(wall, fh, fs - 2 * wall), V3(x + s * (fs / 2 - wall / 2), yc + fh / 2 - 0.04, 0), flueMaterial, r: 0.003))
            }
            m.add(HK.box(V3(fs - 2 * wall, 0.004, fs - 2 * wall), V3(x, yc + fh - 0.08, 0), "plastic.black", r: 0.001, seg: 1))
            // Soot streak down the liner.
            m.add(HK.box(V3(0.08, 0.07, 0.002), V3(x + rng.float(-0.03...0.03), yc + fh - 0.08, fs / 2 + 0.001), "plastic.matte:2A2622", r: 0.0008, seg: 1))
        }
        // Rain cap: hipped sheet on four legs, mesh band.
        if rainCap {
            let rw = W * 0.82, rd = fs + 0.16, ry = yc + fh + 0.18
            for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
                m.add(HK.box(V3(0.02, ry - yc + 0.02, 0.003), V3(sx * (rw / 2 - 0.03), yc + (ry - yc) / 2, sz * (rd / 2 - 0.02)), capMaterial, r: 0.001, seg: 1))
            }}
            let capLoft = Prim.loft([Prim.ring(Shape2D.rect(rw + 0.06, rd + 0.06), y: 0), Prim.ring(Shape2D.rect(rw * 0.5, 0.04), y: 0.09)], capStart: true, capEnd: true, material: capMaterial)
            m.add(capLoft, Xform(translation: V3(0, ry, 0)))
            m.add(HK.box(V3(rw + 0.06, 0.012, rd + 0.06), V3(0, ry - 0.006, 0), capMaterial, r: 0.003, seg: 1))
        }
        // Step flashing and apron at the roof line.
        m.add(HK.box(V3(W + 0.2, 0.004, 0.25), V3(0, 0.002, D / 2 + 0.12), flashingMaterial, r: 0.001, seg: 1))
        m.add(HK.box(V3(W + 0.01, 0.12, 0.004), V3(0, 0.06, D / 2 + 0.002), flashingMaterial, r: 0.001, seg: 1))
        for s: Float in [-1, 1] {
            m.add(HK.box(V3(0.004, 0.12, D + 0.01), V3(s * (W / 2 + 0.002), 0.06, 0), flashingMaterial, r: 0.001, seg: 1))
        }

        groundAO(&m, height: 0.2, floor: 0.7)
        return LODModel(m)
    }
}
