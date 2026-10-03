import RealCore

public extension MaterialLibrary {
    /// Metals. `metal.painted` takes a tint suffix: `metal.painted:B0241A`.
    static let metal: [MaterialSpec] = [
        MaterialSpec(key: "metal.painted", program: .paintedMetal).with {
            $0.colorA = linear(0x2E4A36); $0.colorC = linear(0x5A2E1A, 0.0); $0.knobs = V4(0.5, 0.4, 0.38, 0)
            $0.tileSize = 0.8; $0.hasMetallicMap = true; $0.normalStrength = 1.5; $0.resolution = 1024
        },
        MaterialSpec(key: "metal.rust", program: .rustMetal).with {
            $0.colorA = linear(0x6A2E12); $0.colorB = linear(0x2A140A); $0.knobs = V4(0.3, 0, 0, 0)
            $0.tileSize = 0.6; $0.hasMetallicMap = true; $0.normalStrength = 3
        },
        MaterialSpec(key: "metal.steel", program: nil).with { $0.baseColor = V3(0.56, 0.57, 0.58); $0.metallic = 1; $0.roughness = 0.32 },
        MaterialSpec(key: "metal.iron", program: .paintedMetal).with {
            $0.colorA = linear(0x1A1B1C); $0.colorC = linear(0x3A2418, 0.0); $0.knobs = V4(0.25, 0.3, 0.45, 0); $0.seed = 2
            $0.tileSize = 0.8; $0.hasMetallicMap = true; $0.normalStrength = 1.5; $0.resolution = 512
        },
        // realityhd:material.metal
    ]
}
