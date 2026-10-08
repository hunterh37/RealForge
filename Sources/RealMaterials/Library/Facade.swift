import RealCore

public extension MaterialLibrary {
    /// Facade materials: weathered exterior trim paint, brownstone, painted wrought iron.
    static let facade: [MaterialSpec] = [
        // Exterior oil paint on trim and doors: brush texture, light chalking and grime in the grain.
        // Tint for color: `wood.painted-exterior:1E3A2C`.
        MaterialSpec(key: "wood.painted-exterior", program: .paintedWood).with {
            $0.colorA = linear(0xEFECE3); $0.colorB = linear(0x8A7E6C); $0.colorC = linear(0x3A3128)
            $0.knobs = V4(0.12, 0.08, 0.55, 0); $0.seed = 8101; $0.tileSize = 1.0; $0.normalStrength = 1.2; $0.roughness = 0.5
        },
        // Brownstone (Triassic sandstone): chocolate-brown, fine grain, darker weathered patches.
        MaterialSpec(key: "stone.brownstone", program: .rockGranite).with {
            $0.colorA = linear(0x58392B); $0.colorB = linear(0x472C21); $0.colorC = linear(0x6A4838)
            $0.knobs = V4(0.15, 0, 0.7, 0.4); $0.seed = 8102; $0.tileSize = 0.8; $0.normalStrength = 1.2; $0.roughness = 0.9
            $0.topColor = linear(0x3E2C22); $0.topAmount = 0.15; $0.topLow = 0.7
            $0.triplanar = true
        },
        // Wrought and cast iron under many coats of black paint, rust bleeding through.
        MaterialSpec(key: "metal.wrought-iron", program: .paintedMetal).with {
            $0.colorA = linear(0x161616); $0.colorC = linear(0x5A2E1A, 0.35); $0.knobs = V4(0.35, 0.35, 0.5, 0); $0.seed = 8103
            $0.tileSize = 0.6; $0.hasMetallicMap = true; $0.normalStrength = 1.8; $0.resolution = 512
        },
        // Factory-finished (Kynar) roofing steel: almost no chips, light dirt washed down the slope.
        MaterialSpec(key: "metal.roofing", program: .paintedMetal).with {
            $0.colorA = linear(0x3A3D3F); $0.colorC = linear(0x6A6A66, 0.4); $0.knobs = V4(0.04, 0.45, 0.42, 0); $0.seed = 8104
            $0.tileSize = 1.2; $0.hasMetallicMap = true; $0.normalStrength = 0.6; $0.roughness = 0.45
        },
        // realityhd:material.architecture
    ]
}
