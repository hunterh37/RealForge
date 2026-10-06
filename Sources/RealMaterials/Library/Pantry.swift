import RealCore

public extension MaterialLibrary {
    /// Pantry staples seen as surfaces inside bowls, cups and pans (RealCook.fill): flour, sugar, milk,
    /// oil, melted butter, chocolate. Cookable ones carry a `cooked` look for the cook shader.
    static let pantry: [MaterialSpec] = [
        /// Sifted all-purpose flour: matte, fine soft grain, faint warm cast.
        MaterialSpec(key: "food.flour", program: .pantryFill).with {
            $0.colorA = linear(0xEFEAE0); $0.colorB = linear(0xD9D2C4); $0.colorC = linear(0xF7F4EE)
            $0.knobs = V4(48, 0, 0, 0); $0.seed = 4101; $0.tileSize = 0.05; $0.normalStrength = 0.8; $0.resolution = 512
            $0.roughness = 0.95; $0.baseColor = V3(0.86, 0.83, 0.77)
        },
        /// Granulated sugar: sparkling crystals.
        MaterialSpec(key: "food.sugar", program: .pantryFill).with {
            $0.colorA = linear(0xF4F2EE); $0.colorB = linear(0xC9C7C2); $0.colorC = linear(0xFFFFFF)
            $0.knobs = V4(96, 1, 0, 0); $0.seed = 4102; $0.tileSize = 0.03; $0.normalStrength = 2.6; $0.resolution = 512
            $0.roughness = 0.35; $0.specular = 0.7; $0.baseColor = V3(0.9, 0.89, 0.87)
        },
        /// Whole milk: opaque, slightly blue-white, glossy.
        MaterialSpec(key: "food.milk", program: nil).with {
            $0.baseColor = V3(0.86, 0.87, 0.85); $0.roughness = 0.12; $0.specular = 0.5; $0.clearcoat = 0.4
        },
        /// Neutral cooking oil: thin transparent gold.
        MaterialSpec(key: "food.oil", program: nil).with {
            $0.baseColor = V3(0.72, 0.52, 0.08); $0.roughness = 0.03; $0.specular = 0.6; $0.mode = .transparent; $0.opacity = 0.32
        },
        /// Melted butter pool: foaming gold, browns to nutty beurre noisette in the cook shader.
        MaterialSpec(key: "food.butter-melted", program: .pantryFill).with {
            $0.colorA = linear(0xE8C463); $0.colorB = linear(0xD2A43C); $0.colorC = linear(0xF6E6B0)
            $0.knobs = V4(40, 0, 0.6, 0.35); $0.seed = 4103; $0.tileSize = 0.08; $0.normalStrength = 0.6; $0.resolution = 512
            $0.roughness = 0.1; $0.clearcoat = 0.6; $0.baseColor = V3(0.8, 0.6, 0.2)
            $0.cooked = "food.butter-browned"
        },
        MaterialSpec(key: "food.butter-browned", program: .pantryFill).with {
            $0.colorA = linear(0xB8782E); $0.colorB = linear(0x7A4A1C); $0.colorC = linear(0xD9A25A)
            $0.knobs = V4(40, 0, 0.5, 0.5); $0.seed = 4104; $0.tileSize = 0.08; $0.normalStrength = 0.9; $0.resolution = 512
            $0.roughness = 0.12; $0.clearcoat = 0.5; $0.baseColor = V3(0.5, 0.28, 0.1)
        },
        /// Beaten egg: glossy yellow, sets to a pale curd.
        MaterialSpec(key: "food.egg-beaten", program: .pantryFill).with {
            $0.colorA = linear(0xF0B832); $0.colorB = linear(0xE2A21E); $0.colorC = linear(0xF8D46A)
            $0.knobs = V4(32, 0, 0.7, 0.1); $0.seed = 4105; $0.tileSize = 0.06; $0.normalStrength = 0.4; $0.resolution = 512
            $0.roughness = 0.08; $0.clearcoat = 0.7; $0.baseColor = V3(0.85, 0.6, 0.12)
            $0.cooked = "food.egg-curd"
        },
        MaterialSpec(key: "food.egg-curd", program: .pantryFill).with {
            $0.colorA = linear(0xF6D46E); $0.colorB = linear(0xE9BE4E); $0.colorC = linear(0xFBE7A6)
            $0.knobs = V4(24, 0.2, 0, 0.3); $0.seed = 4106; $0.tileSize = 0.04; $0.normalStrength = 2.2; $0.resolution = 512
            $0.roughness = 0.55; $0.baseColor = V3(0.9, 0.75, 0.35)
        },
        /// Creamed butter and sugar / cookie dough base.
        MaterialSpec(key: "food.creamed", program: .pantryFill).with {
            $0.colorA = linear(0xE9D3A0); $0.colorB = linear(0xD3B676); $0.colorC = linear(0xF5E8C8)
            $0.knobs = V4(28, 0.3, 0.4, 0.2); $0.seed = 4107; $0.tileSize = 0.05; $0.normalStrength = 1.6; $0.resolution = 512
            $0.roughness = 0.6; $0.baseColor = V3(0.82, 0.68, 0.42)
        },
        /// Melted dark chocolate.
        MaterialSpec(key: "food.chocolate-melted", program: .pantryFill).with {
            $0.colorA = linear(0x3A1F12); $0.colorB = linear(0x26130A); $0.colorC = linear(0x5A3420)
            $0.knobs = V4(32, 0, 0.8, 0); $0.seed = 4108; $0.tileSize = 0.08; $0.normalStrength = 0.3; $0.resolution = 512
            $0.roughness = 0.12; $0.clearcoat = 0.8; $0.baseColor = V3(0.12, 0.06, 0.03)
        },
        /// Water in a pot (seen from above: dark, reflective).
        MaterialSpec(key: "food.water", program: nil).with {
            $0.baseColor = V3(0.75, 0.82, 0.86); $0.roughness = 0.02; $0.specular = 0.6; $0.mode = .transparent; $0.opacity = 0.22
        },
    ]
}
