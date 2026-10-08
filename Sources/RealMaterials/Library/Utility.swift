import RealCore

public extension MaterialLibrary {
    /// Overhead distribution line: treated pole wood, creosote, line porcelain, silicone polymer,
    /// cast bronze and aluminum fittings, ACSR strand, transformer tank gray, fiberglass fuse tube.
    static let utility: [MaterialSpec] = [
        // Southern yellow pine pole, pentachlorophenol treated, years in the sun: grey-brown, open checks.
        MaterialSpec(key: "wood.pole-pine", program: .woodPlank).with {
            $0.colorA = linear(0x8A735C); $0.colorB = linear(0x4A3A2C); $0.knobs = V4(0.8, 0.85, 0, 0); $0.seed = 9701
            $0.tileSize = 1.4; $0.normalStrength = 3.5; $0.roughness = 0.85
            $0.topColor = linear(0x9A9288); $0.topAmount = 0.35; $0.topLow = 0.55
        },
        // Creosote-soaked butt zone: near-black brown, slightly oily sheen, grain still legible.
        MaterialSpec(key: "wood.pole-creosote", program: .woodPlank).with {
            $0.colorA = linear(0x3E2E22); $0.colorB = linear(0x1E1610); $0.knobs = V4(0.5, 0.55, 0, 0); $0.seed = 9702
            $0.tileSize = 1.2; $0.normalStrength = 3; $0.roughness = 0.55
        },
        // Douglas fir crossarm, weathered silver-brown.
        MaterialSpec(key: "wood.crossarm-fir", program: .woodPlank).with {
            $0.colorA = linear(0xA08C74); $0.colorB = linear(0x5C4A38); $0.knobs = V4(0.85, 0.85, 0, 0); $0.seed = 9703
            $0.tileSize = 1.0; $0.normalStrength = 3
            $0.topColor = linear(0x8C8A84); $0.topAmount = 0.4; $0.topLow = 0.6
        },
        // ANSI 70 light gray wet-process porcelain glaze (pin insulators, cutout bodies, bushings).
        MaterialSpec(key: "ceramic.porcelain-gray", program: .ceramicGlaze).with {
            $0.colorA = linear(0xCDD4D8); $0.colorB = linear(0xBCC3C8); $0.colorC = linear(0x6E6A62)
            $0.knobs = V4(0.08, 0.25, 0.05, 0.06); $0.seed = 9711; $0.tileSize = 0.25; $0.normalStrength = 0.3
            $0.roughness = 0.06; $0.clearcoat = 0.9
            $0.topColor = linear(0xA8A296); $0.topAmount = 0.3; $0.topLow = 0.75
        },
        // Semiconducting (RIV-free) black top glaze on pin insulators.
        MaterialSpec(key: "ceramic.porcelain-black", program: .ceramicGlaze).with {
            $0.colorA = linear(0x1C1C1E); $0.colorB = linear(0x2A2A2C); $0.colorC = linear(0x4A4640)
            $0.knobs = V4(0.04, 0.2, 0.05, 0.05); $0.seed = 9712; $0.tileSize = 0.2; $0.normalStrength = 0.3
            $0.roughness = 0.05; $0.clearcoat = 1
            $0.topColor = linear(0x5A564E); $0.topAmount = 0.3; $0.topLow = 0.8
        },
        // Unglazed porcelain body exposed at a fracture: dull off-white, granular.
        MaterialSpec(key: "ceramic.porcelain-fracture", program: .ceramicGlaze).with {
            $0.colorA = linear(0xD8D4CA); $0.colorB = linear(0xC4BEB2); $0.colorC = linear(0x8A8478)
            $0.knobs = V4(0.6, 0, 0, 0.8); $0.seed = 9713; $0.tileSize = 0.05; $0.normalStrength = 1.5; $0.roughness = 0.8
        },
        // Gray silicone rubber housing (deadends, arresters): matte, hydrophobic, light dust.
        MaterialSpec(key: "rubber.silicone-gray", program: .plastic).with {
            $0.colorA = linear(0x6A6F74); $0.knobs = V4(0.15, 0.25, 0.55, 0); $0.seed = 9721; $0.tileSize = 0.15
            $0.resolution = 512; $0.normalStrength = 0.6; $0.roughness = 0.55
            $0.topColor = linear(0x8E8A80); $0.topAmount = 0.35; $0.topLow = 0.7
        },
        // Cast tin bronze (hot-line clamps, cutout contacts): warm, dulled, brown tarnish in recesses.
        MaterialSpec(key: "metal.bronze-cast", program: .polishedMetal).with {
            $0.colorA = linear(0xC6AE88); $0.colorB = linear(0x6A5434); $0.colorC = linear(0x4E7A62)
            $0.knobs = V4(0.45, 0.08, 0, 0.55); $0.seed = 9731; $0.tileSize = 0.08; $0.normalStrength = 1.0
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.45
        },
        // Cast or extruded aluminum fitting, oxidized dull (splices, clamp bodies, connectors).
        MaterialSpec(key: "metal.aluminum-cast", program: .brushedMetal).with {
            $0.colorA = linear(0xA4A7A8); $0.colorB = linear(0x6E6C66)
            $0.knobs = V4(0.25, 0.75, 0.6, 0.45); $0.seed = 9732; $0.tileSize = 0.12; $0.normalStrength = 0.8
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.62
        },
        // ACSR outer aluminum strands: bright drawn wire, lay streaks along U.
        MaterialSpec(key: "metal.acsr-strand", program: .brushedMetal).with {
            $0.colorA = linear(0xC6C9CA); $0.colorB = linear(0x8A8A84)
            $0.knobs = V4(1, 0.35, 0.3, 0.2); $0.seed = 9733; $0.tileSize = 0.05; $0.normalStrength = 0.5
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.32
        },
        // Pole-mount transformer tank, ANSI 70 gray enamel, rain streaks and light rust at seams.
        MaterialSpec(key: "metal.transformer-gray", program: .paintedMetal).with {
            $0.colorA = linear(0x9AA0A3); $0.colorC = linear(0x6A4A30, 0.0); $0.knobs = V4(0.06, 0.55, 0.45, 0)
            $0.seed = 9741; $0.tileSize = 0.6; $0.hasMetallicMap = true; $0.normalStrength = 1.0; $0.resolution = 1024
        },
        // Fiberglass-wound expulsion fuse tube, glossy gray-tan.
        MaterialSpec(key: "plastic.fuse-tube", program: .plastic).with {
            $0.colorA = linear(0xB2B4AE); $0.knobs = V4(0.25, 0.2, 0.25, 0); $0.seed = 9751; $0.tileSize = 0.2
            $0.resolution = 512; $0.normalStrength = 0.5; $0.clearcoat = 0.4
        },
        // Tinned copper stranded leader on fuse links and ground leads.
        MaterialSpec(key: "metal.tinned-copper", program: .brushedMetal).with {
            $0.colorA = linear(0xB2AEA6); $0.colorB = linear(0x6E6458)
            $0.knobs = V4(1, 0.4, 0.3, 0.2); $0.seed = 9752; $0.tileSize = 0.03; $0.normalStrength = 0.5
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.4
        },
        // realityhd:material.utility
    ]
}
