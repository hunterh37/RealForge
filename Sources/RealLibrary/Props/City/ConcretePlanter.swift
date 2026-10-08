import simd
import Foundation

/// Square precast concrete street planter: a 1.2 m shell on a recessed plinth, a chamfered rim with
/// a chipped corner, potting soil and a clipped boxwood (the `boxwood-ball` asset). Doubles as a
/// pedestrian barrier.
public struct ConcretePlanter: RealAsset {
    public static let id = "concrete-planter"
    public static let summary = "Square precast concrete planter, 1.2 m, with a chamfered rim, soil and a boxwood shrub."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "concrete", "plant", "barrier"]
    public static let budget = 11000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 15, distance: 1.1)

    /// Shell edge and height (m).
    public var width: Float = 1.2
    public var height: Float = 0.7
    /// Wall thickness (m).
    public var wall: Float = 0.08
    /// Plant a boxwood.
    public var shrub = true
    /// Shrub diameter (m).
    public var shrubDiameter: Float = 0.85
    /// Materials.
    public var concrete: MaterialKey = "concrete.smooth"
    public var stained: MaterialKey = "concrete.rough"
    public var soil: MaterialKey = "soil.potting"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let w = width, plinth: Float = 0.06, rimH: Float = 0.07
        m.add(Prim.roundedBox(V3(w - 0.12, plinth, w - 0.12), radius: 0.01, bevelSegments: 2, material: stained), Xform(translation: V3(0, plinth / 2, 0)))
        let bodyH = height - plinth - rimH
        m.add(Prim.roundedBox(V3(w - 0.04, bodyH, w - 0.04), radius: 0.012, bevelSegments: 2, material: concrete), Xform(translation: V3(0, plinth + bodyH / 2, 0)))
        // Rim: four chamfered coping pieces forming a frame that overhangs the body by 2 cm.
        let prof = Shape2D.rounded([V2(-wall / 2 - 0.02, 0), V2(wall / 2, 0), V2(wall / 2, rimH - 0.012), V2(wall / 2 - 0.012, rimH), V2(-wall / 2 - 0.006, rimH), V2(-wall / 2 - 0.02, rimH - 0.03)], radius: 0.004, segments: 2)
        for k in 0..<4 {
            let a = Float(k) * .pi / 2
            var s = Prim.extrude(prof.map { V2(-$0.x, $0.y) }, depth: w, bevel: 0.004, bevelSegments: 1, material: concrete)
            s = s.transformed(Xform(rotation: simd_quatf(degrees: 90, axis: .up)))
            m.add(s, Xform(translation: V3(sin(a), 0, cos(a)) * (w / 2 - wall / 2) + V3(0, height - rimH, 0), rotation: simd_quatf(angle: a, axis: .up)))
        }
        // Soil 6 cm below the rim.
        let soilY = height - rimH + 0.002
        m.add(Prim.roundedBox(V3(w - 2 * wall, 0.02, w - 2 * wall), radius: 0.005, bevelSegments: 1, material: soil), Xform(translation: V3(0, soilY, 0)))
        // Weathering: the plinth and lower body take splash grime (rough variant on the plinth); a chipped rim corner.
        m.add(Prim.roundedBox(V3(0.07, 0.03, 0.05), radius: 0.01, bevelSegments: 1, material: stained), Xform(translation: V3(w / 2 - 0.035, height - 0.02, w / 2 - 0.03), rotation: simd_quatf(angle: rng.float(0.2...0.5), axis: .up)))
        if shrub {
            var bw = BoxwoodBall(); bw.diameter = shrubDiameter; bw.height = shrubDiameter * 0.9
            let lvl = bw.build(seed: seed &+ 3).levels[0]
            m.add(lvl, Xform(translation: V3(0, soilY + 0.01 - min(0, lvl.bounds.min.y) - 0.05, 0)))
        }
        groundAO(&m, height: 0.15, floor: 0.6)
        return LODModel(m)
    }
}
