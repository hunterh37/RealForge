import RealCore

public extension MaterialLibrary {
    /// Rock (triplanar, moss top layer) and ground (anti-tiled, large tile).
    static let stone: [MaterialSpec] = [
        MaterialSpec(key: "rock.granite", program: .rockGranite).with {
            $0.colorA = linear(0x5F5B56); $0.colorB = linear(0x86817A); $0.colorC = linear(0x9A7468)
            $0.knobs = V4(0.6, 0, 0, 0); $0.tileSize = 1.2; $0.normalStrength = 2.2; $0.triplanar = true
            $0.topAmount = 0.85
        },
        MaterialSpec(key: "rock.sandstone", program: .rockGranite).with {
            $0.colorA = linear(0xA98563); $0.colorB = linear(0xC4A27C); $0.colorC = linear(0x8E5A3A)
            $0.knobs = V4(0.2, 0, 0, 0); $0.seed = 9; $0.tileSize = 1.5; $0.normalStrength = 2; $0.triplanar = true
            $0.topAmount = 0.35
        },
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
