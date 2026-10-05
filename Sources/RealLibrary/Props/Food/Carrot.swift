import simd
import Foundation

/// Fresh carrot lying along +X: crown at +X with trimmed green stem stubs, tapering to a thin curved
/// tail at -X. Two tissues as nested closed shells with matching boundaries: the orange cortex is a
/// thick-walled shell (skin outside, core-shaped hole inside; cut face `food.carrot-cortex`) and the
/// pale core is a solid filling that hole (cut face `food.carrot-core`), so a cross cut shows the core
/// disc inside the cortex ring without overlapping caps. Lenticel rings and root-hair scars are in
/// `food.carrot`; shallow constrictions and a slightly lobed section are in the geometry.
public struct Carrot: RealFood {
    public static let id = "carrot"
    public static let summary = "Fresh carrot, 18 cm: tapered orange root with lenticel rings and root-hair scars, trimmed green crown, core and cortex shells."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.root
    public static let preview = PreviewHint(azimuth: 20, elevation: 25, distance: 0.38, studio: true)

    /// Root length without the stem stubs (m).
    public var length: Float = 0.184
    /// Widest diameter near the crown (m).
    public var diameter: Float = 0.032
    /// Core radius as a fraction of the local radius.
    public var coreFraction: Float = 0.42
    /// Stem stub count and length (m).
    public var stems = 8
    public var stemLength: Float = 0.007
    /// Material keys.
    public var skin: MaterialKey = "food.carrot"
    public var cortex: MaterialKey = "food.carrot-cortex"
    public var core: MaterialKey = "food.carrot-core"
    public var stem: MaterialKey = "food.stem-green"
    public init() {}

    /// On the root axis in the thick half (the axis stays straight and level there).
    public var coreCenter: V3 { V3(length * 0.25, axisHeight, 0) }
    /// Height of the root axis above the ground (lobes reach about 3 % past the nominal radius).
    var axisHeight: Float { diameter / 2 * 1.03 }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? {
        if key == skin { return cortex }
        if key == core { return core }
        return nil
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let L = length, R = diameter / 2
        // Radius along the root, y = 0 tail tip ... L crown.
        let shape: [V2] = [V2(0, 0), V2(R * 0.08, L * 0.02), V2(R * 0.2, L * 0.08), V2(R * 0.4, L * 0.22), V2(R * 0.6, L * 0.4),
                           V2(R * 0.77, L * 0.58), V2(R * 0.9, L * 0.75), V2(R * 0.98, L * 0.88), V2(R, L * 0.94),
                           V2(R * 0.93, L * 0.975), V2(R * 0.7, L * 0.995), V2(R * 0.35, L * 1.0), V2(0, L * 1.0)]
        let outerCurve = FoodMesh.profile(shape)
        var outer = FoodMesh.revolve(edge: 0.0031, seamTile: 0.05, material: skin, curve: outerCurve)
        let coreShape = shape.dropFirst().dropLast().map { V2($0.x * coreFraction, $0.y) }.filter { $0.y > L * 0.03 && $0.y < L * 0.985 }
        let coreCurve = FoodMesh.profile([V2(0, L * 0.025)] + coreShape + [V2(0, L * 0.985)])
        let coreS = FoodMesh.revolve(edge: 0.004, seamTile: 0.03, material: core, curve: coreCurve)
        // Constriction rings and a slightly lobed section on the skin only (the core stays well inside).
        let rings = (0..<12).map { _ in (rng.float(0.05...0.92) * L, rng.float(0.015...0.04), rng.float(0.001...0.0025)) }
        let ph = (0..<3).map { _ in rng.float(0...6.28) }
        outer.deform { p in
            let a = atan2(p.z, p.x)
            var k: Float = 1 + 0.018 * sin(a * 2 + ph[0] + p.y * 20) + 0.01 * sin(a * 3 + ph[1])
            for (y, depth, w) in rings { k -= depth * exp(-pow((p.y - y) / w, 2)) }
            return V3(p.x * k, p.y, p.z * k)
        }
        var cortexS = outer
        cortexS.append(coreS.flipped().with(material: skin))
        var m = Model(name: Self.id)
        // Lay along X (tail at x = 0, crown at x = L), then bend the tail down toward the ground.
        let bend = rng.float(0.6...1.0), sway = rng.float(-0.4...0.4)
        let lay: (V3) -> V3 = { p in
            let t = max(0, 1 - p.x / (L * 0.55))       // 0 over the thick half, 1 at the tail tip
            return V3(p.x, p.y - R * 0.55 * bend * t * t, p.z + R * 0.5 * sway * t * t)
        }
        var a = FoodMesh.layAlongX(cortexS), b = FoodMesh.layAlongX(coreS)
        a.deform(lay); b.deform(lay)
        // Trimmed stem stubs out of the crown, cut flat.
        var stemS = Surface(material: stem)
        for i in 0..<stems {
            var r = rng.fork(i)
            let ang = Float(i) / Float(stems) * 2 * .pi + r.float(-0.3...0.3)
            let rr = i == 0 ? 0 : r.float(0.0015...0.0055)
            let base = V3(L - 0.003, cos(ang) * rr, sin(ang) * rr)
            let dir = simd_normalize(V3(1, cos(ang) * rr * 45, sin(ang) * rr * 45))
            let len = stemLength * r.float(0.6...1.3)
            let rad = r.float(0.0011...0.0017)
            let pts = (0...3).map { base + dir * (len * Float($0) / 3) }
            stemS.append(FoodMesh.tube(pts, radii: [rad * 1.15, rad, rad, rad * 0.95], sides: 7, endBulge: 0.05, material: stem))
        }
        m.add(a); m.add(b); m.add(stemS)
        m = m.transformed(Xform(translation: V3(-L / 2, axisHeight, 0)))
        groundAO(&m, height: 0.012, floor: 0.6)
        return LODModel(m)
    }
}

extension Surface {
    /// Same geometry under another material key.
    func with(material: MaterialKey) -> Surface { var s = self; s.material = material; return s }
}
