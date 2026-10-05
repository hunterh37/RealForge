import simd
import Foundation

/// 12 in beech cooking spoon lying on a counter: a shallow carved bowl with a thin rounded rim, a tapered
/// neck and an oval handle swelling toward a rounded end; the bowl is darkened by sauces. Handle toward
/// -X, bowl toward +X; it rests on the bowl bottom and the handle end. Grain runs along the spoon.
public struct WoodenSpoon: RealAsset {
    public static let id = "wooden-spoon"
    public static let summary = "12 in beech wooden spoon: carved shallow bowl, tapered neck, oval handle, stained bowl."
    public static let tags = ["prop", "kitchen", "cookware", "wood", "tool", "handheld"]
    public static let budget = 8000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 40, distance: 0.7, studio: true)

    /// Overall length (m).
    public var length: Float = 0.3
    /// Bowl length and width (m).
    public var bowlLength: Float = 0.084
    public var bowlWidth: Float = 0.058
    /// Bowl depth (m).
    public var bowlDepth: Float = 0.011
    /// Handle thickness (m).
    public var handleThickness: Float = 0.011
    /// Wood; its splat layer (`wood.beech-spoon-stained`) paints the food stain.
    public var wood: MaterialKey = "wood.beech-spoon"
    public init() {}

    var tipX: Float { length * 0.25 }
    var endX: Float { tipX - length }
    var bowlCenter: Float { tipX - bowlLength / 2 }

    /// Bowl center on the inner surface (asset space).
    public var workPoint: V3 { V3(bowlCenter + shift, centerY(bowlCenter) + thickness(bowlCenter) / 2, 0) }
    /// Middle of the handle (asset space).
    public var gripPoint: V3 { let x = endX + length * 0.3; return V3(x + shift, centerY(x) + thickness(x) / 2, 0) }

    var shift: Float { -(endX + tipX) / 2 }

    func e(_ x: Float) -> Float { (x - bowlCenter) / (bowlLength / 2) }
    func sBowl(_ x: Float) -> Float { smoothstep(bowlCenter - bowlLength * 0.62, bowlCenter - bowlLength * 0.3, x) }

    func width(_ x: Float) -> Float {
        let ee = e(x)
        let wb = bowlWidth * pow(max(0, 1 - ee * ee), 0.48) * (1 - 0.12 * max(0, ee))
        var wh: Float = 0.0145 + 0.0115 * smoothstep(bowlCenter - bowlLength * 0.6, endX + 0.04, x)
        wh *= 1 - smoothstep(bowlCenter - bowlLength * 0.55, bowlCenter - bowlLength * 0.1, x)
        if x < endX + 0.014 { wh *= sqrt(max(0.02, 1 - pow((endX + 0.014 - x) / 0.0145, 2))) }
        return max(0.0015, sqrt(wb * wb + wh * wh))
    }
    func thickness(_ x: Float) -> Float { handleThickness + (0.0046 - handleThickness) * sBowl(x) }
    func depth(_ x: Float) -> Float { let ee = e(x); return bowlDepth * sqrt(max(0, 1 - ee * ee)) * sBowl(x) }
    func centerY(_ x: Float) -> Float {
        let ee = min(1, abs(e(x)))
        let bowlLift = (1 - sqrt(max(0, 1 - ee * ee))) * 0.007 * sBowl(x)
        let neck = 0.0065 * exp(-pow((x - (bowlCenter - bowlLength * 0.75)) / 0.05, 2))
        return thickness(x) / 2 + bowlLift + neck
    }
    func ring(_ x: Float, sides: Int) -> [V3] {
        let w = width(x), th = thickness(x), d = depth(x), yc = centerY(x)
        return (0..<sides).map { k in
            let phi = Float(k) / Float(sides) * 2 * .pi
            let u = cos(phi), s = sin(phi)
            // Lens section: concave top in the bowl, convex bottom, thin rounded rim.
            let y = yc + d * u * u + th / 2 * s * (0.35 + 0.65 * sqrt(max(0, 1 - u * u)))
            return V3(x + shift, y, u * w / 2)
        }
    }

    func model(stations: Int, sides: Int) -> Model {
        var m = Model(name: Self.id)
        let rings = (0...stations).map { i -> [V3] in
            let t = Float(i) / Float(stations)
            return ring(endX + 0.0004 + (length - 0.0008) * t, sides: sides)
        }
        var s = Prim.loft(rings, capStart: true, capEnd: true, material: wood)
        if let i = s.positions.indices.max(by: { s.positions[$0].y < s.positions[$1].y }), s.normals[i].y < 0 { s = s.flipped() }
        s.uvs = s.positions.map { V2($0.x, $0.z + $0.y) }                // grain along the spoon
        s.computeTangents()
        // Food stain: full in the bowl, fading up the neck, heavier inside the bowl than under it.
        let b0 = bowlCenter + shift
        s.paintSplat { p in smoothstep(b0 - self.bowlLength * 0.85, b0 - self.bowlLength * 0.3, p.x) * (0.75 + 0.25 * smoothstep(0.002, 0.006, p.y)) }
        m.add(s)
        // Rest on the bowl bottom and the handle end.
        let lowY = m.bounds.min.y
        var out = Model(name: Self.id)
        for s in m.surfaces { out.surfaces.append(s.transformed(Xform(translation: V3(0, -lowY, 0)))) }
        groundAO(&out, height: 0.01, floor: 0.6)
        return out
    }

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(stations: 90, sides: 32), model(stations: 36, sides: 14)], switchDistances: [2])
    }
}
