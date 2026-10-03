import RealCore

public extension MaterialLibrary {
    /// Ground (anti-tiled, large tile). Rock specs are in Rock.swift.
    static let stone: [MaterialSpec] = [
        MaterialSpec(key: "ground.forest", program: .forestFloor).with {
            $0.colorA = linear(0x2E241B); $0.colorB = linear(0x5C4129); $0.colorC = linear(0x76603F)
            $0.knobs = V4(0.45, 0.7, 0, 0); $0.tileSize = 2.0; $0.normalStrength = 4; $0.resolution = 2048
            $0.antiTile = true
        },
        MaterialSpec(key: "ground.meadow", program: .forestFloor).with {
            $0.colorA = linear(0x3B3020); $0.colorB = linear(0x6E5A30); $0.colorC = linear(0x7D6E3C)
            $0.knobs = V4(0.85, 0.25, 0, 0); $0.seed = 5; $0.tileSize = 2.0; $0.normalStrength = 3; $0.resolution = 2048
            $0.antiTile = true
        },
        // realforge:material.stone
    ]
}
