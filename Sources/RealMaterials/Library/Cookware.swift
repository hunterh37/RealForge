import RealCore

public extension MaterialLibrary {
    /// Cookware and kitchen tools: butcher block, tri-ply and pan-interior stainless, heat tint, seasoned
    /// cast iron, knife steel, POM handles, sheet-pan aluminum, measuring glass.
    static let cookware: [MaterialSpec] = [
        // End-grain butcher block: maple and walnut checker, 3.75 cm blocks, knife scoring, oiled.
        MaterialSpec(key: "wood.butcher-block", program: .butcherBlock).with {
            $0.colorA = linear(0xD9BC8E); $0.colorB = linear(0x5C3B25); $0.colorC = linear(0x3A2818)
            $0.knobs = V4(8, 14, 0.6, 0.62); $0.seed = 1201; $0.tileSize = 0.3; $0.resolution = 2048; $0.normalStrength = 1.2
            $0.roughness = 0.62
        },
        // Tri-ply exterior: brushed 18/10 stainless, spin streaks along U (circumferential on a lathe).
        MaterialSpec(key: "metal.tri-ply", program: .brushedMetal).with {
            $0.colorA = linear(0xB4B6B8); $0.colorB = linear(0x7E786E)
            $0.knobs = V4(1, 0.2, 0.3, 0.3); $0.seed = 1202; $0.tileSize = 0.25; $0.normalStrength = 0.4
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.2
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
        // Seasoned cast iron: black satin polymerized oil over 1.8 mm sand-cast pebble, rubbed spots, carbon.
        MaterialSpec(key: "metal.cast-iron-seasoned", program: .seasonedIron).with {
            $0.colorA = linear(0x1E1D1C); $0.colorB = linear(0x5E5650); $0.colorC = linear(0x2C1E14)
            $0.knobs = V4(110, 0.5, 0.35, 0.42); $0.seed = 1205; $0.tileSize = 0.2; $0.resolution = 2048; $0.normalStrength = 1.4
            $0.hasMetallicMap = true; $0.metallic = 0.2; $0.roughness = 0.42
        },
        // Knife blade: satin stainless with grind lines along U (blade length).
        MaterialSpec(key: "metal.knife-blade", program: .brushedMetal).with {
            $0.colorA = linear(0xBEC1C4); $0.colorB = linear(0x8A8780)
            $0.knobs = V4(1.4, 0.2, 0.15, 0.35); $0.seed = 1206; $0.tileSize = 0.1; $0.normalStrength = 0.5
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.2
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
