import RealCore

public extension MaterialLibrary {
    /// Scene ground and rock variants for the alpine, canyon and winter scenes.
    static let wild: [MaterialSpec] = [
        /// Alpine meadow soil; the splat channel paints a pebble stream bed into it.
        MaterialSpec(key: "ground.alpine", program: .forestFloor).with {
            $0.colorA = linear(0x3B3020); $0.colorB = linear(0x6E5A30); $0.colorC = linear(0x7D6E3C)
            $0.knobs = V4(0.85, 0.25, 0, 0); $0.seed = 5; $0.tileSize = 2.0; $0.normalStrength = 3; $0.resolution = 2048
            $0.antiTile = true
            $0.splat = "ground.pebble-beach"; $0.splatSoftness = 0.25; $0.splatHeight = 1.5
        },
        /// Granite with fresh snow lying on faces that point up (normal.y above about 0.5).
        MaterialSpec(key: "rock.granite-snow", program: .rockGranite).with {
            $0.colorA = linear(0x67635D); $0.colorB = linear(0x8F8A82); $0.colorC = linear(0xA07B6C)
            $0.knobs = V4(0.6, 0.05, 0, 0.3); $0.seed = 7; $0.tileSize = 1.0; $0.normalStrength = 2.4; $0.triplanar = true
            $0.topColor = linear(0xE4E8EE); $0.topAmount = 0.95; $0.topLow = 0.5
        },
        /// Distant mountain rock: dark grey bedded rock at a 30 m tile so bands and ledges read from
        /// 100 m and more, with snow lying on the flatter ledges.
        MaterialSpec(key: "rock.mountain", program: .strataRock).with {
            $0.colorA = linear(0x45433F); $0.colorB = linear(0x66625C); $0.colorC = linear(0x56534E)
            $0.knobs = V4(0.35, 7, 0.5, 0.5); $0.seed = 61; $0.tileSize = 30; $0.normalStrength = 2.6; $0.triplanar = true
            $0.topColor = linear(0xE4E8EE); $0.topAmount = 1; $0.topLow = 0.36
        },
        /// Clear mountain stream: pale body color, faster ripple scroll than a pond.
        MaterialSpec(key: "water.stream", program: .water).with {
            $0.colorA = linear(0x1E2F2C); $0.colorB = linear(0x7F8C78); $0.knobs = V4(0.45, 0, 0, 0)
            $0.tileSize = 1.5; $0.resolution = 1024; $0.normalStrength = 1.6; $0.mode = .transparent; $0.opacity = 0.4
            $0.roughness = 0.04; $0.specular = 0.5; $0.flow = 0.35; $0.hasAOMap = false
        },
    ]
}
