import RealCore

public extension MaterialLibrary {
    /// Log end grain, charred wood, ash, mossy bark and embers for camp and forest assets.
    /// `wood.endgrain*` expects a disc mapped with the pith at the tile center and the bark at radius
    /// 0.42 of the tile (see `WoodParts.endCap`).
    static let woodExtra: [MaterialSpec] = [
        MaterialSpec(key: "wood.endgrain", program: .woodEndGrain).with {
            $0.colorA = linear(0xCFAE80); $0.colorB = linear(0x8E6842); $0.colorC = linear(0xB0804F, 0.62)
            $0.knobs = V4(42, 0.5, 0.7, 0); $0.seed = 31; $0.tileSize = 1; $0.resolution = 2048; $0.normalStrength = 2
            $0.roughness = 0.84
        },
        MaterialSpec(key: "wood.endgrain-weathered", program: .woodEndGrain).with {
            $0.colorA = linear(0xB49A78); $0.colorB = linear(0x76593C); $0.colorC = linear(0x9A7552, 0.55)
            $0.knobs = V4(48, 1, 0.3, 0.65); $0.seed = 32; $0.tileSize = 1; $0.resolution = 2048; $0.normalStrength = 3
            $0.roughness = 0.9; $0.topColor = linear(0x3E5A1C); $0.topAmount = 0.25; $0.topLow = 0.85
        },
        MaterialSpec(key: "wood.charred", program: .charcoal).with {
            $0.colorA = linear(0x2C2A27); $0.colorB = linear(0x9A968E); $0.colorC = linear(0x6E4C30)
            $0.knobs = V4(0.25, 8, 0.3, 0.5); $0.seed = 33; $0.tileSize = 0.3; $0.normalStrength = 4
            $0.roughness = 0.8
        },
        MaterialSpec(key: "wood.ash", program: .charcoal).with {
            $0.colorA = linear(0x3C3936); $0.colorB = linear(0xA6A29A); $0.colorC = linear(0x5A4636)
            $0.knobs = V4(0.85, 14, 0.1, 0); $0.seed = 34; $0.tileSize = 0.5; $0.normalStrength = 2
            $0.roughness = 0.95
        },
        bark.first { $0.key == "bark.oak" }!.with {
            $0.key = "bark.oak-mossy"; $0.seed = 35; $0.wind = 0; $0.knobs = V4(0.5, 0.7, 0, 0)
            $0.topColor = linear(0x3A5020); $0.topAmount = 0.75; $0.topLow = 0.45
        },
        bark.first { $0.key == "bark.pine" }!.with {
            $0.key = "bark.pine-mossy"; $0.seed = 36; $0.wind = 0
            $0.topColor = linear(0x40591E); $0.topAmount = 0.8; $0.topLow = 0.45
        },
        // Dead wood under fallen bark: brown-grey, partly weathered, soft.
        MaterialSpec(key: "wood.deadwood", program: .woodPlank).with {
            $0.colorA = linear(0x6E5A48); $0.colorB = linear(0x3E3024); $0.knobs = V4(0.25, 0.85, 0, 0); $0.seed = 38
            $0.tileSize = 1.0; $0.normalStrength = 3.5; $0.roughness = 0.9
        },
        // Seasoned oak bark on firewood and branch wood: lower contrast than trunk bark, little lichen.
        bark.first { $0.key == "bark.oak" }!.with {
            $0.key = "bark.oak-dry"; $0.seed = 37; $0.wind = 0
            $0.colorA = linear(0x5F5347); $0.colorB = linear(0x2E241C); $0.colorC = linear(0x7C826A)
            $0.knobs = V4(0.15, 0, 0, 0); $0.normalStrength = 4
        },
        MaterialSpec(key: "emissive.ember", program: nil).with {
            $0.baseColor = V3(0.9, 0.3, 0.08); $0.roughness = 0.9; $0.mode = .emissive
            $0.emissive = V3(1, 0.32, 0.06); $0.emissiveIntensity = 3
        },
        // realforge:material.woodextra
    ]
}
