import simd
import Foundation

/// MLB home plate as set in the ground: a whitened rubber pentagon (17 in front edge, 8.5 in sides,
/// 12 in rear edges meeting at the apex) inside a black beveled rubber rim. Only the part above grade is
/// modelled (the 2-3 in buried body and spikes are hidden in the real install): the white top sits
/// 5.5 mm above y = 0, so placed at ground level it reads flush. The front edge faces -Z (pitcher), the
/// apex points +Z (catcher). Centered on the X/Z bounds of the black rim; the white top's rear apex is
/// `HomePlate.apexOffset` meters along +Z from the origin.
public struct HomePlate: RealAsset {
    public static let id = "home-plate"
    public static let summary = "MLB home plate, 17 in pentagon: whitened rubber slab flush with grade inside a black beveled rubber rim, dusted with infield clay."
    public static let tags = ["prop", "sports", "rubber"]
    public static let budget = 4500
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 20, elevation: 35, distance: 1.1, studio: true)

    static let inch: Float = 0.0254
    /// Width of the black beveled rim outside the 17 in white top (m).
    public static let rimWidth: Float = 0.012
    /// Distance (m) along +Z from the asset origin to the rear apex of the white top. Place the plate at
    /// `apexPoint - V3(0, 0, apexOffset)` to put the apex on a foul-line intersection.
    public static let apexOffset: Float = apexY - centerY
    /// Rear apex of the white top from its front-edge line midpoint origin (m): sqrt(12^2 - 8.5^2) in.
    static let apexY: Float = Float(71.75).squareRoot() * inch
    /// Midpoint of the rim's Z extent in the same frame.
    static let centerY: Float = {
        let rimApex: Float = apexY + rimWidth * Float(2).squareRoot()
        let rimFront: Float = 8.5 * inch + rimWidth
        return (rimApex - rimFront) / 2
    }()

    /// White top material key.
    public var top: MaterialKey = "rubber.plate"
    /// Black rim material key.
    public var rim: MaterialKey = "rubber.plate-body"
    /// Infield clay drifted onto the bevel (0 = swept clean).
    public var clay: Float = 1
    public init() {}

    /// White-top outline in plate coordinates (x right, y toward the apex), centered on the rim bounds.
    static func outline(offset: Float) -> [V2] {
        let w: Float = 8.5 * inch, apex = apexY, center = centerY
        let base = [V2(-w, -w), V2(w, -w), V2(w, 0), V2(0, apex), V2(-w, 0)].map { $0 - V2(0, center) }
        return offset == 0 ? base : Shape2D.offset(base, offset)
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Outline y maps to +Z, extrude depth to Y.
        let flat = simd_quatf(degrees: 90, axis: V3(1, 0, 0))
        // Black rim: sloped bevel from grade up to the white top.
        let rimShape = Shape2D.rounded(Self.outline(offset: Self.rimWidth), radius: 0.004, segments: 2)
        m.add(Prim.extrude(rimShape, depth: 0.0045, bevel: 0.0035, bevelSegments: 2, material: rim),
              Xform(translation: V3(0, 0.00225, 0), rotation: flat))
        // White top, slightly crowned edge, standing 1 mm proud of the rim.
        let topShape = Shape2D.rounded(Self.outline(offset: 0), radius: 0.002, segments: 2)
        m.add(Prim.extrude(topShape, depth: 0.0026, bevel: 0.0011, bevelSegments: 2, material: top),
              Xform(translation: V3(0, 0.0042, 0), rotation: flat))
        // Clay drifted against the bevel and swept over the front corners.
        if clay > 0 {
            // A low berm of clay swept against the rim, thicker where the batter and catcher kick it.
            let corners = Self.outline(offset: Self.rimWidth + 0.004)
            var path: [V3] = []
            for i in corners.indices {
                let a = corners[i], b = corners[(i + 1) % corners.count]
                let steps = max(2, Int(simd_distance(a, b) / 0.012))
                for k in 0..<steps { let p = a + (b - a) * (Float(k) / Float(steps)); path.append(V3(p.x, -0.0012, p.y)) }
            }
            let phase = rng.float(0...6.28), phase2 = rng.float(0...6.28)
            let scales = path.indices.map { i -> Float in
                let t = Float(i) / Float(path.count) * 2 * .pi
                let wave = 0.55 + 0.3 * sin(t * 7 + phase) + 0.2 * sin(t * 17 + phase2)
                return max(0.12, wave * clay)
            }
            let profile = (0...8).map { k -> V2 in
                let a = Float(k) / 8 * .pi
                return V2(sin(a) * 0.0045, cos(a) * 0.014)
            }
            m.add(Prim.sweep(profile, along: path, up: .up, scales: scales, closedPath: true, material: "ground.infield"))
        }
        groundAO(&m, height: 0.006, floor: 0.7)
        return LODModel(m)
    }
}
