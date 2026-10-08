import RealCore

public extension MaterialLibrary {
    /// City streetscape: road asphalt, lane paint, sidewalk concrete, granite curb, plaza slabs, cobbles.
    static let city: [MaterialSpec] = [
        // Dense-graded road asphalt, a few years old: grey binder, exposed aggregate, hairline cracks.
        MaterialSpec(key: "asphalt.road", program: .asphalt).with {
            $0.colorA = linear(0x2E2E2E); $0.colorB = linear(0x4E4C48); $0.knobs = V4(0.35, 0, 0, 0); $0.seed = 9101
            $0.tileSize = 3; $0.normalStrength = 3; $0.resolution = 2048; $0.roughness = 0.9; $0.antiTile = true
        },
        // Oxidized older asphalt in wheel paths and gutters: lighter, more cracking.
        MaterialSpec(key: "asphalt.worn", program: .asphalt).with {
            $0.colorA = linear(0x3C3B39); $0.colorB = linear(0x7C786F); $0.knobs = V4(0.75, 0, 0, 0); $0.seed = 9102
            $0.tileSize = 3; $0.normalStrength = 3.5; $0.resolution = 2048; $0.roughness = 0.92; $0.antiTile = true
        },
        // Fresh utility-cut patch: near-black binder, little aggregate showing.
        MaterialSpec(key: "asphalt.patch", program: .asphalt).with {
            $0.colorA = linear(0x1A1A1B); $0.colorB = linear(0x45433F); $0.knobs = V4(0.05, 0, 0, 0); $0.seed = 9103
            $0.tileSize = 2; $0.normalStrength = 2.5; $0.resolution = 1024; $0.roughness = 0.82
        },
        // Thermoplastic lane paint, white, worn by tyres and grit.
        MaterialSpec(key: "paint.lane-white", program: .concrete).with {
            $0.colorA = linear(0xDCDAD2); $0.colorB = linear(0x8E8C86); $0.knobs = V4(0.7, 0.55, 0, 0); $0.seed = 9111
            $0.tileSize = 1; $0.normalStrength = 1.2; $0.resolution = 1024
        },
        // Thermoplastic centre-line paint, yellow.
        MaterialSpec(key: "paint.lane-yellow", program: .concrete).with {
            $0.colorA = linear(0xD8A62A); $0.colorB = linear(0x8A7440); $0.knobs = V4(0.7, 0.55, 0, 0); $0.seed = 9112
            $0.tileSize = 1; $0.normalStrength = 1.2; $0.resolution = 1024
        },
        // Broom-finished sidewalk concrete, light grey with gum and rain stains.
        MaterialSpec(key: "concrete.sidewalk", program: .concrete).with {
            $0.colorA = linear(0x8E8B84); $0.colorB = linear(0x77736B); $0.knobs = V4(0.86, 0.4, 0, 0); $0.seed = 9121
            $0.tileSize = 1.5; $0.normalStrength = 1.1; $0.resolution = 2048; $0.antiTile = true
        },
        // Grey granite kerb stone, sawn top, flamed face, salt-and-pepper speckle.
        MaterialSpec(key: "stone.granite-curb", program: .rockGranite).with {
            $0.colorA = linear(0x9A9894); $0.colorB = linear(0x54524E); $0.colorC = linear(0x6A5E50)
            $0.knobs = V4(0.0, 0, 0, 0); $0.seed = 9131; $0.tileSize = 0.6; $0.normalStrength = 1.6; $0.roughness = 0.8
            $0.triplanar = true
        },
        // Light granite-look plaza slabs, 50 cm, 6 per repeat, sand joints.
        MaterialSpec(key: "paving.plaza", program: .pavers).with {
            $0.colorA = linear(0xB8B2A6); $0.colorB = linear(0x8A8478); $0.colorC = linear(0x7A7062)
            $0.knobs = V4(6, 0.8, 0.5, 0.012); $0.seed = 9141; $0.tileSize = 3; $0.resolution = 2048; $0.normalStrength = 1.6; $0.roughness = 0.86
        },
        // Grey granite setts, worn street cobbles with dark grit joints.
        MaterialSpec(key: "paving.cobble", program: .cobblestone).with {
            $0.colorA = linear(0x77746F); $0.colorB = linear(0x5A5753); $0.colorC = linear(0x34302A)
            $0.knobs = V4(0.5, 0.35, 0.65, 0.0); $0.seed = 9151; $0.tileSize = 1.4; $0.normalStrength = 4; $0.resolution = 2048
        },
        // Traffic-signal yellow powder coat, sun faded.
        MaterialSpec(key: "metal.signal-yellow", program: .paintedMetal).with {
            $0.colorA = linear(0xD9A514); $0.colorC = linear(0x5A2E1A, 0.0); $0.knobs = V4(0.25, 0.45, 0.45, 0)
            $0.tileSize = 0.6; $0.hasMetallicMap = true; $0.normalStrength = 1.2; $0.resolution = 1024; $0.seed = 9161
        },
        // Retroreflective sign sheeting (red for stop and do-not-enter faces).
        MaterialSpec(key: "sign.red", program: nil).with { $0.baseColor = V3(0.55, 0.03, 0.03); $0.roughness = 0.35; $0.clearcoat = 0.6 },
        MaterialSpec(key: "sign.white", program: nil).with { $0.baseColor = V3(0.82, 0.82, 0.80); $0.roughness = 0.35; $0.clearcoat = 0.6 },
        MaterialSpec(key: "sign.green", program: nil).with { $0.baseColor = V3(0.0, 0.16, 0.07); $0.roughness = 0.35; $0.clearcoat = 0.6 },
        // Signal lamps lit: red, amber, green, walk-white, don't-walk orange.
        MaterialSpec(key: "emissive.signal-red", program: nil).with {
            $0.baseColor = V3(0.9, 0.02, 0.01); $0.mode = .emissive; $0.emissive = V3(1, 0.03, 0.01); $0.emissiveIntensity = 2.5
        },
        MaterialSpec(key: "emissive.signal-green", program: nil).with {
            $0.baseColor = V3(0.05, 0.9, 0.6); $0.mode = .emissive; $0.emissive = V3(0.02, 1, 0.65); $0.emissiveIntensity = 2.5
        },
        MaterialSpec(key: "emissive.signal-orange", program: nil).with {
            $0.baseColor = V3(1, 0.35, 0.02); $0.mode = .emissive; $0.emissive = V3(1, 0.32, 0.02); $0.emissiveIntensity = 2.5
        },
        MaterialSpec(key: "emissive.signal-white", program: nil).with {
            $0.baseColor = V3(1, 0.97, 0.9); $0.mode = .emissive; $0.emissive = V3(1, 0.96, 0.88); $0.emissiveIntensity = 4
        },
        // Unlit signal lens: dark tinted polycarbonate.
        MaterialSpec(key: "glass.signal-off", program: nil).with { $0.baseColor = V3(0.05, 0.05, 0.05); $0.roughness = 0.08; $0.clearcoat = 1 },
        // Clear polycarbonate shelter panels.
        MaterialSpec(key: "glass.shelter", program: nil).with {
            $0.baseColor = V3(0.78, 0.82, 0.82); $0.roughness = 0.05; $0.specular = 0.5; $0.mode = .transparent; $0.opacity = 0.22; $0.twoSided = true
        },
        // Fountain basin water, clear with slight green.
        MaterialSpec(key: "water.fountain", program: nil).with {
            $0.baseColor = V3(0.12, 0.17, 0.15); $0.roughness = 0.03; $0.specular = 0.7; $0.mode = .transparent; $0.opacity = 0.7
        },
        // Hot-poured crack sealant, dull from grit and traffic.
        MaterialSpec(key: "asphalt.sealant", program: nil).with { $0.baseColor = V3(0.02, 0.02, 0.019); $0.roughness = 0.7 },
        // Flamed granite paving slab: fine salt-and-pepper speckle, little cloudiness.
        MaterialSpec(key: "stone.granite-paver", program: .rockGranite).with {
            $0.colorA = linear(0xB8B2A6); $0.colorB = linear(0xA29C90); $0.colorC = linear(0x7A7062)
            $0.knobs = V4(0.0, 0, 0, 0); $0.seed = 9132; $0.tileSize = 0.35; $0.normalStrength = 1.0; $0.roughness = 0.82
            $0.triplanar = true
        },
        // Weathered sign sheeting: road grime, faint chalking and a few edge chips.
        MaterialSpec(key: "sign.green-worn", program: .paintedMetal).with {
            $0.colorA = linear(0x0F4A2C); $0.colorC = linear(0x8A8A86, 0.0); $0.knobs = V4(0.08, 0.55, 0.4, 0)
            $0.tileSize = 0.5; $0.normalStrength = 0.4; $0.resolution = 1024; $0.seed = 9171; $0.clearcoat = 0.4
        },
        MaterialSpec(key: "sign.red-worn", program: .paintedMetal).with {
            $0.colorA = linear(0xA41A16); $0.colorC = linear(0x8A8A86, 0.0); $0.knobs = V4(0.06, 0.5, 0.4, 0)
            $0.tileSize = 0.5; $0.normalStrength = 0.4; $0.resolution = 1024; $0.seed = 9172; $0.clearcoat = 0.4
        },
        // Street cast iron (lids, grates): near-black iron, rust bloom only in recesses, grit-dulled.
        MaterialSpec(key: "metal.cast-iron-street", program: .rustMetal).with {
            $0.colorA = linear(0x2E2A27); $0.colorB = linear(0x1A1817); $0.knobs = V4(0.12, 0, 0, 0); $0.seed = 9181
            $0.tileSize = 0.5; $0.hasMetallicMap = true; $0.normalStrength = 2.0; $0.roughness = 0.7
        },
        // Aerated falling water and foam: white, translucent.
        MaterialSpec(key: "water.fountain-foam", program: nil).with {
            $0.baseColor = V3(0.82, 0.87, 0.87); $0.roughness = 0.25; $0.specular = 0.5; $0.mode = .transparent; $0.opacity = 0.3; $0.twoSided = true
        },
        // realityhd:material.city
    ]
}
