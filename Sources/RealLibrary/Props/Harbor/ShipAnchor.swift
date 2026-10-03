import simd
import Foundation

/// Admiralty pattern display anchor, about 1.3 m long, resting the way it lands on a seabed: the stock
/// flat on the ground, the arms in a vertical plane with the lower fluke biting the ground and the upper
/// arm raised. Tapered square shank with a thickened crown, crescent arms, spade flukes with bills, round
/// iron stock with ball ends and a forelock wedge, ring through the eye and a few links of stud chain.
public struct ShipAnchor: RealAsset {
    public static let id = "ship-anchor"
    public static let summary = "Admiralty pattern anchor, 1.3 m: rusted cast iron shank, curved arms with spade flukes, iron stock, ring and short chain."
    public static let tags = ["prop", "harbor", "metal", "decor"]
    public static let budget = 8_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 38, elevation: 22, distance: 1.05, studio: true)

    /// Shank length crown to eye (m).
    public var shank: Float = 1.12
    /// Arm radius of curvature (m); span between fluke bills is about 1.9x this.
    public var armRadius: Float = 0.46
    /// Stock length (m).
    public var stock: Float = 1.1
    /// Number of chain links lying on the ground.
    public var links = 5
    public var iron: MaterialKey = "metal.cast-iron"
    public var rust: MaterialKey = "metal.rust"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var a = Model(name: Self.id)
        let L = shank, R = armRadius, zAxis = V3(0, 0, 1)
        // Local frame: shank along +X from the crown (origin) to the eye; arms in the XY plane.
        let shankProfile = Shape2D.roundedRect(0.088, 0.076, radius: 0.014, segments: 2)
        let shankPath = (0...6).map { V3(0.02 + (L - 0.02) * Float($0) / 6, 0, 0) }
        let taper = shankPath.indices.map { 1.0 - 0.32 * Float($0) / 6 }
        a.add(Prim.sweep(shankProfile, along: shankPath, up: zAxis, scales: taper, material: iron))
        // Eye boss at the end of the shank.
        a.add(Prim.cylinder(radius: 0.045, height: 0.05, bevel: 0.008, segments: 20, material: iron),
              Xform(translation: V3(L + 0.01, 0, -0.025), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        // Crown and crescent arms: one sweep tip to tip through the crown, thickest at the crown.
        let theta: Float = 1.25
        var arm: [V3] = []
        let n = 16
        for k in 0...n {
            let t = -theta + 2 * theta * Float(k) / Float(n)
            arm.append(V3(R - R * cos(t), R * sin(t), 0))
        }
        let armScale = arm.indices.map { i -> Float in let t = abs(Float(i) / Float(n) * 2 - 1); return 1.4 - 0.6 * t }
        a.add(Prim.sweep(Shape2D.roundedRect(0.078, 0.07, radius: 0.016, segments: 2), along: arm, up: zAxis, scales: armScale, material: iron))
        a.add(Prim.superellipsoid(V3(0.16, 0.15, 0.1), exponent: 3, subdivisions: 6, material: iron), Xform(translation: V3(0.015, 0, 0)))
        // Flukes: spade plates near each arm tip, plate spanning Z, facing the shank; bill past the tip.
        for (tip, prev) in [(arm[n], arm[n - 1]), (arm[0], arm[1])] {
            let t = simd_normalize(tip - prev)
            let nrm = simd_cross(t, zAxis)
            let rot = simd_quatf(simd_float3x3(t, zAxis, nrm))
            let spade: [V2] = [V2(-0.2, 0.012), V2(-0.12, 0.13), V2(0.02, 0.14), V2(0.1, 0.06), V2(0.14, 0.0), V2(0.1, -0.06), V2(0.02, -0.14), V2(-0.12, -0.13), V2(-0.2, -0.012)].map { $0 * 1.55 }
            let plate = Prim.extrude(Shape2D.rounded(spade, radius: 0.012, segments: 2), depth: 0.034, bevel: 0.01, bevelSegments: 2, material: iron)
            let inward = simd_dot(nrm, -tip) > 0 ? nrm : -nrm
            a.add(plate, Xform(translation: tip - t * 0.05 + inward * 0.014, rotation: rot))
            // Bill: blunt point beyond the fluke.
            a.add(Prim.tube([tip, tip + t * 0.07], radii: [0.026, 0.012], sides: 10, seamTile: 0.1, material: iron))
        }
        // Stock through the eye: round bar with ball ends, collar and forelock wedge.
        let sx = L - 0.04
        a.add(Prim.cylinder(radius: 0.03, height: stock, bevel: 0.004, segments: 18, material: rust),
              Xform(translation: V3(sx, 0, -stock / 2), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        for s: Float in [-1, 1] {
            a.add(Prim.superellipsoid(V3(0.1, 0.1, 0.1), exponent: 2, subdivisions: 6, material: rust), Xform(translation: V3(sx, 0, s * stock / 2)))
            a.add(Prim.torus(major: 0.036, minor: 0.012, segments: 18, sides: 8, material: rust),
                  Xform(translation: V3(sx, 0, s * 0.055), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }
        a.add(Prim.roundedBox(V3(0.012, 0.09, 0.03), radius: 0.004, bevelSegments: 1, material: rust), Xform(translation: V3(sx, 0.02, 0.08)))
        // Pose: stock lies on the ground (axis at ball radius); tilt about the stock axis until the
        // lower fluke bill touches down.
        let pivot = V3(sx, 0, 0)
        func posed(_ deg: Float) -> Model {
            a.transformed(Xform(translation: V3(0, 0.05, 0), rotation: simd_quatf(degrees: deg, axis: zAxis))
                .applying(pre: Xform(translation: -pivot)))
        }
        var tilt: Float = 0
        while tilt > -45 && posed(tilt).bounds.min.y < -0.002 { tilt -= 0.25 }
        var m = posed(tilt)
        // Ring through the eye, fallen flat, then chain links trailing across the ground.
        let eye = Xform(translation: V3(0, 0.05, 0), rotation: simd_quatf(degrees: tilt, axis: zAxis)).applying(pre: Xform(translation: -pivot)).point(V3(L + 0.01, 0, 0))
        let ringR: Float = 0.13, ringW: Float = 0.022
        let ringC = V3(eye.x + ringR * 0.75, ringW + 0.02, eye.z + 0.02)
        m.add(Prim.torus(major: ringR, minor: ringW, segments: 32, sides: 10, material: rust),
              Xform(translation: ringC, rotation: simd_quatf(degrees: 14, axis: zAxis)))
        if links > 0 {
            let w: Float = 0.012
            var path: [V3] = [ringC + V3(ringR, 0, 0)]
            var dir = simd_normalize(V3(0.6, 0, 1))
            for _ in 0..<links {
                dir = simd_normalize(dir + V3(0, 0, rng.float(-0.35...0.35)))
                path.append(path[path.count - 1] + dir * w * 2 * 3.5)
            }
            let flat = path.map { V3($0.x, w * 1.8, $0.z) }
            m.add(chain(along: flat, wire: w, material: rust, seed: seed))
        }
        // Center the footprint.
        let bb = m.bounds
        m = m.transformed(Xform(translation: V3(-(bb.min.x + bb.max.x) / 2, -bb.min.y, -(bb.min.z + bb.max.z) / 2)))
        groundAO(&m, height: 0.12, floor: 0.45)
        return LODModel(m)
    }
}

extension Xform {
    /// self after `pre` (matrix product self * pre), for pivots.
    func applying(pre: Xform) -> Xform {
        Xform(translation: point(pre.translation), rotation: rotation * pre.rotation, scale: scale * pre.scale)
    }
}
