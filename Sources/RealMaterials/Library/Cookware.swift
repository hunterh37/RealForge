import RealCore

public extension MaterialLibrary {
    /// Cookware and kitchen tools: butcher block, tri-ply and pan-interior stainless, heat tint, seasoned
    /// cast iron, knife steel, POM handles, sheet-pan aluminum, measuring glass.
    static let cookware: [MaterialSpec] = [
        // End-grain butcher block: maple and walnut checker, 3.75 cm blocks, knife scoring, oiled.
        MaterialSpec(key: "wood.butcher-block", program: .butcherBlock).with {
            $0.colorA = linear(0xC9A676); $0.colorB = linear(0x4A3020); $0.colorC = linear(0x2E2016)
            $0.knobs = V4(12, 18, 0.8, 0.62); $0.seed = 1201; $0.tileSize = 0.45; $0.resolution = 2048; $0.normalStrength = 0.8
            $0.roughness = 0.62
        },
        // Butcher-block edges: the same blocks seen from the side, long grain running up the face.
        MaterialSpec(key: "wood.butcher-block-side", program: .butcherBlock).with {
            $0.colorA = linear(0xC4A272); $0.colorB = linear(0x4A3020); $0.colorC = linear(0x2E2016, 1)
            $0.knobs = V4(8, 40, 0.1, 0.6); $0.seed = 1201; $0.tileSize = 0.3; $0.resolution = 1024; $0.normalStrength = 1
            $0.roughness = 0.6
        },
        // Oiled walnut for tool handles: matte, darker, tight grain.
        MaterialSpec(key: "wood.walnut-oiled", program: .woodPlank).with {
            $0.colorA = linear(0x5A3C28); $0.colorB = linear(0x24160E); $0.knobs = V4(0, 0.55, 0, 0); $0.seed = 1214
            $0.tileSize = 0.35; $0.normalStrength = 1.2; $0.roughness = 0.55
        },
        // Tri-ply exterior: brushed 18/10 stainless, spin streaks along U (circumferential on a lathe).
        MaterialSpec(key: "metal.tri-ply", program: .brushedMetal).with {
            $0.colorA = linear(0xB4B6B8); $0.colorB = linear(0x7E786E)
            $0.knobs = V4(1, 0.2, 0.3, 0.3); $0.seed = 1202; $0.tileSize = 0.25; $0.normalStrength = 0.4
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.2
        },
        // Mirror-polished stainless exterior (stock pots, bowls): faint polishing swirl and smudges.
        MaterialSpec(key: "metal.mirror-polish", program: .brushedMetal).with {
            $0.colorA = linear(0xC6C8CA); $0.colorB = linear(0x8A847A)
            $0.knobs = V4(0.25, 0.07, 0.4, 0.25); $0.seed = 1213; $0.tileSize = 0.25; $0.normalStrength = 0.15
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.07
        },
        // Pan interior: polished stainless with a fine satin spin swirl (lathe U runs around the pan),
        // utensil scratches and cooking smudges.
        MaterialSpec(key: "metal.pan-interior", program: .brushedMetal).with {
            $0.colorA = linear(0xC8CACC); $0.colorB = linear(0x8C7E6A)
            $0.knobs = V4(1.3, 0.3, 0.45, 0.7); $0.seed = 1203; $0.tileSize = 0.12; $0.normalStrength = 0.3
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.3
        },
        // Pan floor: interior stainless with a faint gold oil-polymer ring 3 cm in from the floor edge
        // (floor lathes run from the edge, v = 0, to the axis) and utensil scratches.
        MaterialSpec(key: "metal.pan-floor", program: .heatTint).with {
            $0.colorA = linear(0xC6C8CA); $0.colorB = linear(0x8C7E6A); $0.colorC = linear(0x000000, 0.8)
            $0.knobs = V4(0.32, 0.15, 0.8, 0.28); $0.seed = 1209; $0.tileSize = 0.2; $0.normalStrength = 0.3
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.28
        },
        // Heat-tinted stainless for pan bases: gold to blue oxide band across V (lathe radius).
        MaterialSpec(key: "metal.heat-tint", program: .heatTint).with {
            $0.colorA = linear(0xB0B2B4); $0.colorB = linear(0x6E665A)
            $0.knobs = V4(0.75, 0.2, 1, 0.24); $0.seed = 1204; $0.tileSize = 0.5; $0.normalStrength = 0.35
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.24
        },
        // Light heat tint for tall pots: a narrow straw-to-violet ring 8 cm along V (base edge, lower wall).
        MaterialSpec(key: "metal.heat-tint-light", program: .heatTint).with {
            $0.colorA = linear(0xB2B4B6); $0.colorB = linear(0x6E665A)
            $0.knobs = V4(0.45, 0.24, 1, 0.24); $0.seed = 1212; $0.tileSize = 0.35; $0.normalStrength = 0.35
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.24
        },
        // Seasoned cast iron: black satin polymerized oil over 1.8 mm sand-cast pebble, rubbed spots, carbon.
        MaterialSpec(key: "metal.cast-iron-seasoned", program: .seasonedIron).with {
            $0.colorA = linear(0x181716); $0.colorB = linear(0x4A4440); $0.colorC = linear(0x2C1E14)
            $0.knobs = V4(150, 0.4, 0.35, 0.48); $0.seed = 1205; $0.tileSize = 0.2; $0.resolution = 2048; $0.normalStrength = 0.9
            $0.hasMetallicMap = true; $0.metallic = 0.2; $0.roughness = 0.42
        },
        // Seasoned cast-iron cooking floor: years of use flatten the pebble and build a glossier film.
        MaterialSpec(key: "metal.cast-iron-floor", program: .seasonedIron).with {
            $0.colorA = linear(0x1C1B1A); $0.colorB = linear(0x4A433E); $0.colorC = linear(0x2E2015)
            $0.knobs = V4(160, 0.4, 0.45, 0.32); $0.seed = 1210; $0.tileSize = 0.2; $0.resolution = 2048; $0.normalStrength = 0.8
            $0.hasMetallicMap = true; $0.metallic = 0.2; $0.roughness = 0.32
        },
        // Rubbed cast iron (rim, handle top): seasoning worn thin, grey iron sheen through it.
        MaterialSpec(key: "metal.cast-iron-worn", program: .seasonedIron).with {
            $0.colorA = linear(0x262423); $0.colorB = linear(0x6A625C); $0.colorC = linear(0x2C1E14)
            $0.knobs = V4(110, 0.85, 0.1, 0.36); $0.seed = 1211; $0.tileSize = 0.2; $0.resolution = 1024; $0.normalStrength = 1.2
            $0.hasMetallicMap = true; $0.metallic = 0.3; $0.roughness = 0.36
        },
        // Knife blade: satin stainless with grind lines along U (blade length).
        MaterialSpec(key: "metal.knife-blade", program: .brushedMetal).with {
            $0.colorA = linear(0xBEC1C4); $0.colorB = linear(0x8A8780)
            $0.knobs = V4(1.6, 0.28, 0.2, 0.4); $0.seed = 1206; $0.tileSize = 0.1; $0.normalStrength = 0.5
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.28
        },
        // Black POM (acetal) knife handle: fine satin, faint handling scuffs.
        MaterialSpec(key: "plastic.pom", program: .plastic).with {
            $0.colorA = linear(0x1C1B1A); $0.knobs = V4(0.25, 0.12, 0.36, 0); $0.seed = 1207; $0.tileSize = 0.1
            $0.resolution = 512; $0.normalStrength = 0.6; $0.roughness = 0.36
        },
        // Half-sheet aluminum: mill finish under amber baked-on oil film with darker carbon spots.
        MaterialSpec(key: "metal.sheet-pan", program: .polishedMetal).with {
            $0.colorA = linear(0xC6C5C0); $0.colorB = linear(0x9C6C32); $0.colorC = linear(0x3E2716)
            $0.knobs = V4(0.6, 0.3, 0, 0.34); $0.seed = 1208; $0.tileSize = 0.35; $0.normalStrength = 0.6
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.34
        },
        // Borosilicate measuring glass: faint blue-green edge tint, high gloss.
        MaterialSpec(key: "glass.measuring", program: nil).with {
            $0.baseColor = V3(0.82, 0.9, 0.9); $0.roughness = 0.03; $0.specular = 0.5; $0.mode = .transparent; $0.opacity = 0.16; $0.twoSided = true
        },
        // Fired-on red enamel for measuring marks.
        MaterialSpec(key: "paint.measure-red", program: nil).with {
            $0.baseColor = V3(0.62, 0.04, 0.03); $0.roughness = 0.3; $0.specular = 0.5
        },
    ]
}
