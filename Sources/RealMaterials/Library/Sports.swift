import RealCore

public extension MaterialLibrary {
    /// Ballpark and sports-ground materials: striped turf, infield clay, warning track, chalk, chain link,
    /// wall padding, block masonry.
    static let sports: [MaterialSpec] = [
        // Kentucky bluegrass and rye cut at 25 mm, mowed in a checkerboard of 2.25 m mower passes (2 x 2 per tile).
        // UVs decide the band direction: rotate them to run the bands along the foul lines.
        MaterialSpec(key: "turf.ballpark", program: .turf).with {
            $0.colorA = linear(0x2E4F1A); $0.colorB = linear(0x6E9A36); $0.colorC = linear(0x7A6A44)
            $0.knobs = V4(0.2, 2, 1, 0.04); $0.seed = 301; $0.tileSize = 4.5; $0.resolution = 2048
            $0.normalStrength = 1.6; $0.roughness = 0.75
        },
        // Same sward in plain parallel stripes, for foul ground, bullpens and outfield edges.
        MaterialSpec(key: "turf.ballpark-stripe", program: .turf).with {
            $0.colorA = linear(0x2E4F1A); $0.colorB = linear(0x6E9A36); $0.colorC = linear(0x7A6A44)
            $0.knobs = V4(0.18, 2, 0, 0.06); $0.seed = 303; $0.tileSize = 4.5; $0.resolution = 2048
            $0.normalStrength = 1.6; $0.roughness = 0.75
        },
        // Unstriped worn community-field turf: thin patches, more thatch and clover.
        MaterialSpec(key: "turf.worn", program: .turf).with {
            $0.colorA = linear(0x34502A); $0.colorB = linear(0x7E9442); $0.colorC = linear(0x80694A)
            $0.knobs = V4(0, 1, 0, 0.4); $0.seed = 305; $0.tileSize = 2; $0.resolution = 2048
            $0.normalStrength = 1.8; $0.roughness = 0.7; $0.antiTile = true
        },
        // Infield skin: red clay-sand mix, nail-dragged, conditioner granules on top, a few cleat prints.
        MaterialSpec(key: "ground.infield", program: .infieldClay).with {
            $0.colorA = linear(0x7A4430); $0.colorB = linear(0xA8714E); $0.colorC = linear(0x6A2E22)
            $0.knobs = V4(0.6, 0.18, 0.25, 0.35); $0.seed = 311; $0.tileSize = 2; $0.resolution = 2048
            $0.normalStrength = 2.2; $0.antiTile = true
        },
        // Mound and batter's box clay: packed, darker, damp, heavily cleated.
        MaterialSpec(key: "ground.mound-clay", program: .infieldClay).with {
            $0.colorA = linear(0x5E3424); $0.colorB = linear(0x8A5A3E); $0.colorC = linear(0x4E2418)
            $0.knobs = V4(0.15, 0.6, 0.6, 0.2); $0.seed = 313; $0.tileSize = 1.5; $0.resolution = 2048
            $0.normalStrength = 2.4; $0.antiTile = true
        },
        // Warning track: crushed red brick and lava fines, 3 to 8 mm.
        MaterialSpec(key: "ground.warning-track", program: .gravel).with {
            $0.colorA = linear(0x7A4434); $0.colorB = linear(0x4E2E26); $0.colorC = linear(0x8A5A44)
            $0.knobs = V4(1.0, 0.45, 0.6, 0); $0.seed = 315; $0.tileSize = 0.8; $0.normalStrength = 2.4
            $0.resolution = 2048; $0.antiTile = true
        },
        // Field-marking paint and chalk lines: matte white, dusted with clay and scuffed.
        MaterialSpec(key: "paint.field-white", program: .plastic).with {
            $0.colorA = linear(0xE2E0D8); $0.knobs = V4(0.7, 0.55, 0.95, 0); $0.seed = 317; $0.tileSize = 0.6
            $0.resolution = 512; $0.normalStrength = 1.2; $0.roughness = 0.95
        },
        // Galvanized chain-link fabric, 2 in mesh, 9 gauge wire (cutout, two-sided).
        MaterialSpec(key: "fence.chainlink", program: .chainLink).with {
            $0.colorA = linear(0xB8BCC0); $0.colorB = linear(0x6E7276)
            $0.knobs = V4(0.85, 0.034, 0.42, 0.6); $0.seed = 321; $0.tileSize = 0.14; $0.resolution = 512
            $0.normalStrength = 2; $0.mode = .cutout; $0.twoSided = true; $0.hasMetallicMap = true
            $0.metallic = 0.85; $0.roughness = 0.42
        },
        // Black vinyl-coated chain link, the usual ballpark backstop and fence fabric.
        MaterialSpec(key: "fence.chainlink-vinyl", program: .chainLink).with {
            $0.colorA = linear(0x2A2B2C); $0.colorB = linear(0x0E0E0F)
            $0.knobs = V4(0, 0.04, 0.5, 0.3); $0.seed = 323; $0.tileSize = 0.14; $0.resolution = 512
            $0.normalStrength = 2; $0.mode = .cutout; $0.twoSided = true; $0.roughness = 0.5
        },
        // Distance veils for chain link: the wires vanish once alpha-tested mips go sub-pixel, so a faint
        // transparent sheet behind the mesh keeps the fabric reading as a dark haze, denser at grazing angles.
        MaterialSpec(key: "fence.chainlink-veil", program: nil).with {
            $0.baseColor = V3(0.03, 0.03, 0.035); $0.roughness = 0.9; $0.specular = 0.05; $0.mode = .transparent; $0.opacity = 0.22; $0.twoSided = true
        },
        MaterialSpec(key: "fence.chainlink-veil-light", program: nil).with {
            $0.baseColor = V3(0.45, 0.46, 0.47); $0.roughness = 0.8; $0.specular = 0.15; $0.mode = .transparent; $0.opacity = 0.14; $0.twoSided = true
        },
        MaterialSpec(key: "fence.chainlink-veil-yellow", program: nil).with {
            $0.baseColor = V3(0.75, 0.52, 0.05); $0.roughness = 0.6; $0.specular = 0.3; $0.mode = .transparent; $0.opacity = 0.3; $0.twoSided = true
        },
        // Outfield wall padding: pebbled vinyl cover over foam, dark green, sun-faded and scuffed.
        MaterialSpec(key: "padding.vinyl", program: .leather).with {
            $0.colorA = linear(0x1F4430); $0.colorB = linear(0x0E2418); $0.colorC = linear(0x3A6A4C)
            $0.knobs = V4(140, 0.4, 0.55, 0.05); $0.seed = 325; $0.tileSize = 0.5; $0.normalStrength = 1.2; $0.roughness = 0.55
        },
        // Painted concrete block (CMU), 400 x 200 mm units, struck joints. Tint for team colors.
        MaterialSpec(key: "masonry.cmu", program: .brick).with {
            $0.colorA = linear(0x9C9A94); $0.colorB = linear(0x8E8C86); $0.colorC = linear(0x7E7C76)
            $0.seed = 327; $0.tileSize = 0.8; $0.normalStrength = 1.6; $0.roughness = 0.85
        },
        // Same block painted ballpark green (outfield wall backs, dugout exteriors).
        MaterialSpec(key: "masonry.cmu-green", program: .brick).with {
            $0.colorA = linear(0x2A4A36); $0.colorB = linear(0x27452F); $0.colorC = linear(0x223D2A)
            $0.seed = 329; $0.tileSize = 0.8; $0.normalStrength = 1.4; $0.roughness = 0.8
        },
    ]
}
