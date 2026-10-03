import RealCore

public extension MaterialLibrary {
    /// Construction and farm materials: plywood, galvanized steel, safety plastics, straw, painted boards, jute.
    static let industrial: [MaterialSpec] = [
        /// Sheathing plywood face, rotary-cut fir veneer with oval patches. Grain along U.
        MaterialSpec(key: "wood.plywood", program: .plywood).with {
            $0.colorA = linear(0xD6B888); $0.colorB = linear(0xA77445); $0.colorC = linear(0x4A3420)
            $0.knobs = V4(0, 0, 0.7, 0); $0.seed = 21; $0.tileSize = 1.2; $0.normalStrength = 1.5; $0.roughness = 0.75
        },
        /// Plywood edge: 7 plies across V; one V repeat is 18 mm, so map V 0...thickness onto the edge band.
        MaterialSpec(key: "wood.plywood-edge", program: .plywood).with {
            $0.colorA = linear(0xD2B285); $0.colorB = linear(0x9C6C40); $0.colorC = linear(0x3A2A1A)
            $0.knobs = V4(1, 7, 0, 0); $0.seed = 22; $0.tileSize = 0.018; $0.resolution = 512; $0.normalStrength = 1
            $0.roughness = 0.85
        },
        /// Fresh hot-dip galvanized steel: bright spangle, low roughness.
        MaterialSpec(key: "metal.galvanized", program: .galvanized).with {
            $0.colorA = linear(0xB9BCBF); $0.colorB = linear(0xC8C8C2); $0.colorC = linear(0x4A4036)
            $0.knobs = V4(0.15, 0.15, 16, 0); $0.seed = 31; $0.tileSize = 0.3; $0.normalStrength = 0.6
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.35
        },
        /// Aged galvanized steel: dull zinc, white rust blooms, dirt (troughs, cans, buckets).
        MaterialSpec(key: "metal.galvanized-aged", program: .galvanized).with {
            $0.colorA = linear(0xA4A7A8); $0.colorB = linear(0xBDBDB5); $0.colorC = linear(0x4E4234)
            $0.knobs = V4(0.35, 0.3, 12, 0); $0.seed = 32; $0.tileSize = 0.35; $0.normalStrength = 0.8
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.55
        },
        MaterialSpec(key: "plastic.yellow", program: .plastic).with {
            $0.colorA = linear(0xE3A913); $0.knobs = V4(0.5, 0.35, 0.4, 0); $0.tileSize = 0.5; $0.resolution = 512; $0.seed = 12
        },
        /// Worn tire rubber with dust settling on upward faces.
        MaterialSpec(key: "rubber.tire", program: .plastic).with {
            $0.colorA = linear(0x1A1A19); $0.knobs = V4(0.5, 0.7, 0.88, 0); $0.tileSize = 0.4; $0.resolution = 512; $0.seed = 14
            $0.topColor = linear(0x6E6252); $0.topAmount = 0.45; $0.topLow = 0.5
        },
        /// Baled hay: golden strands with some green stems. Strands run along U.
        MaterialSpec(key: "straw.hay", program: .straw).with {
            $0.colorA = linear(0xDDBC72); $0.colorB = linear(0x8E8848); $0.colorC = linear(0x9C968A)
            $0.knobs = V4(0.1, 0.15, 0, 1); $0.seed = 41; $0.tileSize = 0.45; $0.normalStrength = 3; $0.roughness = 0.75
        },
        /// Field-stored round bale surface: weathered straw under white net wrap.
        MaterialSpec(key: "straw.hay-net", program: .straw).with {
            $0.colorA = linear(0xCDB070); $0.colorB = linear(0x8A8247); $0.colorC = linear(0x8A857A)
            $0.knobs = V4(0.35, 0.1, 0.55, 0); $0.seed = 42; $0.tileSize = 0.6; $0.normalStrength = 3; $0.roughness = 0.8
        },
        /// Barn red oxide paint over weathered boards, chalked and peeling along the grain.
        MaterialSpec(key: "wood.barn-red", program: .paintedWood).with {
            $0.colorA = linear(0x7E2A1E); $0.colorB = linear(0x8A7E6C); $0.colorC = linear(0x3A3128)
            $0.knobs = V4(0.42, 0.45, 0.72, 0); $0.seed = 51; $0.tileSize = 1.0; $0.normalStrength = 2.5; $0.roughness = 0.75
        },
        /// White trim paint on boards, same weathering as barn red.
        MaterialSpec(key: "wood.barn-white", program: .paintedWood).with {
            $0.colorA = linear(0xD9D5C9); $0.colorB = linear(0x8A7E6C); $0.colorC = linear(0x3A3128)
            $0.knobs = V4(0.28, 0.2, 0.68, 0); $0.seed = 52; $0.tileSize = 1.0; $0.normalStrength = 2.5; $0.roughness = 0.7
        },
        /// Jute sacking (burlap), plain weave about 2 threads per cm.
        MaterialSpec(key: "sack.jute", program: .jute).with {
            $0.colorA = linear(0xA88B5E); $0.colorB = linear(0x4A3B28); $0.colorC = linear(0x8A6E46)
            $0.knobs = V4(0, 0.2, 48, 0); $0.seed = 61; $0.tileSize = 0.25; $0.normalStrength = 1.8; $0.roughness = 0.92
        },
        /// Rebar and reinforcing mesh: dark mill scale with orange flash rust.
        MaterialSpec(key: "metal.rebar", program: .rustMetal).with {
            $0.colorA = linear(0x5E3A24); $0.colorB = linear(0x2A2420); $0.knobs = V4(0.25, 0, 0, 0); $0.seed = 71
            $0.tileSize = 0.4; $0.hasMetallicMap = true; $0.normalStrength = 2.5
        },
        // realityhd:material.industrial
    ]
}
