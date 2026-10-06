import simd
import Foundation

/// Wedge of Parmigiano-Reggiano cut from a 40 cm wheel, standing on a cut face: the pale straw paste
/// as a craggy slab with a triangular plan (point at -X), and the hard golden rind as a 6 mm band
/// following the wheel's curve along the back (+X), with the wheel's pin-dot stencil in
/// `food.parmesan-rind`. Paste crystals and crumbly fissures live in `food.parmesan`.
public struct ParmesanWedge: RealFood {
    public static let id = "parmesan-wedge"
    public static let summary = "Parmigiano-Reggiano wedge, 11 x 8 x 4.5 cm: crystalline crumbly straw paste, curved golden rind with pin-dot stencil."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let kind = FoodKind.dairy
    public static let preview = PreviewHint(azimuth: 40, elevation: 30, distance: 0.3, studio: true)

    /// Point to rind (m).
    public var length: Float = 0.105
    /// Rind width (m).
    public var width: Float = 0.078
    /// Height (m).
    public var height: Float = 0.045
    /// Rind thickness (m).
    public var rindThickness: Float = 0.008
    /// Wheel radius (m): sets the rind curve.
    public var wheelRadius: Float = 0.2
    /// Material keys.
    public var paste: MaterialKey = "food.parmesan"
    public var rind: MaterialKey = "food.parmesan-rind"
    public init() {}

    public var coreCenter: V3 { V3(0, height / 2, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? {
        if key == paste { return paste }
        if key == rind { return rind }
        return nil
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let L = length, hw = width / 2, H = height, Rw = wheelRadius, rt = rindThickness
        // Back arc of the wheel centred at x = xb - Rw.
        let xb = L / 2
        func arcX(_ z: Float, _ r: Float) -> Float { xb - Rw + sqrt(max(0, r * r - z * z)) }
        let tip = V2(-L / 2, rng.float(-0.003...0.003))
        // Paste plan: tip, then the inner rind arc from -hw to +hw.
        var pastePoly: [V2] = [tip]
        var radii: [Float] = [0.004]
        for k in 0...8 {
            let z = -hw + 2 * hw * Float(k) / 8
            pastePoly.append(V2(arcX(z, Rw - rt + 0.0006), z))
            radii.append(k == 0 || k == 8 ? 0.003 : 0)
        }
        let pasteOutline = RecipeMesh.roundedPolygon(pastePoly, radius: radii, step: 0.002)
        var pasteS = RecipeMesh.slab(outline: pasteOutline, thickness: H, bevel: 0.0014, edge: 0.0035, bevelSegments: 2, material: paste)
        let sd = UInt32(truncatingIfNeeded: seed)
        pasteS.displace { p, n in
            let craggy = RecipeMesh.noise(p, 160, seed: sd &+ 1) * 0.00045 + RecipeMesh.noise(p, 420, seed: sd &+ 2) * 0.0002
            let chip = min(0, RecipeMesh.noise(p, 55, seed: sd &+ 3) + 0.35) * 0.0009
            return (craggy + chip) * (n.y < -0.7 ? 0.1 : 1)
        }
        pasteS = FoodMesh.boxUV(pasteS)
        // Rind band: annular sector between the inner and outer wheel radii.
        var rindPoly: [V2] = []
        let zs = (0...10).map { -hw + 2 * hw * Float($0) / 10 }
        for z in zs { rindPoly.append(V2(arcX(z, Rw), z)) }
        for z in zs.reversed() { rindPoly.append(V2(arcX(z, Rw - rt), z)) }
        var rr: [Float] = Array(repeating: 0, count: rindPoly.count)
        rr[0] = 0.0015; rr[10] = 0.0015; rr[11] = 0.001; rr[21] = 0.001
        let rindOutline = RecipeMesh.roundedPolygon(rindPoly, radius: rr, step: 0.002)
        var rindS = RecipeMesh.slab(outline: rindOutline, thickness: H - 0.0004, bevel: 0.0022, edge: 0.0045, bevelSegments: 3, material: rind)
        rindS.deform { p in V3(p.x, p.y + 0.0002, p.z) }
        rindS.displace { p, _ in RecipeMesh.noise(p, 120, seed: sd &+ 5) * 0.00025 }
        // Rind UV: around the wheel (z) and up (y) so the stencil dots sit on the face.
        rindS.uvs = rindS.positions.map { V2($0.z, $0.y) }
        rindS.computeTangents()
        var m = Model(name: Self.id)
        m.add(pasteS)
        m.add(rindS)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.01, floor: 0.65)
        return LODModel(m)
    }
}
