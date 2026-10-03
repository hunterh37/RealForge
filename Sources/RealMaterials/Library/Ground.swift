import RealCore

public extension MaterialLibrary {
    private static let forestFloor = MaterialSpec(key: "ground.forest", program: .forestFloor).with {
        $0.colorA = linear(0x2E241B); $0.colorB = linear(0x5C4129); $0.colorC = linear(0x76603F)
        $0.knobs = V4(0.45, 0.7, 0, 0); $0.tileSize = 2.0; $0.normalStrength = 4; $0.resolution = 2048
        $0.antiTile = true
    }
    private static let meadow = MaterialSpec(key: "ground.meadow", program: .forestFloor).with {
        $0.colorA = linear(0x3B3020); $0.colorB = linear(0x6E5A30); $0.colorC = linear(0x7D6E3C)
        $0.knobs = V4(0.85, 0.25, 0, 0); $0.seed = 5; $0.tileSize = 2.0; $0.normalStrength = 3; $0.resolution = 2048
        $0.antiTile = true
    }

    /// Ground surfaces: forest floor, gravel, sand, mud, snow, cobbles, dirt. Large tiles, mostly anti-tiled.
    static let ground: [MaterialSpec] = [
        forestFloor,
        meadow,
        /// Autumn broadleaf litter: oak, beech and maple leaves, little moss.
        MaterialSpec(key: "ground.leaf-litter", program: .forestFloor).with {
            $0.colorA = linear(0x2A2018); $0.colorB = linear(0x62432A); $0.colorC = linear(0x8A6E44)
            $0.knobs = V4(0.1, 1.0, 0, 0); $0.seed = 13; $0.tileSize = 1.6; $0.normalStrength = 4; $0.resolution = 2048
            $0.antiTile = true
        },
        /// Pine and spruce needle duff with a few cones' worth of twigs and sparse moss.
        MaterialSpec(key: "ground.pine-needles", program: .forestFloor).with {
            $0.colorA = linear(0x2B1F16); $0.colorB = linear(0x7A5232); $0.colorC = linear(0xA87A48)
            $0.knobs = V4(0.25, 0.05, 1.0, 0); $0.seed = 17; $0.tileSize = 1.5; $0.normalStrength = 3.5; $0.resolution = 2048
            $0.antiTile = true
        },
        /// Crushed limestone driveway gravel, 15 to 40 mm, dusty fines between stones.
        MaterialSpec(key: "ground.gravel", program: .gravel).with {
            $0.colorA = linear(0x8A857D); $0.colorB = linear(0x6A665F); $0.colorC = linear(0x7A6F60)
            $0.knobs = V4(0.85, 1.0, 0.35, 0); $0.seed = 21; $0.tileSize = 1.0; $0.normalStrength = 3; $0.resolution = 2048
            $0.antiTile = true
        },
        /// Rounded beach pebbles, 3 to 8 cm, almost no fines.
        MaterialSpec(key: "ground.pebble-beach", program: .gravel).with {
            $0.colorA = linear(0x8E8982); $0.colorB = linear(0x5C5752); $0.colorC = linear(0x9C9078)
            $0.knobs = V4(0, 2.4, 0.05, 0); $0.seed = 23; $0.tileSize = 1.6; $0.normalStrength = 3; $0.resolution = 2048
            $0.antiTile = true
        },
        /// Raked granite gravel for a dry garden, 8 cm furrows.
        MaterialSpec(key: "ground.raked-gravel", program: .gravel).with {
            $0.colorA = linear(0xBDB7AC); $0.colorB = linear(0x9C968C); $0.colorC = linear(0xA8A092)
            $0.knobs = V4(0.6, 0.55, 0.15, 1.0); $0.seed = 25; $0.tileSize = 2.0; $0.normalStrength = 3; $0.resolution = 2048
        },
        /// Dry beach or desert sand with wind ripples about 7 cm apart and a few shell bits.
        MaterialSpec(key: "ground.sand", program: .sand).with {
            $0.colorA = linear(0xC9B18C); $0.colorB = linear(0x8E7B60); $0.colorC = linear(0xDCD2C2)
            $0.knobs = V4(1.0, 0, 0.12, 30); $0.seed = 31; $0.tileSize = 2.0; $0.normalStrength = 3; $0.resolution = 2048
            $0.antiTile = true
        },
        /// Wet mud: standing water in hollows, drier cracked crust on high spots, boot prints.
        MaterialSpec(key: "ground.mud", program: .mud).with {
            $0.colorA = linear(0x3D3026); $0.colorB = linear(0x6E5C48); $0.colorC = linear(0x9C8452)
            $0.knobs = V4(0.2, 0.55, 0.15, 0); $0.seed = 41; $0.tileSize = 4.0; $0.normalStrength = 3.5; $0.resolution = 2048
            $0.antiTile = true
        },
        /// Muddy water surface for puddles: flooded mud program, near-mirror roughness.
        MaterialSpec(key: "ground.puddle", program: .mud).with {
            $0.colorA = linear(0x3D3026); $0.colorB = linear(0x6E5C48); $0.colorC = linear(0x9C8452)
            $0.knobs = V4(1.0, 0, 0, 0); $0.seed = 43; $0.tileSize = 1.0; $0.normalStrength = 1.5; $0.resolution = 1024
            $0.specular = 0.5
        },
        /// Wind-packed snow with sastrugi ridges and glinting crystals.
        MaterialSpec(key: "ground.snow", program: .snow).with {
            $0.colorA = linear(0xDDE1E7); $0.colorB = linear(0xB9C4D2); $0.colorC = linear(0x7A7064)
            $0.knobs = V4(1.0, 0.7, 0.5, 0); $0.seed = 51; $0.tileSize = 3.0; $0.normalStrength = 3; $0.resolution = 2048
            $0.antiTile = true
        },
        /// Granite cobbles about 14 x 18 cm in running rows, worn tops, soil and moss joints.
        MaterialSpec(key: "ground.cobble", program: .cobblestone).with {
            $0.colorA = linear(0x7A7671); $0.colorB = linear(0x5B5855); $0.colorC = linear(0x4A3E30)
            $0.knobs = V4(0.5, 0.35, 0.65, 0.35); $0.seed = 61; $0.tileSize = 1.4; $0.normalStrength = 4; $0.resolution = 2048
        },
        /// Packed earth footpath with embedded stones, surface roots and dry cracks.
        MaterialSpec(key: "ground.dirt", program: .dirtPath).with {
            $0.colorA = linear(0x6A5440); $0.colorB = linear(0x917B60); $0.colorC = linear(0x3E3226)
            $0.knobs = V4(0.5, 0.5, 0.25, 0.2); $0.seed = 71; $0.tileSize = 2.0; $0.normalStrength = 3; $0.resolution = 2048
            $0.antiTile = true
        },
        /// Meadow with weathered granite blended in by `Surface.splat` (steep terrain faces).
        meadow.with {
            $0.key = "ground.meadow-rock"; $0.splat = "rock.granite-weathered"; $0.splatSoftness = 0.22; $0.splatHeight = 1.2
        },
        /// Meadow worn to packed earth where `Surface.splat` is high (footpaths, gateways).
        meadow.with {
            $0.key = "ground.meadow-worn"; $0.splat = "ground.dirt"; $0.splatSoftness = 0.25; $0.splatHeight = 1.5
        },
        /// Forest floor worn to packed earth where `Surface.splat` is high.
        forestFloor.with {
            $0.key = "ground.forest-worn"; $0.splat = "ground.dirt"; $0.splatSoftness = 0.25; $0.splatHeight = 1.5
        },
        // realityhd:material.ground
    ]
}
