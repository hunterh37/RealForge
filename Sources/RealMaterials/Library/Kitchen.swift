import RealCore

public extension MaterialLibrary {
    /// RealityHD 6 kitchen: counters, backsplash, cabinet paint, fixtures, gas flame, floor.
    static let kitchen: [MaterialSpec] = [
        // Engineered quartz counter (white with soft grey veining): fine quartz-grain speckle, polished.
        MaterialSpec(key: "stone.quartz", program: .quartzSlab).with {
            $0.colorA = linear(0xEDEBE6); $0.colorB = linear(0xB9B8B4, 0.35); $0.colorC = linear(0xC9C6C0, 0.55)
            $0.knobs = V4(260, 0.35, 0.035, 0.15); $0.seed = 601; $0.tileSize = 1.0; $0.resolution = 2048
            $0.normalStrength = 0.15; $0.roughness = 0.15; $0.clearcoat = 0.6
        },
        // Glazed white subway tile, 7.5 x 15 cm in running bond, 2 mm grout (2 x 4 tiles per 30 cm repeat).
        MaterialSpec(key: "tile.subway", program: .subwayTile).with {
            $0.colorA = linear(0xF1F0EB); $0.colorB = linear(0xC9C5BC); $0.colorC = linear(0x8F8574, 0.18)
            $0.knobs = V4(2, 4, 0.0067, 0.035); $0.seed = 602; $0.tileSize = 0.3; $0.resolution = 1024
            $0.normalStrength = 1.2; $0.roughness = 0.08; $0.clearcoat = 0.5
        },
        // Satin painted shaker cabinetry (sprayed lacquer over MDF/maple): no grain telegraph, light
        // brush texture only. Tint for color: `wood.painted-shaker:9AA58E` (sage).
        MaterialSpec(key: "wood.painted-shaker", program: .paintedWood).with {
            $0.colorA = linear(0xEEECE6); $0.colorB = linear(0xC9B79A); $0.colorC = linear(0x8C8172, 0.05)
            $0.knobs = V4(0, 0.02, 0.36, 1); $0.seed = 603; $0.tileSize = 1.0; $0.normalStrength = 0.25; $0.roughness = 0.36
            $0.clearcoat = 0.15
        },
        // Handled shaker paint (drawer fronts, toe kicks): same finish with soft handling grime and a
        // little more sheen where hands polish it. Tint like `wood.painted-shaker`.
        MaterialSpec(key: "wood.painted-shaker-worn", program: .paintedWood).with {
            $0.colorA = linear(0xEEECE6); $0.colorB = linear(0xC9B79A); $0.colorC = linear(0x8C8172, 0.12)
            $0.knobs = V4(0, 0.02, 0.33, 1); $0.seed = 607; $0.tileSize = 0.6; $0.normalStrength = 0.25; $0.roughness = 0.33
            $0.clearcoat = 0.15
        },
        // Brushed nickel: warm grey satin, fine grain along U, faint fingerprints.
        MaterialSpec(key: "metal.brushed-nickel", program: .brushedMetal).with {
            $0.colorA = linear(0xB4AEA3); $0.colorB = linear(0x857D70)
            $0.knobs = V4(0.7, 0.28, 0.3, 0.2); $0.seed = 604; $0.tileSize = 0.2; $0.normalStrength = 0.3
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.28
        },
        // Natural gas flame crown: blue inner cones, violet-blue mantle, occasional orange tips. Atlas UVs
        // (u around the burner 0...1, v port to tip 0...1, one repeat); alpha-blended unlit emitter.
        MaterialSpec(key: "emissive.flame", program: .gasFlame).with {
            $0.colorA = linear(0x9CC8FF); $0.colorB = linear(0x2648E8); $0.colorC = linear(0xFF9A3C)
            $0.knobs = V4(36, 0.35, 0.8, 0.5); $0.seed = 605; $0.tileSize = 1; $0.resolution = 512
            $0.mode = .emissive; $0.emissive = V3(0.3, 0.45, 1); $0.emissiveIntensity = 1; $0.opacity = 0.99
            $0.twoSided = true; $0.hasAOMap = false; $0.normalStrength = 0
        },
        // Engineered white oak plank floor, 15 cm boards, satin lacquer, micro-bevelled seams.
        MaterialSpec(key: "floor.oak-plank", program: .plankFloor).with {
            $0.colorA = linear(0xC9A77E); $0.colorB = linear(0x9C7A55); $0.colorC = linear(0x3A2A1C)
            $0.knobs = V4(14, 0.34, 0.24, 0.0012); $0.seed = 606; $0.tileSize = 2.1; $0.resolution = 2048
            $0.normalStrength = 1.2; $0.roughness = 0.36; $0.clearcoat = 0.2; $0.antiTile = true
        },
        // Appliance stainless around the controls: fingerprints and cooking grease films, warmer haze.
        MaterialSpec(key: "metal.stainless-smudged", program: .brushedMetal).with {
            $0.colorA = linear(0xA7A8A9); $0.colorB = linear(0x6F675B)
            $0.knobs = V4(0.8, 0.27, 0.9, 0.35); $0.seed = 608; $0.tileSize = 0.25; $0.normalStrength = 0.35
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.27
        },
        // Matte black enamel-coated cast iron (burner grates): satin, a few rubbed high spots.
        MaterialSpec(key: "metal.grate-iron", program: .paintedMetal).with {
            $0.colorA = linear(0x1A1919); $0.colorC = linear(0x4A4744, 0.6); $0.knobs = V4(0.1, 0.5, 0.55, 0)
            $0.seed = 609; $0.tileSize = 0.3; $0.normalStrength = 1.6; $0.roughness = 0.55
        },
        // Black porcelain cooktop enamel: glossy, faint orange peel. Tint for color.
        MaterialSpec(key: "metal.cooktop-enamel", program: .paintedMetal).with {
            $0.colorA = linear(0x121213); $0.colorC = linear(0x1C1C1D, 0.4); $0.knobs = V4(0.0, 0.2, 0.25, 0)
            $0.seed = 610; $0.tileSize = 0.5; $0.normalStrength = 0.5; $0.roughness = 0.16; $0.clearcoat = 0.7
        },
        // Oven liner: blue-grey speckled porcelain enamel.
        MaterialSpec(key: "metal.oven-enamel", program: .paintedMetal).with {
            $0.colorA = linear(0x262C3A); $0.colorC = linear(0x8A8F99, 0.5); $0.knobs = V4(0.0, 0.3, 0.4, 0)
            $0.seed = 611; $0.tileSize = 0.3; $0.normalStrength = 0.8; $0.roughness = 0.35
        },
        // Tinted oven-door glass: dark smoked, glossy.
        MaterialSpec(key: "glass.oven", program: nil).with {
            $0.baseColor = V3(0.02, 0.02, 0.022); $0.roughness = 0.03; $0.specular = 0.5; $0.mode = .transparent; $0.opacity = 0.62; $0.twoSided = true
        },
        // Vitreous china / porcelain tableware: bright white glaze, glossy, no crackle.
        MaterialSpec(key: "ceramic.vitreous", program: .ceramicGlaze).with {
            $0.colorA = linear(0xF4F3EF); $0.colorB = linear(0xE6E5E0); $0.colorC = linear(0xC9C6BE, 0.1)
            $0.knobs = V4(0.05, 0.15, 0, 0.05); $0.seed = 612; $0.tileSize = 0.3; $0.normalStrength = 0.3; $0.roughness = 0.05; $0.clearcoat = 0.8
        },
        // realityhd:material.kitchen
    ]
}
