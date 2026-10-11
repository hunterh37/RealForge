import simd
import Foundation

/// Folding roadside warning triangle: red ABS frame, white retroreflective band, two rear stay legs, rubber feet.
public struct WarningTriangle: RealAsset {
    public static let id = "warning-triangle"
    public static let summary = "Folding roadside warning triangle, 43 cm sides: red fluorescent frame with white reflective band, two stay legs, stands on asphalt."
    public static let tags = ["prop", "road", "sign", "plastic", "outdoor", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"

    /// Outer side length of the triangle in meters.
    public var side: Float = 0.43
    /// Gap between the lower bar and the ground in meters.
    public var lift: Float = 0.028
    /// Fluorescent red-orange of the frame.
    public var frameMaterial = "plastic.orange:D2231B"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let h = side * 0.8660254
        // Outline in the XY plane, apex up, base at y = lift, z = 0 is the front face centre.
        let outer = Shape2D.rounded([V2(-side / 2, 0), V2(side / 2, 0), V2(0, h)], radius: 0.028, segments: 5)
        func band(_ inset: Float, _ width: Float, _ thick: Float, _ z: Float, _ mat: MaterialKey) {
            let c = Shape2D.offset(outer, -(inset + width / 2))
            let path = c.map { V3($0.x, $0.y + lift, z) }
            var sw = Prim.sweep(Shape2D.roundedRect(thick, width, radius: min(width, thick) * 0.3, segments: 2), along: path, up: V3(0, 0, 1), closedPath: true, material: mat)
            sw.uvs = sw.positions.map { V2($0.x, $0.y) }
            sw.computeTangents()
            m.add(sw)
        }
        band(0.0, 0.014, 0.016, 0, frameMaterial)         // outer border
        band(0.014, 0.026, 0.010, 0.002, "plastic.white")   // reflective band, slightly proud
        band(0.040, 0.014, 0.016, 0, frameMaterial)         // inner border
        // Pebble prism texture hint: thin white micro-ribs across the band's lower bar.
        for k in 0..<18 {
            let x = -side * 0.5 + 0.05 + Float(k) * (side - 0.1) / 17
            m.add(Prim.roundedBox(V3(0.0035, 0.024, 0.0014), radius: 0.0004, bevelSegments: 1, material: "plastic.matte"),
                  Xform(translation: V3(x, lift + 0.0245, 0.0065)))
        }
        // Rear stay legs: from the lower corners back to ground feet, with hinge pins and rubber feet.
        let back = -0.215 * side / 0.43 * 1.0
        for sx: Float in [-1, 1] {
            let hinge = V3(sx * (side / 2 - 0.045), lift + 0.02, -0.009)
            let foot = V3(sx * (side / 2 - 0.02), 0.012, back + 0.09)
            m.add(Prim.tube([hinge, V3(hinge.x + sx * 0.008, 0.05, -0.08), foot], radii: [0.0055, 0.0055, 0.0055], sides: 8, seamTile: 0.1, material: "metal.steel", capEnd: true))
            m.add(Prim.cylinder(radius: 0.0085, height: 0.022, bevel: 0.002, segments: 12, material: "plastic.black"),
                  Xform(translation: V3(hinge.x, hinge.y - 0.012, hinge.z), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
            m.add(Prim.roundedBox(V3(0.04, 0.012, 0.03), radius: 0.003, bevelSegments: 2, material: "rubber"), Xform(translation: V3(foot.x, 0.006, foot.z)))
            // Front feet under the lower bar.
            m.add(Prim.roundedBox(V3(0.04, lift, 0.02), radius: 0.003, bevelSegments: 2, material: "rubber"), Xform(translation: V3(sx * (side / 2 - 0.05), lift / 2, 0)))
        }
        // Rear approval label and a worn scuff along the lower bar.
        m.add(Prim.roundedBox(V3(0.07, 0.034, 0.0012), radius: 0.0004, bevelSegments: 1, material: "paper.sheet"), Xform(translation: V3(0.02, lift + 0.13, -0.0085)))
        m.add(Prim.roundedBox(V3(0.06, 0.0025, 0.0014), radius: 0.0008, bevelSegments: 1, material: "plastic.black"), Xform(translation: V3(-0.07, lift + 0.036, 0.0095), rotation: simd_quatf(degrees: -2, axis: V3(0, 0, 1))))
        // Apex hanging hole boss.
        m.add(Prim.cylinder(radius: 0.011, height: 0.016, bevel: 0.003, segments: 16, material: frameMaterial),
              Xform(translation: V3(0, h + lift - 0.05, 0), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(0, 0, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.08, floor: 0.6)
        return LODModel(m)
    }
}
