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
        // realforge:material.foliage
    ]
}
