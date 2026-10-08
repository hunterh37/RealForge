import RealCore

public extension MaterialLibrary {
    /// Work truck materials: automotive gloss white with clearcoat, fiberglass gelcoat, truck tire rubber,
    /// cab dash plastic, seat vinyl, rubber floor mat, smoked window glass.
    static let vehicle: [MaterialSpec] = [
        /// Fleet white automotive paint over steel: high-gloss clearcoat, fine stone chips and road dirt.
        MaterialSpec(key: "paint.truck-white", program: .paintedMetal).with {
            $0.colorA = linear(0xEDEEEA); $0.colorC = linear(0x6E6A62, 0.6); $0.knobs = V4(0.06, 0.35, 0.1, 0)
            $0.seed = 1101; $0.tileSize = 1.2; $0.hasMetallicMap = true; $0.normalStrength = 0.25; $0.roughness = 0.12; $0.clearcoat = 1
            $0.antiTile = true
        },
        /// Painted steel utility body: white enamel, less gloss than the cab, scuffs near handles.
        MaterialSpec(key: "paint.body-white", program: .paintedMetal).with {
            $0.colorA = linear(0xE8E9E4); $0.colorC = linear(0x6A655C, 0.7); $0.knobs = V4(0.14, 0.5, 0.22, 0)
            $0.seed = 1102; $0.tileSize = 1.0; $0.hasMetallicMap = true; $0.normalStrength = 0.35; $0.roughness = 0.22; $0.clearcoat = 0.6
            $0.antiTile = true
        },
        /// Insulated boom fiberglass: white gelcoat, glossy, faint fiber print and grime streaks.
        MaterialSpec(key: "fiberglass.boom", program: .plastic).with {
            $0.colorA = linear(0xEAE8DE); $0.knobs = V4(0.12, 0.3, 0.18, 0); $0.seed = 1103; $0.tileSize = 0.6
            $0.normalStrength = 0.3; $0.roughness = 0.2; $0.clearcoat = 0.8
        },
        /// One-man bucket fiberglass: yellow-white gelcoat, scuffed by boots and tools. Tint for color.
        MaterialSpec(key: "fiberglass.bucket", program: .plastic).with {
            $0.colorA = linear(0xE4E4DE); $0.knobs = V4(0.45, 0.55, 0.32, 0); $0.seed = 1104; $0.tileSize = 0.4
            $0.normalStrength = 0.5; $0.roughness = 0.32; $0.clearcoat = 0.4
        },
        /// Truck tire rubber: near black, matte, light road dust on the shoulders.
        MaterialSpec(key: "rubber.truck-tire", program: .plastic).with {
            $0.colorA = linear(0x1C1C1B); $0.knobs = V4(0.35, 0.45, 0.85, 0); $0.tileSize = 0.3; $0.resolution = 512; $0.seed = 1105
            $0.normalStrength = 0.8; $0.roughness = 0.88; $0.topColor = linear(0x5E584E); $0.topAmount = 0.4; $0.topLow = 0.55
        },
        /// Molded dash plastic: dark charcoal, fine stipple grain, satin.
        MaterialSpec(key: "plastic.dash", program: .leather).with {
            $0.colorA = linear(0x2E2F31); $0.colorB = linear(0x232426); $0.colorC = linear(0x3A3B3D)
            $0.knobs = V4(60, 0.1, 0.62, 0); $0.seed = 1106; $0.tileSize = 0.05; $0.resolution = 512; $0.normalStrength = 0.6; $0.roughness = 0.62
        },
        /// Grey seat vinyl, pebbled, worn on the bolster.
        MaterialSpec(key: "vinyl.seat-grey", program: .leather).with {
            $0.colorA = linear(0x55585C); $0.colorB = linear(0x3C3F42); $0.colorC = linear(0x6E7276)
            $0.knobs = V4(40, 0.3, 0.55, 0.3); $0.seed = 1107; $0.tileSize = 0.12; $0.resolution = 512; $0.normalStrength = 0.8; $0.roughness = 0.55
        },
        /// Ribbed rubber floor mat with dirt.
        MaterialSpec(key: "rubber.floor-mat", program: .plastic).with {
            $0.colorA = linear(0x262624); $0.knobs = V4(0.4, 0.7, 0.8, 0); $0.tileSize = 0.4; $0.resolution = 512; $0.seed = 1108
            $0.normalStrength = 0.8; $0.roughness = 0.85; $0.topColor = linear(0x6A5E4C); $0.topAmount = 0.3; $0.topLow = 0.7
        },
        /// Tinted automotive glass (side and rear windows).
        MaterialSpec(key: "glass.tinted", program: nil).with {
            $0.baseColor = V3(0.12, 0.14, 0.15); $0.roughness = 0.04; $0.specular = 0.6; $0.mode = .transparent; $0.opacity = 0.55; $0.twoSided = true
        },
    ]
}
