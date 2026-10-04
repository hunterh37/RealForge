import RealCore

public extension MaterialLibrary {
    /// RealityHD 5 hospital materials: sheet vinyl floors, wall tile, drapes and exam paper, medical
    /// vinyl upholstery, surgical stainless, molded device plastics, clear medical plastics and fluids,
    /// patient-monitor display, pharmacy labels. Tints replace colorA (`vinyl.medical:2F5F66`).
    static let medical: [MaterialSpec] = [
        // Hospital corridor/ward sheet vinyl: warm grey with white and charcoal directional chips, welded
        // seams every 2 m (tileSize 2 = one sheet width per tile), light traffic. Tint for color.
        MaterialSpec(key: "floor.vinyl", program: .sheetVinyl).with {
            $0.colorA = linear(0xB9B4AA); $0.colorB = linear(0xE6E3DC, 0.3); $0.colorC = linear(0x6E6A65, 0.15)
            $0.knobs = V4(60, 1, 0.32, 0.4); $0.seed = 501; $0.tileSize = 2; $0.resolution = 2048; $0.normalStrength = 0.3; $0.roughness = 0.32
        },
        // Operating-room static-dissipative sheet vinyl: blue-grey with dark conductive chips, polished.
        MaterialSpec(key: "floor.vinyl-or", program: .sheetVinyl).with {
            $0.colorA = linear(0x8F9EA3); $0.colorB = linear(0x4C5458, 0.3); $0.colorC = linear(0xD2D8D8, 0.15)
            $0.knobs = V4(80, 1, 0.22, 0.15); $0.seed = 502; $0.tileSize = 2; $0.resolution = 2048; $0.normalStrength = 0.25; $0.roughness = 0.22
        },
        // Lobby sheet vinyl in a warm sand tone with fewer chips.
        MaterialSpec(key: "floor.vinyl-sand", program: .sheetVinyl).with {
            $0.colorA = linear(0xC8B79E); $0.colorB = linear(0xE8DECC, 0.35); $0.colorC = linear(0x8A7A62, 0.25)
            $0.knobs = V4(48, 1, 0.3, 0.5); $0.seed = 503; $0.tileSize = 2; $0.resolution = 2048; $0.normalStrength = 0.3; $0.roughness = 0.3
        },
        // Glazed white wall tile, 10 x 20 cm (tileSize 0.4 = 4 x 2 tiles), pale grout.
        MaterialSpec(key: "tile.wall", program: .wallTile).with {
            $0.colorA = linear(0xEEEEEA); $0.colorB = linear(0xC9C6BE); $0.colorC = linear(0x8A8274, 0.2)
            $0.knobs = V4(2, 4, 0.03, 0.04); $0.seed = 504; $0.tileSize = 0.4; $0.resolution = 1024; $0.normalStrength = 0.8; $0.roughness = 0.15; $0.clearcoat = 0.3
        },
        // Operating-room large-format wall tile, 30 x 60 cm, pale green-grey glaze, epoxy grout.
        MaterialSpec(key: "tile.wall-or", program: .wallTile).with {
            $0.colorA = linear(0xC7D6CF); $0.colorB = linear(0xAEBDB6); $0.colorC = linear(0x6C7A72, 0.05)
            $0.knobs = V4(2, 2, 0.012, 0.03); $0.seed = 505; $0.tileSize = 1.2; $0.resolution = 1024; $0.normalStrength = 0.6; $0.roughness = 0.14; $0.clearcoat = 0.35
        },
        // Hospital wall paint: washable semi-gloss eggshell. Tint for color.
        MaterialSpec(key: "paint.hospital", program: .paintedWall).with {
            $0.colorA = linear(0xE6E8E2); $0.knobs = V4(0.4, 0.5, 0.55, 0); $0.seed = 506; $0.tileSize = 1.2; $0.normalStrength = 0.3; $0.roughness = 0.55
        },
        // Surgical drape / wrap: blue SMS nonwoven with bond dots and fold creases.
        MaterialSpec(key: "drape.surgical", program: .nonwoven).with {
            $0.colorA = linear(0x3D7FA6); $0.colorB = linear(0x2F6A8E); $0.knobs = V4(160, 0, 0.92, 0.6)
            $0.seed = 507; $0.tileSize = 0.4; $0.resolution = 1024; $0.normalStrength = 0.9; $0.roughness = 0.92
        },
        // Sterilization wrap in green.
        MaterialSpec(key: "drape.green", program: .nonwoven).with {
            $0.colorA = linear(0x4E8C76); $0.colorB = linear(0x3E7462); $0.knobs = V4(160, 0, 0.92, 0.3)
            $0.seed = 508; $0.tileSize = 0.4; $0.resolution = 1024; $0.normalStrength = 0.9; $0.roughness = 0.92
        },
        // Crepe exam-table paper, white, 53 cm roll (tileSize 0.5).
        MaterialSpec(key: "paper.exam", program: .nonwoven).with {
            $0.colorA = linear(0xF3F2EC); $0.colorB = linear(0xE2E0D8); $0.knobs = V4(40, 1, 0.88, 0)
            $0.seed = 509; $0.tileSize = 0.5; $0.resolution = 1024; $0.normalStrength = 1.2; $0.roughness = 0.88
        },
        // Medical-grade upholstery vinyl: fine emboss, satin, wipe-clean. Tint for color (teal default).
        MaterialSpec(key: "vinyl.medical", program: .leather).with {
            $0.colorA = linear(0x2E5E68); $0.colorB = linear(0x173238); $0.colorC = linear(0x4A7C86)
            $0.knobs = V4(220, 0.15, 0.48, 0.08); $0.seed = 510; $0.tileSize = 0.3; $0.normalStrength = 0.8; $0.roughness = 0.48
        },
        // Black medical vinyl (stretcher pads, OR table pads, stools).
        MaterialSpec(key: "vinyl.medical-black", program: .leather).with {
            $0.colorA = linear(0x1C1D1F); $0.colorB = linear(0x0C0C0D); $0.colorC = linear(0x34363A)
            $0.knobs = V4(220, 0.2, 0.42, 0.1); $0.seed = 511; $0.tileSize = 0.3; $0.normalStrength = 0.8; $0.roughness = 0.42
        },
        // Satin surgical stainless (instruments: bead-blasted satin with fine grind lines along U).
        MaterialSpec(key: "metal.surgical", program: .brushedMetal).with {
            $0.colorA = linear(0xB4B6B8); $0.colorB = linear(0x8E8C88)
            $0.knobs = V4(0.5, 0.3, 0.15, 0.2); $0.seed = 512; $0.tileSize = 0.08; $0.normalStrength = 0.25
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.3
        },
        // Mirror-finish stainless (instrument working surfaces, tray rims, reflectors).
        MaterialSpec(key: "metal.surgical-mirror", program: .brushedMetal).with {
            $0.colorA = linear(0xC4C6C8); $0.colorB = linear(0x9A9894)
            $0.knobs = V4(0.15, 0.1, 0.1, 0.1); $0.seed = 513; $0.tileSize = 0.08; $0.normalStrength = 0.1
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.1
        },
        // Electropolished casework stainless (carts, sinks, tables): brushed along U, smudged.
        MaterialSpec(key: "metal.casework", program: .brushedMetal).with {
            $0.colorA = linear(0xACAEB0); $0.colorB = linear(0x82807A)
            $0.knobs = V4(0.75, 0.26, 0.45, 0.3); $0.seed = 514; $0.tileSize = 0.4; $0.normalStrength = 0.35
            $0.hasMetallicMap = true; $0.metallic = 1; $0.roughness = 0.26
        },
        // Hospital white epoxy powder coat (bed frames, IV poles, cabinets, scale columns). Tint for color.
        MaterialSpec(key: "metal.powder-white", program: .paintedMetal).with {
            $0.colorA = linear(0xEDEDE8); $0.colorC = linear(0x9A9A96, 0.6); $0.knobs = V4(0.12, 0.2, 0.34, 0)
            $0.seed = 515; $0.tileSize = 0.8; $0.hasMetallicMap = true; $0.normalStrength = 0.5; $0.roughness = 0.38
        },
        // Molded device housing plastic: warm off-white ABS/PC with fine texture. Tint for color.
        MaterialSpec(key: "plastic.medical", program: .plastic).with {
            $0.colorA = linear(0xEEECE6); $0.knobs = V4(0.15, 0.1, 0.32, 0); $0.seed = 516; $0.tileSize = 0.15; $0.resolution = 512; $0.normalStrength = 0.35
        },
        // Light grey device plastic (monitor bezels, pump housings).
        MaterialSpec(key: "plastic.medical-grey", program: .plastic).with {
            $0.colorA = linear(0xA9AEB2); $0.knobs = V4(0.15, 0.1, 0.38, 0); $0.seed = 517; $0.tileSize = 0.15; $0.resolution = 512; $0.normalStrength = 0.35
        },
        // Clear polypropylene/PC (syringe barrels, specimen tubes, container lids): glossy, faint blue.
        MaterialSpec(key: "plastic.clear", program: nil).with {
            $0.baseColor = V3(0.86, 0.9, 0.93); $0.roughness = 0.08; $0.specular = 0.5; $0.mode = .transparent; $0.opacity = 0.22; $0.twoSided = true
        },
        // Frosted translucent plastic (IV bag film, sharps lids, pill bottle bodies' amber is a tint).
        MaterialSpec(key: "plastic.frosted", program: nil).with {
            $0.baseColor = V3(0.9, 0.92, 0.92); $0.roughness = 0.4; $0.specular = 0.4; $0.mode = .transparent; $0.opacity = 0.45; $0.twoSided = true
        },
        // Amber pharmacy-vial plastic.
        MaterialSpec(key: "plastic.amber", program: nil).with {
            $0.baseColor = V3(0.62, 0.3, 0.06); $0.roughness = 0.12; $0.specular = 0.5; $0.mode = .transparent; $0.opacity = 0.7; $0.twoSided = true
        },
        // Clear fluid (saline, drug in a syringe): faint, glossy.
        MaterialSpec(key: "fluid.saline", program: nil).with {
            $0.baseColor = V3(0.88, 0.93, 0.96); $0.roughness = 0.02; $0.specular = 0.6; $0.mode = .transparent; $0.opacity = 0.18
        },
        // Glass vial / ampoule.
        MaterialSpec(key: "glass.vial", program: nil).with {
            $0.baseColor = V3(0.86, 0.9, 0.9); $0.roughness = 0.03; $0.specular = 0.6; $0.mode = .transparent; $0.opacity = 0.16; $0.twoSided = true
        },
        // Medical silicone / PVC tubing (stethoscope tubes, cuffs' hoses): soft satin. Tint for color.
        MaterialSpec(key: "rubber.tubing", program: .plastic).with {
            $0.colorA = linear(0x1E1F21); $0.knobs = V4(0.1, 0.1, 0.55, 0); $0.seed = 518; $0.tileSize = 0.1; $0.resolution = 256; $0.normalStrength = 0.2
        },
        // Translucent grey silicone (diaphragm rims, ear tips, bulbs).
        MaterialSpec(key: "rubber.silicone", program: .plastic).with {
            $0.colorA = linear(0x5A5D60); $0.knobs = V4(0.1, 0.1, 0.62, 0); $0.seed = 519; $0.tileSize = 0.1; $0.resolution = 256; $0.normalStrength = 0.2
        },
        // Nylon cuff / strap fabric (BP cuffs, restraint straps). Tint for color.
        MaterialSpec(key: "fabric.nylon", program: .fabricWeave).with {
            $0.colorA = linear(0x1F3A66); $0.colorB = linear(0x182E52, 0.4); $0.colorC = linear(0x2A2620, 0.03)
            $0.knobs = V4(120, 0.15, 0.7, 0); $0.seed = 520; $0.tileSize = 0.04; $0.normalStrength = 1.6; $0.roughness = 0.7
        },
        // Cubicle privacy curtain: dense polyester weave, pale teal. Tint for color.
        MaterialSpec(key: "fabric.curtain", program: .fabricWeave).with {
            $0.colorA = linear(0x8CB4B0); $0.colorB = linear(0x7AA29E, 0.5); $0.colorC = linear(0x5A5248, 0.02)
            $0.knobs = V4(64, 0.3, 0.9, 0); $0.seed = 521; $0.tileSize = 0.06; $0.normalStrength = 1.8; $0.roughness = 0.9
        },
        // Open-weave mesh band at the top of privacy curtains.
        MaterialSpec(key: "fabric.curtain-mesh", program: .chairMesh).with {
            $0.colorA = linear(0xE6E6E0); $0.colorB = linear(0xD4D4CE); $0.colorC = linear(0x9A9A94); $0.knobs = V4(60, 0.5, 0.9, 2)
            $0.seed = 522; $0.tileSize = 0.05; $0.normalStrength = 1.5; $0.roughness = 0.9
        },
        // Ceil-blue scrubs / linen cotton-poly twill. Tint for color.
        MaterialSpec(key: "fabric.scrubs", program: .fabricWeave).with {
            $0.colorA = linear(0x6E9CB8); $0.colorB = linear(0x5E8AA4, 0.5); $0.colorC = linear(0x3A3630, 0.02)
            $0.knobs = V4(90, 0.4, 0.92, 0); $0.seed = 523; $0.tileSize = 0.05; $0.normalStrength = 1.8; $0.roughness = 0.92
        },
        // White hospital linen (sheets, pillowcases): percale with faint blue.
        MaterialSpec(key: "fabric.linen", program: .fabricWeave).with {
            $0.colorA = linear(0xF0F1EE); $0.colorB = linear(0xE2E5E6, 0.5); $0.colorC = linear(0x8C8A84, 0.01)
            $0.knobs = V4(110, 0.3, 0.9, 0); $0.seed = 524; $0.tileSize = 0.04; $0.normalStrength = 1.4; $0.roughness = 0.9
        },
        // Bedside monitor display: ECG, pleth, resp, arterial traces and numerics (emissive, 16:10, v down).
        MaterialSpec(key: "screen.vitals", program: .vitalsUI).with {
            $0.colorA = linear(0x030405); $0.knobs = V4(72, 98, 0.62, 0); $0.seed = 525; $0.tileSize = 1; $0.resolution = 2048
            $0.mode = .emissive; $0.emissive = V3(1, 1, 1); $0.emissiveIntensity = 0.95; $0.roughness = 0.3; $0.specular = 0.15
        },
        // Same display in alarm (tachycardic, low SpO2, yellow banner).
        MaterialSpec(key: "screen.vitals-alarm", program: .vitalsUI).with {
            $0.colorA = linear(0x030405); $0.knobs = V4(128, 89, 0.35, 1); $0.seed = 526; $0.tileSize = 1; $0.resolution = 2048
            $0.mode = .emissive; $0.emissive = V3(1, 1, 1); $0.emissiveIntensity = 0.95; $0.roughness = 0.3; $0.specular = 0.15
        },
        // Pharmacy label: white paper, blue band, barcode (UVs 0...1 across the label, v down).
        MaterialSpec(key: "label.rx", program: .medLabel).with {
            $0.colorA = linear(0xF6F5F0); $0.colorB = linear(0x2A5DA8); $0.colorC = linear(0x1A1A1C)
            $0.knobs = V4(0.22, 1, 4, 0.2); $0.seed = 527; $0.tileSize = 1; $0.resolution = 512; $0.normalStrength = 0.1
        },
        // Biohazard / warning label: red-orange band.
        MaterialSpec(key: "label.hazard", program: .medLabel).with {
            $0.colorA = linear(0xF4F1E8); $0.colorB = linear(0xD8381E); $0.colorC = linear(0x1A1A1C)
            $0.knobs = V4(0.35, 0, 3, 0.4); $0.seed = 528; $0.tileSize = 1; $0.resolution = 512; $0.normalStrength = 0.1
        },
        // Clear printed film label (IV bags): white ink on film is approximated by a pale label.
        MaterialSpec(key: "label.iv", program: .medLabel).with {
            $0.colorA = linear(0xEDF1F2); $0.colorB = linear(0x2F7A4A); $0.colorC = linear(0x223040)
            $0.knobs = V4(0.14, 1, 6, 0.9); $0.seed = 529; $0.tileSize = 1; $0.resolution = 512; $0.normalStrength = 0.1
        },
        // Cool-white surgical LED (lit lens, 4500 K).
        MaterialSpec(key: "emissive.surgical", program: nil).with {
            $0.baseColor = V3(0.95, 0.97, 1); $0.mode = .emissive; $0.emissive = V3(0.94, 0.97, 1); $0.emissiveIntensity = 6
        },
        // Green power/status LED.
        MaterialSpec(key: "emissive.led-green", program: nil).with {
            $0.baseColor = V3(0.3, 1, 0.4); $0.mode = .emissive; $0.emissive = V3(0.2, 1, 0.35); $0.emissiveIntensity = 4
        },
        // Red alarm/record LED.
        MaterialSpec(key: "emissive.led-red", program: nil).with {
            $0.baseColor = V3(1, 0.25, 0.2); $0.mode = .emissive; $0.emissive = V3(1, 0.15, 0.1); $0.emissiveIntensity = 4
        },
        // Small monochrome LCD (thermometers, oximeters, glucometers, pumps): lit grey-green, unlit look via screen.off.
        MaterialSpec(key: "screen.lcd", program: nil).with {
            $0.baseColor = V3(0.62, 0.72, 0.66); $0.mode = .emissive; $0.emissive = V3(0.55, 0.8, 0.7); $0.emissiveIntensity = 0.7; $0.roughness = 0.2
        },
        // realityhd:material.medical
    ]
}
