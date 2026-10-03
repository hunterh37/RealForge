import RealCore

public extension MaterialLibrary {
    /// Alpha-tested atlases (`tileSize = 0`, UVs 0...1), two-sided, with wind and back-light translucency.
    static let foliage: [MaterialSpec] = [
        MaterialSpec(key: "leaf.oak", program: .leafBroad).with {
            $0.colorA = linear(0x2F4A16); $0.colorB = linear(0x4E6A22); $0.colorC = linear(0x8A7A2A)
            $0.knobs = V4(1, 0.08, 2, 0); $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 2
            $0.roughness = 0.55; $0.specular = 0.4
            $0.wind = 0.06; $0.translucency = 0.5
        },
        MaterialSpec(key: "leaf.maple", program: .leafBroad).with {
            $0.colorA = linear(0x3D5A1A); $0.colorB = linear(0x5F7D26); $0.colorC = linear(0xC0601E)
            $0.knobs = V4(1, 0.15, 2, 0); $0.seed = 7; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 2
            $0.wind = 0.06; $0.translucency = 0.55
        },
        MaterialSpec(key: "leaf.birch", program: .leafBroad).with {
            $0.colorA = linear(0x4A6A1E); $0.colorB = linear(0x6F8C2C); $0.colorC = linear(0xB8A23A)
            $0.knobs = V4(0, 0.1, 2, 0); $0.seed = 3; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 1.5
            $0.wind = 0.07; $0.translucency = 0.55
        },
        MaterialSpec(key: "leaf.spruce", program: .leafNeedle).with {
            $0.colorA = linear(0x1C3320); $0.colorB = linear(0x2A4426); $0.colorC = linear(0x5C7F34)
            $0.knobs = V4(0.6, 0, 2, 0); $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 2.5
            $0.roughness = 0.6
            $0.wind = 0.03; $0.translucency = 0.25
        },
        MaterialSpec(key: "grass.meadow", program: .grassBlades).with {
            $0.colorA = linear(0x2B4214); $0.colorB = linear(0x6C8A2E); $0.colorC = linear(0x9C8F55)
            $0.knobs = V4(0.12, 0, 1, 0); $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.resolution = 512
            $0.normalStrength = 1.5; $0.hasAOMap = true
            $0.wind = 0.05; $0.translucency = 0.45
        },
        MaterialSpec(key: "leaf.maple-norway", program: .leafPalmate).with {
            $0.colorA = linear(0x2F4F17); $0.colorB = linear(0x557A24); $0.colorC = linear(0xC9A02A)
            $0.knobs = V4(0.38, 0.08, 2, 5); $0.seed = 11; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 2
            $0.roughness = 0.55; $0.specular = 0.4
            $0.wind = 0.06; $0.translucency = 0.55
        },
        MaterialSpec(key: "leaf.maple-red", program: .leafPalmate).with {
            $0.colorA = linear(0xA3261A); $0.colorB = linear(0xD85A1E); $0.colorC = linear(0xE8A23A)
            $0.knobs = V4(0.38, 0.35, 2, 5); $0.seed = 12; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 2
            $0.roughness = 0.55; $0.specular = 0.4
            $0.wind = 0.06; $0.translucency = 0.6
        },
        MaterialSpec(key: "leaf.japanese-maple", program: .leafPalmate).with {
            $0.colorA = linear(0x6E1414); $0.colorB = linear(0xA22A1C); $0.colorC = linear(0xC2401C)
            $0.knobs = V4(0.72, 0.2, 2, 7); $0.seed = 13; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 2
            $0.roughness = 0.55; $0.specular = 0.4
            $0.wind = 0.07; $0.translucency = 0.6
        },
        MaterialSpec(key: "leaf.willow", program: .leafLanceolate).with {
            $0.colorA = linear(0x4A6623); $0.colorB = linear(0x9AA77A); $0.colorC = linear(0xC4B03A)
            $0.knobs = V4(8, 0.06, 2, 0); $0.seed = 14; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 1.5
            $0.roughness = 0.55; $0.specular = 0.4
            $0.wind = 0.09; $0.translucency = 0.5
        },
        MaterialSpec(key: "leaf.beech", program: .leafBroad).with {
            $0.colorA = linear(0x34561A); $0.colorB = linear(0x5D8526); $0.colorC = linear(0xA8682A)
            $0.knobs = V4(0, 0.06, 2, 0.58); $0.seed = 15; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 2
            $0.roughness = 0.55; $0.specular = 0.4
            $0.wind = 0.06; $0.translucency = 0.55
        },
        MaterialSpec(key: "leaf.aspen", program: .leafBroad).with {
            $0.colorA = linear(0x3F6420); $0.colorB = linear(0x7A9A35); $0.colorC = linear(0xD9B23A)
            $0.knobs = V4(0, 0.05, 2, 0.92); $0.seed = 16; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 2
            $0.roughness = 0.55; $0.specular = 0.4
            $0.wind = 0.09; $0.translucency = 0.55
        },
        MaterialSpec(key: "leaf.aspen-gold", program: .leafBroad).with {
            $0.colorA = linear(0xC79A1E); $0.colorB = linear(0xE6C24A); $0.colorC = linear(0xD58A1E)
            $0.knobs = V4(0, 0.3, 2, 0.92); $0.seed = 17; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 2
            $0.roughness = 0.55; $0.specular = 0.4
            $0.wind = 0.09; $0.translucency = 0.6
        },
        // realityhd:material.foliage
    ]
}
