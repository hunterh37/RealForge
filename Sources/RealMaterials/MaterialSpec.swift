import simd
import RealCore

/// GPU texture program ids (match `evaluate()` in the Metal source).
public enum TextureProgram: Int32, Sendable, CaseIterable {
    case barkOak = 0, barkBirch, barkPine, leafBroad, leafNeedle, grassBlades, rockGranite, forestFloor
    case woodPlank, paintedMetal, rustMetal, concrete, asphalt, plastic, brick
}

/// A fully specified PBR material: which texture program, its colors/knobs, and how RealityKit should
/// render it. Colors are linear RGB.
public struct MaterialSpec: Sendable, Hashable {
    public enum Mode: Sendable, Hashable { case opaque, cutout, emissive }

    public var key: MaterialKey
    public var program: TextureProgram?
    public var colorA: V4 = V4(0.5, 0.5, 0.5, 1)
    public var colorB: V4 = V4(0.3, 0.3, 0.3, 1)
    public var colorC: V4 = V4(0.2, 0.2, 0.2, 0)
    public var knobs: V4 = .zero
    public var seed: UInt32 = 1
    /// Meters covered by one texture repeat (UVs from RealCore are in meters). 0 = UVs are atlas space.
    public var tileSize: Float = 1
    /// Resolution class. Actual pixels = resolution * RealQuality.textureScale (clamped 128...4096).
    public var resolution: Int = 1024
    public var normalStrength: Float = 2
    public var mode: Mode = .opaque
    public var twoSided = false
    public var hasMetallicMap = false
    public var hasAOMap = true
    /// Untextured fallbacks / scalar overrides.
    public var baseColor: V3 = V3(0.5, 0.5, 0.5)
    public var roughness: Float = 0.8
    public var metallic: Float = 0
    public var emissive: V3 = .zero
    public var emissiveIntensity: Float = 0
    public var clearcoat: Float = 0
    public var specular: Float = 0.5
    public var opacity: Float = 1
    /// Vertex wind amplitude in meters at weight 1 (0 = static, PhysicallyBasedMaterial path).
    public var wind: Float = 0
    /// Back-lit transmission strength for leaves (ShaderGraph path).
    public var translucency: Float = 0
    /// Large-surface anti-tiling (ShaderGraph path): ground, asphalt, big rock faces.
    public var antiTile = false
    /// Object-space triplanar color/roughness/AO (ShaderGraph path).
    public var triplanar = false
    /// World-up layer (moss/snow/dust): linear color, amount 0...1, and threshold on normal.y.
    public var topColor: V4 = linear(0x2F4A16)
    public var topAmount: Float = 0
    public var topLow: Float = 0.55

    public init(key: MaterialKey, program: TextureProgram?) { self.key = key; self.program = program }

    public func with(_ edit: (inout MaterialSpec) -> Void) -> MaterialSpec { var c = self; edit(&c); return c }
}

/// sRGB hex -> linear color.
public func linear(_ hex: UInt32, _ a: Float = 1) -> V4 {
    func ch(_ v: UInt32) -> Float { let c = Float(v) / 255; return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    return V4(ch((hex >> 16) & 0xFF), ch((hex >> 8) & 0xFF), ch(hex & 0xFF), a)
}

/// Built-in material library. Keys may carry a hex color suffix: "metal.painted:2E5E3A".
public enum MaterialLibrary {
    public static func spec(for key: MaterialKey) -> MaterialSpec {
        let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
        let base = parts[0]
        let tint: V4? = parts.count > 1 ? UInt32(parts[1], radix: 16).map { linear($0) } : nil
        var s = builtIn(base) ?? MaterialSpec(key: base, program: nil)
        s.key = key
        if let tint {
            s.colorA = tint
            s.baseColor = V3(tint.x, tint.y, tint.z)
            s.seed = s.seed &+ UInt32(truncatingIfNeeded: tint.x.bitPattern &+ tint.y.bitPattern)
        }
        return s
    }

    public static let keys: [MaterialKey] = [
        "bark.oak", "bark.birch", "bark.pine", "leaf.oak", "leaf.maple", "leaf.birch", "leaf.spruce", "grass.meadow",
        "rock.granite", "rock.sandstone", "ground.forest", "ground.meadow", "wood.oak", "wood.weathered", "wood.pine",
        "metal.painted", "metal.rust", "metal.steel", "metal.iron", "concrete.smooth", "concrete.rough", "asphalt",
        "plastic.orange", "plastic.white", "plastic.black", "rubber", "brick.red", "glass.lamp", "emissive.warm",
    ]

    static func builtIn(_ k: String) -> MaterialSpec? {
        switch k {
        // ------------------------------------------------ bark
        case "bark.oak":
            return MaterialSpec(key: k, program: .barkOak).with {
                $0.colorA = linear(0x6E655A); $0.colorB = linear(0x1E1712); $0.colorC = linear(0x8C9478)
                $0.knobs = V4(0.35, 0.4, 0, 0); $0.tileSize = 0.5; $0.normalStrength = 5; $0.roughness = 0.9
                $0.wind = 0.03
            }
        case "bark.birch":
            return MaterialSpec(key: k, program: .barkBirch).with {
                $0.colorA = linear(0xD9D5CB); $0.colorB = linear(0x1C1A18); $0.colorC = linear(0xC9A890)
                $0.tileSize = 0.6; $0.normalStrength = 3; $0.roughness = 0.6
                $0.wind = 0.04
            }
        case "bark.pine":
            return MaterialSpec(key: k, program: .barkPine).with {
                $0.colorA = linear(0x6B3F28); $0.colorB = linear(0x1B120D); $0.colorC = linear(0x7A706A)
                $0.tileSize = 0.45; $0.normalStrength = 5; $0.roughness = 0.9
                $0.wind = 0.02
            }
        // ------------------------------------------------ foliage (atlas UVs, alpha-tested, two-sided)
        case "leaf.oak":
            return MaterialSpec(key: k, program: .leafBroad).with {
                $0.colorA = linear(0x2F4A16); $0.colorB = linear(0x4E6A22); $0.colorC = linear(0x8A7A2A)
                $0.knobs = V4(1, 0.08, 2, 0); $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 2
                $0.roughness = 0.55; $0.specular = 0.4
                $0.wind = 0.06; $0.translucency = 0.5
            }
        case "leaf.maple":
            return MaterialSpec(key: k, program: .leafBroad).with {
                $0.colorA = linear(0x3D5A1A); $0.colorB = linear(0x5F7D26); $0.colorC = linear(0xC0601E)
                $0.knobs = V4(1, 0.15, 2, 0); $0.seed = 7; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 2
                $0.wind = 0.06; $0.translucency = 0.55
            }
        case "leaf.birch":
            return MaterialSpec(key: k, program: .leafBroad).with {
                $0.colorA = linear(0x4A6A1E); $0.colorB = linear(0x6F8C2C); $0.colorC = linear(0xB8A23A)
                $0.knobs = V4(0, 0.1, 2, 0); $0.seed = 3; $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 1.5
                $0.wind = 0.07; $0.translucency = 0.55
            }
        case "leaf.spruce":
            return MaterialSpec(key: k, program: .leafNeedle).with {
                $0.colorA = linear(0x1C3320); $0.colorB = linear(0x2A4426); $0.colorC = linear(0x5C7F34)
                $0.knobs = V4(0.6, 0, 2, 0); $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.normalStrength = 2.5
                $0.roughness = 0.6
                $0.wind = 0.03; $0.translucency = 0.25
            }
        case "grass.meadow":
            return MaterialSpec(key: k, program: .grassBlades).with {
                $0.colorA = linear(0x2B4214); $0.colorB = linear(0x6C8A2E); $0.colorC = linear(0x9C8F55)
                $0.knobs = V4(0.12, 0, 1, 0); $0.tileSize = 0; $0.mode = .cutout; $0.twoSided = true; $0.resolution = 512
                $0.normalStrength = 1.5; $0.hasAOMap = true
                $0.wind = 0.05; $0.translucency = 0.45
            }
        // ------------------------------------------------ stone / ground
        case "rock.granite":
            return MaterialSpec(key: k, program: .rockGranite).with {
                $0.colorA = linear(0x5F5B56); $0.colorB = linear(0x86817A); $0.colorC = linear(0x9A7468)
                $0.knobs = V4(0.6, 0, 0, 0); $0.tileSize = 1.2; $0.normalStrength = 2.2; $0.triplanar = true
                $0.topAmount = 0.85
            }
        case "rock.sandstone":
            return MaterialSpec(key: k, program: .rockGranite).with {
                $0.colorA = linear(0xA98563); $0.colorB = linear(0xC4A27C); $0.colorC = linear(0x8E5A3A)
                $0.knobs = V4(0.2, 0, 0, 0); $0.seed = 9; $0.tileSize = 1.5; $0.normalStrength = 2; $0.triplanar = true
                $0.topAmount = 0.35
            }
        case "ground.forest":
            return MaterialSpec(key: k, program: .forestFloor).with {
                $0.colorA = linear(0x2E241B); $0.colorB = linear(0x5C4129); $0.colorC = linear(0x76603F)
                $0.knobs = V4(0.45, 0.7, 0, 0); $0.tileSize = 2.0; $0.normalStrength = 4; $0.resolution = 2048
                $0.antiTile = true
            }
        case "ground.meadow":
            return MaterialSpec(key: k, program: .forestFloor).with {
                $0.colorA = linear(0x3B3020); $0.colorB = linear(0x6E5A30); $0.colorC = linear(0x7D6E3C)
                $0.knobs = V4(0.85, 0.25, 0, 0); $0.seed = 5; $0.tileSize = 2.0; $0.normalStrength = 3; $0.resolution = 2048
                $0.antiTile = true
            }
        // ------------------------------------------------ wood
        case "wood.oak":
            return MaterialSpec(key: k, program: .woodPlank).with {
                $0.colorA = linear(0xB48A5E); $0.colorB = linear(0x6B4528); $0.knobs = V4(0, 0.55, 0, 0)
                $0.tileSize = 1.0; $0.normalStrength = 1.5
            }
        case "wood.pine":
            return MaterialSpec(key: k, program: .woodPlank).with {
                $0.colorA = linear(0xD8B585); $0.colorB = linear(0xA0703E); $0.knobs = V4(0, 0.6, 0, 0); $0.seed = 4
                $0.tileSize = 1.0; $0.normalStrength = 1.5
            }
        case "wood.weathered":
            return MaterialSpec(key: k, program: .woodPlank).with {
                $0.colorA = linear(0x9C8468); $0.colorB = linear(0x5A4632); $0.knobs = V4(0.75, 0.8, 0, 0); $0.seed = 11
                $0.tileSize = 1.0; $0.normalStrength = 3
            }
        // ------------------------------------------------ metal
        case "metal.painted":
            return MaterialSpec(key: k, program: .paintedMetal).with {
                $0.colorA = linear(0x2E4A36); $0.colorC = linear(0x5A2E1A, 0.0); $0.knobs = V4(0.5, 0.4, 0.38, 0)
                $0.tileSize = 0.8; $0.hasMetallicMap = true; $0.normalStrength = 1.5; $0.resolution = 1024
            }
        case "metal.rust":
            return MaterialSpec(key: k, program: .rustMetal).with {
                $0.colorA = linear(0x6A2E12); $0.colorB = linear(0x2A140A); $0.knobs = V4(0.3, 0, 0, 0)
                $0.tileSize = 0.6; $0.hasMetallicMap = true; $0.normalStrength = 3
            }
        case "metal.steel":
            return MaterialSpec(key: k, program: nil).with { $0.baseColor = V3(0.56, 0.57, 0.58); $0.metallic = 1; $0.roughness = 0.32 }
        case "metal.iron":
            return MaterialSpec(key: k, program: .paintedMetal).with {
                $0.colorA = linear(0x1A1B1C); $0.colorC = linear(0x3A2418, 0.0); $0.knobs = V4(0.25, 0.3, 0.45, 0); $0.seed = 2
                $0.tileSize = 0.8; $0.hasMetallicMap = true; $0.normalStrength = 1.5; $0.resolution = 512
            }
        // ------------------------------------------------ mineral / road
        case "concrete.smooth":
            return MaterialSpec(key: k, program: .concrete).with {
                $0.colorA = linear(0x9A9790); $0.colorB = linear(0x7E7A72); $0.knobs = V4(0.72, 0.4, 0, 0); $0.tileSize = 1.5; $0.normalStrength = 2
            }
        case "concrete.rough":
            return MaterialSpec(key: k, program: .concrete).with {
                $0.colorA = linear(0x8A867E); $0.colorB = linear(0x6E6A62); $0.knobs = V4(0.88, 0.7, 0, 0); $0.seed = 6; $0.tileSize = 1.5; $0.normalStrength = 2
                $0.antiTile = true
            }
        case "asphalt":
            return MaterialSpec(key: k, program: .asphalt).with {
                $0.colorA = linear(0x1E1E1F); $0.colorB = linear(0x5A5853); $0.knobs = V4(0.5, 0, 0, 0); $0.tileSize = 2; $0.normalStrength = 4; $0.resolution = 2048
                $0.antiTile = true
            }
        case "brick.red":
            return MaterialSpec(key: k, program: .brick).with {
                $0.colorA = linear(0x8A3E2A); $0.colorB = linear(0x6A2E22); $0.colorC = linear(0xA59E92); $0.tileSize = 0.6; $0.normalStrength = 4
            }
        // ------------------------------------------------ plastic / rubber
        case "plastic.orange":
            return MaterialSpec(key: k, program: .plastic).with {
                $0.colorA = linear(0xF0581A); $0.knobs = V4(0.6, 0.35, 0.42, 0); $0.tileSize = 0.5; $0.resolution = 512; $0.normalStrength = 1
            }
        case "plastic.white":
            return MaterialSpec(key: k, program: .plastic).with {
                $0.colorA = linear(0xE8E6E0); $0.knobs = V4(0.4, 0.3, 0.35, 0); $0.tileSize = 0.5; $0.resolution = 512; $0.seed = 3
            }
        case "plastic.black", "rubber":
            return MaterialSpec(key: k, program: .plastic).with {
                $0.colorA = linear(0x161616); $0.knobs = V4(0.3, 0.5, k == "rubber" ? 0.85 : 0.45, 0); $0.tileSize = 0.5; $0.resolution = 512; $0.seed = 8
            }
        // ------------------------------------------------ untextured
        case "glass.lamp":
            return MaterialSpec(key: k, program: nil).with {
                $0.baseColor = V3(1, 0.85, 0.6); $0.roughness = 0.25; $0.mode = .emissive
                $0.emissive = V3(1, 0.78, 0.5); $0.emissiveIntensity = 2.5
            }
        case "emissive.warm":
            return MaterialSpec(key: k, program: nil).with {
                $0.baseColor = V3(1, 0.7, 0.4); $0.mode = .emissive; $0.emissive = V3(1, 0.62, 0.32); $0.emissiveIntensity = 4
            }
        default: return nil
        }
    }
}
