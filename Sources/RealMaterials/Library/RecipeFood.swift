import RealCore

public extension MaterialLibrary {
    /// Recipe-pack ingredients (meat, fish, cheese, herbs, bread, produce) and pantry fills. Same
    /// conventions as `food`: `cooked` links raw -> cooked, radial cut faces are centered at uv 0.5
    /// with `tileSize` = the tissue diameter.
    static let recipeFood: [MaterialSpec] = {
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
        func fill(_ key: String, _ a: UInt32, _ b: UInt32, _ c: UInt32, knobs: V4, tile: Float, rough: Float, seed: UInt32,
                  normal: Float, clearcoat: Float = 0, cooked: String? = nil) -> MaterialSpec {
            MaterialSpec(key: key, program: .pantryFill).with {
                $0.colorA = linear(a); $0.colorB = linear(b); $0.colorC = linear(c)
                $0.knobs = knobs; $0.seed = seed; $0.tileSize = tile; $0.normalStrength = normal; $0.resolution = 512
                $0.roughness = rough; $0.clearcoat = clearcoat; $0.baseColor = V3($0.colorA.x, $0.colorA.y, $0.colorA.z)
                $0.cooked = cooked.map { MaterialKey($0) }
            }
        }
        var o: [MaterialSpec] = []
        // Ribeye: marbled lean surface, seared crust, cut face, fat cap.
        o.append(spec("food.beef-raw", .foodTissue, 0x7A1A20, 0x4E0E14, 0xEADBC4,
                      knobs: V4(8, 0.9, 0.55, 0), tile: 0.1, rough: 0.55, seed: 5101, normal: 0.9, clearcoat: 0.1, cooked: "food.beef-seared"))
        o.append(spec("food.beef-seared", .foodCrumb, 0x6A3420, 0x2A140A, 0xB8784A, ca: 0.4,
                      knobs: V4(30, 0.85, 0.45, 0), tile: 0.08, rough: 0.45, seed: 5102, normal: 1.8, clearcoat: 0.3))
        o.append(spec("food.beef-section", .foodTissue, 0x9A2228, 0x641218, 0xF0E2CE,
                      knobs: V4(6, 0.85, 0.36, 0), tile: 0.08, rough: 0.36, seed: 5103, normal: 0.7, clearcoat: 0.3, cooked: "food.beef-section-cooked"))
        o.append(spec("food.beef-section-cooked", .foodTissue, 0xC2565A, 0x8C3A38, 0xF2E0C8,
                      knobs: V4(6, 0.8, 0.4, 0), tile: 0.08, rough: 0.4, seed: 5103, normal: 0.8, clearcoat: 0.3))
        o.append(spec("food.beef-fat", .foodSmooth, 0xECDDC4, 0xDCC6A6, 0xC89890, ca: 0.5,
                      knobs: V4(40, 0.5, 0.5, 1), tile: 0.06, rough: 0.5, seed: 5104, normal: 0.9, clearcoat: 0.2, cooked: "food.beef-fat-cooked"))
        o.append(spec("food.beef-fat-cooked", .foodCrumb, 0xD8A460, 0x8A5426, 0xF2D49A, ca: 0.5,
                      knobs: V4(24, 0.6, 0.35, 3), tile: 0.06, rough: 0.35, seed: 5105, normal: 1.2, clearcoat: 0.4))
        // Salmon: flesh with myomere lines, silver skin.
        o.append(spec("food.salmon", .foodTissue, 0xEA7A58, 0xD45838, 0xF2CDBD,
                      knobs: V4(9, 0.6, 0.4, 1), tile: 0.1, rough: 0.4, seed: 5201, normal: 0.8, clearcoat: 0.3, cooked: "food.salmon-cooked"))
        o.append(spec("food.salmon-cooked", .foodTissue, 0xF2A486, 0xE08A68, 0xFCEEE4,
                      knobs: V4(9, 0.9, 0.55, 1), tile: 0.1, rough: 0.55, seed: 5201, normal: 1.2))
        o.append(spec("food.salmon-skin", .foodTissue, 0xA9AEB0, 0x3E4246, 0xC8B8D8, ca: 0.6,
                      knobs: V4(90, 0.6, 0.25, 2), tile: 0.1, rough: 0.25, seed: 5202, normal: 0.8, clearcoat: 0.6, cooked: "food.salmon-skin-crisp"))
        o.append(spec("food.salmon-skin-crisp", .foodCrumb, 0x8E6A4A, 0x3A2416, 0xC8A070, ca: 0.4,
                      knobs: V4(30, 0.7, 0.4, 4), tile: 0.08, rough: 0.4, seed: 5203, normal: 1.4, clearcoat: 0.3))
        // Shrimp: translucent grey-pink body turning coral and white.
        o.append(spec("food.shrimp-raw", .foodTissue, 0xA49EA4, 0xA87266, 0xD08068, ca: 0.25,
                      knobs: V4(6, 0.8, 0.26, 3), tile: 0.06, rough: 0.26, seed: 5301, normal: 0.8, clearcoat: 0.5, cooked: "food.shrimp-cooked"))
        o.append(spec("food.shrimp-cooked", .foodTissue, 0xF6E2D6, 0xF07450, 0xE8502E, ca: 0.8,
                      knobs: V4(6, 1.0, 0.3, 3), tile: 0.06, rough: 0.3, seed: 5301, normal: 0.8, clearcoat: 0.5))
        o.append(spec("food.shrimp-flesh", .foodSmooth, 0xD8CCC4, 0xC8B8B0, 0xE8DEDA,
                      knobs: V4(20, 0.3, 0.2, 4), tile: 0.03, rough: 0.2, seed: 5302, normal: 0.4, clearcoat: 0.6, cooked: "food.shrimp-flesh-cooked"))
        o.append(spec("food.shrimp-flesh-cooked", .foodSmooth, 0xF8F0EA, 0xF2D8CC, 0xFFFFFF,
                      knobs: V4(30, 0.3, 0.5, 5), tile: 0.03, rough: 0.5, seed: 5303, normal: 0.6))
        o.append(spec("food.shrimp-tail", .foodTissue, 0xA88880, 0x9A4A3A, 0xC0503A, ca: 0.5,
                      knobs: V4(3, 0.8, 0.2, 3), tile: 0.03, rough: 0.2, seed: 5304, normal: 0.8, clearcoat: 0.8, cooked: "food.shrimp-tail-cooked"))
        o.append(spec("food.shrimp-tail-cooked", .foodTissue, 0xE8482A, 0xB82A16, 0xF4A070, ca: 0.6,
                      knobs: V4(3, 0.8, 0.3, 3), tile: 0.03, rough: 0.3, seed: 5304, normal: 0.8, clearcoat: 0.5))
        // Ground beef 80/20.
        o.append(spec("food.ground-beef", .foodTissue, 0x9A2A30, 0x6A1A20, 0xE8D0C4,
                      knobs: V4(16, 0.8, 0.55, 9), tile: 0.05, rough: 0.55, seed: 5401, normal: 3.0, clearcoat: 0.15, cooked: "food.ground-beef-cooked"))
        o.append(spec("food.ground-beef-cooked", .foodTissue, 0x6A4030, 0x3A1E12, 0xA88060,
                      knobs: V4(16, 0.6, 0.55, 9), tile: 0.05, rough: 0.55, seed: 5401, normal: 2.0, clearcoat: 0.2))
        // Bacon: fat and lean stripes.
        o.append(spec("food.bacon", .foodTissue, 0xB25058, 0x8A3038, 0xE8D4CA,
                      knobs: V4(3, 0.6, 0.4, 10), tile: 0.03, rough: 0.4, seed: 5501, normal: 1.0, clearcoat: 0.4, cooked: "food.bacon-cooked"))
        o.append(spec("food.bacon-cooked", .foodTissue, 0x8E3A22, 0x4E1C10, 0xE0A660,
                      knobs: V4(5, 1.0, 0.4, 10), tile: 0.03, rough: 0.4, seed: 5501, normal: 1.6, clearcoat: 0.4))
        // Dry spaghetti and boiled pasta.
        o.append(spec("food.pasta-dry", .foodSmooth, 0xE6CE90, 0xD8BC78, 0xC4A468, ca: 0.4,
                      knobs: V4(80, 0.4, 0.42, 7), tile: 0.02, rough: 0.42, seed: 5601, normal: 0.3, clearcoat: 0.1, res: 512, cooked: "food.pasta-cooked"))
        o.append(spec("food.pasta-cooked", .foodSmooth, 0xF2DCA0, 0xE6CC8A, 0xF8ECC4, ca: 0.3,
                      knobs: V4(40, 0.2, 0.22, 4), tile: 0.02, rough: 0.22, seed: 5602, normal: 0.2, clearcoat: 0.6, res: 512))
        // Cheeses.
        o.append(spec("food.parmesan", .foodTissue, 0xF0E2B6, 0xDCC894, 0xFFFBEC,
                      knobs: V4(56, 1.0, 0.72, 4), tile: 0.05, rough: 0.72, seed: 5701, normal: 2.6, cooked: "food.parmesan-cooked"))
        o.append(spec("food.parmesan-cooked", .foodCrumb, 0xE6B860, 0xA06A26, 0xF6DC9A, ca: 0.4,
                      knobs: V4(20, 0.6, 0.5, 3), tile: 0.05, rough: 0.5, seed: 5702, normal: 1.2, clearcoat: 0.2))
        o.append(spec("food.parmesan-rind", .foodTissue, 0xC89A52, 0x9A6A30, 0x6E4A22,
                      knobs: V4(22, 0.7, 0.55, 5), tile: 0.05, rough: 0.55, seed: 5703, normal: 1.6))
        o.append(spec("food.mozzarella", .foodSmooth, 0xF6F3EA, 0xEDE8DA, 0xFFFFFF,
                      knobs: V4(20, 0.3, 0.16, 4), tile: 0.06, rough: 0.16, seed: 5801, normal: 0.4, clearcoat: 0.9, cooked: "food.mozzarella-melted"))
        o.append(spec("food.mozzarella-melted", .foodCrumb, 0xF4E6C0, 0xC88A3E, 0xFFF6DC, ca: 0.5,
                      knobs: V4(10, 0.6, 0.25, 4), tile: 0.06, rough: 0.25, seed: 5802, normal: 0.8, clearcoat: 0.6))
        o.append(spec("food.mozzarella-section", .foodSmooth, 0xF8F6EE, 0xEAE4D4, 0xDDD6C4,
                      knobs: V4(30, 0.6, 0.35, 0), tile: 0.04, rough: 0.35, seed: 5803, normal: 0.6, clearcoat: 0.5, cooked: "food.mozzarella-melted"))
        o.append(spec("food.cheddar", .foodSmooth, 0xF0A030, 0xE48E22, 0xF8C060, ca: 0.4,
                      knobs: V4(50, 0.4, 0.38, 1), tile: 0.05, rough: 0.38, seed: 5901, normal: 0.6, clearcoat: 0.3, cooked: "food.cheddar-melted"))
        o.append(spec("food.cheddar-melted", .foodSmooth, 0xE88A1E, 0xD07212, 0xF8B850, ca: 0.4,
                      knobs: V4(20, 0.3, 0.1, 4), tile: 0.05, rough: 0.1, seed: 5902, normal: 0.3, clearcoat: 0.9))
        // Avocado.
        o.append(spec("food.avocado-skin", .foodTissue, 0x2E3A1A, 0x1A1E10, 0x4A2E36, ca: 0.4,
                      knobs: V4(40, 0.9, 0.55, 8), tile: 0.06, rough: 0.55, seed: 6001, normal: 2.0))
        o.append(spec("food.avocado-flesh", .foodTissue, 0xE8E27A, 0x8CB43A, 0x3A5A1A,
                      knobs: V4(4, 0.4, 0.3, 7), tile: 0.16, rough: 0.3, seed: 6002, normal: 0.4, clearcoat: 0.6))
        o.append(spec("food.avocado-pit", .foodSmooth, 0x8A5A34, 0x6A4022, 0xB88A5A, ca: 0.5,
                      knobs: V4(20, 0.5, 0.35, 3), tile: 0.04, rough: 0.35, seed: 6003, normal: 0.6, clearcoat: 0.4))
        o.append(spec("food.avocado-pit-section", .foodSmooth, 0xF2E6C4, 0xE2CFA0, 0xB88A5A,
                      knobs: V4(30, 0.4, 0.5, 0), tile: 0.04, rough: 0.5, seed: 6004, normal: 0.4))
        // Lime.
        o.append(spec("food.lime", .fruitSkin, 0x3A7A18, 0x2A5E10, 0x7AA03A, ca: 0.6,
                      knobs: V4(110, 0.3, 0.32, 2), tile: 0.05, rough: 0.32, seed: 6101, normal: 1.0, clearcoat: 0.5))
        o.append(spec("food.lime-pith", .foodSmooth, 0xEEF2D2, 0xDDE6B0, 0xE6EEC0,
                      knobs: V4(50, 0.5, 0.6, 6), tile: 0.03, rough: 0.6, seed: 6102, normal: 0.6))
        o.append(spec("food.lime-flesh", .radialFlesh, 0xB6D45A, 0x96BC3A, 0xEEF4D2,
                      knobs: V4(10, 0.6, 0.16, 4), tile: 0.046, rough: 0.16, seed: 6103, normal: 0.9, clearcoat: 0.6))
        // Herbs.
        o.append(spec("food.basil", .foodTissue, 0x2E6A1C, 0x3E8424, 0x6EA444, ca: 0.6,
                      knobs: V4(6, 0.6, 0.35, 6), tile: 0.06, rough: 0.35, seed: 6201, normal: 0.7, clearcoat: 0.4, cooked: "food.basil-wilted"))
        o.append(spec("food.basil-wilted", .foodTissue, 0x1E3E12, 0x2A4A16, 0x3A5A22, ca: 0.6,
                      knobs: V4(6, 0.6, 0.25, 6), tile: 0.06, rough: 0.25, seed: 6201, normal: 0.5, clearcoat: 0.5))
        o.append(spec("food.cilantro", .foodTissue, 0x3A7A22, 0x4A8E2C, 0x86B85A, ca: 0.6,
                      knobs: V4(4, 0.6, 0.4, 6), tile: 0.03, rough: 0.4, seed: 6202, normal: 0.6, clearcoat: 0.3, cooked: "food.basil-wilted"))
        o.append(spec("food.herb-stem", .fruitSkin, 0x5E8E34, 0x3E6A20, 0x9ABC62, ca: 0.3,
                      knobs: V4(40, 0.4, 0.4, 0), tile: 0.02, rough: 0.4, seed: 6203, normal: 0.8, cooked: "food.basil-wilted"))
        o.append(spec("food.herb-stem-section", .foodSmooth, 0xB6D47A, 0x9EC062, 0xE4F0C4,
                      knobs: V4(20, 0.4, 0.3, 0), tile: 0.01, rough: 0.3, seed: 6204, normal: 0.4))
        // Cremini mushroom.
        o.append(spec("food.mushroom-cap", .foodTissue, 0x7E5A40, 0x6A4A34, 0xB89878, ca: 0.6,
                      knobs: V4(30, 0.3, 0.75, 13), tile: 0.05, rough: 0.75, seed: 6301, normal: 0.8, cooked: "food.mushroom-cooked"))
        o.append(spec("food.mushroom-cooked", .foodCrumb, 0x6A4228, 0x3A2010, 0xA87850, ca: 0.4,
                      knobs: V4(20, 0.6, 0.3, 2), tile: 0.05, rough: 0.3, seed: 6302, normal: 0.8, clearcoat: 0.5))
        o.append(spec("food.mushroom-flesh", .foodSmooth, 0xEEE4D2, 0xE0D2BA, 0xC8B49A, ca: 0.5,
                      knobs: V4(40, 0.4, 0.5, 6), tile: 0.03, rough: 0.5, seed: 6303, normal: 0.5, cooked: "food.mushroom-flesh-cooked"))
        o.append(spec("food.mushroom-flesh-cooked", .foodSmooth, 0xA88460, 0x8A6644, 0x6A4A30, ca: 0.5,
                      knobs: V4(40, 0.4, 0.3, 6), tile: 0.03, rough: 0.3, seed: 6304, normal: 0.5, clearcoat: 0.4))
        o.append(spec("food.mushroom-gills", .foodTissue, 0x6E5440, 0x4A3628, 0x2A1E16, ca: 0,
                      knobs: V4(90, 0.5, 0.7, 12), tile: 0.08, rough: 0.7, seed: 6305, normal: 1.6, cooked: "food.mushroom-cooked"))
        // Broccoli.
        o.append(spec("food.broccoli", .foodTissue, 0x46743A, 0x2E5426, 0x9AA84A, ca: 0.3,
                      knobs: V4(70, 1.0, 0.7, 11), tile: 0.05, rough: 0.7, seed: 6401, normal: 2.0, cooked: "food.broccoli-cooked"))
        o.append(spec("food.broccoli-cooked", .foodTissue, 0x3E8A2A, 0x2A6A1C, 0x6EA43A, ca: 0.2,
                      knobs: V4(40, 0.9, 0.4, 11), tile: 0.05, rough: 0.4, seed: 6401, normal: 1.6, clearcoat: 0.3))
        o.append(spec("food.broccoli-stem", .fruitSkin, 0x8AAA5A, 0x6A8E42, 0xC4D49A, ca: 0.4,
                      knobs: V4(30, 0.4, 0.45, 0), tile: 0.03, rough: 0.45, seed: 6402, normal: 0.8, cooked: "food.broccoli-stem-cooked"))
        o.append(spec("food.broccoli-stem-cooked", .fruitSkin, 0x6EA43A, 0x4E8A2A, 0xA8CC6A, ca: 0.4,
                      knobs: V4(30, 0.4, 0.3, 0), tile: 0.03, rough: 0.3, seed: 6402, normal: 0.6, clearcoat: 0.4))
        o.append(spec("food.broccoli-flesh", .radialFlesh, 0xD6E2A6, 0xB8CC7E, 0x9EBC5A, ca: 0.6,
                      knobs: V4(12, 0.6, 0.3, 5), tile: 0.022, rough: 0.3, seed: 6403, normal: 0.5, clearcoat: 0.3))
        // Scallion.
        o.append(spec("food.scallion-green", .fruitSkin, 0x3E8A2A, 0x2A6A1C, 0x9EC46A, ca: 0.4,
                      knobs: V4(60, 0.3, 0.3, 0), tile: 0.03, rough: 0.3, seed: 6501, normal: 0.6, clearcoat: 0.4, cooked: "food.basil-wilted"))
        o.append(spec("food.scallion-white", .foodSmooth, 0xE4EAC8, 0xDCE6C2, 0xC8DCA4, ca: 0.6,
                      knobs: V4(60, 0.6, 0.3, 0), tile: 0.02, rough: 0.3, seed: 6502, normal: 0.5, clearcoat: 0.4, cooked: "food.onion-cooked"))
        o.append(spec("food.scallion-section", .radialFlesh, 0xEEF2D8, 0xB4D47A, 0xFFFFF2, ca: 0.55,
                      knobs: V4(5, 0.7, 0.24, 0), tile: 0.014, rough: 0.24, seed: 6503, normal: 0.6, clearcoat: 0.5))
        o.append(spec("food.scallion-root", .papery, 0xD8CDB0, 0x8A7A5A, 0xEDE6D0, ca: 0.3,
                      knobs: V4(60, 0.4, 0.7, 0), tile: 0.02, rough: 0.7, seed: 6504, normal: 1.0))
        // Jalapeno.
        o.append(spec("food.jalapeno", .fruitSkin, 0x1E5A1A, 0x0E3A10, 0x6A8A3A, ca: 0.2,
                      knobs: V4(30, 0.3, 0.14, 0), tile: 0.06, rough: 0.14, seed: 6601, normal: 0.8, clearcoat: 1, cooked: "food.jalapeno-charred"))
        o.append(spec("food.jalapeno-charred", .foodCrumb, 0x3A4A1A, 0x14100A, 0x8A8A4A, ca: 0.3,
                      knobs: V4(20, 0.7, 0.35, 4), tile: 0.06, rough: 0.35, seed: 6602, normal: 1.4, clearcoat: 0.3))
        o.append(spec("food.jalapeno-section", .radialFlesh, 0x6E9E3A, 0xD8E2B0, 0xF2EED0,
                      knobs: V4(3, 0.6, 0.25, 3), tile: 0.024, rough: 0.25, seed: 6603, normal: 0.6, clearcoat: 0.5))
        // Ginger.
        o.append(spec("food.ginger", .rootSkin, 0xB88E5C, 0x7A5A36, 0xD8BC8E, ca: 0.8,
                      knobs: V4(30, 0.4, 0.62, 0), tile: 0.04, rough: 0.62, seed: 6701, normal: 2.2, cooked: "food.ginger-cooked"))
        o.append(spec("food.ginger-cooked", .foodCrumb, 0xC8902E, 0x8A5A1A, 0xE8C070, ca: 0.4,
                      knobs: V4(20, 0.4, 0.4, 2), tile: 0.04, rough: 0.4, seed: 6702, normal: 1.0, clearcoat: 0.3))
        o.append(spec("food.ginger-flesh", .radialFlesh, 0xF2D47A, 0xE6C25A, 0xD8B44A,
                      knobs: V4(5, 0.6, 0.35, 5), tile: 0.025, rough: 0.35, seed: 6703, normal: 0.5, clearcoat: 0.3))
        // Breads.
        o.append(spec("food.bread-crust", .foodCrumb, 0x9A5A26, 0x5A2C10, 0xD8A060, ca: 0.6,
                      knobs: V4(30, 0.7, 0.6, 3), tile: 0.05, rough: 0.6, seed: 6801, normal: 1.4, cooked: "food.bread-crust-toasted"))
        o.append(spec("food.bread-crust-toasted", .foodCrumb, 0x6A3416, 0x2E1408, 0xA06A3A, ca: 0.5,
                      knobs: V4(30, 0.8, 0.6, 3), tile: 0.05, rough: 0.6, seed: 6802, normal: 1.4))
        o.append(spec("food.bread-crumb", .foodCrumb, 0xEEE0C2, 0x9C8460, 0xFFF8E6, ca: 0.4,
                      knobs: V4(14, 0.0, 0.85, 3), tile: 0.06, rough: 0.85, seed: 6803, normal: 2.4, cooked: "food.bread-toast"))
        o.append(spec("food.bread-toast", .foodCrumb, 0xD8A058, 0x8A5420, 0xF0CC8A, ca: 0.5,
                      knobs: V4(14, 0.6, 0.85, 3), tile: 0.06, rough: 0.85, seed: 6804, normal: 2.4))
        o.append(spec("food.bun-crust", .foodCrumb, 0xC2782E, 0x8A4A18, 0xF0C080, ca: 0.4,
                      knobs: V4(60, 0.6, 0.28, 3), tile: 0.06, rough: 0.28, seed: 6901, normal: 0.6, clearcoat: 0.6, cooked: "food.bread-crust-toasted"))
        o.append(spec("food.bun-crumb", .foodCrumb, 0xF2E4C6, 0xD8C49E, 0xFFFAEA, ca: 0.4,
                      knobs: V4(36, 0.0, 0.85, 3), tile: 0.05, rough: 0.85, seed: 6902, normal: 1.6, cooked: "food.bread-toast"))
        o.append(spec("food.sesame", .foodSmooth, 0xF2E6C4, 0xE2D2A8, 0xC8B080, ca: 0.4,
                      knobs: V4(20, 0.4, 0.45, 0), tile: 0.01, rough: 0.45, seed: 6903, normal: 0.4, res: 256, cooked: "food.sesame-toasted"))
        o.append(spec("food.sesame-toasted", .foodSmooth, 0xD8A866, 0xB8864A, 0x9A6A3A, ca: 0.4,
                      knobs: V4(20, 0.4, 0.4, 0), tile: 0.01, rough: 0.4, seed: 6904, normal: 0.4, res: 256))
        o.append(spec("food.tortilla", .foodSmooth, 0xEFE2C2, 0xE0CFA6, 0xA88050, ca: 0.8,
                      knobs: V4(50, 0.6, 0.7, 7), tile: 0.08, rough: 0.7, seed: 7001, normal: 0.8, cooked: "food.tortilla-cooked"))
        o.append(spec("food.tortilla-cooked", .foodCrumb, 0xEEDCB2, 0x8A5426, 0xF8EED2, ca: 0.4,
                      knobs: V4(22, 0.9, 0.7, 4), tile: 0.08, rough: 0.7, seed: 7002, normal: 1.0))
        // Banana.
        o.append(spec("food.banana-peel", .foodTissue, 0xF2CE3A, 0x6A4418, 0x8AA43A, ca: 0.5,
                      knobs: V4(5, 0.6, 0.45, 12), tile: 0.12, rough: 0.45, seed: 7101, normal: 0.8, clearcoat: 0.3))
        o.append(spec("food.banana-peel-section", .foodSmooth, 0xF4ECC8, 0xE8DCA8, 0xF2CE3A,
                      knobs: V4(30, 0.4, 0.6, 6), tile: 0.02, rough: 0.6, seed: 7102, normal: 0.4))
        o.append(spec("food.banana-flesh", .foodSmooth, 0xF4E8BE, 0xEAD8A0, 0xD8C080, ca: 0.4,
                      knobs: V4(30, 0.5, 0.4, 0), tile: 0.04, rough: 0.4, seed: 7103, normal: 0.5, clearcoat: 0.3, cooked: "food.banana-cooked"))
        o.append(spec("food.banana-cooked", .foodCrumb, 0xE0B060, 0x9A6420, 0xF2D49A, ca: 0.4,
                      knobs: V4(20, 0.5, 0.3, 2), tile: 0.04, rough: 0.3, seed: 7104, normal: 0.6, clearcoat: 0.5))
        o.append(spec("food.banana-tip", .foodSmooth, 0x3A2A1A, 0x2A1E12, 0x5A4630, ca: 0.4,
                      knobs: V4(20, 0.5, 0.7, 6), tile: 0.02, rough: 0.7, seed: 7105, normal: 1.0))
        // Pantry fills (RealCook.fill).
        o.append(fill("food.rice", 0xF2EEE2, 0xD6CFBE, 0xFFFFFF, knobs: V4(80, 0.6, 0, 0), tile: 0.04, rough: 0.45, seed: 4201,
                      normal: 2.0, cooked: "food.rice-cooked"))
        o.append(fill("food.rice-cooked", 0xF6F4EC, 0xE2DDD0, 0xFFFFFF, knobs: V4(36, 0.2, 0.2, 0), tile: 0.04, rough: 0.35, seed: 4202,
                      normal: 2.4, clearcoat: 0.3))
        o.append(fill("food.tomato-sauce", 0xA8200E, 0x7A1408, 0xD0502A, knobs: V4(30, 0, 0.5, 0.15), tile: 0.08, rough: 0.2, seed: 4203,
                      normal: 0.8, clearcoat: 0.5, cooked: "food.tomato-sauce-reduced"))
        o.append(fill("food.tomato-sauce-reduced", 0x7E1608, 0x4E0C04, 0xA8301A, knobs: V4(30, 0, 0.5, 0.25), tile: 0.08, rough: 0.25, seed: 4204,
                      normal: 1.0, clearcoat: 0.4))
        o.append(fill("food.cream", 0xF8F4E8, 0xEDE6D2, 0xFFFFFF, knobs: V4(30, 0, 0.3, 0.05), tile: 0.08, rough: 0.12, seed: 4205,
                      normal: 0.3, clearcoat: 0.6, cooked: "food.cream-reduced"))
        o.append(fill("food.cream-reduced", 0xF0E2BE, 0xD8C494, 0xFAF0D8, knobs: V4(30, 0, 0.4, 0.2), tile: 0.08, rough: 0.15, seed: 4206,
                      normal: 0.5, clearcoat: 0.5))
        o.append(fill("food.soy-sauce", 0x2A0E04, 0x160602, 0x5A2A10, knobs: V4(30, 0, 0.2, 0), tile: 0.08, rough: 0.04, seed: 4207,
                      normal: 0.2, clearcoat: 1))
        o.append(fill("food.stock", 0xB8862E, 0x8A5A1A, 0xE8C070, knobs: V4(30, 0, 0.3, 0.05), tile: 0.08, rough: 0.04, seed: 4208,
                      normal: 0.2, clearcoat: 1, cooked: "food.stock-reduced"))
        o.append(fill("food.stock-reduced", 0x7A4A16, 0x4E2A0A, 0xA86A2A, knobs: V4(30, 0, 0.3, 0.1), tile: 0.08, rough: 0.06, seed: 4209,
                      normal: 0.3, clearcoat: 1))
        o.append(fill("food.cheese-grated", 0xF2DC9A, 0xD8BC70, 0xFFF4D0, knobs: V4(40, 0.4, 0.5, 0), tile: 0.05, rough: 0.7, seed: 4210,
                      normal: 2.6, cooked: "food.cheese-melted"))
        o.append(fill("food.cheese-melted", 0xEEC060, 0xC0802A, 0xF8DC90, knobs: V4(30, 0, 0.5, 0.2), tile: 0.06, rough: 0.2, seed: 4211,
                      normal: 0.8, clearcoat: 0.6))
        return o
    }()
}
