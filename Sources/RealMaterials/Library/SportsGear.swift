import RealCore

public extension MaterialLibrary {
    /// Baseball gear: ball hide and seam thread, bat woods, helmet shell, base canvas, plate rubber.
    static let sportsGear: [MaterialSpec] = [
        // Baseball cowhide: white alum-tanned leather, fine grain, rubbed with mud.
        MaterialSpec(key: "leather.baseball", program: .leather).with {
            $0.colorA = linear(0xE4DDCC); $0.colorB = linear(0xA89C84); $0.colorC = linear(0xC8B89A)
            $0.knobs = V4(110, 0.55, 0.55, 0.05); $0.seed = 331; $0.tileSize = 0.06; $0.normalStrength = 0.55; $0.roughness = 0.58
        },
        // Red waxed cotton seam thread.
        MaterialSpec(key: "thread.red", program: .fabricWeave).with {
            $0.colorA = linear(0xB0201C); $0.colorB = linear(0x8A1814, 0.1); $0.colorC = linear(0x5A1410, 0.2)
            $0.knobs = V4(40, 0.3, 0.7, 0); $0.seed = 333; $0.tileSize = 0.01; $0.normalStrength = 2; $0.roughness = 0.7
        },
        // Northern white ash bat billet, natural lacquer finish. Grain along U.
        MaterialSpec(key: "wood.ash-bat", program: .woodPlank).with {
            $0.colorA = linear(0xD8BE92); $0.colorB = linear(0x9A7A4E)
            $0.knobs = V4(0, 0.35, 0, 0); $0.seed = 335; $0.tileSize = 0.5; $0.normalStrength = 0.8
            $0.roughness = 0.35; $0.clearcoat = 0.6
        },
        // Hard maple bat, two-tone black barrel lacquer finish. Grain along U.
        MaterialSpec(key: "wood.maple-bat", program: .woodPlank).with {
            $0.colorA = linear(0x2A1E16); $0.colorB = linear(0x140E0A)
            $0.knobs = V4(0, 0.25, 0, 0); $0.seed = 337; $0.tileSize = 0.5; $0.normalStrength = 0.5
            $0.roughness = 0.25; $0.clearcoat = 0.8
        },
        // Glossy ABS helmet shell (tint for team color), light scuffs.
        MaterialSpec(key: "plastic.helmet", program: .plastic).with {
            $0.colorA = linear(0x1A2A4E); $0.knobs = V4(0.9, 0.3, 0.12, 0); $0.seed = 339; $0.tileSize = 0.3
            $0.resolution = 512; $0.roughness = 0.15; $0.clearcoat = 1
            $0.splat = "tar.pine"; $0.splatSoftness = 0.45; $0.splatHeight = 1.2
        },
        // Base cover: white vinyl-coated canvas, scuffed with infield clay.
        MaterialSpec(key: "fabric.base", program: .fabricWeave).with {
            $0.colorA = linear(0xE6E3DA); $0.colorB = linear(0xC9C2B2, 0.1); $0.colorC = linear(0x8A6A52, 0.35)
            $0.knobs = V4(40, 0.5, 0.75, 0); $0.seed = 341; $0.tileSize = 0.05; $0.normalStrength = 0.8; $0.roughness = 0.7
        },
        // Home plate and pitching rubber: whitened rubber with a dusty top.
        MaterialSpec(key: "rubber.plate", program: .plastic).with {
            $0.colorA = linear(0xDCD8CE); $0.knobs = V4(0.9, 1.0, 0.8, 0); $0.seed = 343; $0.tileSize = 0.25; $0.normalStrength = 1.5
            $0.resolution = 512; $0.roughness = 0.8
        },
        // Home plate body: black rubber bevel, dusty with clay.
        MaterialSpec(key: "rubber.plate-body", program: .plastic).with {
            $0.colorA = linear(0x1E1D1C); $0.knobs = V4(0.5, 0.75, 0.85, 0); $0.seed = 345; $0.tileSize = 0.3
            $0.resolution = 512; $0.roughness = 0.85
        },
        // Natural hard maple (two-tone bat handle), clear lacquer. Grain along U.
        MaterialSpec(key: "wood.maple-natural", program: .woodPlank).with {
            $0.colorA = linear(0xE6D2AE); $0.colorB = linear(0xB89A6E)
            $0.knobs = V4(0, 0.3, 0, 0); $0.seed = 347; $0.tileSize = 0.5; $0.normalStrength = 0.5
            $0.roughness = 0.3; $0.clearcoat = 0.7
        },
        // Pine tar smeared on a bat handle: sticky dark amber-brown.
        MaterialSpec(key: "tar.pine", program: .leather).with {
            $0.colorA = linear(0x2E1B0D); $0.colorB = linear(0x170D06); $0.colorC = linear(0x4A2E16)
            $0.knobs = V4(60, 0.6, 0.4, 0.2); $0.seed = 349; $0.tileSize = 0.08; $0.normalStrength = 0.4; $0.roughness = 0.4
        },
        // Off-white waxed polyester thread (base seams).
        MaterialSpec(key: "thread.white", program: .fabricWeave).with {
            $0.colorA = linear(0xE2DED2); $0.colorB = linear(0xBDB6A6, 0.1); $0.colorC = linear(0x8A7A66, 0.2)
            $0.knobs = V4(40, 0.3, 0.7, 0); $0.seed = 351; $0.tileSize = 0.01; $0.normalStrength = 2; $0.roughness = 0.7
        },
        // 5-gallon HDPE bucket: off-white, scuffed, clay-dirty.
        MaterialSpec(key: "plastic.bucket", program: .plastic).with {
            $0.colorA = linear(0xE2DFD4); $0.knobs = V4(1.0, 1.0, 0.5, 0); $0.seed = 353; $0.tileSize = 0.35
            $0.resolution = 512; $0.normalStrength = 1.2; $0.roughness = 0.5
            $0.splat = "fabric.base-clay"; $0.splatSoftness = 0.3; $0.splatHeight = 0.6
        },
        // Helmet liner: black closed-cell foam, fine pores, matte.
        MaterialSpec(key: "foam.liner", program: .leather).with {
            $0.colorA = linear(0x1A1A1C); $0.colorB = linear(0x0C0C0D); $0.colorC = linear(0x2A2A2C)
            $0.knobs = V4(90, 0.2, 0.92, 0); $0.seed = 355; $0.tileSize = 0.05; $0.normalStrength = 1.2; $0.roughness = 0.92
        },
        // Base cover sides after slides: canvas rubbed with red-brown infield clay.
        MaterialSpec(key: "fabric.base-clay", program: .fabricWeave).with {
            $0.colorA = linear(0xC9B8A4); $0.colorB = linear(0xB09A84, 0.1); $0.colorC = linear(0x8A5E44, 0.6)
            $0.knobs = V4(40, 0.5, 0.75, 0); $0.seed = 357; $0.tileSize = 0.05; $0.normalStrength = 1.4; $0.roughness = 0.8
        },
        // Base cover with clay painted in through Surface.splat (weight 1 = fabric.base-clay).
        MaterialSpec(key: "fabric.base-dusty", program: .fabricWeave).with {
            $0.colorA = linear(0xE6E3DA); $0.colorB = linear(0xC9C2B2, 0.1); $0.colorC = linear(0x8A6A52, 0.35)
            $0.knobs = V4(40, 0.5, 0.75, 0); $0.seed = 341; $0.tileSize = 0.05; $0.normalStrength = 0.8; $0.roughness = 0.7
            $0.splat = "fabric.base-clay"; $0.splatSoftness = 0.3; $0.splatHeight = 0.8
        },
        // Practice ball: hide greyed by clay and grass, scuffed.
        MaterialSpec(key: "leather.baseball-dirty", program: .leather).with {
            $0.colorA = linear(0xCDC2AA); $0.colorB = linear(0x8E8068); $0.colorC = linear(0x9A7E5E)
            $0.knobs = V4(110, 0.95, 0.65, 0.15); $0.seed = 359; $0.tileSize = 0.06; $0.normalStrength = 0.7; $0.roughness = 0.68
        },
    ]
}
