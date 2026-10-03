import RealCore

public extension MaterialLibrary {
    /// RealityHD 3 interior and craft materials: leather, brushed and polished metals, glazed ceramic,
    /// chair cane, fine hardwoods, chrome, powder coat. Tints replace colorA (`leather.tan:6B2A1E`).
    static let craft: [MaterialSpec] = [
        // Vegetable-tanned saddle leather, pebble grain, rubbed lighter on wear.
        MaterialSpec(key: "leather.tan", program: .leather).with {
            $0.colorA = linear(0x8A5530); $0.colorB = linear(0x3A2214); $0.colorC = linear(0xB98258)
            $0.knobs = V4(80, 0.5, 0.5, 0.18); $0.seed = 81; $0.tileSize = 0.16; $0.normalStrength = 1.6; $0.roughness = 0.52
        },
        // Oxblood club-chair leather, waxed, deep creases.
        MaterialSpec(key: "leather.oxblood", program: .leather).with {
            $0.colorA = linear(0x4E1A14); $0.colorB = linear(0x1E0A08); $0.colorC = linear(0x64291C)
            $0.knobs = V4(90, 0.35, 0.5, 0.45); $0.seed = 82; $0.tileSize = 0.2; $0.normalStrength = 2.2; $0.roughness = 0.5
        },
        // Black corrected-grain leather (straps, grips, cases).
        MaterialSpec(key: "leather.black", program: .leather).with {
            $0.colorA = linear(0x1C1A19); $0.colorB = linear(0x0A0909); $0.colorC = linear(0x3A3632)
            $0.knobs = V4(110, 0.3, 0.45, 0.2); $0.seed = 83; $0.tileSize = 0.2; $0.normalStrength = 1.2; $0.roughness = 0.45
        },
        // Polished yellow brass with light tarnish (hardware, latches, instruments).
        MaterialSpec(key: "metal.brass", program: .polishedMetal).with {
            $0.colorA = linear(0xD9B263); $0.colorB = linear(0x6E5328); $0.colorC = linear(0x4F8A6E)
            $0.knobs = V4(0.25, 0.0, 0, 0.22); $0.seed = 84; $0.tileSize = 0.3; $0.normalStrength = 0.6
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.22
        },
        // Old brass: brown tarnish, verdigris in patches (ship fittings, antique hardware).
        MaterialSpec(key: "metal.brass-aged", program: .polishedMetal).with {
            $0.colorA = linear(0xC9A256); $0.colorB = linear(0x4E3A1C); $0.colorC = linear(0x5E9A7E)
            $0.knobs = V4(0.7, 0.25, 0, 0.35); $0.seed = 85; $0.tileSize = 0.3; $0.normalStrength = 0.8
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.35
        },
        // Hand-hammered copper, warm polish with light tarnish (kettles, pans).
        MaterialSpec(key: "metal.copper", program: .polishedMetal).with {
            $0.colorA = linear(0xD98A5E); $0.colorB = linear(0x6A3220); $0.colorC = linear(0x58A08A)
            $0.knobs = V4(0.5, 0.04, 26, 0.22); $0.seed = 86; $0.tileSize = 0.35; $0.normalStrength = 1.2
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.2
        },
        // Weathered copper: dark tarnish with verdigris (roof flashing, outdoor fittings).
        MaterialSpec(key: "metal.copper-patina", program: .polishedMetal).with {
            $0.colorA = linear(0xB87452); $0.colorB = linear(0x3E2218); $0.colorC = linear(0x62A68E)
            $0.knobs = V4(0.85, 0.6, 0, 0.45); $0.seed = 87; $0.tileSize = 0.4; $0.normalStrength = 1
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.45
        },
        // Brushed aluminum, grain along U (drawer pulls, trims, appliance panels).
        MaterialSpec(key: "metal.aluminum-brushed", program: .brushedMetal).with {
            $0.colorA = linear(0xC4C7CA); $0.colorB = linear(0x8A8378)
            $0.knobs = V4(1, 0.3, 0.25, 0.3); $0.seed = 88; $0.tileSize = 0.3; $0.normalStrength = 0.4
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.3
        },
        // Brushed stainless steel, slightly darker and smoother than aluminum.
        MaterialSpec(key: "metal.stainless", program: .brushedMetal).with {
            $0.colorA = linear(0xA9ABAD); $0.colorB = linear(0x7E7870)
            $0.knobs = V4(0.8, 0.24, 0.35, 0.25); $0.seed = 89; $0.tileSize = 0.3; $0.normalStrength = 0.35
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.24
        },
        // Chrome plate, near-mirror.
        MaterialSpec(key: "metal.chrome", program: nil).with { $0.baseColor = V3(0.75, 0.76, 0.78); $0.metallic = 1; $0.roughness = 0.07 },
        // Satin powder coat: even color, few chips, light dirt. Tint: `metal.powdercoat:B3201C`.
        MaterialSpec(key: "metal.powdercoat", program: .paintedMetal).with {
            $0.colorA = linear(0xA8231C); $0.colorC = linear(0x8A8A86, 0.8); $0.knobs = V4(0.24, 0.35, 0.36, 0)
            $0.seed = 90; $0.tileSize = 0.8; $0.hasMetallicMap = true; $0.normalStrength = 0.8; $0.roughness = 0.42
        },
        // Cast iron, raw: black-grey mill finish with light surface rust (anchors, skillets, machine bases).
        MaterialSpec(key: "metal.cast-iron", program: .rustMetal).with {
            $0.colorA = linear(0x5A3220); $0.colorB = linear(0x22191A); $0.knobs = V4(0.35, 0, 0, 0); $0.seed = 91
            $0.tileSize = 0.5; $0.hasMetallicMap = true; $0.normalStrength = 2.5
        },
        // Salt-glazed stoneware: buff glaze with iron speckle, runs along V (lathe height).
        MaterialSpec(key: "ceramic.stoneware", program: .ceramicGlaze).with {
            $0.colorA = linear(0xC9B795); $0.colorB = linear(0x9C7E58); $0.colorC = linear(0x3A2A1E)
            $0.knobs = V4(0.35, 0.35, 0, 0.2); $0.seed = 92; $0.tileSize = 0.4; $0.normalStrength = 0.8
            $0.roughness = 0.18; $0.clearcoat = 0.4
        },
        // Cobalt-blue slip glaze for bands and lettering.
        MaterialSpec(key: "ceramic.cobalt", program: .ceramicGlaze).with {
            $0.colorA = linear(0x2A3E78); $0.colorB = linear(0x4A5C8E); $0.colorC = linear(0x14183A)
            $0.knobs = V4(0.2, 0.8, 0, 0.16); $0.seed = 93; $0.tileSize = 0.3; $0.normalStrength = 0.6
            $0.roughness = 0.16; $0.clearcoat = 0.4
        },
        // Celadon porcelain with fine crackle.
        MaterialSpec(key: "ceramic.celadon", program: .ceramicGlaze).with {
            $0.colorA = linear(0x9DB9A0); $0.colorB = linear(0x7E9A84); $0.colorC = linear(0x4A5A4C)
            $0.knobs = V4(0.05, 0.4, 0.6, 0.1); $0.seed = 94; $0.tileSize = 0.3; $0.normalStrength = 0.5
            $0.roughness = 0.1; $0.clearcoat = 0.6
        },
        // Unglazed terracotta / bisque foot ring.
        MaterialSpec(key: "ceramic.bisque", program: .ceramicGlaze).with {
            $0.colorA = linear(0xB88A62); $0.colorB = linear(0x9A6E4A); $0.colorC = linear(0x5A3A26)
            $0.knobs = V4(0.5, 0.5, 0, 0.82); $0.seed = 95; $0.tileSize = 0.3; $0.normalStrength = 1.2; $0.roughness = 0.82
        },
        // Hand-woven rattan chair cane, open octagonal weave (cutout, two-sided).
        MaterialSpec(key: "cane.woven", program: .caneWeave).with {
            $0.colorA = linear(0xD7B57A); $0.colorB = linear(0x8A6538)
            $0.knobs = V4(14, 0.16, 0.4, 0.15); $0.seed = 96; $0.tileSize = 0.18; $0.normalStrength = 2
            $0.mode = .cutout; $0.twoSided = true; $0.roughness = 0.4; $0.hasAOMap = true
        },
        // Steam-bent beech with walnut stain and satin lacquer (bentwood furniture). Grain along U.
        MaterialSpec(key: "wood.beech-stained", program: .woodPlank).with {
            $0.colorA = linear(0x74462A); $0.colorB = linear(0x2A150A); $0.knobs = V4(0.04, 0.42, 0, 0); $0.seed = 97
            $0.tileSize = 0.3; $0.normalStrength = 1.5; $0.clearcoat = 0.5
        },
        // Oiled American walnut.
        MaterialSpec(key: "wood.walnut", program: .woodPlank).with {
            $0.colorA = linear(0x6E4A30); $0.colorB = linear(0x2E1C12); $0.knobs = V4(0, 0.42, 0, 0); $0.seed = 98
            $0.tileSize = 0.9; $0.normalStrength = 1.0; $0.clearcoat = 0.3
        },
        // Polished mahogany (turned feet, frames).
        MaterialSpec(key: "wood.mahogany", program: .woodPlank).with {
            $0.colorA = linear(0x7A3A22); $0.colorB = linear(0x3A160C); $0.knobs = V4(0, 0.3, 0, 0); $0.seed = 99
            $0.tileSize = 0.7; $0.normalStrength = 0.8; $0.clearcoat = 0.6
        },
        // Peeled rattan / wicker strands: honey skin with nodes. Grain along U.
        MaterialSpec(key: "wood.rattan", program: .woodPlank).with {
            $0.colorA = linear(0xC99A5E); $0.colorB = linear(0x8A5E30); $0.knobs = V4(0.05, 0.5, 0, 0); $0.seed = 100
            $0.tileSize = 0.35; $0.normalStrength = 1.2
        },
        // Weathered granite with lichen and moss on top faces (garden stone, monuments).
        MaterialSpec(key: "stone.granite-moss", program: .rockGranite).with {
            $0.colorA = linear(0x8E8A82); $0.colorB = linear(0x5E5A54); $0.colorC = linear(0x2E2C2A)
            $0.knobs = V4(0.6, 0.5, 0, 0); $0.seed = 101; $0.tileSize = 0.5; $0.normalStrength = 1.6
            $0.triplanar = true; $0.topColor = linear(0x3E5420); $0.topAmount = 0.55; $0.topLow = 0.6; $0.roughness = 0.85
        },
        // Woven willow (stake-and-strand basketry), 8 mm rods, sun-faded honey with darker skins.
        MaterialSpec(key: "wicker.willow", program: .fabricWeave).with {
            $0.colorA = linear(0xC49A62); $0.colorB = linear(0xA97C48, 1); $0.colorC = linear(0x4A3622, 0.15)
            $0.knobs = V4(20, 0.25, 0.62, 0); $0.seed = 102; $0.tileSize = 0.16; $0.normalStrength = 4; $0.roughness = 0.62
        },
        // Vintage stove enamel over steel: chipped at edges and contact points, rubbed thin, dusty.
        // Tint: `metal.enamel:1B1B1C`.
        MaterialSpec(key: "metal.enamel", program: .paintedMetal).with {
            $0.colorA = linear(0x1B1B1C); $0.colorC = linear(0x6E6A64, 0.9); $0.knobs = V4(0.55, 0.45, 0.3, 0)
            $0.seed = 103; $0.tileSize = 0.5; $0.hasMetallicMap = true; $0.normalStrength = 1.2; $0.roughness = 0.3
        },
        // Seat-worn oxblood: lighter rubbed patches, deeper creases (cushions, arm tops).
        MaterialSpec(key: "leather.oxblood-worn", program: .leather).with {
            $0.colorA = linear(0x5A2018); $0.colorB = linear(0x1E0A08); $0.colorC = linear(0x7E4030)
            $0.knobs = V4(90, 0.75, 0.48, 0.75); $0.seed = 104; $0.tileSize = 0.22; $0.normalStrength = 2.2; $0.roughness = 0.48
        },
        // Old pine boards, grey-brown with soft weathering (lids, shelves, crates indoors).
        MaterialSpec(key: "wood.pine-aged", program: .woodPlank).with {
            $0.colorA = linear(0x8C7254); $0.colorB = linear(0x4E3C2A); $0.knobs = V4(0.3, 0.75, 0, 0); $0.seed = 105
            $0.tileSize = 0.6; $0.normalStrength = 1.6
        },
        // Warm tungsten filament bulb glow.
        MaterialSpec(key: "emissive.bulb", program: nil).with {
            $0.baseColor = V3(1, 0.92, 0.75); $0.mode = .emissive; $0.emissive = V3(1, 0.85, 0.6); $0.emissiveIntensity = 6
        },
        // realityhd:material.craft
    ]
}
