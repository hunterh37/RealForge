import RealCore

public extension MaterialLibrary {
    /// Insects: chitin cuticle (glossy, matte, chestnut, metallic, soft green), setae, compound eyes,
    /// scaled butterfly and moth wings, beetle elytra and orthopteran tegmina (atlas maps over the
    /// normalized wing frame, tileSize 1), cutout venation over transparent membranes, the monarch
    /// caterpillar banding and the firefly lantern. Tile sizes are millimetres: these are life-size.
    static let insect: [MaterialSpec] = {
        func chitin(_ key: String, _ a: UInt32, _ b: UInt32, pits: Float, shift: Float, rough: Float, metal: Float = 0, coat: Float = 0.6, seed: UInt32) -> MaterialSpec {
            MaterialSpec(key: key, program: .chitin).with {
                $0.colorA = linear(a); $0.colorB = linear(b); $0.colorC = linear(0x0A0806)
                $0.knobs = V4(pits, shift, rough, metal); $0.seed = seed; $0.tileSize = 0.008; $0.resolution = 512
                $0.normalStrength = 0.8; $0.roughness = rough; $0.metallic = metal; $0.clearcoat = coat; $0.hasMetallicMap = metal > 0
                $0.baseColor = V3(linear(a).x, linear(a).y, linear(a).z)
            }
        }
        func wing(_ key: String, _ pattern: Float, _ outline: InsectWings.Shape, a: UInt32 = 0x808080, b: UInt32 = 0x404040, c: UInt32 = 0x202020,
                  aspect: Float = 1, rough: Float = 0.6, coat: Float = 0, metal: Bool = false, seed: UInt32) -> MaterialSpec {
            MaterialSpec(key: key, program: .insectWing).with {
                $0.colorA = linear(a); $0.colorB = linear(b); $0.colorC = linear(c)
                $0.knobs = V4(pattern, Float(outline.rawValue), aspect, 0); $0.seed = seed; $0.tileSize = 1; $0.resolution = 1024
                $0.normalStrength = 0.6; $0.twoSided = true; $0.roughness = rough; $0.clearcoat = coat; $0.hasMetallicMap = metal
                $0.baseColor = V3(linear(a).x, linear(a).y, linear(a).z)
            }
        }
        func veins(_ key: String, _ style: Float, _ outline: InsectWings.Shape, _ a: UInt32, _ b: UInt32 = 0x2A2018, seed: UInt32) -> MaterialSpec {
            MaterialSpec(key: key, program: .insectVeins).with {
                $0.colorA = linear(a); $0.colorB = linear(b); $0.knobs = V4(style, Float(outline.rawValue), 0, 0)
                $0.seed = seed; $0.tileSize = 0; $0.resolution = 1024; $0.mode = .cutout; $0.twoSided = true
                $0.normalStrength = 0.5; $0.roughness = 0.35; $0.baseColor = V3(linear(a).x, linear(a).y, linear(a).z)
            }
        }
        func membrane(_ key: String, _ color: V3, _ opacity: Float) -> MaterialSpec {
            MaterialSpec(key: key, program: nil).with {
                $0.baseColor = color; $0.roughness = 0.06; $0.specular = 0.6; $0.mode = .transparent; $0.opacity = opacity
                $0.twoSided = true; $0.clearcoat = 1
            }
        }
        return [
            chitin("insect.chitin", 0x1C1916, 0x2C2620, pits: 30, shift: 0.15, rough: 0.22, seed: 1101),
            chitin("insect.chitin-matte", 0x1E1C1A, 0x2A2622, pits: 40, shift: 0.1, rough: 0.62, coat: 0, seed: 1102),
            chitin("insect.chitin-chestnut", 0x5E2412, 0x2E120A, pits: 26, shift: 0.35, rough: 0.2, seed: 1103),
            chitin("insect.chitin-metallic", 0x2AA040, 0xC8A830, pits: 36, shift: 0.7, rough: 0.2, metal: 0.85, coat: 0.3, seed: 1104),
            chitin("insect.chitin-soft", 0x7FA845, 0x5E8A34, pits: 12, shift: 0.3, rough: 0.48, coat: 0.2, seed: 1105),
            MaterialSpec(key: "insect.fur", program: .insectFur).with {
                $0.colorA = linear(0xE8B830); $0.colorB = linear(0x4A3410); $0.knobs = V4(64, 0.35, 0.78, 0)
                $0.seed = 1110; $0.tileSize = 0.004; $0.resolution = 512; $0.normalStrength = 1.4; $0.roughness = 0.78
                $0.baseColor = V3(0.75, 0.5, 0.05)
            },
            MaterialSpec(key: "insect.eye", program: .compoundEye).with {
                $0.colorA = linear(0x3A2E26); $0.colorB = linear(0x0E0C0A); $0.knobs = V4(36, 0, 0.12, 0)
                $0.seed = 1111; $0.tileSize = 0.0025; $0.resolution = 512; $0.normalStrength = 1.2; $0.roughness = 0.12; $0.clearcoat = 1
                $0.baseColor = V3(0.04, 0.03, 0.025)
            },
            wing("insect.wing-monarch-fore", 0, .monarchFore, seed: 1120),
            wing("insect.wing-monarch-hind", 1, .monarchHind, seed: 1121),
            wing("insect.wing-swallowtail-fore", 2, .swallowtailFore, seed: 1122),
            wing("insect.wing-swallowtail-hind", 3, .swallowtailHind, seed: 1123),
            wing("insect.wing-morpho-fore", 4, .morphoFore, rough: 0.3, metal: true, seed: 1124),
            wing("insect.wing-morpho-hind", 5, .morphoHind, rough: 0.3, metal: true, seed: 1125),
            wing("insect.wing-luna-fore", 6, .lunaFore, rough: 0.75, seed: 1126),
            wing("insect.wing-luna-hind", 7, .lunaHind, rough: 0.75, seed: 1127),
            wing("insect.tegmen-katydid", 8, .katydidTegmen, a: 0x6FA548, b: 0xA8D27A, c: 0x7A5A2E, rough: 0.55, seed: 1128),
            wing("insect.tegmen-grasshopper", 9, .tegmen, a: 0x7E7A42, b: 0x5C4A2C, c: 0x2A2216, rough: 0.6, seed: 1129),
            wing("insect.tegmen-cricket", 13, .tegmen, a: 0x241C16, b: 0x5A4632, rough: 0.35, coat: 0.4, seed: 1130),
            wing("insect.elytra-ladybug", 10, .tegmen, aspect: 1.9, rough: 0.12, coat: 1, seed: 1131),
            wing("insect.elytra-firefly", 11, .tegmen, rough: 0.45, seed: 1132),
            wing("insect.elytra-jewel", 12, .tegmen, rough: 0.22, coat: 0.6, metal: true, seed: 1133),
            veins("insect.veins-dragonfly-fore", 0, .dragonflyFore, 0x2A2418, 0x3A2414, seed: 1140),
            veins("insect.veins-dragonfly-hind", 0, .dragonflyHind, 0x2A2418, 0x3A2414, seed: 1141),
            veins("insect.veins-damselfly", 1, .damselfly, 0x1A1A1C, 0x202024, seed: 1142),
            veins("insect.veins-bee-fore", 2, .beeFore, 0x4A3826, 0x6A4A26, seed: 1143),
            veins("insect.veins-bee-hind", 2, .beeHind, 0x4A3826, 0x6A4A26, seed: 1144),
            veins("insect.veins-cicada-fore", 3, .cicadaFore, 0x4A6A34, seed: 1145),
            veins("insect.veins-cicada-hind", 3, .cicadaHind, 0x4A6A34, seed: 1146),
            veins("insect.veins-beetle", 4, .membraneHind, 0x5A3A20, seed: 1147),
            veins("insect.veins-fan", 5, .membraneHind, 0x6A5A40, seed: 1148),
            membrane("insect.membrane", V3(0.8, 0.82, 0.82), 0.14),
            membrane("insect.membrane-amber", V3(0.75, 0.55, 0.25), 0.28),
            membrane("insect.membrane-smoky", V3(0.35, 0.3, 0.26), 0.4),
            MaterialSpec(key: "insect.lantern", program: nil).with {
                $0.baseColor = V3(1, 0.95, 0.7); $0.roughness = 0.4; $0.mode = .emissive
                $0.emissive = V3(1, 0.9, 0.46); $0.emissiveIntensity = 3
            },
            MaterialSpec(key: "insect.lantern-off", program: nil).with {
                $0.baseColor = V3(0.82, 0.78, 0.5); $0.roughness = 0.5
            },
            MaterialSpec(key: "insect.netting", program: .chainLink).with {
                $0.colorA = linear(0xE6E2D4); $0.colorB = linear(0xA8A290)
                $0.knobs = V4(0, 0.07, 0.6, 0); $0.seed = 1160; $0.tileSize = 0.012; $0.resolution = 512
                $0.normalStrength = 1; $0.mode = .cutout; $0.twoSided = true; $0.roughness = 0.75
            },
            wing("leaf.milkweed", 8, .katydidTegmen, a: 0x5E7E48, b: 0xC8C8A0, c: 0x8A7A4A, rough: 0.7, seed: 1171).with {
                $0.translucency = 0.45; $0.specular = 0.3; $0.wind = 0.03
            },
            MaterialSpec(key: "soil.ant-mound", program: .pottingSoil).with {
                $0.colorA = linear(0x4A3826); $0.colorB = linear(0x6A5034); $0.colorC = linear(0xA8946E)
                $0.knobs = V4(0.25, 0.2, 0.25, 220); $0.seed = 1170; $0.tileSize = 0.2; $0.normalStrength = 3; $0.roughness = 0.92
            },
            MaterialSpec(key: "insect.caterpillar", program: .caterpillarBands).with {
                $0.colorA = linear(0xE8C42A); $0.colorB = linear(0x161412); $0.colorC = linear(0xEEEBE0)
                $0.seed = 1150; $0.tileSize = 1; $0.resolution = 512; $0.normalStrength = 0.8; $0.roughness = 0.45; $0.clearcoat = 0.3
                $0.baseColor = V3(0.5, 0.45, 0.2)
            },
        ]
    }()
}
