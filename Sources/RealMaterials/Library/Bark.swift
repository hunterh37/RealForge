import RealCore

public extension MaterialLibrary {
    /// Tree bark. `tileSize` is one bark repeat; trees quantize UV seams to it.
    static let bark: [MaterialSpec] = [
        MaterialSpec(key: "bark.oak", program: .barkOak).with {
            $0.colorA = linear(0x6E655A); $0.colorB = linear(0x1E1712); $0.colorC = linear(0x8C9478)
            $0.knobs = V4(0.35, 0.4, 0, 0); $0.tileSize = 0.5; $0.normalStrength = 5; $0.roughness = 0.9
            $0.wind = 0.03
        },
        MaterialSpec(key: "bark.birch", program: .barkBirch).with {
            $0.colorA = linear(0xD9D5CB); $0.colorB = linear(0x1C1A18); $0.colorC = linear(0xC9A890)
            $0.tileSize = 0.6; $0.normalStrength = 3; $0.roughness = 0.6
            $0.wind = 0.04
        },
        MaterialSpec(key: "bark.pine", program: .barkPine).with {
            $0.colorA = linear(0x6B3F28); $0.colorB = linear(0x1B120D); $0.colorC = linear(0x7A706A)
            $0.tileSize = 0.45; $0.normalStrength = 5; $0.roughness = 0.9
            $0.wind = 0.02
        },
        MaterialSpec(key: "bark.maple", program: .barkOak).with {
            $0.colorA = linear(0x726A5F); $0.colorB = linear(0x2A221C); $0.colorC = linear(0x8C9478)
            $0.knobs = V4(0.2, 0.2, 0, 0); $0.seed = 5; $0.tileSize = 0.4; $0.normalStrength = 4; $0.roughness = 0.9
            $0.wind = 0.03
        },
        MaterialSpec(key: "bark.willow", program: .barkOak).with {
            $0.colorA = linear(0x6A6156); $0.colorB = linear(0x231C16); $0.colorC = linear(0x7E8A6A)
            $0.knobs = V4(0.25, 0.5, 0, 0); $0.seed = 9; $0.tileSize = 0.6; $0.normalStrength = 5; $0.roughness = 0.92
            $0.wind = 0.03
        },
        MaterialSpec(key: "bark.beech", program: .barkSmooth).with {
            $0.colorA = linear(0x6A6862); $0.colorB = linear(0x2E2A26); $0.colorC = linear(0x8F9A6A)
            $0.knobs = V4(0.35, 0.6, 0, 0); $0.seed = 2; $0.tileSize = 0.6; $0.normalStrength = 2.5; $0.roughness = 0.7
            $0.wind = 0.03
        },
        MaterialSpec(key: "bark.japanese-maple", program: .barkSmooth).with {
            $0.colorA = linear(0x6E695C); $0.colorB = linear(0x2A2420); $0.colorC = linear(0x7D8862)
            $0.knobs = V4(0.15, 0.9, 0, 0); $0.seed = 4; $0.tileSize = 0.35; $0.normalStrength = 2.5; $0.roughness = 0.7
            $0.wind = 0.04
        },
        MaterialSpec(key: "bark.aspen", program: .barkAspen).with {
            $0.colorA = linear(0xD0D2BC); $0.colorB = linear(0x1F1D1A); $0.colorC = linear(0xB4BA8C)
            $0.knobs = V4(0.5, 0, 0, 0); $0.seed = 6; $0.tileSize = 0.6; $0.normalStrength = 2.5; $0.roughness = 0.6
            $0.wind = 0.04
        },
        MaterialSpec(key: "bark.dead", program: .barkDead).with {
            $0.colorA = linear(0x8A847C); $0.colorB = linear(0x4A3E34); $0.colorC = linear(0x8C6A4A)
            $0.knobs = V4(0.45, 0, 0, 0); $0.seed = 8; $0.tileSize = 0.9; $0.normalStrength = 4; $0.roughness = 0.85
            $0.wind = 0.01
        },
        // realityhd:material.bark
    ]
}
