import simd
import Foundation

/// Plaza paving tile on the 3 m city grid: 50 cm granite slabs, 6 x 6 in a stack bond on a sand
/// bed, the outer ring in a darker granite as a border band. Slabs vary a millimeter or two in
/// height and tone. Top y = 0.25 (sidewalk height), so it butts `sidewalk-curb` tiles flush.
public struct PlazaPaving: RealAsset {
    public static let id = "plaza-paving"
    public static let summary = "Plaza paving tile, 3 x 3 m snap cell: 50 cm granite-look concrete slabs in a stack bond with a darker band, sand joints, sidewalk height."
    public static let tags = ["structure", "city", "street", "road", "tile", "outdoor", "concrete", "stone"]
    public static let budget = 5200
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 35, distance: 1.0)

    /// Cell edge length (m).
    public var cell: Float = CityGrid.walkCell
    /// Surface height (m).
    public var top: Float = CityGrid.walkTop
    /// Slab edge (m).
    public var slab: Float = 0.5
    /// Slab thickness (m).
    public var thickness: Float = 0.06
    /// Joint width (m).
    public var joint: Float = 0.006
    /// Draw the darker outer band.
    public var band = true
    /// Slab tones (sRGB hex) for the field, and the band tone.
    public var tones: [UInt32] = [0xB8B2A6, 0xAEA89C, 0xC2BCB0]
    public var bandTone: UInt32 = 0x6E6C68
    /// Granite material tinted per slab; bedding sand.
    public var stone: MaterialKey = "stone.granite-paver"
    public var sand: MaterialKey = "ground.sand:4A453E"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let n = Int((cell / slab).rounded()), h = cell / 2
        citySlab(&m, x: cell - 0.03, z: cell - 0.03, top: top - thickness + 0.004, material: sand)
        let keys = tones.map { "\(stone):\(String(format: "%06X", $0))" }, bandKey = "\(stone):\(String(format: "%06X", bandTone))"
        for i in 0..<n { for j in 0..<n {
            let edge = band && (i == 0 || j == 0 || i == n - 1 || j == n - 1)
            let k: MaterialKey = edge ? bandKey : keys[rng.int(0...(keys.count - 1))]
            let t = thickness + rng.float(-0.0018...0.0012)
            var s = Prim.roundedBox(V3(slab - joint, t, slab - joint), radius: 0.004, bevelSegments: 1, material: k)
            let cx = -h + slab * (Float(i) + 0.5), cz = -h + slab * (Float(j) + 0.5)
            for v in s.positions.indices where abs(s.normals[v].y) > 0.7 { s.uvs[v] = V2(s.positions[v].x + cx * 3.1, s.positions[v].z + cz * 2.3) }
            s.computeTangents()
            m.add(s, Xform(translation: V3(cx, top - thickness + t / 2, cz), rotation: simd_quatf(angle: rng.float(-0.003...0.003), axis: rng.unitVector())))
        }}
        // A few dark rain-stain and gum spots on the field.
        for _ in 0..<10 {
            let p = V2(rng.float(-1.2...1.2), rng.float(-1.2...1.2)), r = rng.float(0.01...0.03)
            cityLayer(&m, outline: Shape2D.circle(r, segments: 8).map { $0 + p }, y: top + 0.0012, lift: 0.0006, thick: 0.001, material: "asphalt.worn")
        }
        groundAO(&m, height: 0.06, floor: 0.75)
        return LODModel(m)
    }
}
