import RealCore

public extension MaterialLibrary {
    /// Architectural trim stone and render: dressed limestone, sandstone, cast stone, honed marble, stucco.
    static let architecture: [MaterialSpec] = [
        // Dressed Portland-type limestone: pale buff, fine shelly texture, soot and rain streaks.
        MaterialSpec(key: "stone.limestone", program: .concrete).with {
            $0.colorA = linear(0xD8CEB8); $0.colorB = linear(0xBFB399); $0.knobs = V4(0.86, 0.55, 0, 0); $0.seed = 9101
            $0.tileSize = 0.4; $0.normalStrength = 0.35; $0.roughness = 0.86
        },
        // Limestone where rain never washes it (soffits, modillions, dentils): grey soot crust over buff.
        MaterialSpec(key: "stone.limestone-sooted", program: .concrete).with {
            $0.colorA = linear(0xB9AF9C); $0.colorB = linear(0x8E887A); $0.knobs = V4(0.9, 0.95, 0, 0); $0.seed = 9106
            $0.tileSize = 0.4; $0.normalStrength = 0.4; $0.roughness = 0.9
        },
        // Dressed buff sandstone: warmer, coarser grain.
        MaterialSpec(key: "stone.sandstone", program: .concrete).with {
            $0.colorA = linear(0xC9A97E); $0.colorB = linear(0xA88760); $0.knobs = V4(0.9, 0.5, 0, 0); $0.seed = 9102
            $0.tileSize = 0.6; $0.normalStrength = 0.8; $0.roughness = 0.9
        },
        // Cast stone (reconstituted): even light grey-buff, fine pores.
        MaterialSpec(key: "stone.cast-stone", program: .concrete).with {
            $0.colorA = linear(0xC8C2B4); $0.colorB = linear(0x9C968A); $0.knobs = V4(0.6, 0.35, 0, 0); $0.seed = 9103
            $0.tileSize = 0.45; $0.normalStrength = 0.5; $0.roughness = 0.88
        },
        // Honed white marble (columns, balusters): soft grey veins, matte.
        MaterialSpec(key: "stone.marble-honed", program: .marble).with {
            $0.colorA = linear(0xE6E3DC); $0.colorB = linear(0xCFCDC7); $0.colorC = linear(0xD6D3CC, 0.3)
            $0.knobs = V4(1, 0.45, 0.02, 0.4); $0.seed = 9104; $0.tileSize = 1.0; $0.normalStrength = 0.3; $0.roughness = 0.4
        },
        // Common facing brick, 215 x 65 mm, strong per-brick variation, lime mortar.
        MaterialSpec(key: "brick.common", program: .brick).with {
            $0.colorA = linear(0x93462F); $0.colorB = linear(0x5A2A1E); $0.colorC = linear(0xB4AC9C); $0.seed = 9107
            $0.tileSize = 0.46; $0.normalStrength = 3; $0.roughness = 0.88
        },
        // Painted lime stucco: cream, trowel texture.
        MaterialSpec(key: "paint.stucco", program: .paintedWall).with {
            $0.colorA = linear(0xE4DAC4); $0.knobs = V4(1, 0.8, 0.88, 0); $0.seed = 9105; $0.tileSize = 0.9; $0.normalStrength = 1.4; $0.roughness = 0.9
        },
    ]
}
