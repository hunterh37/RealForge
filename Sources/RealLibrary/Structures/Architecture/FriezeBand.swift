import simd
import Foundation

/// Frieze band: flat frieze field over a fillet and bead-and-reel astragal, capped by a cyma reversa, with carved
/// rosettes at `rosetteSpacing`. Back face on the wall plane, run along X; tile every `length`.
public struct FriezeBand: RealAsset {
    public static let id = "frieze-band"
    public static let summary = "Frieze band, 1.2 m run: flat frieze field with carved rosettes between an astragal and a cyma reversa cap; tiles along X."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone", "ornament"]
    public static let budget = 9_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 25, elevation: 5, distance: 0.95)

    /// Run length along X (m).
    public var length: Float = 1.2
    /// Height of the flat frieze field (m); moldings add about 0.12 m.
    public var fieldHeight: Float = 0.322
    /// Projection of the field from the wall (m).
    public var fieldDepth: Float = 0.02
    /// Rosette centers along X (m); 0 = no rosettes.
    public var rosetteSpacing: Float = 0.6
    /// Rosette diameter (m).
    public var rosetteDiameter: Float = 0.15
    /// Rain streak and soot strength (0 = freshly cut).
    public var weathering: Float = 0.5
    public var miterStart = false
    public var miterEnd = false
    public var material: MaterialKey = "stone.limestone"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var p = ArchProfile()
        p.step(fieldDepth + 0.02); p.fillet(0.012)
        p.step(-0.006)
        let by = p.end.y + 0.012, bx = p.end.x
        p.bead(0.012)
        p.step(-(p.end.x - fieldDepth))
        let fy = p.end.y
        p.fillet(fieldHeight)
        p.step(0.01); p.cymaReversa(0.045, 0.035); p.fillet(0.016)
        var m = Model(name: Self.id)
        m.add(ArchTrimKit.sweep(p, length: length, material: material, miterStart: miterStart, miterEnd: miterEnd))
        if rosetteSpacing > 0 {
            let n = max(1, Int((length / rosetteSpacing).rounded())), pitch = length / Float(n)
            let ro = ArchTrimKit.rosette(radius: rosetteDiameter / 2, height: 0.03, petals: 8, material: material)
            let disk = Prim.cylinder(radius: rosetteDiameter * 0.18, height: 0.04, bevel: 0.006, segments: 16, material: material)
            for i in 0..<n {
                let c = V3(-length / 2 + pitch * (Float(i) + 0.5), fy + fieldHeight / 2, fieldDepth - 0.001)
                let face = simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))
                m.add(ro, Xform(translation: c, rotation: face))
                m.add(disk, Xform(translation: c, rotation: face))
            }
        }
        // Bead-and-reel carved on the astragal.
        m.add(ArchTrimKit.beadAndReel(length: length, r: 0.0105, at: V2(by, bx + 0.004), material: material))
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        return LODModel(ArchTrimKit.ground(m))
    }
}
