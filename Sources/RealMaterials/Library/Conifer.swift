import RealCore

public extension MaterialLibrary {
    /// Conifers, palms, cacti and agave, plus snow-covered variants of the spruce materials.
    static let conifer: [MaterialSpec] = [
        // Scots pine: grey-brown plated lower trunk, thin orange flaking bark above.
        MaterialSpec(key: "bark.scots-pine", program: .barkScotsPine).with {
            $0.colorA = linear(0x5E5047); $0.colorB = linear(0x3A1E14); $0.colorC = linear(0x857A70)
            $0.knobs = V4(0, 0, 0, 0); $0.seed = 11; $0.tileSize = 0.5; $0.normalStrength = 6; $0.roughness = 0.9
            $0.wind = 0.02
        },
        MaterialSpec(key: "bark.scots-pine-upper", program: .barkScotsPine).with {
            $0.colorA = linear(0xB0623A); $0.colorB = linear(0x4A2414); $0.colorC = linear(0xD49468)
            $0.knobs = V4(1, 0, 0, 0); $0.seed = 12; $0.tileSize = 0.3; $0.normalStrength = 3; $0.roughness = 0.78
            $0.wind = 0.02
        },
        // Balsam fir: smooth grey bark with resin blisters and lenticels.
        MaterialSpec(key: "bark.fir", program: .barkBirch).with {
            $0.colorA = linear(0x6E6A64); $0.colorB = linear(0x2A2622); $0.colorC = linear(0x5A4C42)
            $0.seed = 13; $0.tileSize = 0.4; $0.normalStrength = 3; $0.roughness = 0.75
            $0.wind = 0.02
        },
        // Cypress: fibrous grey-brown bark in long vertical strips.
        MaterialSpec(key: "bark.cypress", program: .barkPalm).with {
            $0.colorA = linear(0x6A5848); $0.colorB = linear(0x2E2219); $0.colorC = linear(0x8A8076)
            $0.knobs = V4(0, 6, 0, 0); $0.seed = 14; $0.tileSize = 0.35; $0.normalStrength = 5; $0.roughness = 0.9
            $0.wind = 0.02
        },
        // Coconut palm trunk: grey with leaf-scar rings about 8 cm apart.
        MaterialSpec(key: "bark.palm", program: .barkPalm).with {
            $0.colorA = linear(0x8A8072); $0.colorB = linear(0x3E352C); $0.colorC = linear(0xA8A196)
            $0.knobs = V4(1, 6, 0, 0); $0.seed = 15; $0.tileSize = 0.5; $0.normalStrength = 5; $0.roughness = 0.88
            $0.wind = 0.03
        },
        // Frond petiole and rachis base: green-yellow fibrous stem.
        MaterialSpec(key: "leaf.palm-stem", program: .barkPalm).with {
            $0.colorA = linear(0x7A7A38); $0.colorB = linear(0x3E3A1C); $0.colorC = linear(0x9C8E52)
            $0.knobs = V4(0, 6, 0, 0); $0.seed = 16; $0.tileSize = 0.4; $0.normalStrength = 2; $0.roughness = 0.6
            $0.wind = 0.12
        },
        // Coconut husk.
        MaterialSpec(key: "fruit.coconut", program: .barkPalm).with {
            $0.colorA = linear(0x6E7A2C); $0.colorB = linear(0x3E4418); $0.colorC = linear(0x8C7A34)
            $0.knobs = V4(0, 6, 0, 0); $0.seed = 17; $0.tileSize = 0.25; $0.normalStrength = 1.5; $0.roughness = 0.55
            $0.resolution = 512; $0.wind = 0.03
        },
        MaterialSpec(key: "leaf.pine", program: .leafPine).with {
            $0.colorA = linear(0x263A2C); $0.colorB = linear(0x3C5440); $0.colorC = linear(0x7E968A)
            $0.knobs = V4(0, 30, 2, 0); $0.seed = 21; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true
            $0.normalStrength = 2; $0.roughness = 0.5
            $0.wind = 0.04; $0.translucency = 0.25
        },
        MaterialSpec(key: "leaf.fir", program: .leafFir).with {
            $0.colorA = linear(0x18301C); $0.colorB = linear(0x234026); $0.colorC = linear(0x5E8838)
            $0.knobs = V4(0, 0.7, 2, 0); $0.seed = 22; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true
            $0.normalStrength = 2.5; $0.roughness = 0.45
            $0.wind = 0.03; $0.translucency = 0.25
        },
        MaterialSpec(key: "leaf.cypress", program: .leafCypress).with {
            $0.colorA = linear(0x1E2E1A); $0.colorB = linear(0x2E4024); $0.colorC = linear(0x5A6E30)
            $0.knobs = V4(0.6, 0, 2, 0); $0.seed = 23; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true
            $0.normalStrength = 3; $0.roughness = 0.6
            $0.wind = 0.025; $0.translucency = 0.2
        },
        // Coconut frond atlas: two fronds side by side, width 0.36 x length.
        MaterialSpec(key: "leaf.palm", program: .leafPalm).with {
            $0.colorA = linear(0x4A6A22); $0.colorB = linear(0x6E8A2E); $0.colorC = linear(0x8E7A44)
            $0.knobs = V4(0, 0.1, 2, 0.36); $0.seed = 24; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true
            $0.resolution = 2048; $0.normalStrength = 2; $0.roughness = 0.45; $0.specular = 0.5
            $0.wind = 0.14; $0.translucency = 0.5
        },
        // Saguaro: muted sage green, grey spines, felted areoles on rib crests.
        MaterialSpec(key: "cactus.saguaro", program: .cactusRibs).with {
            $0.colorA = linear(0x61704E); $0.colorB = linear(0x435238); $0.colorC = linear(0x8E887C)
            $0.knobs = V4(1, 10, 0.8, 0.36); $0.seed = 31; $0.tileSize = 0.25; $0.normalStrength = 3; $0.roughness = 0.6
        },
        // Barrel cactus: brighter green, long red-amber spines.
        MaterialSpec(key: "cactus.barrel", program: .cactusRibs).with {
            $0.colorA = linear(0x4E6E36); $0.colorB = linear(0x34502A); $0.colorC = linear(0xB06A3C)
            $0.knobs = V4(1.3, 8, 1, 0.3); $0.seed = 32; $0.tileSize = 0.2; $0.normalStrength = 3; $0.roughness = 0.55
        },
        // Old saguaro base: grey-brown corky skin over the ribs.
        MaterialSpec(key: "cactus.saguaro-cork", program: .barkPalm).with {
            $0.colorA = linear(0x6E655A); $0.colorB = linear(0x3A3028); $0.colorC = linear(0x8C8478)
            $0.knobs = V4(0, 6, 0, 0); $0.seed = 34; $0.tileSize = 0.25; $0.normalStrength = 4; $0.roughness = 0.92
        },
        // Barrel cactus fruit: yellow, waxy.
        MaterialSpec(key: "fruit.cactus", program: nil).with {
            $0.baseColor = V3(0.55, 0.42, 0.08); $0.roughness = 0.45
        },
        MaterialSpec(key: "cactus.spine", program: nil).with {
            $0.baseColor = V3(0.42, 0.2, 0.09); $0.roughness = 0.45
        },
        // Agave americana: blue-grey wax bloom with bud imprints.
        MaterialSpec(key: "leaf.agave", program: .leafAgave).with {
            $0.colorA = linear(0x6A847C); $0.colorB = linear(0x4A5E56); $0.colorC = linear(0x849C92)
            $0.knobs = V4(0.6, 4, 0, 0); $0.seed = 33; $0.tileSize = 0.6; $0.normalStrength = 2; $0.roughness = 0.55
            $0.wind = 0.005
        },
        MaterialSpec(key: "leaf.agave-spine", program: nil).with {
            $0.baseColor = V3(0.09, 0.05, 0.03); $0.roughness = 0.4
        },
        // Snow-loaded spruce: snow on up-facing bark and needle sprays.
        MaterialSpec(key: "bark.pine-snow", program: .barkPine).with {
            $0.colorA = linear(0x6B3F28); $0.colorB = linear(0x1B120D); $0.colorC = linear(0x7A706A)
            $0.tileSize = 0.45; $0.normalStrength = 5; $0.roughness = 0.9
            $0.wind = 0.015
            $0.topColor = linear(0xF2F4F8); $0.topAmount = 1; $0.topLow = 0.35
        },
        MaterialSpec(key: "leaf.spruce-snow", program: .leafNeedle).with {
            $0.colorA = linear(0x1A3020); $0.colorB = linear(0x284224); $0.colorC = linear(0x3E5A30)
            $0.knobs = V4(0.2, 0, 2, 0); $0.seed = 25; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 2.5
            $0.roughness = 0.6
            $0.wind = 0.015; $0.translucency = 0.15
            $0.topColor = linear(0xF2F4F8); $0.topAmount = 1; $0.topLow = 0.4
        },
        // realforge:material.conifer
    ]
}
