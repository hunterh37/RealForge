import RealCore

public extension MaterialLibrary {
    /// Raw cooking ingredients and their cooked counterparts (`cooked` links raw -> cooked; the cook
    /// shader blends by doneness and adds browning on top). Skins use u around and v along the item;
    /// cut-face (`radialFlesh`) keys are centered at uv 0.5 with `tileSize` = the tissue diameter so
    /// rings, locules and segments center on the cut.
    static let food: [MaterialSpec] = {
        func spec(_ key: String, _ program: TextureProgram, _ a: UInt32, _ b: UInt32, _ c: UInt32, ca: Float = 1,
                  knobs: V4, tile: Float, rough: Float, seed: UInt32, normal: Float = 1, clearcoat: Float = 0,
                  res: Int = 1024, cooked: String? = nil) -> MaterialSpec {
            MaterialSpec(key: key, program: program).with {
                $0.colorA = linear(a); $0.colorB = linear(b); $0.colorC = linear(c, ca)
                $0.knobs = knobs; $0.tileSize = tile; $0.roughness = rough; $0.seed = seed
                $0.normalStrength = normal; $0.clearcoat = clearcoat; $0.resolution = res
                $0.baseColor = V3($0.colorA.x, $0.colorA.y, $0.colorA.z)
                $0.cooked = cooked.map { MaterialKey($0) }
            }
        }
        var out: [MaterialSpec] = []
        // Chicken breast: raw surface (wet pink, fat striations, silverskin) and cut face (end grain).
        out.append(spec("food.chicken-raw", .poultryFlesh, 0xEDB3A6, 0xD98F86, 0xF4E8E2, ca: 0.7,
                        knobs: V4(44, 0.85, 0.34, 0.22), tile: 0.06, rough: 0.34, seed: 1101, normal: 0.7, clearcoat: 0.7, cooked: "food.chicken-cooked"))
        out.append(spec("food.chicken-cooked", .foodCrumb, 0xEADCC6, 0xC2965C, 0xFFFFFF, ca: 0.3,
                        knobs: V4(44, 0.35, 0.62, 0), tile: 0.06, rough: 0.62, seed: 1102, normal: 1.4))
        out.append(spec("food.chicken-flesh", .foodSmooth, 0xEFB1A3, 0xE0978B, 0xF5E4DE,
                        knobs: V4(36, 0.7, 0.3, 5), tile: 0.04, rough: 0.3, seed: 1103, normal: 0.9, clearcoat: 0.6, cooked: "food.chicken-flesh-cooked"))
        out.append(spec("food.chicken-flesh-cooked", .foodCrumb, 0xF0E6D6, 0xD7C2A0, 0xFFFFFF, ca: 0.6,
                        knobs: V4(36, 0, 0.68, 1), tile: 0.04, rough: 0.68, seed: 1104, normal: 1.0))
        // Yellow onion: papery skin, white fleshy scale, cut rings.
        out.append(spec("food.onion-skin", .papery, 0xBE7A3A, 0x8A4A20, 0xE0BC88, ca: 0.45,
                        knobs: V4(180, 0.5, 0.55, 0), tile: 0.08, rough: 0.55, seed: 1201, normal: 1.4))
        out.append(spec("food.onion", .foodSmooth, 0xEDE6C6, 0xDAD3A2, 0xF7F4E4,
                        knobs: V4(70, 0.5, 0.3, 0), tile: 0.06, rough: 0.3, seed: 1202, normal: 0.6, clearcoat: 0.4, cooked: "food.onion-cooked"))
        out.append(spec("food.onion-cooked", .foodCrumb, 0xD6A15A, 0xA0642A, 0xF2D49A, ca: 0.4,
                        knobs: V4(40, 0.5, 0.35, 2), tile: 0.06, rough: 0.35, seed: 1203, normal: 0.6, clearcoat: 0.3))
        out.append(spec("food.onion-rings", .radialFlesh, 0xF1EDD6, 0xD9E0A8, 0xFFFFF2, ca: 0.55,
                        knobs: V4(9, 0.7, 0.24, 0), tile: 0.08, rough: 0.24, seed: 1204, normal: 0.8, clearcoat: 0.5, cooked: "food.onion-rings-cooked"))
        out.append(spec("food.onion-rings-cooked", .radialFlesh, 0xD9A65E, 0xC48A3E, 0xEEC888, ca: 0.5,
                        knobs: V4(9, 0.5, 0.3, 0), tile: 0.08, rough: 0.3, seed: 1204, normal: 0.6, clearcoat: 0.3))
        // Carrot: skin, cortex (phloem) cut face, core (xylem) cut face.
        out.append(spec("food.carrot", .rootSkin, 0xE2680F, 0x8E3606, 0xF4A45E, ca: 0.8,
                        knobs: V4(14, 0.12, 0.5, 0), tile: 0.05, rough: 0.5, seed: 1301, normal: 1.6, cooked: "food.carrot-cooked"))
        out.append(spec("food.carrot-cooked", .rootSkin, 0xD5560A, 0x7A2C04, 0xE88A3A, ca: 0.5,
                        knobs: V4(14, 0.05, 0.32, 0), tile: 0.05, rough: 0.32, seed: 1301, normal: 1.2, clearcoat: 0.3))
        out.append(spec("food.carrot-cortex", .radialFlesh, 0xF27A16, 0xD9600C, 0xE8701A,
                        knobs: V4(48, 0.6, 0.32, 2), tile: 0.032, rough: 0.32, seed: 1302, normal: 0.6, clearcoat: 0.4, cooked: "food.carrot-cortex-cooked"))
        out.append(spec("food.carrot-cortex-cooked", .radialFlesh, 0xE0600C, 0xBF4E08, 0xD45A0C,
                        knobs: V4(48, 0.4, 0.3, 2), tile: 0.032, rough: 0.3, seed: 1302, normal: 0.5, clearcoat: 0.4))
        out.append(spec("food.carrot-core", .radialFlesh, 0xF2A040, 0xF5C878, 0xE9781A,
                        knobs: V4(12, 0.8, 0.3, 1), tile: 0.014, rough: 0.3, seed: 1303, normal: 0.6, clearcoat: 0.4, cooked: "food.carrot-core-cooked"))
        out.append(spec("food.carrot-core-cooked", .radialFlesh, 0xE68A2A, 0xEDB060, 0xD8681A,
                        knobs: V4(12, 0.6, 0.3, 1), tile: 0.014, rough: 0.3, seed: 1303, normal: 0.5, clearcoat: 0.4))
        // Red bell pepper: glossy skin, wall flesh, white pith with seeds.
        out.append(spec("food.pepper-red", .fruitSkin, 0xB0120D, 0x6E0808, 0xD4503A, ca: 0.25,
                        knobs: V4(30, 0.35, 0.14, 0), tile: 0.08, rough: 0.14, seed: 1401, normal: 0.8, clearcoat: 1, cooked: "food.pepper-red-cooked"))
        out.append(spec("food.pepper-red-cooked", .foodCrumb, 0x92180E, 0x3A1408, 0xC04A30, ca: 0.3,
                        knobs: V4(24, 0.5, 0.3, 4), tile: 0.08, rough: 0.3, seed: 1402, normal: 1.0, clearcoat: 0.4))
        out.append(spec("food.pepper-flesh", .foodSmooth, 0xD4302A, 0xBE231E, 0xEE7562,
                        knobs: V4(70, 0.6, 0.3, 0), tile: 0.04, rough: 0.3, seed: 1403, normal: 0.6, clearcoat: 0.5, cooked: "food.pepper-flesh-cooked"))
        out.append(spec("food.pepper-flesh-cooked", .foodSmooth, 0xA8261A, 0x8E1C12, 0xC8503A,
                        knobs: V4(70, 0.4, 0.28, 0), tile: 0.04, rough: 0.28, seed: 1403, normal: 0.5, clearcoat: 0.5))
        out.append(spec("food.pepper-pith", .foodSmooth, 0xF2ECD6, 0xDCD2AC, 0xF7F2E2,
                        knobs: V4(40, 0.6, 0.55, 6), tile: 0.03, rough: 0.55, seed: 1404, normal: 0.8))
        out.append(spec("food.stem-green", .fruitSkin, 0x55702E, 0x2E4416, 0xA2AE62, ca: 0.35,
                        knobs: V4(40, 0.5, 0.42, 0), tile: 0.03, rough: 0.42, seed: 1405, normal: 1.2))
        // Roma tomato: skin and locular cut face.
        out.append(spec("food.tomato", .fruitSkin, 0xC0180D, 0xC8401A, 0xF08A68, ca: 0.3,
                        knobs: V4(60, 0.25, 0.12, 1), tile: 0.06, rough: 0.12, seed: 1501, normal: 0.6, clearcoat: 1, cooked: "food.tomato-cooked"))
        out.append(spec("food.tomato-cooked", .foodCrumb, 0xA61C0E, 0x46120A, 0xD05A3A, ca: 0.3,
                        knobs: V4(26, 0.45, 0.3, 4), tile: 0.06, rough: 0.3, seed: 1502, normal: 1.0, clearcoat: 0.4))
        out.append(spec("food.tomato-flesh", .radialFlesh, 0xD62C18, 0xE2813A, 0xF2E2A2,
                        knobs: V4(3, 0.6, 0.22, 3), tile: 0.05, rough: 0.22, seed: 1503, normal: 0.8, clearcoat: 0.6, cooked: "food.tomato-flesh-cooked"))
        out.append(spec("food.tomato-flesh-cooked", .radialFlesh, 0xB2200E, 0xC0602A, 0xE2C888,
                        knobs: V4(3, 0.5, 0.25, 3), tile: 0.05, rough: 0.25, seed: 1503, normal: 0.6, clearcoat: 0.5))
        // Garlic: papery skin, clove flesh, bulb cross section.
        out.append(spec("food.garlic-skin", .papery, 0xEFE7D7, 0x9A6274, 0xF8F3EA, ca: 0.35,
                        knobs: V4(90, 0.4, 0.5, 1), tile: 0.05, rough: 0.5, seed: 1601, normal: 1.2))
        out.append(spec("food.garlic-clove", .foodSmooth, 0xF1E7C6, 0xE4D4A2, 0xFAF4E0,
                        knobs: V4(60, 0.5, 0.34, 0), tile: 0.03, rough: 0.34, seed: 1602, normal: 0.5, clearcoat: 0.3, cooked: "food.garlic-clove-cooked"))
        out.append(spec("food.garlic-clove-cooked", .foodSmooth, 0xE2B866, 0xC48C3A, 0xF0D08C,
                        knobs: V4(60, 0.4, 0.4, 0), tile: 0.03, rough: 0.4, seed: 1602, normal: 0.5, clearcoat: 0.2))
        out.append(spec("food.garlic-section", .radialFlesh, 0xF0E5C2, 0xD3D08E, 0xB89A86,
                        knobs: V4(9, 0.5, 0.34, 7), tile: 0.06, rough: 0.34, seed: 1603, normal: 0.6, clearcoat: 0.3, cooked: "food.garlic-section-cooked"))
        out.append(spec("food.garlic-section-cooked", .radialFlesh, 0xE0B464, 0xC09440, 0x9A7656,
                        knobs: V4(9, 0.4, 0.4, 7), tile: 0.06, rough: 0.4, seed: 1603, normal: 0.6))
        // Lemon: rind, white pith (rind cut face), segmented flesh.
        out.append(spec("food.lemon", .fruitSkin, 0xF0CB12, 0xE2B000, 0xB89A0E, ca: 0.6,
                        knobs: V4(70, 0.3, 0.32, 2), tile: 0.05, rough: 0.32, seed: 1701, normal: 1.5, clearcoat: 0.4))
        out.append(spec("food.lemon-pith", .foodSmooth, 0xF7F1DA, 0xEDE2B4, 0xF2E6B8,
                        knobs: V4(50, 0.5, 0.6, 6), tile: 0.03, rough: 0.6, seed: 1702, normal: 0.6))
        out.append(spec("food.lemon-flesh", .radialFlesh, 0xF2D648, 0xE2BA2C, 0xF8F2D6,
                        knobs: V4(10, 0.6, 0.16, 4), tile: 0.048, rough: 0.16, seed: 1703, normal: 0.9, clearcoat: 0.6))
        // Egg: brown shell, raw albumen (transparent), yolk.
        out.append(spec("food.egg-shell", .fruitSkin, 0xD2A47C, 0xC08F62, 0x8A5A3A, ca: 0.45,
                        knobs: V4(180, 0.3, 0.55, 4), tile: 0.05, rough: 0.55, seed: 1801, normal: 0.7))
        out.append(spec("food.egg-white", .foodSmooth, 0xF2F0D8, 0xE6E6C4, 0xFFFFFF,
                        knobs: V4(20, 0.3, 0.05, 4), tile: 0.05, rough: 0.05, seed: 1802, normal: 0.3, clearcoat: 1, res: 512,
                        cooked: "food.egg-white-cooked").with { $0.mode = .transparent; $0.opacity = 0.22 })
        out.append(spec("food.egg-white-cooked", .foodSmooth, 0xF8F6EE, 0xEDE9DC, 0xFFFFFF,
                        knobs: V4(20, 0.3, 0.5, 4), tile: 0.05, rough: 0.5, seed: 1803, normal: 0.5, res: 512))
        out.append(spec("food.egg-yolk", .foodSmooth, 0xF09C0A, 0xE58404, 0xFFC244, ca: 0.5,
                        knobs: V4(20, 0.3, 0.12, 3), tile: 0.03, rough: 0.12, seed: 1804, normal: 0.3, clearcoat: 0.8, res: 512, cooked: "food.egg-yolk-cooked"))
        out.append(spec("food.egg-yolk-cooked", .foodSmooth, 0xF2C24C, 0xE6AE38, 0xF8DA80, ca: 0.5,
                        knobs: V4(20, 0.3, 0.72, 3), tile: 0.03, rough: 0.72, seed: 1805, normal: 0.6, res: 512))
        // Butter block and browned butter.
        out.append(spec("food.butter", .foodSmooth, 0xF4E0A0, 0xEDD48E, 0xE2CA82,
                        knobs: V4(50, 0.4, 0.4, 1), tile: 0.06, rough: 0.4, seed: 1901, normal: 0.6, clearcoat: 0.2, cooked: "food.butter-cooked"))
        out.append(spec("food.butter-cooked", .foodCrumb, 0xC88A3C, 0x6A3812, 0xE8B866, ca: 0.3,
                        knobs: V4(60, 0.4, 0.15, 5), tile: 0.06, rough: 0.15, seed: 1902, normal: 0.4, clearcoat: 0.6))
        // Russet potato: netted skin and cut face.
        out.append(spec("food.potato", .rootSkin, 0xA67A50, 0x6A4628, 0xD4B48A, ca: 0.7,
                        knobs: V4(10, 0.25, 0.85, 1), tile: 0.06, rough: 0.85, seed: 2001, normal: 1.8, cooked: "food.potato-cooked"))
        out.append(spec("food.potato-cooked", .foodCrumb, 0x9C6A3A, 0x56361A, 0xC89A60, ca: 0.3,
                        knobs: V4(14, 0.35, 0.7, 4), tile: 0.06, rough: 0.7, seed: 2002, normal: 1.6))
        out.append(spec("food.potato-flesh", .radialFlesh, 0xF1E2B0, 0xE6DCAC, 0xD4C48C,
                        knobs: V4(5, 0.6, 0.4, 5), tile: 0.06, rough: 0.4, seed: 2003, normal: 0.6, clearcoat: 0.3, cooked: "food.potato-flesh-cooked"))
        out.append(spec("food.potato-flesh-cooked", .radialFlesh, 0xEDD08A, 0xE2C88A, 0xD2B678,
                        knobs: V4(5, 0.4, 0.5, 5), tile: 0.06, rough: 0.5, seed: 2003, normal: 0.6))
        // Strawberry: seeded skin and cut face.
        out.append(spec("food.strawberry", .fruitSkin, 0xC40C18, 0x8E0610, 0xE6C25A,
                        knobs: V4(13, 0.25, 0.16, 3), tile: 0.04, rough: 0.16, seed: 2101, normal: 1.6, clearcoat: 1))
        out.append(spec("food.strawberry-flesh", .radialFlesh, 0xE8434A, 0xBE0E1E, 0xF8E2DE,
                        knobs: V4(14, 0.6, 0.22, 6), tile: 0.034, rough: 0.22, seed: 2102, normal: 0.6, clearcoat: 0.6))
        // Dark chocolate bar.
        out.append(spec("food.chocolate", .foodSmooth, 0x3B1F13, 0x2C160D, 0x7C5C4A, ca: 0.3,
                        knobs: V4(20, 0.3, 0.22, 2), tile: 0.08, rough: 0.22, seed: 2201, normal: 0.4, clearcoat: 0.3))
        // Pancake or cake batter and its baked crumb.
        out.append(spec("food.batter", .foodSmooth, 0xF0DCA4, 0xE2C886, 0xC4A26A, ca: 0.5,
                        knobs: V4(30, 0.4, 0.3, 7), tile: 0.05, rough: 0.3, seed: 2301, normal: 0.6, clearcoat: 0.3, cooked: "food.batter-cooked"))
        out.append(spec("food.batter-cooked", .foodCrumb, 0xD89E50, 0xA0642A, 0xF0D090, ca: 0.6,
                        knobs: V4(30, 0.4, 0.72, 3), tile: 0.05, rough: 0.72, seed: 2302, normal: 1.4))
        return out
    }()
}
