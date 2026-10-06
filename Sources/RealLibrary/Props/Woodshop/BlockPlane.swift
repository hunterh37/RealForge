import simd
import Foundation

/// Low-angle block plane, 159 x 52 mm, resting on its sole: cast iron body with machined sole and side
/// faces, blue-grey stove enamel on the bed, toe deck and wall edges; 35 mm iron bedded bevel-up at 12
/// degrees with a 25 degree bevel, edge just through the mouth; nickel-plated lever cap with a brass
/// clamp screw; walnut front knob; knurled brass depth-adjuster knob behind the iron.
///
/// Asset frame directly: sole on y = 0, toe toward +X (the push direction), width along Z.
public struct BlockPlane: RealAsset {
    public static let id = "block-plane"
    public static let summary = "Low-angle block plane: enamelled cast iron body with machined sole and sides, bevel-up iron at the mouth, lever cap, brass adjuster knob."
    public static let tags = ["prop", "workshop", "tool", "handheld", "metal"]
    public static let budget = 8_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 35, elevation: 32, distance: 0.42)

    /// Sole length and width (m).
    public var length: Float = 0.159
    public var width: Float = 0.050
    /// Bed angle (degrees), low-angle.
    public var bedAngle: Float = 12
    /// Iron projection below the sole at the mouth (m).
    public var projection: Float = 0.00015
    public var body: MaterialKey = "metal.plane-japanned"
    public var machined: MaterialKey = "metal.machined"
    public var iron: MaterialKey = "metal.tool-ground"
    public var cap: MaterialKey = "metal.plane-nickel"
    public var brass: MaterialKey = "metal.brass-aged"
    public var knob: MaterialKey = "wood.walnut"
    public init() {}

    static let edgeX: Float = 0.0405, ironT: Float = 0.0032

    var dir: V2 { let a = bedAngle * .pi / 180; return V2(-cos(a), sin(a)) }
    var nrm: V2 { let a = bedAngle * .pi / 180; return V2(sin(a), cos(a)) }
    /// Point on the iron: `u` along it from the edge (up the bed), `v` off its bottom face.
    func ironPoint(_ u: Float, _ v: Float) -> V2 { V2(Self.edgeX, -projection) + dir * u + nrm * v }

    /// Center of the sole, on the bench, asset space.
    public var soleCenter: V3 { V3(0, 0, 0) }
    /// Unit push direction (toward the toe), asset space.
    public var pushDirection: V3 { V3(1, 0, 0) }
    /// Center of the hand hold: the palm on top of the lever cap.
    public var grip: V3 { let p = ironPoint(0.064, Self.ironT + 0.012); return V3(p.x, p.y, 0) }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length, Wd = width, hx = L / 2
        let layFlat = simd_quatf(angle: -.pi / 2, axis: V3(1, 0, 0))   // XY outline -> XZ plan, depth Z -> Y

        // MARK: sole (machined) with the mouth
        let sole = Shape2D.roundedRect(L, Wd, radius: 0.006, segments: 4)
        let mouth = Shape2D.roundedRect(0.0268, 0.037, radius: 0.001, segments: 2).map { $0 + V2(0.0309, 0) }
        m.add(HTKit.plate(outer: sole, holes: [mouth], depth: 0.005, bevel: 0.0008, segments: 2, material: machined),
              Xform(translation: V3(0, 0.0025, 0), rotation: layFlat))

        // MARK: side walls: enamelled castings with machined outer faces
        let wallT: Float = 0.004
        let prof: [V2] = [V2(-hx, 0.0045), V2(hx, 0.0045), V2(hx, 0.0105), V2(hx - 0.012, 0.0150), V2(0.048, 0.0185), V2(0.026, 0.0215),
                          V2(-0.004, 0.0225), V2(-0.030, 0.0215), V2(-0.050, 0.0185), V2(-hx + 0.010, 0.0150), V2(-hx, 0.0115)]
        let wall = Shape2D.rounded(prof, radius: 0.004, segments: 4)
        let skin = Shape2D.offset(wall, -0.0007)
        for s: Float in [-1, 1] {
            let zc = s * (Wd / 2 - wallT / 2 - 0.0002)
            var w = Prim.extrude(wall, depth: wallT, bevel: 0.0009, bevelSegments: 2, material: body)
            // Enamel chipped to bare iron along the top edges at the toe and heel, where it gets knocked.
            let chip = rng.float(0...1)
            w.paintSplat { q in
                let top = smoothstep(0.010, 0.016, q.y)
                let ends = max(smoothstep(0.035, 0.065, q.x), smoothstep(-0.04, -0.07, q.x), 0.35)
                return top * ends * (0.8 + 0.2 * chip)
            }
            m.add(w, Xform(translation: V3(0, 0, zc)))
            m.add(Prim.extrude(skin, depth: 0.0003, bevel: 0.0001, bevelSegments: 1, material: machined),
                  Xform(translation: V3(0, 0, zc + s * (wallT / 2 - 0.0001))))
        }

        // MARK: bed and heel casting (enamel), toe deck and knob
        let a = bedAngle * .pi / 180
        let bedTop = { (x: Float) -> Float in -self.projection + (Self.edgeX - x) * tan(a) - 0.0002 }
        let bedProf: [V2] = [V2(-hx + 0.0015, 0.004), V2(0.0175, 0.004), V2(0.0175, bedTop(0.0175)), V2(-0.060, bedTop(-0.060)),
                             V2(-0.064, 0.0150), V2(-hx + 0.0015, 0.0150)]
        m.add(Prim.extrude(Shape2D.rounded(bedProf, radius: 0.0012, segments: 2), depth: Wd - 2 * wallT - 0.001, bevel: 0.0006,
                           bevelSegments: 1, material: body))
        let deck: [V2] = [V2(0.0475, 0.004), V2(hx - 0.0015, 0.004), V2(hx - 0.0015, 0.0100), V2(0.068, 0.0150), V2(0.0475, 0.0150)]
        m.add(Prim.extrude(Shape2D.rounded(deck, radius: 0.0015, segments: 2), depth: Wd - 2 * wallT - 0.001, bevel: 0.0008,
                           bevelSegments: 1, material: body))
        let knobProf: [(Float, Float)] = [(0.0, 0.0), (0.0062, 0.0), (0.0058, 0.0035), (0.0072, 0.0080), (0.0090, 0.0120), (0.0088, 0.0150),
                                          (0.0070, 0.0166), (0.0, 0.0170)]
        m.add(turned(knobProf, segments: 24, material: knob, seamTile: 0.05, grainVertical: true), Xform(translation: V3(0.060, 0.0138, 0)))

        // MARK: iron, bevel up, edge through the mouth
        let p0 = V2(0, 0), ironLen: Float = 0.105, bevL = Self.ironT / tan(25 * Float.pi / 180)
        let ironProf: [V2] = [p0, V2(ironLen, 0), V2(ironLen, Self.ironT), V2(bevL, Self.ironT), V2(0, 0.0002)]
        var ironS = Prim.extrude(ironProf, depth: 0.035, bevel: 0.0002, bevelSegments: 1, material: iron)
        let ironRot = simd_quatf(angle: .pi - a, axis: V3(0, 0, 1)) * simd_quatf(angle: .pi, axis: V3(1, 0, 0))
        ironS = ironS.transformed(Xform(translation: V3(Self.edgeX, -projection, 0), rotation: ironRot))
        m.add(ironS)

        // MARK: lever cap: nickel casting over the iron with a domed palm rest and a brass clamp screw
        let us: [Float] = [0.026, 0.032, 0.045, 0.060, 0.075, 0.088, 0.096]
        let capW: [Float] = [0.024, 0.032, 0.038, 0.041, 0.042, 0.041, 0.036]
        let capH: [Float] = [0.0030, 0.0062, 0.0098, 0.0118, 0.0122, 0.0108, 0.0060]
        let capPath = us.indices.map { i -> V3 in let p = ironPoint(us[i], Self.ironT + capH[i] / 2 + 0.0002); return V3(p.x, p.y, 0) }
        let up3 = V3(nrm.x, nrm.y, 0)
        m.add(HTKit.loft(capPath, up: up3, material: cap) { i in
            HTKit.section(capW[i], capH[i], n: 24, exponent: 3.2).map { V2($0.x, max($0.y, -capH[i] / 2 * 0.9)) }
        })
        let sp = ironPoint(0.068, Self.ironT + 0.0122 + 0.0001)
        let screw = turned([(0.0, 0.0), (0.0060, 0.0), (0.0063, 0.0015), (0.0063, 0.0040), (0.0050, 0.0052), (0.0, 0.0055)], segments: 24, material: brass)
        m.add(screw, Xform(translation: V3(sp.x, sp.y - 0.0012, 0), rotation: simd_quatf(angle: -a, axis: V3(0, 0, 1))))

        // MARK: depth adjuster: stem from the iron and a knurled brass knob
        let kc = ironPoint(0.110, 0.0030)
        let kDir = V3(dir.x, dir.y, 0)
        let kRot = simd_quatf(from: V3(0, 1, 0), to: kDir)
        m.add(Prim.cylinder(radius: 0.0022, height: 0.016, bevel: 0.0003, segments: 12, bevelSegments: 1, material: brass),
              Xform(translation: V3(kc.x, kc.y, 0) - kDir * 0.016, rotation: kRot))
        var knurl = Prim.cylinder(radius: 0.0078, height: 0.010, bevel: 0.0012, segments: 48, bevelSegments: 2, material: brass)
        knurl.deform { q in
            let r = sqrt(q.x * q.x + q.z * q.z)
            guard r > 0.0074, q.y > 0.0014, q.y < 0.0086 else { return q }
            let ang = atan2(q.z, q.x), k = 1 + 0.05 * cos(ang * 24)
            return V3(q.x * k, q.y, q.z * k)
        }
        knurl.recomputeNormals(weldSeams: true); knurl.computeTangents()
        m.add(knurl, Xform(translation: V3(kc.x, kc.y, 0), rotation: kRot))

        _ = rng.float()
        groundAO(&m, height: 0.012, floor: 0.6)
        return LODModel(m)
    }
}
