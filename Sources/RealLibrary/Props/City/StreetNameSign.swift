import simd
import Foundation

/// Corner street name sign: a perforated square galvanized post topped by a cast cross bracket that
/// holds two green retroreflective blades at right angles, each lettered on both faces with a white
/// border. Blade names and suffixes are knobs.
public struct StreetNameSign: RealAsset {
    public static let id = "street-name-sign"
    public static let summary = "Street name sign post: square perforated steel post with two crossed green street name blades and a cap bracket."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "metal", "sign"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 8, distance: 1.1)

    /// Street on the lower blade (runs along X).
    public var lower = "ARCH ST"
    /// Street on the upper blade (runs along Z).
    public var upper = "MAIN ST"
    /// Blade length and height (m).
    public var bladeLength: Float = 0.9
    public var bladeHeight: Float = 0.15
    /// Overall height (m).
    public var height: Float = 3.1
    /// Materials.
    public var post: MaterialKey = "metal.galvanized"
    public var face: MaterialKey = "sign.green-worn"
    public var bracket: MaterialKey = "metal.galvanized-aged"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let bh = bladeHeight, top = height, upperY = top - bh / 2 - 0.004, lowerY = upperY - bh - 0.02
        citySquarePost(&m, side: 0.05, height: lowerY - bh / 2 - 0.03, material: post)
        // Cross bracket: a cast collar on the post top with slotted clamps above and below.
        let collarY = lowerY - bh / 2 - 0.03
        m.add(Prim.roundedBox(V3(0.07, 0.06, 0.07), radius: 0.008, bevelSegments: 2, material: bracket), Xform(translation: V3(0, collarY + 0.02, 0)))
        // Spine pieces between the clamps (kept off the blade faces so the legends read).
        for (y0, y1) in [(collarY + 0.04, lowerY - bh / 2 - 0.004), (lowerY + bh / 2 + 0.004, upperY - bh / 2 - 0.004)] where y1 > y0 {
            m.add(Prim.roundedBox(V3(0.03, y1 - y0, 0.03), radius: 0.004, bevelSegments: 1, material: bracket), Xform(translation: V3(0, (y0 + y1) / 2, 0)))
        }
        for (y, yaw) in [(lowerY, Float(0)), (upperY, Float.pi / 2)] {
            // Clamp channel along the blade's top and bottom edges.
            for e: Float in [-1, 1] {
                m.add(Prim.roundedBox(V3(0.12, 0.018, 0.016), radius: 0.004, bevelSegments: 1, material: bracket),
                      Xform(translation: V3(0, y + e * (bh / 2 + 0.002), 0), rotation: simd_quatf(angle: yaw, axis: .up)))
            }
            let name = y == lowerY ? lower : upper
            let blade = Shape2D.roundedRect(bladeLength, bh, radius: 0.012, segments: 3)
            let x = Xform(translation: V3(0, y, 0), rotation: simd_quatf(angle: yaw + rng.float(-0.01...0.01), axis: .up))
            let fadeTint = y == lowerY ? "\(face):\(String(format: "%02X%02X%02X", 20 + rng.int(0...20), 70 + rng.int(0...25), 45 + rng.int(0...15)))" : face
            citySignPlate(&m, outline: blade, x: x, thickness: 0.003, border: 0.008, face: fadeTint, back: nil, twoSided: true,
                          text: [(name, V2(0, 0), bh * 0.56, 0.7)])
        }
        // Cap on the bracket top.
        m.add(Prim.cylinder(radius: 0.02, height: 0.012, bevel: 0.004, segments: 14, material: bracket), Xform(translation: V3(0, upperY + bh / 2 + 0.01, 0)))
        // Story detail: a half-peeled sticker and a strip of tape residue on the post at eye height.
        m.add(cuboid(V3(0.04, 0.055, 0.0008), material: "sign.white"), Xform(translation: V3(0, 1.52, 0.0256), rotation: simd_quatf(angle: rng.float(-0.2...0.2), axis: V3(0, 0, 1))))
        m.add(cuboid(V3(0.03, 0.012, 0.0008), material: "sign.red"), Xform(translation: V3(0, 1.53, 0.0262)))
        m.add(cuboid(V3(0.0008, 0.03, 0.045), material: "plastic.matte"), Xform(translation: V3(0.0256, 1.2, 0)))
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
