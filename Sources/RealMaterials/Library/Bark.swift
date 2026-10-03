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
        // realforge:material.bark
    ]
}
