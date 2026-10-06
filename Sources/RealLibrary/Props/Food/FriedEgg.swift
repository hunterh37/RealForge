import simd
import Foundation

/// Egg just cracked into a pan: an irregular thin spread of albumen (closed shell, `food.egg-white`,
/// clear raw, sets white) with a thicker ring around the yolk and a thin wavy rim, and a domed yolk
/// (closed shell, `food.egg-yolk`) seated on the white with a hairline gap so the two shells never
/// overlap. Each shell caps with its own material.
public struct FriedEgg: RealFood {
    public static let id = "fried-egg"
    public static let summary = "Egg cracked into a pan, 13 cm: irregular thin white with thick ring and domed yolk; cooks from clear to set white."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let kind = FoodKind.egg
    public static let preview = PreviewHint(azimuth: 25, elevation: 45, distance: 0.32, studio: true)

    /// Spread of the white (m).
    public var spread: Float = 0.125
    /// Yolk diameter and height (m).
    public var yolkDiameter: Float = 0.032
    public var yolkHeight: Float = 0.017
    /// Material keys.
    public var white: MaterialKey = "food.egg-white"
    public var yolk: MaterialKey = "food.egg-yolk"
    public init() {}

    var whiteCenterTop: Float { 0.0042 }
    public var coreCenter: V3 { V3(yolkOffset.x, whiteCenterTop + yolkHeight * 0.4, yolkOffset.y) }
    var yolkOffset: V2 { V2(-0.008, 0.004) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? {
        if key == white { return white }
        if key == yolk { return yolk }
        return nil
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let R = spread / 2 / 1.12, yr = yolkDiameter / 2, ct = whiteCenterTop
        // White profile around the yolk position: flat bottom, rim, thin plateau, thick ring, dip under the yolk.
        let pts: [V2] = [V2(0, 0), V2(R * 0.6, 0), V2(R - 0.0012, 0.0002), V2(R, 0.0011), V2(R - 0.0015, 0.0021),
                         V2(R * 0.8, 0.0026), V2(R * 0.55, 0.0032), V2(yr * 1.9, 0.0052), V2(yr * 1.35, 0.0068),
                         V2(yr * 1.12, 0.0058), V2(yr * 0.95, ct + 0.0002), V2(yr * 0.5, ct), V2(0, ct)]
        var w = FoodMesh.revolve(edge: 0.004, seamTile: 0.05, material: white, curve: FoodMesh.profile(pts, per: 5))
        let ph = (0..<5).map { _ in rng.float(0...6.28) }
        // Irregular outline: lobes grow with the radius so the yolk area stays round.
        let outline: (Float) -> Float = { a in
            1 + 0.13 * sin(a * 2 + ph[0]) + 0.08 * sin(a * 3 + ph[1]) + 0.04 * sin(a * 7 + ph[2]) + 0.02 * sin(a * 13 + ph[3])
        }
        w.deform { p in
            let a = atan2(p.z, p.x), r = simd_length(V2(p.x, p.z))
            let t = smoothstep(yr * 2.2, R * 0.7, r)
            let k = 1 + (outline(a) - 1) * t
            // The yolk sits off-center in the spread: shift the far field the other way.
            let shift = -self.yolkOffset * t * 1.5
            return V3(p.x * k + shift.x + self.yolkOffset.x, p.y + 0.0003 * sin(r * 300 + ph[4]) * t, p.z * k + shift.y + self.yolkOffset.y)
        }
        // Yolk: a dome with a flat underside resting 0.15 mm above the white.
        var y = FoodMesh.revolve(edge: 0.0026, seamTile: 0.03, material: yolk) { t in
            if t < 0.5 {
                let f = t / 0.5
                return V2(yr * 0.96 * sin(f * .pi / 2), ct + 0.00015 + 0.0006 * (1 - cos(f * .pi / 2)))
            }
            let f = (t - 0.5) / 0.5
            return V2(yr * 0.96 * cos(f * .pi / 2) * (1 + 0.04 * sin(f * .pi)), ct + 0.00075 + self.yolkHeight * pow(sin(f * .pi / 2), 0.8))
        }
        y.deform { p in V3(p.x + self.yolkOffset.x, p.y, p.z + self.yolkOffset.y) }
        var m = Model(name: Self.id)
        m.add(FoodMesh.planarUV(w)); m.add(FoodMesh.boxUV(y))
        groundAO(&m, height: 0.004, floor: 0.8)
        return LODModel(m)
    }
}
