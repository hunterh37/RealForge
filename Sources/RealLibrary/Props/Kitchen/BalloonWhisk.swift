import simd
import Foundation

/// 11 in French balloon whisk lying on its side: four nested loops of 1.6 mm stainless wire (eight
/// wires) crossing at a rounded tip, a ferrule where they enter a hollow brushed handle that swells in
/// the middle, and an end cap with a hanging ring. Handle toward -X, balloon toward +X; the whisk rests
/// on the balloon and the handle end, so its axis tilts a few degrees.
public struct BalloonWhisk: RealAsset {
    public static let id = "balloon-whisk"
    public static let summary = "11 in balloon whisk: four nested stainless wire loops, ferrule, brushed stainless handle with hanging ring."
    public static let tags = ["prop", "kitchen", "cookware", "metal", "tool", "handheld"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 35, distance: 0.6, studio: true)

    /// Balloon length from the ferrule to the tip (m).
    public var balloonLength: Float = 0.165
    /// Balloon radius at its widest (m).
    public var balloonRadius: Float = 0.032
    /// Number of wire loops (two wires each).
    public var loops: Int = 4
    /// Wire radius (m).
    public var wire: Float = 0.0008
    /// Handle length (m).
    public var handleLength: Float = 0.115
    /// Wire and handle finishes.
    public var wireMaterial: MaterialKey = "metal.surgical"
    public var handleMaterial: MaterialKey = "metal.stainless"
    public init() {}

    /// Middle of the balloon (asset space), the working end.
    public var workPoint: V3 { placement().point(V3(balloonLength * 0.6, 0, 0)) }
    /// Middle of the handle (asset space).
    public var gripPoint: V3 { placement().point(V3(-handleLength * 0.5, 0, 0)) }

    func radiusAt(_ w: Float) -> Float { balloonRadius / 0.47 * w * pow(max(0, 1 - w * w), 0.6) }

    func placement() -> Xform {
        let xb = balloonLength * 0.6, rh: Float = 0.0105
        let tilt = asin((balloonRadius - rh) / (xb + handleLength))
        let rot = simd_quatf(angle: tilt, axis: V3(0, 0, 1))
        let low = min(rot.act(V3(xb, -balloonRadius, 0)).y, rot.act(V3(-handleLength, -rh, 0)).y)
        let minX = -handleLength - 0.016, maxX = balloonLength
        return Xform(translation: V3(-(minX + maxX) / 2, -low, 0), rotation: rot)
    }

    func model(steps: Int, sides: Int, segments: Int, detail: Bool) -> Model {
        var m = Model(name: Self.id)
        let L = balloonLength
        for k in 0..<loops {
            let a = Float(k) / Float(loops) * .pi
            let tipX = L - Float(k) * (wire * 2.3)
            let path = (0...steps).map { i -> V3 in
                let w = -0.985 + 1.97 * Float(i) / Float(steps)
                let x = tipX * (1 - pow(abs(w), 2.5))
                let r = radiusAt(w) * (1 - Float(k) * 0.012)
                return V3(x, r * cos(a), r * sin(a))
            }
            m.add(Prim.tube(path, radii: path.map { _ in wire }, sides: sides, seamTile: 0.02, material: wireMaterial, capEnd: true))
        }
        // Ferrule and handle, turned along +Y then laid along -X.
        let H = handleLength
        let prof: [(Float, Float)] = [(0, -0.002), (0.0072, -0.002), (0.0088, 0.004), (0.0088, 0.016), (0.0082, 0.019),
                                      (0.0086, 0.024), (0.0105, H * 0.45), (0.0102, H * 0.75), (0.0094, H - 0.006),
                                      (0.0088, H - 0.002), (0.0065, H + 0.002), (0.003, H + 0.0035), (0, H + 0.0038)]
        let toX = simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1))      // +Y -> -X
        m.add(turned(prof, segments: segments, material: handleMaterial, seamTile: 0.06, grainVertical: true), Xform(translation: V3(0.016, 0, 0), rotation: toX))
        // Ferrule seam bead and the hanging ring through the end cap.
        m.add(Prim.torus(major: 0.0088, minor: 0.0006, segments: segments, sides: 5, material: handleMaterial),
              Xform(translation: V3(0.016 - 0.0175, 0, 0), rotation: toX))
        m.add(Prim.torus(major: 0.0085, minor: 0.0013, segments: detail ? 28 : 14, sides: detail ? 8 : 5, material: wireMaterial),
              Xform(translation: V3(0.016 - H - 0.0105, 0, 0)))
        var out = Model(name: Self.id)
        let p = placement()
        for s in m.surfaces { out.surfaces.append(s.transformed(p)) }
        groundAO(&out, height: 0.02, floor: 0.6)
        return out
    }

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(steps: 110, sides: 6, segments: 32, detail: true), model(steps: 48, sides: 4, segments: 16, detail: false)],
                 switchDistances: [2])
    }
}
