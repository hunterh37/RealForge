import Foundation
import RealCore
import RealMaterials

/// Material keys and specs for animals. RealityHD resolves keys through `MaterialLibrary`; animal
/// specs are species-specific, so `AnimalKit` registers them as `RealMaterialCache` overrides.
///
/// Keys: `fauna.<species>.<region>` with regions body, head, flight, covert, tail, crest, arm, beak,
/// leg, eye, ring. Atlas programs (body, head) use UV 0...1 over the part, see `Loft`.
public enum FaunaMaterials {
    public enum Region: String, CaseIterable, Sendable {
        case body, head, flight, covert, tail, crest, arm, beak, leg, eye, ring, backCard, bellyCard
    }

    public static func key(_ id: String, _ r: Region) -> MaterialKey { "fauna.\(id).\(r.rawValue)" }

    static func seed(_ id: String, _ r: Region) -> UInt32 {
        var h: UInt32 = 2166136261
        for b in (id + r.rawValue).utf8 { h = (h ^ UInt32(b)) &* 16777619 }
        return h & 0xFFFF | 1
    }

    /// Every spec one bird needs.
    public static func specs(for p: BirdProfile) -> [MaterialSpec] {
        let id = p.species.rawValue, c = p.plumage
        func make(_ r: Region, _ program: TextureProgram, _ edit: (inout MaterialSpec) -> Void) -> MaterialSpec {
            MaterialSpec(key: key(id, r), program: program).with {
                $0.seed = seed(id, r)
                edit(&$0)
            }
        }
        return [
            make(.body, .plumageBody) {
                $0.colorA = linear(c.back); $0.colorB = linear(c.belly); $0.colorC = linear(c.breast)
                $0.knobs = V4(c.featherRows, c.flankLine, c.breastExtent, c.spotting)
                $0.tileSize = 0; $0.resolution = 1024; $0.normalStrength = 2.2; $0.roughness = 0.62
                if c.iridescence > 0 { $0.roughness = 0.42; $0.specular = 0.8 }
            },
            make(.head, .plumageHead) {
                $0.colorA = linear(c.crown); $0.colorB = linear(c.cheek); $0.colorC = linear(c.mask)
                $0.knobs = V4(c.featherRows * 1.4, c.crownLine, c.throatExtent, c.maskExtent)
                $0.tileSize = 0; $0.resolution = 1024; $0.normalStrength = 2; $0.roughness = 0.6
            },
            make(.flight, .plumageFeather) {
                $0.colorA = linear(c.flight); $0.colorB = linear(c.flight); $0.colorC = linear(c.wingEdge)
                $0.knobs = V4(30, c.fringe, c.barring, 0.8)
                $0.tileSize = 0; $0.resolution = 512; $0.normalStrength = 2; $0.mode = .cutout; $0.twoSided = true; $0.roughness = 0.6
            },
            make(.covert, .plumageFeather) {
                $0.colorA = linear(c.wing); $0.colorB = linear(c.wing); $0.colorC = linear(c.wingEdge)
                $0.knobs = V4(26, min(1, c.fringe * 1.3), 0, 0.2)
                $0.tileSize = 0; $0.resolution = 512; $0.normalStrength = 2; $0.mode = .cutout; $0.twoSided = true; $0.roughness = 0.6
            },
            make(.tail, .plumageFeather) {
                $0.colorA = linear(c.tail); $0.colorB = linear(c.tail); $0.colorC = linear(c.tailEdge)
                $0.knobs = V4(28, c.fringe, c.barring, 0.3)
                $0.tileSize = 0; $0.resolution = 512; $0.normalStrength = 2; $0.mode = .cutout; $0.twoSided = true; $0.roughness = 0.6
            },
            make(.crest, .plumageFeather) {
                $0.colorA = linear(c.crown); $0.colorB = linear(c.crown); $0.colorC = linear(c.crown)
                $0.knobs = V4(32, 0, 0, 0.2)
                $0.tileSize = 0; $0.resolution = 512; $0.normalStrength = 2; $0.mode = .cutout; $0.twoSided = true; $0.roughness = 0.6
            },
            make(.backCard, .plumageFeather) {
                $0.colorA = linear(c.back); $0.colorB = linear(c.back); $0.colorC = linear(c.back)
                $0.knobs = V4(30, 0.1, 0, 0.2)
                $0.tileSize = 0; $0.resolution = 512; $0.normalStrength = 2; $0.mode = .cutout; $0.twoSided = true; $0.roughness = 0.6
            },
            make(.bellyCard, .plumageFeather) {
                $0.colorA = linear(c.belly); $0.colorB = linear(c.belly); $0.colorC = linear(c.belly)
                $0.knobs = V4(30, 0.1, 0, 0.2)
                $0.tileSize = 0; $0.resolution = 512; $0.normalStrength = 2; $0.mode = .cutout; $0.twoSided = true; $0.roughness = 0.6
            },
            make(.arm, .plumageBody) {
                $0.colorA = linear(c.wing); $0.colorB = linear(c.wing); $0.colorC = linear(c.wing)
                $0.knobs = V4(24, 0.5, 0, 0)
                $0.tileSize = 0; $0.resolution = 512; $0.normalStrength = 2; $0.roughness = 0.62
            },
            make(.beak, .plastic) {
                $0.colorA = linear(c.beak); $0.knobs = V4(0.35, 0.3, 0.38, 0)
                $0.tileSize = 0.05; $0.resolution = 256; $0.normalStrength = 0.6; $0.roughness = 0.38; $0.clearcoat = 0.25
            },
            make(.leg, .plastic) {
                $0.colorA = linear(c.leg); $0.knobs = V4(0.4, 0.5, 0.65, 0)
                $0.tileSize = 0.03; $0.resolution = 256; $0.normalStrength = 1.4; $0.roughness = 0.62
            },
            make(.eye, .plastic) {
                $0.colorA = linear(c.eye); $0.knobs = V4(0.2, 0.2, 0.2, 0)
                $0.tileSize = 0.02; $0.resolution = 128; $0.normalStrength = 0; $0.roughness = 0.04; $0.clearcoat = 1; $0.specular = 1
            },
            make(.ring, .plastic) {
                $0.colorA = linear(c.eyeRing); $0.knobs = V4(0.4, 0.4, 0.55, 0)
                $0.tileSize = 0.02; $0.resolution = 128; $0.normalStrength = 0.4; $0.roughness = 0.55
            },
        ]
    }

    // MARK: ground animals

    public enum GroundRegion: String, CaseIterable, Sendable {
        case body, head, tail, ear, nose, eye, claw, whisker, quill
    }

    public static func key(_ id: String, _ r: GroundRegion) -> MaterialKey { "fauna.\(id).\(r.rawValue)" }

    static func seed(_ id: String, _ r: GroundRegion) -> UInt32 {
        var h: UInt32 = 2166136261
        for b in (id + r.rawValue).utf8 { h = (h ^ UInt32(b)) &* 16777619 }
        return h & 0xFFFF | 1
    }

    /// Every spec one ground animal needs.
    public static func specs(for p: GroundProfile) -> [MaterialSpec] {
        let id = p.species.rawValue, c = p.palette
        func make(_ r: GroundRegion, _ program: TextureProgram, _ edit: (inout MaterialSpec) -> Void) -> MaterialSpec {
            MaterialSpec(key: key(id, r), program: program).with { $0.seed = seed(id, r); edit(&$0) }
        }
        return [
            make(.body, .furCoat) {
                $0.colorA = linear(c.back); $0.colorB = linear(c.belly); $0.colorC = linear(c.accent)
                $0.knobs = V4(c.strands, c.flankLine, c.pattern, 0.6)
                $0.tileSize = 0; $0.resolution = 1024; $0.normalStrength = 2.4; $0.roughness = 0.92
            },
            make(.head, .furCoat) {
                $0.colorA = linear(c.face); $0.colorB = linear(c.belly); $0.colorC = linear(c.accent)
                $0.knobs = V4(c.strands * 1.3, c.flankLine + 0.04, c.pattern * 0.8, 0.4)
                $0.tileSize = 0; $0.resolution = 512; $0.normalStrength = 2; $0.roughness = 0.9
            },
            make(.tail, .furCoat) {
                $0.colorA = linear(c.tail); $0.colorB = linear(c.tailTip); $0.colorC = linear(c.accent)
                $0.knobs = V4(c.strands, 0.32, 0.25, 0.9)
                $0.tileSize = 0; $0.resolution = 512; $0.normalStrength = 2.6; $0.roughness = 0.92
            },
            make(.ear, .plastic) {
                $0.colorA = linear(c.ear); $0.knobs = V4(0.6, 0.4, 0.6, 0)
                $0.tileSize = 0.03; $0.resolution = 256; $0.normalStrength = 0.5; $0.roughness = 0.7
            },
            make(.nose, .plastic) {
                $0.colorA = linear(c.nose); $0.knobs = V4(0.4, 0.3, 0.3, 0)
                $0.tileSize = 0.02; $0.resolution = 128; $0.normalStrength = 0.3; $0.roughness = 0.35; $0.clearcoat = 0.3
            },
            make(.eye, .plastic) {
                $0.colorA = linear(c.eye); $0.knobs = V4(0.2, 0.2, 0.2, 0)
                $0.tileSize = 0.02; $0.resolution = 128; $0.normalStrength = 0; $0.roughness = 0.04; $0.clearcoat = 1; $0.specular = 1
            },
            make(.claw, .plastic) {
                $0.colorA = linear(c.claw); $0.knobs = V4(0.4, 0.4, 0.5, 0)
                $0.tileSize = 0.02; $0.resolution = 128; $0.normalStrength = 0.3; $0.roughness = 0.5
            },
            make(.whisker, .plastic) {
                $0.colorA = linear(0xE6E0D4); $0.knobs = V4(0.3, 0.3, 0.4, 0)
                $0.tileSize = 0.02; $0.resolution = 64; $0.normalStrength = 0; $0.roughness = 0.5
            },
            make(.quill, .quillCoat) {
                $0.colorA = linear(c.accent); $0.colorB = linear(c.back); $0.colorC = linear(c.belly)
                $0.knobs = V4(70, 0.85, 0.5, 0)
                $0.tileSize = 0.15; $0.resolution = 1024; $0.normalStrength = 4; $0.roughness = 0.6
            },
        ]
    }
}
