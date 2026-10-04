import RealCore

public extension MaterialLibrary {
    /// RealityHD 4 interiors: office floors, ceilings, walls, veneers, laminates, glass, screens, paper,
    /// stone and facade materials. Tints replace colorA (`carpet.tile:4A4E54`, `paint.wall:D8D2C6`).
    static let office: [MaterialSpec] = [
        // Loop-pile nylon carpet tile: 2 x 2 tiles of 50 cm per repeat, laid quarter-turn, heathered charcoal
        // with blue-grey yarn and rare rust flecks, multi-level streak pattern, cut seams. Tint for color.
        MaterialSpec(key: "carpet.tile", program: .carpetTile).with {
            $0.colorA = linear(0x55575B); $0.colorB = linear(0x44484F, 0.4); $0.colorC = linear(0x7A5A44, 0.015)
            $0.knobs = V4(120, 0.7, 0.96, 0); $0.seed = 401; $0.tileSize = 1.0; $0.resolution = 2048; $0.normalStrength = 3; $0.roughness = 0.96
        },
        // Cut-pile wool rug, plush with pile shading. Border band (knobs.w) needs one tile across the rug. Tint for color.
        MaterialSpec(key: "carpet.rug", program: .carpetPile).with {
            $0.colorA = linear(0x7A6450); $0.colorB = linear(0x6A5442, 0.35); $0.colorC = linear(0x3A2C22)
            $0.knobs = V4(150, 0.8, 0.98, 0); $0.seed = 402; $0.tileSize = 0.5; $0.normalStrength = 3; $0.roughness = 0.98
        },
        // Mineral-fiber acoustic ceiling tile, fissured with pinholes, 60 cm (grid is geometry).
        MaterialSpec(key: "ceiling.acoustic", program: .acousticTile).with {
            $0.colorA = linear(0xE4E2DC); $0.colorB = linear(0x8E8A82); $0.knobs = V4(0.8, 0.35, 0.95, 0.15); $0.seed = 403
            $0.tileSize = 0.6; $0.normalStrength = 2.5; $0.roughness = 0.95
        },
        // Eggshell latex paint on drywall: faint roller stipple and lap sheen. Tint for color.
        MaterialSpec(key: "paint.wall", program: .paintedWall).with {
            $0.colorA = linear(0xDDD8CE); $0.knobs = V4(0.6, 0.6, 0.78, 0); $0.seed = 404; $0.tileSize = 1.2; $0.normalStrength = 0.35; $0.roughness = 0.78
        },
        // Flat-cut white oak veneer, satin lacquer: cathedrals, ring-porous earlywood, ray flecks, book-matched
        // leaves every 15 cm across V. Grain along U.
        MaterialSpec(key: "wood.veneer-oak", program: .woodVeneer).with {
            $0.colorA = linear(0xC9A27A); $0.colorB = linear(0x9A7450); $0.colorC = linear(0x6E5034, 0.18)
            $0.knobs = V4(28, 10, 1, 8); $0.seed = 405; $0.tileSize = 1.2; $0.resolution = 2048; $0.normalStrength = 0.6; $0.roughness = 0.42; $0.clearcoat = 0.2
        },
        // Flat-cut walnut veneer, satin lacquer: diffuse-porous, darker cathedrals, leaves every 15 cm. Grain along U.
        MaterialSpec(key: "wood.veneer-walnut", program: .woodVeneer).with {
            $0.colorA = linear(0x7A5238); $0.colorB = linear(0x4A3020); $0.colorC = linear(0x2E1C12, 0)
            $0.knobs = V4(24, 9, 0.4, 8); $0.seed = 406; $0.tileSize = 1.2; $0.resolution = 2048; $0.normalStrength = 0.5; $0.roughness = 0.4; $0.clearcoat = 0.35
        },
        // Matte high-pressure laminate (desk tops, cabinet carcasses): fine suede emboss. Tint for color.
        MaterialSpec(key: "laminate.white", program: .laminate).with {
            $0.colorA = linear(0xE4E2DC); $0.knobs = V4(0.5, 0, 0.45, 0); $0.seed = 407; $0.tileSize = 0.4; $0.resolution = 1024; $0.normalStrength = 0.35; $0.roughness = 0.45
        },
        // Matte textured ABS (monitors, keyboards, phones). Tint for color.
        MaterialSpec(key: "plastic.matte", program: .plastic).with {
            $0.colorA = linear(0x2A2B2D); $0.knobs = V4(0.2, 0.2, 0.55, 0); $0.seed = 408; $0.tileSize = 0.2; $0.resolution = 512; $0.normalStrength = 0.8
        },
        // Glossy molded plastic (white appliances, water cooler).
        MaterialSpec(key: "plastic.gloss", program: .plastic).with {
            $0.colorA = linear(0xEDEBE6); $0.knobs = V4(0.1, 0.05, 0.12, 0); $0.seed = 409; $0.tileSize = 0.5; $0.resolution = 512; $0.normalStrength = 0.2; $0.clearcoat = 0.6
        },
        // Silver anodized aluminum (frames, chair bases, laptop bodies).
        MaterialSpec(key: "metal.anodized", program: .brushedMetal).with {
            $0.colorA = linear(0xB8BABD); $0.colorB = linear(0x8C8C8A)
            $0.knobs = V4(0.4, 0.38, 0.15, 0.1); $0.seed = 410; $0.tileSize = 0.3; $0.normalStrength = 0.2
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.38
        },
        // Black anodized aluminum (window frames, mullions, trims).
        MaterialSpec(key: "metal.anodized-black", program: .brushedMetal).with {
            $0.colorA = linear(0x2A2B2D); $0.colorB = linear(0x1A1A1B)
            $0.knobs = V4(0.3, 0.42, 0.15, 0.08); $0.seed = 411; $0.tileSize = 0.3; $0.normalStrength = 0.2
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.42
        },
        // Elastomeric chair mesh, black: glossy monofilaments along V, fine weft, open gaps (opaque, dark gaps).
        MaterialSpec(key: "fabric.mesh", program: .chairMesh).with {
            $0.colorA = linear(0x2A2B2E); $0.colorB = linear(0x1C1D1F); $0.colorC = linear(0x050505)
            $0.knobs = V4(40, 0.5, 0.45, 3); $0.seed = 412; $0.tileSize = 0.08; $0.normalStrength = 2.5; $0.roughness = 0.5
        },
        // Tight woven upholstery (chair seats, sofas, acoustic panels). Tint for color.
        MaterialSpec(key: "fabric.upholstery", program: .fabricWeave).with {
            $0.colorA = linear(0x3C3F44); $0.colorB = linear(0x2E3034, 0.6); $0.colorC = linear(0x201C18, 0.05)
            $0.knobs = V4(48, 0.6, 0.94, 0); $0.seed = 413; $0.tileSize = 0.05; $0.normalStrength = 2.4; $0.roughness = 0.94
        },
        // Clear float glass, faint green edge tint.
        MaterialSpec(key: "glass.clear", program: nil).with {
            $0.baseColor = V3(0.8, 0.86, 0.84); $0.roughness = 0.02; $0.specular = 0.5; $0.mode = .transparent; $0.opacity = 0.12; $0.twoSided = true
        },
        // Acid-etched (frosted) glass: privacy bands and partitions.
        MaterialSpec(key: "glass.frosted", program: nil).with {
            $0.baseColor = V3(0.9, 0.92, 0.92); $0.roughness = 0.45; $0.specular = 0.4; $0.mode = .transparent; $0.opacity = 0.7; $0.twoSided = true
        },
        // Curtain-wall insulated glazing: grey-blue tint, high reflectance.
        MaterialSpec(key: "glass.curtain", program: nil).with {
            $0.baseColor = V3(0.07, 0.1, 0.13); $0.roughness = 0.02; $0.specular = 1; $0.metallic = 0.6; $0.mode = .transparent; $0.opacity = 0.8; $0.twoSided = true
        },
        // Cased emerald glass (banker's lamp shade): deep green, glossy.
        MaterialSpec(key: "glass.emerald", program: nil).with {
            $0.baseColor = V3(0.02, 0.16, 0.06); $0.roughness = 0.05; $0.specular = 0.6; $0.clearcoat = 1
        },
        // Opal diffuser (lamp shade lining, LED panels when off).
        MaterialSpec(key: "plastic.diffuser", program: nil).with { $0.baseColor = V3(0.82, 0.82, 0.8); $0.roughness = 0.35 },
        // Lit LED panel / opal diffuser, 4000 K.
        MaterialSpec(key: "emissive.panel", program: nil).with {
            $0.baseColor = V3(0.95, 0.95, 0.92); $0.mode = .emissive; $0.emissive = V3(1, 0.97, 0.9); $0.emissiveIntensity = 3
        },
        // Lit push-button ring (elevator call, indicator).
        MaterialSpec(key: "emissive.indicator", program: nil).with {
            $0.baseColor = V3(1, 0.85, 0.6); $0.mode = .emissive; $0.emissive = V3(1, 0.62, 0.25); $0.emissiveIntensity = 4
        },
        // Display panel switched off: glossy black glass.
        MaterialSpec(key: "screen.off", program: nil).with { $0.baseColor = V3(0.012, 0.013, 0.015); $0.roughness = 0.06; $0.specular = 0.6; $0.clearcoat = 1 },
        // Display panel showing a desktop (emissive texture): wallpaper, menu bar, dock, spreadsheet, code editor
        // and messages windows. UVs: 0...1 across a 16:10 screen, v up the panel (tileSize 1 = one image per UV unit).
        MaterialSpec(key: "screen.ui", program: .screenUI).with {
            $0.colorA = linear(0x1A2A66); $0.colorB = linear(0x7A5AA8); $0.colorC = linear(0xF0A6C8)
            $0.knobs = V4(0.7, 0, 0, 0); $0.seed = 414; $0.tileSize = 1; $0.resolution = 2048
            $0.mode = .emissive; $0.emissive = V3(1, 1, 1); $0.emissiveIntensity = 0.92; $0.roughness = 0.35; $0.specular = 0.15
        },
        // Uncoated office paper: formation flocs, faint emboss. Tint for color.
        MaterialSpec(key: "paper.sheet", program: .laminate).with {
            $0.colorA = linear(0xEEEDE8); $0.knobs = V4(0.15, 1, 0.9, 0.2); $0.seed = 415; $0.tileSize = 0.3; $0.resolution = 1024; $0.normalStrength = 0.4; $0.roughness = 0.9
        },
        // Page block edges: 100 stacked sheets per V tile (tileSize 0.01 = 1 cm of pages), lines along U.
        MaterialSpec(key: "paper.pages", program: .pageEdge).with {
            $0.colorA = linear(0xECE6D6); $0.colorB = linear(0x9C9280); $0.colorC = linear(0xB4A88E)
            $0.knobs = V4(100, 0.35, 1, 0.5); $0.seed = 416; $0.tileSize = 0.01; $0.normalStrength = 0.8; $0.roughness = 0.9
        },
        // Bookcloth over board covers: fine sized plain weave. Tint for color.
        MaterialSpec(key: "book.cloth", program: .fabricWeave).with {
            $0.colorA = linear(0x2E4A6A); $0.colorB = linear(0x26405C, 0.5); $0.colorC = linear(0x1A1410, 0.1)
            $0.knobs = V4(70, 0.25, 0.78, 0); $0.seed = 417; $0.tileSize = 0.03; $0.normalStrength = 1.2; $0.roughness = 0.78
        },
        // Polished Carrara-type marble: soft grey branching veins over cloudy white.
        MaterialSpec(key: "stone.marble", program: .marble).with {
            $0.colorA = linear(0xE8E7E3); $0.colorB = linear(0x929498); $0.colorC = linear(0xD2D3D4, 0.3)
            $0.knobs = V4(1, 0.45, 0.02, 0.08); $0.seed = 418; $0.tileSize = 1.2; $0.resolution = 2048; $0.normalStrength = 0.1; $0.roughness = 0.08; $0.clearcoat = 0.8
        },
        // Polished Nero Marquina: black ground with crisp white calcite veins (reception counters).
        MaterialSpec(key: "stone.marble-dark", program: .marble).with {
            $0.colorA = linear(0x1C1C1E); $0.colorB = linear(0xD8D6D0); $0.colorC = linear(0x262628, 0.2)
            $0.knobs = V4(1, 0.4, 0.014, 0.07); $0.seed = 419; $0.tileSize = 1.2; $0.resolution = 2048; $0.normalStrength = 0.1; $0.roughness = 0.07; $0.clearcoat = 0.8
        },
        // Ground and polished terrazzo: grey cement with white, grey and charcoal marble chips (5-20 mm).
        MaterialSpec(key: "stone.terrazzo", program: .terrazzo).with {
            $0.colorA = linear(0xB8B4AC); $0.colorB = linear(0x7C7A76); $0.colorC = linear(0x34322F, 0.35)
            $0.knobs = V4(60, 0.55, 0.2, 0.35); $0.seed = 420; $0.tileSize = 1.0; $0.resolution = 2048; $0.normalStrength = 0.3; $0.roughness = 0.2; $0.clearcoat = 0.5
        },
        // Large-format concrete pavers, 4 x 4 slabs of 60 cm per repeat, sand joints, weathered.
        MaterialSpec(key: "paving.slab", program: .pavers).with {
            $0.colorA = linear(0xA8A49C); $0.colorB = linear(0x6E6A62); $0.colorC = linear(0x8E8270)
            $0.knobs = V4(4, 1, 0.8, 0.01); $0.seed = 421; $0.tileSize = 2.4; $0.resolution = 2048; $0.normalStrength = 1.5; $0.roughness = 0.88
        },
        // Snake plant leaf: dark green with grey-green zigzag cross bands and a yellow margin ('Laurentii').
        // UVs: u 0...1 across the leaf width, v 0...1 base to tip (tileSize 1). knobs.w = margin width (0 = none).
        MaterialSpec(key: "leaf.sansevieria", program: .sansevieria).with {
            $0.colorA = linear(0x22381E); $0.colorB = linear(0x6E8466); $0.colorC = linear(0xC8BC58)
            $0.knobs = V4(18, 1.1, 0.42, 0.06); $0.seed = 422; $0.tileSize = 1; $0.resolution = 1024; $0.normalStrength = 0.6; $0.roughness = 0.42
        },
        // Potting mix: dark peat crumbs, bark flakes, white perlite.
        MaterialSpec(key: "soil.potting", program: .pottingSoil).with {
            $0.colorA = linear(0x3A2A1E); $0.colorB = linear(0x5A3A24); $0.colorC = linear(0xD8D6D0)
            $0.knobs = V4(0.12, 0.3, 0.4, 150); $0.seed = 423; $0.tileSize = 0.3; $0.normalStrength = 3; $0.roughness = 0.9
        },
        // realityhd:material.office
    ]
}
