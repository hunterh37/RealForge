import RealCore

public extension MaterialLibrary {
    /// Grass, wildflowers, ferns, moss, fungi and leaf litter. Blade (`grassBlade`) and card (`grassCard`)
    /// variants of one grass share colors so LODs match. Wind values match within a plant so parts sway together.
    static let plants: [MaterialSpec] = [
        // Geometric blades: strip atlas of 8 blade variants (u across, v root to tip).
        MaterialSpec(key: "grass.lawn", program: .grassBlade).with {
            $0.colorA = linear(0x2A4A14); $0.colorB = linear(0x5E8C28); $0.colorC = linear(0xA89660)
            $0.knobs = V4(0.04, 0.2, 8, 1); $0.seed = 21; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true
            $0.resolution = 512; $0.normalStrength = 1.5; $0.roughness = 0.5; $0.specular = 0.45
            $0.wind = 0.025; $0.translucency = 0.5
        },
        MaterialSpec(key: "grass.tall", program: .grassBlade).with {
            $0.colorA = linear(0x30501A); $0.colorB = linear(0x6E9034); $0.colorC = linear(0xB5A26C)
            $0.knobs = V4(0.1, 0.5, 8, 0); $0.seed = 22; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true
            $0.resolution = 512; $0.normalStrength = 1.5; $0.roughness = 0.5; $0.specular = 0.45
            $0.wind = 0.07; $0.translucency = 0.5
        },
        MaterialSpec(key: "grass.dry", program: .grassBlade).with {
            $0.colorA = linear(0x5E6430); $0.colorB = linear(0x9C9450); $0.colorC = linear(0xB8A070)
            $0.knobs = V4(0.6, 0.9, 8, 0); $0.seed = 23; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true
            $0.resolution = 512; $0.normalStrength = 1.5; $0.roughness = 0.65; $0.specular = 0.4
            $0.wind = 0.06; $0.translucency = 0.35
        },
        MaterialSpec(key: "grass.reed", program: .grassBlade).with {
            $0.colorA = linear(0x3A5428); $0.colorB = linear(0x74904A); $0.colorC = linear(0xA8925E)
            $0.knobs = V4(0.12, 0.45, 8, 0); $0.seed = 24; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true
            $0.resolution = 512; $0.normalStrength = 1.5; $0.roughness = 0.4; $0.specular = 0.5
            $0.wind = 0.08; $0.translucency = 0.4
        },
        // Distance cards (2x2 atlas: clump, clump with seed stalks, single panicle, top-down thatch).
        MaterialSpec(key: "grass.lawn-card", program: .grassCard).with {
            $0.colorA = linear(0x2A4A14); $0.colorB = linear(0x5E8C28); $0.colorC = linear(0xA89660)
            $0.knobs = V4(0.04, 0.2, 0, 0); $0.seed = 21; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true
            $0.resolution = 1024; $0.normalStrength = 1.5; $0.roughness = 0.55
            $0.wind = 0.025; $0.translucency = 0.45
        },
        MaterialSpec(key: "grass.tall-card", program: .grassCard).with {
            $0.colorA = linear(0x30501A); $0.colorB = linear(0x6E9034); $0.colorC = linear(0xB5A26C)
            $0.knobs = V4(0.1, 0.5, 0, 0); $0.seed = 22; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true
            $0.resolution = 1024; $0.normalStrength = 1.5; $0.roughness = 0.55
            $0.wind = 0.07; $0.translucency = 0.45
        },
        MaterialSpec(key: "grass.dry-card", program: .grassCard).with {
            $0.colorA = linear(0x5E6430); $0.colorB = linear(0x9C9450); $0.colorC = linear(0xB8A070)
            $0.knobs = V4(0.6, 0.9, 0, 0); $0.seed = 23; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true
            $0.resolution = 1024; $0.normalStrength = 1.5; $0.roughness = 0.65
            $0.wind = 0.06; $0.translucency = 0.3
        },
        // Opaque top-down mown thatch for the floor of lawn tiles.
        MaterialSpec(key: "grass.lawn-thatch", program: .grassCard).with {
            $0.colorA = linear(0x2A4A14); $0.colorB = linear(0x5E8C28); $0.colorC = linear(0xA89660)
            $0.knobs = V4(0.04, 0.2, 1, 0); $0.seed = 21; $0.tileSize = 0.5
            $0.resolution = 1024; $0.normalStrength = 2; $0.roughness = 0.7; $0.antiTile = true
        },
        MaterialSpec(key: "grass.seedhead", program: .grassCard).with {
            $0.colorA = linear(0x8E9058); $0.colorB = linear(0xC0AA78); $0.colorC = linear(0x6E4A5E)
            $0.knobs = V4(0, 0, 0, 0); $0.seed = 25; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true
            $0.resolution = 512; $0.normalStrength = 1.5; $0.roughness = 0.65
            $0.wind = 0.05; $0.translucency = 0.35
        },
        // Wildflower heads and small leaves, 4x4 atlas (see `flowers` in PlantShaders.swift).
        MaterialSpec(key: "flower.meadow", program: .flowers).with {
            $0.colorA = linear(0x2C4A18); $0.colorB = linear(0x5A7C2C)
            $0.knobs = V4(0, 0, 4, 0); $0.seed = 26; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true
            $0.resolution = 1024; $0.normalStrength = 1.5; $0.roughness = 0.5
            $0.wind = 0.05; $0.translucency = 0.4
        },
        MaterialSpec(key: "fern.lady", program: .fernFrond).with {
            $0.colorA = linear(0x2F5218); $0.colorB = linear(0x6C9A30); $0.colorC = linear(0x8A6A36)
            $0.knobs = V4(0.08, 0, 4, 0); $0.seed = 27; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true
            $0.resolution = 1024; $0.normalStrength = 2; $0.roughness = 0.55
            $0.wind = 0.05; $0.translucency = 0.55
        },
        MaterialSpec(key: "fern.bracken", program: .fernFrond).with {
            $0.colorA = linear(0x34521A); $0.colorB = linear(0x66882A); $0.colorC = linear(0x9A6430)
            $0.knobs = V4(0.18, 1, 4, 0); $0.seed = 28; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true
            $0.resolution = 1024; $0.normalStrength = 2; $0.roughness = 0.6
            $0.wind = 0.05; $0.translucency = 0.5
        },
        MaterialSpec(key: "litter.dry", program: .leafLitter).with {
            $0.colorA = linear(0x3E2A1A); $0.colorB = linear(0x947650); $0.colorC = linear(0x8E5A2C)
            $0.knobs = V4(0, 0, 4, 0); $0.seed = 29; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true
            $0.resolution = 1024; $0.normalStrength = 2.5; $0.roughness = 0.75
        },
        MaterialSpec(key: "moss.cushion", program: .moss).with {
            $0.colorA = linear(0x1A280B); $0.colorB = linear(0x48601E); $0.colorC = linear(0x5C5030)
            $0.knobs = V4(0.3, 90, 0, 0); $0.seed = 30; $0.tileSize = 0.15; $0.normalStrength = 4
            $0.resolution = 1024; $0.roughness = 0.85
        },
        MaterialSpec(key: "plant.cattail", program: .moss).with {
            $0.colorA = linear(0x3A2414); $0.colorB = linear(0x5E3C22); $0.colorC = linear(0x6A5038)
            $0.knobs = V4(0.2, 120, 0, 0); $0.seed = 31; $0.tileSize = 0.05; $0.normalStrength = 3
            $0.resolution = 512; $0.roughness = 0.9; $0.wind = 0.05
        },
        MaterialSpec(key: "fungus.cap", program: .fungus).with {
            $0.colorA = linear(0x5E3A1E); $0.colorB = linear(0x9A6838); $0.colorC = linear(0xE2D8C6)
            $0.knobs = V4(0, 0.08, 0.42, 0); $0.seed = 32; $0.tileSize = 0.06; $0.normalStrength = 1.5
            $0.resolution = 512; $0.roughness = 0.45; $0.specular = 0.55
        },
        MaterialSpec(key: "fungus.gills", program: .fungus).with {
            $0.colorA = linear(0xC4AE92); $0.knobs = V4(1, 0, 0.7, 0); $0.seed = 33; $0.tileSize = 0.04
            $0.normalStrength = 2.5; $0.resolution = 512; $0.roughness = 0.7
        },
        MaterialSpec(key: "fungus.stalk", program: .fungus).with {
            $0.colorA = linear(0xD6CBB4); $0.colorB = linear(0xA8946E); $0.knobs = V4(2, 0, 0.55, 0); $0.seed = 34
            $0.tileSize = 0.05; $0.normalStrength = 1.5; $0.resolution = 512; $0.roughness = 0.6
        },
        MaterialSpec(key: "plant.stem", program: .plantStem).with {
            $0.colorA = linear(0x3E5E20); $0.colorB = linear(0x76963E); $0.colorC = linear(0x8A7A4A)
            $0.knobs = V4(0.1, 0, 0, 0); $0.seed = 35; $0.tileSize = 0.02; $0.normalStrength = 1
            $0.resolution = 256; $0.roughness = 0.5; $0.wind = 0.05
        },
        // Tintable petal: key suffix sets the body color ("flower.petal:E8334A"); pale throat, veins along v.
        MaterialSpec(key: "flower.petal", program: .petal).with {
            $0.colorA = linear(0xE8E4D8); $0.colorB = linear(0xD6D590); $0.colorC = linear(0xFFFFFF)
            $0.knobs = V4(0.005, 0, 0, 0); $0.seed = 7501; $0.tileSize = 0.12; $0.normalStrength = 0.7
            $0.resolution = 256; $0.roughness = 0.5; $0.twoSided = true; $0.translucency = 0.5; $0.wind = 0.05
        },
        // Tintable two-sided broad leaf ("leaf.plain:2E6A35"): veins along v, light transmission.
        MaterialSpec(key: "leaf.plain", program: .plantStem).with {
            $0.colorA = linear(0x3E6A2A); $0.colorB = linear(0x5E8A3A); $0.colorC = linear(0x8A7A4A)
            $0.knobs = V4(0.04, 0, 0, 0); $0.seed = 7502; $0.tileSize = 0.06; $0.normalStrength = 1
            $0.resolution = 256; $0.roughness = 0.45; $0.twoSided = true; $0.translucency = 0.35; $0.wind = 0.04
        },
        // realityhd:material.plants
    ]
}
