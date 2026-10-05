import RealCore

public extension MaterialLibrary {
    /// Woodshop pack: dimensional lumber stock by species, fresh end grain, machined cast iron saw tables,
    /// saw plate steel and carbide, butcher-block maple, sealed shop concrete, sawdust and hardboard.
    static let woodshop: [MaterialSpec] = [
        // Kiln-dried SPF stud lumber: pale yellow-white, faint latewood lines, mill-planed (no clearcoat).
        MaterialSpec(key: "wood.lumber-pine", program: .woodPlank).with {
            $0.colorA = linear(0xE3C99B); $0.colorB = linear(0xB88A55); $0.knobs = V4(0, 0.7, 0, 0); $0.seed = 801
            $0.tileSize = 0.9; $0.normalStrength = 1.0; $0.roughness = 0.78
        },
        // Planed red oak: pinkish tan with open pores.
        MaterialSpec(key: "wood.lumber-oak", program: .woodPlank).with {
            $0.colorA = linear(0xC99C74); $0.colorB = linear(0x8E5E3C); $0.knobs = V4(0, 0.65, 0, 0); $0.seed = 802
            $0.tileSize = 0.7; $0.normalStrength = 1.4; $0.roughness = 0.72
        },
        // Hard maple: creamy, low contrast.
        MaterialSpec(key: "wood.lumber-maple", program: .woodPlank).with {
            $0.colorA = linear(0xEADBBE); $0.colorB = linear(0xC6AC82); $0.knobs = V4(0, 0.6, 0, 0); $0.seed = 803
            $0.tileSize = 0.6; $0.normalStrength = 0.6; $0.roughness = 0.68
        },
        // Unfinished black walnut: chocolate with purple-grey streaks.
        MaterialSpec(key: "wood.lumber-walnut", program: .woodPlank).with {
            $0.colorA = linear(0x7A5638); $0.colorB = linear(0x3E2618); $0.knobs = V4(0, 0.65, 0, 0); $0.seed = 804
            $0.tileSize = 0.7; $0.normalStrength = 1.1; $0.roughness = 0.7
        },
        // Fresh-sawn end grain (pine): pale, tight rings, saw-blade roughness. Same disc mapping as wood.endgrain.
        MaterialSpec(key: "wood.endgrain-fresh", program: .woodEndGrain).with {
            $0.colorA = linear(0xE0C597); $0.colorB = linear(0xB08A5A); $0.colorC = linear(0xC9A06C, 0.55)
            $0.knobs = V4(30, 0.3, 0.4, 0); $0.seed = 805; $0.tileSize = 0.25; $0.resolution = 1024; $0.normalStrength = 1.6
            $0.roughness = 0.88
        },
        // Butcher-block maple workbench top: edge-glued strips under an oil finish.
        MaterialSpec(key: "wood.butcher-block", program: .woodPlank).with {
            $0.colorA = linear(0xDCC39A); $0.colorB = linear(0xA9875C); $0.knobs = V4(0.1, 0.5, 0, 0); $0.seed = 806
            $0.tileSize = 0.6; $0.normalStrength = 0.8; $0.roughness = 0.45; $0.clearcoat = 0.3
        },
        // Ground cast iron saw table: grey, fine circular grinding swirl streaks along U, waxed.
        MaterialSpec(key: "metal.machined", program: .brushedMetal).with {
            $0.colorA = linear(0x9EA1A3); $0.colorB = linear(0x6E7072)
            $0.knobs = V4(0.55, 0.34, 0.25, 0.15); $0.seed = 807; $0.tileSize = 0.25; $0.normalStrength = 0.25
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.34
        },
        // Saw blade plate steel: bright, faint radial grind (map U around the arbor).
        MaterialSpec(key: "metal.sawblade", program: .brushedMetal).with {
            $0.colorA = linear(0xC9CCCF); $0.colorB = linear(0x8F9295)
            $0.knobs = V4(0.7, 0.25, 0.1, 0.05); $0.seed = 808; $0.tileSize = 0.12; $0.normalStrength = 0.15
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.25
        },
        // Brazed tungsten carbide tips: dark grey, satin.
        MaterialSpec(key: "metal.carbide", program: nil).with { $0.baseColor = V3(0.2, 0.2, 0.21); $0.metallic = 1; $0.roughness = 0.4 },
        // Die-cast aluminum tool housings (saw shoes, motor housings), unpainted.
        MaterialSpec(key: "metal.diecast", program: .brushedMetal).with {
            $0.colorA = linear(0xA9ACAE); $0.colorB = linear(0x7C7F82)
            $0.knobs = V4(0.15, 0.5, 0.35, 0.25); $0.seed = 809; $0.tileSize = 0.2; $0.normalStrength = 0.4
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.5
        },
        // Glass-filled nylon tool body; tint with `:RRGGBB` (yellow F2B705, teal 1E7F8C, red C4241A).
        MaterialSpec(key: "plastic.tool", program: .plastic).with {
            $0.colorA = linear(0xF2B705); $0.knobs = V4(0.25, 0.25, 0.5, 0); $0.seed = 810; $0.tileSize = 0.15; $0.resolution = 512
            $0.normalStrength = 0.6
        },
        // Sealed shop concrete: grey with a light sawdust film and old stains.
        MaterialSpec(key: "concrete.shop", program: .concrete).with {
            $0.colorA = linear(0xA29E96); $0.colorB = linear(0x857C6E); $0.knobs = V4(0.55, 0.55, 0, 0); $0.seed = 811
            $0.tileSize = 2.0; $0.normalStrength = 1.2; $0.antiTile = true
        },
        // Loose sawdust and fine shavings.
        MaterialSpec(key: "wood.sawdust", program: .sand).with {
            $0.colorA = linear(0xE2C89A); $0.colorB = linear(0xB89466); $0.colorC = linear(0xF1E2C2)
            $0.knobs = V4(0.12, 0, 0.35, 12); $0.seed = 812; $0.tileSize = 0.4; $0.normalStrength = 2.5; $0.resolution = 1024
        },
        // Tempered hardboard (pegboard face, jig bases): brown, smooth, faint fibre mottling.
        MaterialSpec(key: "wood.hardboard", program: .concrete).with {
            $0.colorA = linear(0x8A6440); $0.colorB = linear(0x6E4C30); $0.knobs = V4(0.6, 0.25, 0, 0); $0.seed = 813
            $0.tileSize = 0.5; $0.normalStrength = 0.4
        },
        // realityhd:material.woodshop
    ]
}
