import simd
import Foundation

/// Modillion cornice: Roman Corinthian cornice in dressed limestone. Profile bottom to top: fillet,
/// cyma reversa bed mold, dentil band with ovolo cap, modillion fascia, corona over a flat soffit,
/// cyma recta crown. Scroll modillions carry the soffit at `modillionSpacing`. Back face on the wall
/// plane (z min), length along X; tile every `length`, miter the ends for outside corners.
public struct ModillionCornice: RealAsset {
    public static let id = "modillion-cornice"
    public static let summary = "Classical modillion cornice, 1.2 m run: bed mold, dentils, scroll modillions under a corona and cyma crown; tiles along X."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone"]
    public static let budget = 18_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: -18, distance: 1.1)

    /// Run length along X (m).
    public var length: Float = 1.2
    /// Overall height scale (1 = 0.48 m tall, 0.45 m projection).
    public var scale: Float = 1
    /// Modillion centers along X (m, before `scale`).
    public var modillionSpacing: Float = 0.3
    /// Dentil centers along X (m, before `scale`).
    public var dentilSpacing: Float = 0.09
    /// 45-degree outside-corner miter at the -X / +X end.
    public var miterStart = false
    public var miterEnd = false
    /// Stone material key.
    public var material: MaterialKey = "stone.limestone"
    /// Sheltered undersides (modillions, dentils, rosettes) that collect soot.
    /// Rain streak and soot strength (0 = freshly cut).
    public var weathering: Float = 0.55
    public var shelteredMaterial: MaterialKey = "stone.limestone-sooted"
    public init() {}

    /// The cornice profile (x projection, y height), 0.48 m tall before scaling.
    public static func profile() -> ArchProfile {
        var p = ArchProfile()
        p.step(0.02); p.fillet(0.02)
        p.cymaReversa(0.04, 0.03)
        p.step(0.005); p.fillet(0.01)
        p.fillet(0.07)                       // dentil backing (y 0.08...0.15)
        p.step(0.06); p.ovolo(0.03, 0.03)    // dentil cap
        p.fillet(0.012)
        p.step(-0.01); p.fillet(0.083)       // modillion fascia (y ~0.192...0.275)
        p.step(0.245)                        // soffit
        p.fillet(0.008); p.step(-0.006)      // drip lip
        p.fillet(0.092)                      // corona
        p.step(0.012); p.fillet(0.012)
        p.cymaRecta(0.075, 0.062)
        p.fillet(0.018)
        return p
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let k = scale, L = length
        let prof = Self.profile().scaled(k)
        m.add(ArchTrimKit.sweep(prof, length: L, material: material, miterStart: miterStart, miterEnd: miterEnd))

        // Dentils: blocks proud of the backing fascia, under the ovolo cap.
        let dn = max(1, Int((L / (dentilSpacing * k)).rounded()))
        let dPitch = L / Float(dn)
        let chipped = rng.int(0...(dn - 1))
        for i in 0..<dn {
            var r = rng.fork(i)
            let x = -L / 2 + dPitch * (Float(i) + 0.5)
            var sz = V3(dPitch * 0.64, 0.07 * k, 0.06 * k) + V3(r.float(-0.001...0.001), 0, r.float(-0.001...0.001))
            var c = V3(x, 0.115 * k, (0.055 + 0.03) * k - 0.002)
            if i == chipped { sz.y -= 0.012 * k; c.y -= 0.006 * k; sz.z -= 0.006 * k }   // one weathered, chipped dentil
            m.add(Prim.roundedBox(sz, radius: 0.003 * k, bevelSegments: 1, material: shelteredMaterial), Xform(translation: c))
        }

        // Scroll modillions under the soffit.
        let mn = max(1, Int((L / (modillionSpacing * k)).rounded()))
        let mPitch = L / Float(mn)
        let z0: Float = 0.12 * k, z1: Float = 0.36 * k, yTop: Float = 0.275 * k, hBack: Float = 0.085 * k
        var outline: [V2] = []
        // Bottom: deep scroll at the back easing to a slim front, then a rounded nose curl.
        let nb = 10
        for j in 0...nb {
            let t = Float(j) / Float(nb)
            let z = z0 + (z1 - 0.03 * k - z0) * t
            let h = hBack - (hBack - 0.045 * k) * smoothstep(0.15, 0.85, t)
            outline.append(V2(z, yTop - h))
        }
        let rN = 0.0225 * k, cN = V2(z1 - 0.03 * k, yTop - rN)
        for j in 1...6 { let a = -Float.pi / 2 + Float(j) / 6 * Float.pi; outline.append(cN + V2(cos(a), sin(a)) * rN + V2(0.0075 * k * sin(Float(j) / 6 * .pi), 0)) }
        outline.append(V2(z1 - 0.03 * k, yTop - 0.0005))
        outline.append(V2(z0, yTop - 0.0005))
        outline = Shape2D.deduped(outline)
        let width = 0.095 * k
        let body = Prim.extrude(outline, depth: width, bevel: 0.004 * k, bevelSegments: 2, material: shelteredMaterial)
        // Side volute bosses (front curl and back scroll eye).
        let boss = Prim.cylinder(radius: 0.017 * k, height: 0.006 * k, bevel: 0.002 * k, segments: 14, material: shelteredMaterial)
        let eye = Prim.cylinder(radius: 0.026 * k, height: 0.006 * k, bevel: 0.002 * k, segments: 16, material: shelteredMaterial)
        let nose = ArchTrimKit.volute(radius: 0.021 * k, turns: 2, wire: 0.003 * k, material: shelteredMaterial)
        let rosette = ArchTrimKit.rosette(radius: 0.05 * k, height: 0.022 * k, petals: 8, material: shelteredMaterial)
        for i in 0..<mn {
            let x = -L / 2 + mPitch * (Float(i) + 0.5)
            let rot = simd_quatf(angle: -.pi / 2, axis: V3(0, 1, 0))
            m.add(body, Xform(translation: V3(x, 0, 0), rotation: rot))
            for s in [Float(-1), 1] {
                let side = simd_quatf(angle: s * .pi / 2, axis: V3(0, 0, 1))
                m.add(boss, Xform(translation: V3(x + s * (width / 2 - 0.001), cN.y, cN.x), rotation: side))
                m.add(eye, Xform(translation: V3(x + s * (width / 2 - 0.001), yTop - hBack * 0.55, z0 + 0.04 * k), rotation: side))
                let face = simd_quatf(angle: s * .pi / 2, axis: V3(0, 1, 0)) * (s > 0 ? .identity : simd_quatf(angle: .pi, axis: V3(1, 0, 0)))
                m.add(nose, Xform(translation: V3(x + s * (width / 2 + 0.003 * k), cN.y, cN.x), rotation: face))
            }
            // Coffer rosette on the soffit between modillions.
            if i < mn - 1 || mn == 1 {
                m.add(rosette, Xform(translation: V3(x + mPitch / 2, yTop + 0.001, (z0 + z1) / 2 + 0.02 * k), rotation: simd_quatf(angle: .pi, axis: V3(1, 0, 0))))
            }
        }
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        let lite = lite(seed: seed)
        let g = ArchTrimKit.ground(m), b = m.bounds
        let shift = Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2))
        return LODModel(levels: [g, lite.transformed(shift)], switchDistances: [12])
    }

    /// Far level: profile sweep plus plain modillion and dentil blocks.
    func lite(seed: UInt64) -> Model {
        var m = Model(name: Self.id)
        let k = scale, L = length
        m.add(ArchTrimKit.sweep(Self.profile().scaled(k), length: L, material: material, miterStart: miterStart, miterEnd: miterEnd, span: L))
        let mn = max(1, Int((L / (modillionSpacing * k)).rounded())), mPitch = L / Float(mn)
        for i in 0..<mn {
            m.add(Prim.roundedBox(V3(0.095 * k, 0.07 * k, 0.24 * k), radius: 0.004 * k, bevelSegments: 1, material: material),
                  Xform(translation: V3(-L / 2 + mPitch * (Float(i) + 0.5), 0.24 * k, 0.24 * k)))
        }
        return m
    }
}
