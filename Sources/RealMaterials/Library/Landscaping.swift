import RealCore

public extension MaterialLibrary {
    /// Landscaping hardscape: herringbone pavers, bark mulch, cast-concrete wall block and cap stone.
    static let landscaping: [MaterialSpec] = [
        // Clay-look concrete pavers, 10 x 20 cm, 90-degree herringbone, polymeric sand joints.
        MaterialSpec(key: "paver.herringbone", program: .paverHerringbone).with {
            $0.colorA = linear(0x9A5A42); $0.colorB = linear(0x7A4A3A); $0.colorC = linear(0xA89A80)
            $0.knobs = V4(8, 1, 0.6, 0.05); $0.seed = 7301; $0.tileSize = 0.8; $0.resolution = 2048; $0.normalStrength = 2.5; $0.roughness = 0.85
        },
        // Charcoal-blend concrete paver variant.
        MaterialSpec(key: "paver.charcoal", program: .paverHerringbone).with {
            $0.colorA = linear(0x6A6862); $0.colorB = linear(0x8C8880); $0.colorC = linear(0x9C9484)
            $0.knobs = V4(8, 1, 0.5, 0.05); $0.seed = 7302; $0.tileSize = 0.8; $0.resolution = 2048; $0.normalStrength = 2.5; $0.roughness = 0.86
        },
        // Shredded hardwood mulch, dyed brown, partly sun bleached.
        MaterialSpec(key: "mulch.bark", program: .barkMulch).with {
            $0.colorA = linear(0x5E3C24); $0.colorB = linear(0x140C06); $0.colorC = linear(0xA08468)
            $0.knobs = V4(12, 0.55, 0.9, 0.1); $0.seed = 7311; $0.tileSize = 0.5; $0.resolution = 2048; $0.normalStrength = 5; $0.roughness = 0.9
            $0.antiTile = true
        },
        // Red-dyed mulch.
        MaterialSpec(key: "mulch.red", program: .barkMulch).with {
            $0.colorA = linear(0x7A3020); $0.colorB = linear(0x24100A); $0.colorC = linear(0x9A6050)
            $0.knobs = V4(14, 0.3, 0.9, 0.05); $0.seed = 7312; $0.tileSize = 0.5; $0.resolution = 2048; $0.normalStrength = 3; $0.roughness = 0.9
            $0.antiTile = true
        },
        // Split-face concrete retaining wall block: tan aggregate face, rough.
        MaterialSpec(key: "stone.wall-block", program: .rockGranite).with {
            $0.colorA = linear(0x9C8E78); $0.colorB = linear(0x6E6456); $0.colorC = linear(0x5A5040)
            $0.knobs = V4(0.05, 0, 0, 0); $0.seed = 7321; $0.tileSize = 0.6; $0.normalStrength = 3; $0.roughness = 0.92
            $0.topColor = linear(0x5E6244); $0.topAmount = 0.3; $0.topLow = 0.75
            $0.triplanar = true
        },
        // Smooth cast cap stone / tumbled concrete (wall caps, fountain, fire pit).
        MaterialSpec(key: "stone.cap", program: .rockGranite).with {
            $0.colorA = linear(0xB0A48C); $0.colorB = linear(0x948872); $0.colorC = linear(0x7A6E5A)
            $0.knobs = V4(0.02, 0, 0.7, 0); $0.seed = 7331; $0.tileSize = 0.8; $0.normalStrength = 1.2; $0.roughness = 0.85
            $0.topColor = linear(0x8A8670); $0.topAmount = 0.25; $0.topLow = 0.8
            $0.triplanar = true
        },
        // Grey cast stone for fountains and fire pits, darker water/soot stains.
        MaterialSpec(key: "stone.cast-grey", program: .rockGranite).with {
            $0.colorA = linear(0x9A968C); $0.colorB = linear(0x7E7A72); $0.colorC = linear(0x6A665E)
            $0.knobs = V4(0.15, 0, 0.7, 0.4); $0.seed = 7332; $0.tileSize = 0.8; $0.normalStrength = 1.4; $0.roughness = 0.88
            $0.topColor = linear(0x3E4A26); $0.topAmount = 0.4; $0.topLow = 0.7
            $0.triplanar = true
        },
        // Single tumbled clay-tone concrete paver face (individual paver geometry; tint per paver).
        MaterialSpec(key: "paver.clay", program: .concrete).with {
            $0.colorA = linear(0x9A5A42); $0.colorB = linear(0x5E3A2C)
            $0.knobs = V4(0.86, 0.45, 0, 0); $0.seed = 7341; $0.tileSize = 0.4; $0.normalStrength = 2; $0.roughness = 0.86
        },
        // Stained, older clay paver (oil drip, tannin) mixed into the field.
        MaterialSpec(key: "paver.clay-stained", program: .concrete).with {
            $0.colorA = linear(0x7A4636); $0.colorB = linear(0x3A2620)
            $0.knobs = V4(0.86, 1.0, 0, 0); $0.seed = 7342; $0.tileSize = 0.4; $0.normalStrength = 2; $0.roughness = 0.86
        },
        // Exposed-aggregate precast concrete: grey cement matrix with river-pebble chips, matte.
        MaterialSpec(key: "concrete.exposed-aggregate", program: .terrazzo).with {
            $0.colorA = linear(0x948F86); $0.colorB = linear(0x8A7A66); $0.colorC = linear(0x5E5650, 0.4)
            $0.knobs = V4(45, 0.5, 0.88, 0.0); $0.seed = 7343; $0.tileSize = 0.6; $0.resolution = 2048; $0.normalStrength = 2.5; $0.roughness = 0.88
        },
        // Sun-silvered cedar on the exposed top members.
        MaterialSpec(key: "wood.cedar-weathered", program: .woodPlank).with {
            $0.colorA = linear(0xA09080); $0.colorB = linear(0x5E5248); $0.knobs = V4(0.85, 0.85, 0, 0); $0.seed = 7352
            $0.tileSize = 0.9; $0.normalStrength = 3
        },
        // Western red cedar lumber, weathering toward silver.
        MaterialSpec(key: "wood.cedar", program: .woodPlank).with {
            $0.colorA = linear(0xB07850); $0.colorB = linear(0x6A3E24); $0.knobs = V4(0.3, 0.75, 0, 0); $0.seed = 7351
            $0.topColor = linear(0x9A9286); $0.topAmount = 0.55; $0.topLow = 0.6
            $0.tileSize = 0.9; $0.normalStrength = 2.5
        },
        // Sod mat underside: dense loam bound with fine roots, no perlite.
        MaterialSpec(key: "soil.sod", program: .pottingSoil).with {
            $0.colorA = linear(0x3E2C1E); $0.colorB = linear(0x5A4632); $0.colorC = linear(0x8A7A5A)
            $0.knobs = V4(0, 0.35, 0.55, 120); $0.seed = 7371; $0.tileSize = 0.3; $0.normalStrength = 2.5; $0.roughness = 0.92
        },
        // Weathering (Corten) steel edging and fire rings: stable orange-brown patina.
        MaterialSpec(key: "metal.corten", program: .rustMetal).with {
            $0.colorA = linear(0x7A3A1A); $0.colorB = linear(0x3A1C0E); $0.knobs = V4(0.05, 0, 0, 0); $0.seed = 7361
            $0.tileSize = 0.5; $0.hasMetallicMap = true; $0.normalStrength = 2
        },
        // Planting: small-leaf shrub sprays (leafBroad, f.z twigs per card side), dense leaf mass for
        // shrub cores (moss program), petals (plantStem: veins along v) and floret masses.
        MaterialSpec(key: "leaf.boxwood", program: .leafBroad).with {
            $0.colorA = linear(0x1C3410); $0.colorB = linear(0x355A1C); $0.colorC = linear(0x7A9A32)
            $0.knobs = V4(0, 0.12, 4, 0.55); $0.seed = 7401; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 1.5
            $0.roughness = 0.58; $0.specular = 0.32; $0.wind = 0.02; $0.translucency = 0.35
        },
        MaterialSpec(key: "leaf.boxwood-mass", program: .moss).with {
            $0.colorA = linear(0x13240A); $0.colorB = linear(0x2C4A16); $0.colorC = linear(0x4A5A22)
            $0.knobs = V4(0.15, 40, 0, 0); $0.seed = 7402; $0.tileSize = 0.25; $0.normalStrength = 3; $0.resolution = 1024; $0.roughness = 0.6
        },
        MaterialSpec(key: "leaf.privet", program: .leafBroad).with {
            $0.colorA = linear(0x2A4614); $0.colorB = linear(0x48702A); $0.colorC = linear(0x8AA040)
            $0.knobs = V4(0, 0.1, 4, 0.5); $0.seed = 7403; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 1.5
            $0.roughness = 0.6; $0.specular = 0.32; $0.wind = 0.025; $0.translucency = 0.45
        },
        MaterialSpec(key: "leaf.privet-mass", program: .moss).with {
            $0.colorA = linear(0x1A2E0E); $0.colorB = linear(0x38581E); $0.colorC = linear(0x5A6028)
            $0.knobs = V4(0.15, 36, 0, 0); $0.seed = 7404; $0.tileSize = 0.3; $0.normalStrength = 3; $0.resolution = 1024; $0.roughness = 0.65
        },
        MaterialSpec(key: "leaf.arborvitae-mass", program: .moss).with {
            $0.colorA = linear(0x14240E); $0.colorB = linear(0x2A4418); $0.colorC = linear(0x4E4A22)
            $0.knobs = V4(0.2, 50, 0, 0); $0.seed = 7405; $0.tileSize = 0.3; $0.normalStrength = 3; $0.resolution = 1024; $0.roughness = 0.7
        },
        MaterialSpec(key: "leaf.hydrangea", program: .leafBroad).with {
            $0.colorA = linear(0x2C4C18); $0.colorB = linear(0x4A7026); $0.colorC = linear(0x8A8A30)
            $0.knobs = V4(0, 0.06, 2, 0.62); $0.seed = 7406; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 2
            $0.roughness = 0.62; $0.specular = 0.3; $0.wind = 0.04; $0.translucency = 0.4
        },
        MaterialSpec(key: "leaf.rose", program: .leafBroad).with {
            $0.colorA = linear(0x1E3612); $0.colorB = linear(0x3A5A1E); $0.colorC = linear(0x6A3A20)
            $0.knobs = V4(0, 0.1, 3, 0.55); $0.seed = 7407; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 2
            $0.roughness = 0.5; $0.specular = 0.38; $0.wind = 0.04; $0.translucency = 0.35
        },
        MaterialSpec(key: "leaf.azalea", program: .leafBroad).with {
            $0.colorA = linear(0x22380F); $0.colorB = linear(0x3E5C1C); $0.colorC = linear(0x6A6A26)
            $0.knobs = V4(0, 0.08, 3, 0.42); $0.seed = 7408; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 1.5
            $0.roughness = 0.6; $0.specular = 0.3; $0.wind = 0.03; $0.translucency = 0.35
        },
        // Hosta blade: glaucous blue-green wax bloom with fine parallel striation.
        MaterialSpec(key: "leaf.hosta", program: .leafAgave).with {
            $0.colorA = linear(0x3E5E3A); $0.colorB = linear(0x2A4426); $0.colorC = linear(0x6A8456)
            $0.knobs = V4(0.3, 0, 0, 0); $0.seed = 7409; $0.tileSize = 0.25; $0.normalStrength = 2.5; $0.roughness = 0.5
            $0.twoSided = true; $0.wind = 0.01; $0.translucency = 0.3
        },
        MaterialSpec(key: "flower.hydrangea", program: .moss).with {
            $0.colorA = linear(0x4A62B0); $0.colorB = linear(0x8C9ADA); $0.colorC = linear(0xB088C0)
            $0.knobs = V4(0.35, 9, 0, 0); $0.seed = 7410; $0.tileSize = 0.2; $0.normalStrength = 5; $0.resolution = 1024; $0.roughness = 0.6
            $0.wind = 0.02
        },
        MaterialSpec(key: "flower.lavender", program: .moss).with {
            $0.colorA = linear(0x4A3478); $0.colorB = linear(0x7A62B0); $0.colorC = linear(0x5A4A6A)
            $0.knobs = V4(0.2, 30, 0, 0); $0.seed = 7411; $0.tileSize = 0.04; $0.normalStrength = 3; $0.resolution = 512; $0.roughness = 0.7
            $0.wind = 0.05
        },
        MaterialSpec(key: "flower.rose", program: .plantStem).with {
            $0.colorA = linear(0x7E0812); $0.colorB = linear(0xA41822); $0.colorC = linear(0x44060E)
            $0.knobs = V4(0.05, 0, 0, 0); $0.seed = 7412; $0.tileSize = 0.04; $0.normalStrength = 0.8; $0.resolution = 256; $0.roughness = 0.72
            $0.twoSided = true; $0.translucency = 0.4; $0.wind = 0.04
        },
        MaterialSpec(key: "flower.azalea", program: .plantStem).with {
            $0.colorA = linear(0xC8306E); $0.colorB = linear(0xE04C88); $0.colorC = linear(0x8A1E4A)
            $0.knobs = V4(0.04, 0, 0, 0); $0.seed = 7413; $0.tileSize = 0.03; $0.normalStrength = 0.7; $0.resolution = 256; $0.roughness = 0.55
            $0.twoSided = true; $0.translucency = 0.45; $0.wind = 0.04
        },
        MaterialSpec(key: "flower.daylily", program: .plantStem).with {
            $0.colorA = linear(0xD8641A); $0.colorB = linear(0xEE8A2A); $0.colorC = linear(0x8A3010)
            $0.knobs = V4(0.04, 0, 0, 0); $0.seed = 7414; $0.tileSize = 0.04; $0.normalStrength = 0.8; $0.resolution = 256; $0.roughness = 0.5
            $0.twoSided = true; $0.translucency = 0.45; $0.wind = 0.05
        },
        // Unglazed terracotta planter clay, faint efflorescence.
        MaterialSpec(key: "ceramic.terracotta", program: .ceramicGlaze).with {
            $0.colorA = linear(0xB0623C); $0.colorB = linear(0x94502E); $0.colorC = linear(0xD8CCB8)
            $0.knobs = V4(0.5, 0.5, 0, 0.85); $0.seed = 7415; $0.tileSize = 0.3; $0.normalStrength = 1.2; $0.roughness = 0.85
        },
        // Lavender foliage: narrow silver grey-green blades (grassBlade strip atlas).
        MaterialSpec(key: "leaf.lavender", program: .grassBlade).with {
            $0.colorA = linear(0x66765E); $0.colorB = linear(0xA2B096); $0.colorC = linear(0xB4B49C)
            $0.knobs = V4(0.05, 0.5, 8, 0); $0.seed = 7416; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true
            $0.resolution = 512; $0.normalStrength = 1.2; $0.roughness = 0.75; $0.specular = 0.3
            $0.wind = 0.04; $0.translucency = 0.3
        },
        // Fountain grass bottlebrush plume: fuzzy buff-pink bristles.
        MaterialSpec(key: "grass.plume", program: .moss).with {
            $0.colorA = linear(0xA8987A); $0.colorB = linear(0xD8CCB0); $0.colorC = linear(0xB09088)
            $0.knobs = V4(0.4, 20, 0, 0); $0.seed = 7417; $0.tileSize = 0.04; $0.normalStrength = 3; $0.resolution = 512; $0.roughness = 0.85
            $0.wind = 0.06; $0.twoSided = true; $0.translucency = 0.5
        },
        MaterialSpec(key: "leaf.lavender-mass", program: .moss).with {
            $0.colorA = linear(0x1C241A); $0.colorB = linear(0x48563F); $0.colorC = linear(0x5A5A4A)
            $0.knobs = V4(0.15, 40, 0, 0); $0.seed = 7418; $0.tileSize = 0.2; $0.normalStrength = 3; $0.resolution = 512; $0.roughness = 0.8
        },
        // realityhd:material.landscaping
    ]
}
