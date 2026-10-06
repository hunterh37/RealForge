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
        // Pegboard (pegboard-wall): tempered hardboard, 1/4 in holes on a 1 in grid (12 per 0.3048 m tile), satin face.
        MaterialSpec(key: "wood.pegboard", program: .pegboard).with {
            $0.colorA = linear(0x84603E); $0.colorB = linear(0x6A4B31); $0.colorC = linear(0x1C1712)
            $0.knobs = V4(12, 0.125, 0.5, 0.6); $0.seed = 871; $0.tileSize = 0.3048; $0.resolution = 1024; $0.normalStrength = 1.2
            $0.roughness = 0.5
        },
        // Fire extinguisher label band (fire-extinguisher): white film, red band, greeked instructions and a barcode.
        MaterialSpec(key: "label.fire-extinguisher", program: .medLabel).with {
            $0.colorA = linear(0xF2F0EA); $0.colorB = linear(0xC4241A); $0.colorC = linear(0x1A1A1C)
            $0.knobs = V4(0.22, 1, 6, 0.7); $0.seed = 872; $0.tileSize = 1; $0.resolution = 512; $0.normalStrength = 0.1
        },
        // Cordless tool rubber overmold (cordless-drill, random-orbit-sander, jigsaw): black TPE, fine 2 mm pebble, palm-polished patches.
        MaterialSpec(key: "rubber.cordless-grip", program: .leather).with {
            $0.colorA = linear(0x1E1E1F); $0.colorB = linear(0x0C0C0D); $0.colorC = linear(0x34302C)
            $0.knobs = V4(16, 0.35, 0.78, 0); $0.seed = 941; $0.tileSize = 0.032; $0.resolution = 512; $0.normalStrength = 1.1
        },
        // Cordless sander disc (random-orbit-sander): 120 grit aluminum oxide, red-brown, fine grit sparkle.
        MaterialSpec(key: "abrasive.cordless-disc-120", program: .sand).with {
            $0.colorA = linear(0x8E3E22); $0.colorB = linear(0x5E2814); $0.colorC = linear(0xC9A27A)
            $0.knobs = V4(0, 0, 0.25, 30); $0.seed = 942; $0.tileSize = 0.03; $0.resolution = 512; $0.normalStrength = 1.4
        },
        // Cordless sander dust canister (random-orbit-sander): smoked translucent polycarbonate.
        MaterialSpec(key: "plastic.cordless-smoke", program: nil).with {
            $0.baseColor = V3(0.32, 0.33, 0.34); $0.roughness = 0.12; $0.specular = 0.5; $0.mode = .transparent; $0.opacity = 0.42; $0.twoSided = true
        },
        // Hand-saw tote: lacquered apple/beech, warm red-brown. Splat = hand-worn patches (Surface.splat on the grip).
        MaterialSpec(key: "wood.saw-tote", program: .woodPlank).with {
            $0.colorA = linear(0x7E4A2C); $0.colorB = linear(0x3E1F10); $0.knobs = V4(0.05, 0.4, 0, 0); $0.seed = 841
            $0.tileSize = 0.25; $0.normalStrength = 1.2; $0.clearcoat = 0.45; $0.roughness = 0.4
            $0.splat = "wood.saw-tote-worn"; $0.splatSoftness = 0.3; $0.splatHeight = 0.8
        },
        // Hand-saw tote where the palm rides: lacquer gone, lighter, oily satin.
        MaterialSpec(key: "wood.saw-tote-worn", program: .woodPlank).with {
            $0.colorA = linear(0xA36E46); $0.colorB = linear(0x6A3E22); $0.knobs = V4(0.3, 0.75, 0, 0); $0.seed = 842
            $0.tileSize = 0.25; $0.normalStrength = 1.4; $0.roughness = 0.6
        },
        // Hammer handle hickory: pale sapwood with tan heart streaks under a thin satin lacquer.
        MaterialSpec(key: "wood.hammer-hickory", program: .woodPlank).with {
            $0.colorA = linear(0xD9B98C); $0.colorB = linear(0x9C6E43); $0.knobs = V4(0.05, 0.45, 0, 0); $0.seed = 843
            $0.tileSize = 0.35; $0.normalStrength = 1.0; $0.clearcoat = 0.35; $0.roughness = 0.45
            $0.splat = "wood.hammer-hickory-grimy"; $0.splatSoftness = 0.35; $0.splatHeight = 0.8
        },
        // Hammer grip after years of hands: lacquer rubbed off, darker with hand oil and dirt.
        MaterialSpec(key: "wood.hammer-hickory-grimy", program: .woodPlank).with {
            $0.colorA = linear(0x8E6A44); $0.colorB = linear(0x5A3C22); $0.knobs = V4(0.45, 0.75, 0, 0); $0.seed = 850
            $0.tileSize = 0.35; $0.normalStrength = 1.2; $0.roughness = 0.62
        },
        // Forged hammer head steel: polished then lightly oxidized, smudges, grind lines along U.
        MaterialSpec(key: "metal.hammer-forged", program: .brushedMetal).with {
            $0.colorA = linear(0xA2A6AA); $0.colorB = linear(0x5A5D60)
            $0.knobs = V4(0.45, 0.42, 0.5, 0.4); $0.seed = 844; $0.tileSize = 0.12; $0.normalStrength = 0.5
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.42
            $0.splat = "metal.hammer-polished"; $0.splatSoftness = 0.3; $0.splatHeight = 1.0
        },
        // Hammer head: black satin enamel over forged steel, chipped on the edges; splat = polished bright steel
        // (face end, claw tips) where the paint was ground off at the factory and worn off since.
        MaterialSpec(key: "metal.hammer-painted", program: .paintedMetal).with {
            $0.colorA = linear(0x1C1D1F); $0.colorC = linear(0x5A5650, 0.9); $0.knobs = V4(0.45, 0.3, 0.32, 0)
            $0.seed = 857; $0.tileSize = 0.15; $0.hasMetallicMap = true; $0.normalStrength = 0.9; $0.roughness = 0.32
            $0.splat = "metal.hammer-polished"; $0.splatSoftness = 0.25; $0.splatHeight = 0.6
        },
        // Hammer steel rubbed bright where it strikes and pulls nails (face rim, claw tips).
        MaterialSpec(key: "metal.hammer-polished", program: .brushedMetal).with {
            $0.colorA = linear(0x9EA2A6); $0.colorB = linear(0x6E7276)
            $0.knobs = V4(0.6, 0.2, 0.3, 0.5); $0.seed = 851; $0.tileSize = 0.08; $0.normalStrength = 0.4
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.2
        },
        // Chisel handle ash: pale, lacquered; splat = grime on the grip and bruised end grain at the strike end.
        MaterialSpec(key: "wood.chisel-ash", program: .woodPlank).with {
            $0.colorA = linear(0xD8BE92); $0.colorB = linear(0x9A7A4E); $0.knobs = V4(0.02, 0.38, 0, 0); $0.seed = 852
            $0.tileSize = 0.3; $0.normalStrength = 0.9; $0.roughness = 0.38; $0.clearcoat = 0.5
            $0.splat = "wood.chisel-ash-grimy"; $0.splatSoftness = 0.35; $0.splatHeight = 0.8
        },
        MaterialSpec(key: "wood.chisel-ash-grimy", program: .woodPlank).with {
            $0.colorA = linear(0x9E8158); $0.colorB = linear(0x5E4628); $0.knobs = V4(0.4, 0.7, 0, 0); $0.seed = 853
            $0.tileSize = 0.3; $0.normalStrength = 1.2; $0.roughness = 0.6
        },
        // Pencil lacquer: gloss enamel with handling scuffs and a little shop dirt. Tint with `:RRGGBB`.
        MaterialSpec(key: "plastic.pencil-lacquer", program: .plastic).with {
            $0.colorA = linear(0xC4241A); $0.knobs = V4(0.35, 0.3, 0.16, 0); $0.seed = 854; $0.tileSize = 0.12; $0.resolution = 512
            $0.normalStrength = 0.5; $0.clearcoat = 0.5
        },
        // Job-site tape case: yellow ABS with scuffs and ground-in dirt. Tint with `:RRGGBB`.
        MaterialSpec(key: "plastic.tape-case", program: .plastic).with {
            $0.colorA = linear(0xF0B408); $0.knobs = V4(0.75, 0.6, 0.5, 0); $0.seed = 855; $0.tileSize = 0.1; $0.resolution = 1024
            $0.normalStrength = 1.0
        },
        // Ground tool steel (chisel and plane irons): bright, fine grind scratches along U.
        MaterialSpec(key: "metal.tool-ground", program: .brushedMetal).with {
            $0.colorA = linear(0xBDC1C4); $0.colorB = linear(0x7F8386)
            $0.knobs = V4(0.8, 0.3, 0.25, 0.3); $0.seed = 845; $0.tileSize = 0.06; $0.normalStrength = 0.25
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.3
        },
        // Pencil slat cedar: pinkish tan, tight grain, knife-cut (no finish).
        MaterialSpec(key: "wood.pencil-cedar", program: .woodPlank).with {
            $0.colorA = linear(0xD8AE86); $0.colorB = linear(0xA8714E); $0.knobs = V4(0.1, 0.75, 0, 0); $0.seed = 846
            $0.tileSize = 0.12; $0.normalStrength = 1.6; $0.roughness = 0.8
        },
        // Pencil lead (graphite and clay): dark grey, waxy semi-metallic sheen.
        MaterialSpec(key: "graphite.pencil", program: nil).with { $0.baseColor = V3(0.05, 0.05, 0.055); $0.metallic = 0.45; $0.roughness = 0.42 },
        // Block plane body enamel: blue-grey stove enamel over cast iron, chipped on the edges. Tint with `:RRGGBB`.
        MaterialSpec(key: "metal.plane-japanned", program: .paintedMetal).with {
            $0.colorA = linear(0x3C4A58); $0.colorC = linear(0x55575A, 0.9); $0.knobs = V4(0.5, 0.35, 0.24, 0)
            $0.seed = 847; $0.tileSize = 0.25; $0.hasMetallicMap = true; $0.normalStrength = 0.9; $0.roughness = 0.25; $0.clearcoat = 0.3
            $0.splat = "metal.cast-iron"; $0.splatSoftness = 0.15; $0.splatHeight = 2.0
        },
        // Nickel-plated lever cap: satin, faint polishing swirls, palm smudges.
        MaterialSpec(key: "metal.plane-nickel", program: .brushedMetal).with {
            $0.colorA = linear(0xC4C1B8); $0.colorB = linear(0x8A877F)
            $0.knobs = V4(0.35, 0.36, 0.55, 0.35); $0.seed = 856; $0.tileSize = 0.12; $0.normalStrength = 0.3
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.34
        },
        // Tape-measure blade print (tapeRule): yellow lacquer, black 1/16 in graduations and inch numerals, red 16 in stud box.
        MaterialSpec(key: "label.tape-rule", program: .tapeRule).with {
            $0.colorA = linear(0xF2C318); $0.colorB = linear(0x111111); $0.colorC = linear(0xD0281E)
            $0.knobs = V4(0.28, 0.25, 1.0, 1.0); $0.seed = 848; $0.tileSize = 0.4064; $0.resolution = 2048
            $0.normalStrength = 0.3; $0.roughness = 0.28; $0.clearcoat = 0.4
        },
        // Bright zinc electroplate on screws and small hardware: bluish silver, fine draw lines along U.
        MaterialSpec(key: "metal.screw-zinc", program: .brushedMetal).with {
            $0.colorA = linear(0xB4BDC8); $0.colorB = linear(0x7E8894)
            $0.knobs = V4(0.35, 0.45, 0.35, 0.2); $0.seed = 861; $0.tileSize = 0.04; $0.normalStrength = 0.35
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.5
        },
        // Yellow zinc (dichromate) plate: brassy gold with olive patches.
        MaterialSpec(key: "metal.screw-zinc-yellow", program: .brushedMetal).with {
            $0.colorA = linear(0xD2B866); $0.colorB = linear(0x9A8448)
            $0.knobs = V4(0.35, 0.45, 0.3, 0.15); $0.seed = 862; $0.tileSize = 0.04; $0.normalStrength = 0.25
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.32
        },
        // Kraft corrugated board for small parts boxes: brown, fibrous mottling, matte.
        MaterialSpec(key: "paper.screwbox-kraft", program: .laminate).with {
            $0.colorA = linear(0xB98F5E); $0.knobs = V4(0.1, 1, 0.92, 0.35); $0.seed = 863
            $0.tileSize = 0.2; $0.resolution = 1024; $0.normalStrength = 0.22; $0.roughness = 0.9
        },
        // Dried yellow PVA glue: translucent amber, glossy skin.
        MaterialSpec(key: "plastic.glue-dried", program: .plastic).with {
            $0.colorA = linear(0xC28E2E); $0.knobs = V4(0.15, 0.1, 0.1, 0); $0.seed = 864; $0.tileSize = 0.05; $0.resolution = 256
            $0.normalStrength = 0.5; $0.roughness = 0.2; $0.clearcoat = 0.6
        },
        // Lumber grade stamp ink: faint blue-black, alpha-blended over the board face (`lumber` stamp glyphs).
        MaterialSpec(key: "wood.lumber-stamp", program: nil).with {
            $0.baseColor = V3(0.025, 0.035, 0.06); $0.roughness = 0.85; $0.mode = .transparent; $0.opacity = 0.62
        },
        // Hand-saw plate: cold-rolled spring steel, satin with long grind streaks along U and handling smudges.
        MaterialSpec(key: "metal.saw-plate", program: .brushedMetal).with {
            $0.colorA = linear(0xD2D5D8); $0.colorB = linear(0x8E9194)
            $0.knobs = V4(0.6, 0.5, 0.45, 0.3); $0.seed = 849; $0.tileSize = 0.3; $0.normalStrength = 0.2
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.5
        },
        // Painted CMU shop wall (woodshop scene): 400 x 200 mm blocks under two coats of off-white latex,
        // mortar joints still read as shallow grooves, slight block-to-block tone shift.
        MaterialSpec(key: "masonry.cmu-painted", program: .brick).with {
            $0.colorA = linear(0xE6E3DA); $0.colorB = linear(0xDDD9CF); $0.colorC = linear(0xE2DED4)
            $0.seed = 871; $0.tileSize = 0.8; $0.normalStrength = 0.6; $0.roughness = 0.82
        },
        // Plywood layout marks: soft graphite pencil, slightly glossy, alpha-blended (`plywood-sheet` cut lines).
        MaterialSpec(key: "wood.plywood-pencil", program: nil).with {
            $0.baseColor = V3(0.14, 0.14, 0.15); $0.roughness = 0.42; $0.mode = .transparent; $0.opacity = 0.7
        },
        // Worn cordless tool nylon (cordless-drill, random-orbit-sander, jigsaw battery packs and feet): heavy scuffs, shop grime; tint with `:RRGGBB`.
        MaterialSpec(key: "plastic.cordless-worn", program: .plastic).with {
            $0.colorA = linear(0x1A1A1B); $0.knobs = V4(1.0, 0.9, 0.55, 0); $0.seed = 943; $0.tileSize = 0.07; $0.resolution = 512
            $0.normalStrength = 0.8
        },
        // Fire extinguisher shell (fire-extinguisher): glossy red polyester powder coat, few chips, light dust.
        MaterialSpec(key: "metal.fire-extinguisher-red", program: .paintedMetal).with {
            $0.colorA = linear(0xB51D17); $0.colorC = linear(0x6E6A64, 0.9); $0.knobs = V4(0.08, 0.18, 0.18, 0)
            $0.seed = 873; $0.tileSize = 0.5; $0.hasMetallicMap = true; $0.normalStrength = 0.5; $0.roughness = 0.2; $0.clearcoat = 0.5
        },
        // First aid cabinet label (first-aid-kit): white film, green band, two greeked lines.
        MaterialSpec(key: "label.first-aid", program: .medLabel).with {
            $0.colorA = linear(0xF4F4F0); $0.colorB = linear(0x2E8A4A); $0.colorC = linear(0x1A1A1C)
            $0.knobs = V4(0.3, 0, 2, 0.7); $0.seed = 874; $0.tileSize = 1; $0.resolution = 256; $0.normalStrength = 0.1
        },
        // Table saw top (table-saw): waxed ground cast iron, satin grey, grinding swirl, less mirror than metal.machined.
        MaterialSpec(key: "metal.table-saw-iron", program: .brushedMetal).with {
            $0.colorA = linear(0xC2C5C7); $0.colorB = linear(0x8E9194)
            $0.knobs = V4(0.55, 0.34, 0.25, 0.15); $0.seed = 875; $0.tileSize = 0.25; $0.normalStrength = 0.3
            $0.hasMetallicMap = true; $0.metallic = 0.55; $0.roughness = 0.42
        },
        // Light surface rust bloom on cast iron (table-saw): a can ring and drips left on a wing.
        MaterialSpec(key: "metal.table-saw-rust", program: .rustMetal).with {
            $0.colorA = linear(0x8A4A26); $0.colorB = linear(0x5A3018); $0.knobs = V4(0.3, 0, 0, 0)
            $0.seed = 876; $0.tileSize = 0.2; $0.hasMetallicMap = true; $0.normalStrength = 0.6
        },
        // Bright zinc-plated clamp bar stock: silver with a faint blue cast, rolling streaks along U.
        MaterialSpec(key: "metal.clamp-bar", program: .brushedMetal).with {
            $0.colorA = linear(0xBCC2C8); $0.colorB = linear(0x8B9299)
            $0.knobs = V4(0.5, 0.35, 0.25, 0.15); $0.seed = 865; $0.tileSize = 0.3; $0.normalStrength = 0.3
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.36
        },
        // Polycarbonate safety lens: clear with a faint grey-blue body, glossy hard coat.
        MaterialSpec(key: "plastic.lens-clear", program: nil).with {
            $0.baseColor = V3(0.78, 0.82, 0.85); $0.roughness = 0.03; $0.specular = 0.6; $0.mode = .transparent; $0.opacity = 0.3; $0.twoSided = true
        },
        // Cordless tool housing nylon with a fine molded stipple (cordless-drill, random-orbit-sander, jigsaw); tint with `:RRGGBB`.
        MaterialSpec(key: "plastic.cordless-stipple", program: .leather).with {
            $0.colorA = linear(0x1E7F8C); $0.colorB = linear(0x303436); $0.colorC = linear(0x8A9496)
            $0.knobs = V4(40, 0.18, 0.46, 0); $0.seed = 944; $0.tileSize = 0.05; $0.resolution = 512; $0.normalStrength = 0.35
        },
        // Masking tape owner label (cordless family battery packs).
        MaterialSpec(key: "paper.cordless-tape", program: .plastic).with {
            $0.colorA = linear(0xD8C9A2); $0.knobs = V4(0.6, 0.7, 0.85, 0); $0.seed = 945; $0.tileSize = 0.05; $0.resolution = 256; $0.normalStrength = 0.6
        },
        // Lumber rack steel: black powder coat, scuffed to bare steel where boards slide, light shop grime.
        MaterialSpec(key: "metal.rack-powdercoat", program: .paintedMetal).with {
            $0.colorA = linear(0x232629); $0.colorC = linear(0x7C7B78, 0.85); $0.knobs = V4(0.5, 0.4, 0.5, 0)
            $0.seed = 841; $0.tileSize = 0.45; $0.hasMetallicMap = true; $0.normalStrength = 0.9; $0.roughness = 0.5
        },
        // Shop vacuum drum label (shop-vac): black film, yellow warning band, white greeked specs.
        MaterialSpec(key: "label.shop-vac", program: .medLabel).with {
            $0.colorA = linear(0x1E1E20); $0.colorB = linear(0xE8B21C); $0.colorC = linear(0xE6E6E2)
            $0.knobs = V4(0.18, 0, 4, 0.6); $0.seed = 875; $0.tileSize = 1; $0.resolution = 512; $0.normalStrength = 0.1
        },
        // Shop light housing (shop-light): white powder-coated steel with sawdust settled on the upward faces
        // (topLow is high because the ShaderGraph mask adds the bright paint's luminance).
        MaterialSpec(key: "metal.shop-light-white", program: .paintedMetal).with {
            $0.colorA = linear(0xEDEDE8); $0.colorC = linear(0x9A9A96, 0.6); $0.knobs = V4(0.05, 0.35, 0.34, 0)
            $0.seed = 876; $0.tileSize = 0.8; $0.hasMetallicMap = true; $0.normalStrength = 0.5; $0.roughness = 0.38
            $0.topColor = linear(0x6A5C46); $0.topAmount = 0.7; $0.topLow = 2.45
        },
        // realityhd:material.woodshop
    ]
}
