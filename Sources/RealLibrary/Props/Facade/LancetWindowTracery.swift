import simd
import Foundation

/// Gothic lancet window: 0.7 m wide, 1.9 m tall pointed opening with a moulded limestone surround, a
/// central mullion forking into two sub-lancets under a quatrefoil, leaded glass and a drip sill.
public struct LancetWindowTracery: RealAsset {
    public static let id = "lancet-window-tracery"
    public static let summary = "Gothic lancet window, 0.7 x 1.9 m: moulded stone surround, mullion, quatrefoil, leaded glass."
    public static let tags = ["prop", "architecture", "facade", "window", "stone", "glass"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 8, distance: 3.4)

    public var width: Float = 0.7
    public var springHeight: Float = 1.25
    public var stone: MaterialKey = "stone.limestone"
    public var sill: MaterialKey = "stone.limestone-sooted"
    public var lead: MaterialKey = "metal.wrought-iron"
    public var glass: MaterialKey = "glass.tinted"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, S = springHeight, base: Float = 0.1
        let inner = FC.archOutline(width: W - 0.1, spring: S, pointed: true).map { V2($0.x, $0.y + base) }
        m.add(Prim.extrude(inner, depth: 0.012, bevel: 0.001, bevelSegments: 1, material: glass), Xform(translation: V3(0, 0, 0.03)))
        // Moulded surround: a roll moulding and a hollow behind it, both following the arch.
        let roll = FC.archPath(width: W - 0.04, spring: S, pointed: true, z: 0.06).map { V3($0.x, $0.y + base, $0.z) }
        FA.path(&m, roll, r: 0.032, stone, sides: 10)
        let hollow = FC.archPath(width: W + 0.06, spring: S, pointed: true, z: 0.035).map { V3($0.x, $0.y + base, $0.z) }
        FA.path(&m, hollow, r: 0.02, stone, sides: 8)
        let hw = W / 2
        let apexY = FC.archRise(width: W - 0.1, spring: S, pointed: true) + base
        // Mullion and sub-arches.
        let mid = base + S * 0.5
        FA.rod(&m, V3(0, base, 0.05), V3(0, mid + 0.2, 0.05), r: 0.015, stone)
        for e: Float in [-1, 1] {
            let pts = [V3(0, mid + 0.2, 0.05), V3(e * 0.07, mid + 0.3, 0.05), V3(e * 0.15, mid + 0.45, 0.05), V3(e * (hw - 0.07), base + S, 0.05)]
            FA.path(&m, pts, r: 0.012, stone, sides: 8)
        }
        // Quatrefoil under the apex.
        let qc = V3(0, (mid + 0.45 + apexY) / 2 + 0.12, 0.05)
        m.add(Prim.torus(major: 0.09, minor: 0.011, segments: 24, sides: 6, material: stone), Xform(translation: qc, rotation: FA.q(90, FA.X)))
        for k in 0..<4 {
            let a = Float(k) * .pi / 2 + .pi / 4
            m.add(Prim.torus(major: 0.035, minor: 0.008, segments: 14, sides: 5, material: stone),
                  Xform(translation: qc + V3(cos(a) * 0.065, sin(a) * 0.065, 0), rotation: FA.q(90, FA.X)))
        }
        // Leaded cames: horizontal bars and diagonal pair.
        for i in 1..<8 {
            let y = base + Float(i) * 0.15
            if y < base + S { FA.rod(&m, V3(-hw + 0.06, y, 0.042), V3(hw - 0.06, y, 0.042), r: 0.0025, lead, sides: 5) }
        }
        // Sill with drip groove.
        FA.box(&m, V3(W + 0.2, 0.06, 0.2), V3(0, 0.03, 0.1), sill, r: 0.005)
        FA.box(&m, V3(W + 0.1, 0.04, 0.1), V3(0, base - 0.02, 0.05), stone, r: 0.004)
        groundAO(&m, height: 0.12, floor: 0.85)
        return LODModel(FA.centerZ(m))
    }
}
