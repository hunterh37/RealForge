import RealCore

public extension MaterialLibrary {
    /// Transparent liquids and glass. Water depth comes from `Surface.splat` (0 shore, 1 deep).
    static let water: [MaterialSpec] = [
        // Pond: tea-green body color, shallow edges see through to the bed.
        MaterialSpec(key: "water.pond", program: .water).with {
            $0.colorA = linear(0x1C2B22); $0.colorB = linear(0x6B7A55); $0.knobs = V4(0.45, 0, 0, 0)
            $0.tileSize = 3; $0.resolution = 1024; $0.normalStrength = 1.2; $0.mode = .transparent; $0.opacity = 0.55
            $0.roughness = 0.04; $0.specular = 0.5; $0.flow = 0.05; $0.hasAOMap = false
        },
        // Rain puddle: thin muddy water over a mud bed, nearly still.
        MaterialSpec(key: "water.puddle", program: .water).with {
            $0.colorA = linear(0x1C1813); $0.colorB = linear(0x2E271F); $0.knobs = V4(0.2, 0, 0, 0); $0.seed = 7
            $0.tileSize = 1.5; $0.resolution = 1024; $0.normalStrength = 0.6; $0.mode = .transparent; $0.opacity = 0.5
            $0.roughness = 0.03; $0.specular = 0.5; $0.flow = 0.015; $0.hasAOMap = false
        },
        // Clear pane glass, 4-6 mm float glass (PhysicallyBasedMaterial path).
        MaterialSpec(key: "glass.pane", program: nil).with {
            $0.baseColor = V3(0.82, 0.86, 0.84); $0.roughness = 0.02; $0.specular = 0.5; $0.mode = .transparent; $0.opacity = 0.18; $0.twoSided = true
        },
        // realityhd:material.water
    ]
}
