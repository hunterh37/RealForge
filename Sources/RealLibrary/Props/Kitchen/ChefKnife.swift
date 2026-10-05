import simd
import Foundation

/// 8 in chef knife (gyuto) lying on its side: blade face normal +Y, blade along +X with the tip at max X,
/// edge toward -Z. Flat-ground satin blade tapering from a 2.4 mm spine, mirror secondary bevel, half
/// bolster, full tang showing between black POM scales, three flush rivets. The knife rests on the
/// handle scale and the tip, so it tilts about 2 degrees.
public struct ChefKnife: RealAsset {
    public static let id = "chef-knife"
    public static let summary = "8 in chef knife (gyuto): flat-ground satin blade, polished edge bevel, full tang, three-rivet black POM handle."
    public static let tags = ["prop", "kitchen", "cookware", "metal", "tool", "handheld"]
    public static let budget = 8000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 45, distance: 0.8, studio: true)

    /// Blade length from heel to tip (m); 8 in = 0.21.
    public var bladeLength: Float = 0.21
    /// Blade height at the heel (m).
    public var heelHeight: Float = 0.048
    /// Spine thickness at the heel (m).
    public var spineThickness: Float = 0.0024
    /// Handle length (m).
    public var handleLength: Float = 0.125
    /// Handle thickness across the scales (m).
    public var handleThickness: Float = 0.019
    /// Blade finish (grind lines along the blade).
    public var blade: MaterialKey = "metal.knife-blade"
    /// Secondary edge bevel.
    public var edgeBevel: MaterialKey = "metal.surgical-mirror"
    /// Handle scales.
    public var scales: MaterialKey = "plastic.pom"
    /// Tang, bolster and rivets.
    public var steel: MaterialKey = "metal.stainless"
    public init() {}

    /// Direction the cutting edge faces (asset space).
    public var edgeDirection: V3 { V3(0, 0, -1) }
    /// Point of the tip (asset space).
    public var tipPoint: V3 { placement().point(V3(bladeLength, 0, tipZ)) }
    /// Middle of the handle (asset space), where a hand closes.
    public var gripPoint: V3 { placement().point(V3(-handleLength * 0.5 - 0.006, 0, -0.012)) }

    var tipZ: Float { spineZ(1) }
    func spineZ(_ u: Float) -> Float { u < 0.45 ? 0 : -heelHeight * 0.4 * pow((u - 0.45) / 0.55, 2.4) }
    func edgeZ(_ u: Float) -> Float { u < 0.25 ? -heelHeight : -heelHeight * (1 - 0.6 * pow((u - 0.25) / 0.75, 2.2)) }

    /// Local knife frame (blade plane XZ, spine at z = 0) to asset space: tilt onto handle and tip, center, ground.
    func placement() -> Xform {
        let tilt = atan2(handleThickness / 2, bladeLength + handleLength * 0.55)
        let rot = simd_quatf(angle: -tilt, axis: V3(0, 0, 1))
        let contact = V3(-handleLength * 0.55, -handleThickness / 2, -0.012), tip = V3(bladeLength, 0, tipZ)
        let lowY = min(rot.act(contact).y, rot.act(tip).y)
        let minX = -handleLength - 0.01, maxX = bladeLength
        return Xform(translation: V3(-(minX + maxX) / 2, -lowY, heelHeight / 2 - 0.004), rotation: rot)
    }

    func bladeSurfaces(stations: Int, across: Int) -> [Surface] {
        let L = bladeLength
        var body: [[V3]] = [], bevel: [[V3]] = []
        for i in 0...stations {
            let s = Float(i) / Float(stations)
            let u = min(0.996, 1 - pow(1 - s, 1.35))
            let x = -0.006 + (L + 0.006) * u
            let zs = spineZ(u), ze = edgeZ(u), h = zs - ze
            let ts = spineThickness * (1 - 0.8 * pow(u, 1.25))
            let tb = min(0.03, 0.0012 / max(h, 0.001))                  // bevel ~1.2 mm tall
            func w(_ t: Float) -> Float { ts * (0.1 + 0.9 * pow(t, 0.9)) }
            var ring: [V3] = []
            for k in 0...across { let t = tb + (1 - tb) * Float(k) / Float(across); ring.append(V3(x, w(t) / 2, ze + t * h)) }
            ring.append(V3(x, 0, zs + ts * 0.25))                         // rounded spine
            for k in stride(from: across, through: 0, by: -1) { let t = tb + (1 - tb) * Float(k) / Float(across); ring.append(V3(x, -w(t) / 2, ze + t * h)) }
            body.append(ring)
            let eb = w(tb) * 0.98, e0: Float = 0.00012
            bevel.append([V3(x, e0 / 2, ze), V3(x, eb / 2, ze + tb * h * 1.02), V3(x, 0, ze + tb * h * 1.1),
                          V3(x, -eb / 2, ze + tb * h * 1.02), V3(x, -e0 / 2, ze)])
        }
        func oriented(_ s: Surface) -> Surface {
            var s = s
            // Outward normals: the vertex at the +Y face mid-height must face +Y.
            if let i = s.positions.indices.max(by: { s.positions[$0].y < s.positions[$1].y }), s.normals[i].y < 0 { s = s.flipped() }
            s.uvs = s.positions.map { V2($0.x, $0.z) }
            s.computeTangents()
            return s
        }
        return [oriented(Prim.loft(body, capStart: true, capEnd: true, material: blade)),
                oriented(Prim.loft(bevel, capStart: true, capEnd: true, material: edgeBevel))]
    }

    func handleOutline() -> [V2] {
        let hl = handleLength
        let pts: [V2] = [V2(-0.004, 0.0012), V2(-hl * 0.45, 0.0028), V2(-hl * 0.9, 0.0022), V2(-hl - 0.004, -0.003),
                         V2(-hl - 0.007, -0.012), V2(-hl - 0.003, -0.024), V2(-hl * 0.9, -0.0285), V2(-hl * 0.5, -0.024),
                         V2(-hl * 0.18, -0.0245), V2(-0.004, -0.027)]
        return Shape2D.rounded(pts, radius: 0.005, segments: 4)
    }

    func model(stations: Int, across: Int, detail: Bool) -> Model {
        var m = Model(name: Self.id)
        for s in bladeSurfaces(stations: stations, across: across) { m.add(s) }
        m.add(handleParts(detail: detail))
        var out = Model(name: Self.id)
        let p = placement()
        for s in m.surfaces { out.surfaces.append(s.transformed(p)) }
        groundAO(&out, height: 0.01, floor: 0.6)
        return out
    }

    /// Tang, POM scales, half bolster and rivets in the knife frame (handle toward -X, spine at z = 0,
    /// edge toward -Z, scales facing +-Y). The knife block reuses it for seated knives.
    public func handleParts(detail: Bool) -> Model {
        var m = Model(name: "handle")
        // Extrusions along local Y (outline x, z -> rotate +90 about X maps outline y to z).
        let toY = simd_quatf(degrees: 90, axis: V3(1, 0, 0))
        let o = handleOutline()
        m.add(Prim.extrude(Shape2D.offset(o, 0.0003), depth: spineThickness, bevel: 0.0003, bevelSegments: 1, material: steel),
              Xform(rotation: toY))
        let half = handleThickness / 2, bev: Float = 0.0038
        let depth = half + bev
        for sgn: Float in [-1, 1] {
            let scale = Prim.extrude(Shape2D.offset(o, -0.0003), depth: depth, bevel: bev, bevelSegments: detail ? 4 : 2, material: scales)
            m.add(scale, Xform(translation: V3(0, sgn * (half - depth / 2), 0), rotation: toY))
        }
        // Half bolster at the heel.
        m.add(Prim.superellipsoid(V3(0.016, 0.0118, 0.029), exponent: 3, subdivisions: detail ? 8 : 4, material: steel),
              Xform(translation: V3(-0.003, 0, -0.0125)))
        if detail {
            for x in [Float(-0.03), -0.068, -0.106].map({ $0 * handleLength / 0.125 }) {
                for sgn: Float in [-1, 1] {
                    panRivet(&m, at: V3(x, sgn * (half - 0.00005), -0.0118), normal: V3(0, sgn, 0), radius: 0.0029, height: 0.00025, material: steel)
                }
            }
        }
        return m
    }

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(stations: 64, across: 8, detail: true), model(stations: 24, across: 4, detail: false)], switchDistances: [2])
    }
}
