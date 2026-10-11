import simd
import Foundation

/// Cross lug wrench: chrome-plated steel, scuffed, black grip. Lies flat on its four arms.
public struct LugWrench: RealAsset {
    public static let id = "lug-wrench"
    public static let summary = "Four-way cross lug wrench: 460 mm chrome arms with 17, 19, 21 and 22 mm sockets, rubber-sleeved long arm."
    public static let tags = ["prop", "tool", "vehicle", "metal", "handheld"]
    public static let budget = 9000
    public static let author = "realityhd"

    /// Distance from the hub to each socket center in meters.
    public var armLength: Float = 0.215
    /// Arm bar radius in meters.
    public var barRadius: Float = 0.0085
    /// Socket across-flats sizes in millimeters, one per arm (+X, +Z, -X, -Z).
    public var socketSizes: [Float] = [22, 21, 19, 17]
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let h: Float = 0.03, yBar = h / 2
        let dirs: [V3] = [V3(1, 0, 0), V3(0, 0, 1), V3(-1, 0, 0), V3(0, 0, -1)]
        // Two forged bars through the hub, slightly bowed in the middle section.
        m.add(Prim.tube([V3(-armLength, yBar, 0), V3(0, yBar, 0), V3(armLength, yBar, 0)], radii: [barRadius, barRadius, barRadius], sides: 14, seamTile: 0.12, material: "metal.chrome", capEnd: true))
        m.add(Prim.tube([V3(0, yBar, -armLength), V3(0, yBar, armLength)], radii: [barRadius, barRadius], sides: 14, seamTile: 0.12, material: "metal.chrome", capEnd: true))
        // Hub boss where the bars cross.
        m.add(Prim.cylinder(radius: 0.0165, height: h, bevel: 0.004, segments: 24, material: "metal.chrome"))
        m.add(Prim.cylinder(radius: 0.007, height: 0.002, bevel: 0.0008, segments: 12, material: "metal.steel"), Xform(translation: V3(0, h, 0)))
        // Sockets: round chrome barrels with a hex bore, 3 mm walls.
        for (i, d) in dirs.enumerated() {
            let af = socketSizes[i % socketSizes.count] / 1000
            let outer = af * 0.5 + 0.0075
            let c = d * armLength
            m.add(Prim.cylinder(radius: outer, height: h, bevel: 0.0025, segments: 28, material: "metal.chrome"), Xform(translation: c))
            // Bore: dark hex disc just proud of the top face, steel hex rim around it.
            let rHex = af * 0.5774
            m.add(turned([(0, 0), (rHex + 0.0014, 0), (rHex + 0.0014, 0.0007), (0, 0.0007)], segments: 6, material: "metal.steel", seamTile: 0.05), Xform(translation: c + V3(0, h - 0.0002, 0)))
            m.add(turned([(0, 0), (rHex, 0), (rHex, 0.0010), (0, 0.0010)], segments: 6, material: "plastic.black", seamTile: 0.05), Xform(translation: c + V3(0, h + 0.0004, 0)))
        }
        // Grip sleeve on the +X arm, ridged ends.
        m.add(Prim.tube([V3(0.085, yBar, 0), V3(0.175, yBar, 0)], radii: [barRadius + 0.0022, barRadius + 0.0022], sides: 14, seamTile: 0.1, material: "rubber.silicone", capEnd: true))
        for x: Float in [0.085, 0.175] {
            m.add(Prim.cylinder(radius: barRadius + 0.0034, height: 0.005, bevel: 0.0014, segments: 14, material: "rubber.silicone"),
                  Xform(translation: V3(x, yBar, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        }
        var out = Model(name: Self.id)
        out.add(m, Xform(rotation: simd_quatf(degrees: rng.float(-4...4), axis: V3(0, 1, 0))))
        groundAO(&out, height: 0.03, floor: 0.5)
        return LODModel(out)
    }
}
