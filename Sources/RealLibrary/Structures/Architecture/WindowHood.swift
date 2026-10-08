import simd
import Foundation

/// Window hood: flat stone lintel over an opening with a projecting keystone, capped by a small
/// cornice with mitered returns. Back on the wall plane; the lintel soffit sits at y = 0, so place the
/// asset at the window head.
public struct WindowHood: RealAsset {
    public static let id = "window-hood"
    public static let summary = "Window hood, 1.3 m: flat stone lintel with a projecting keystone under a molded cornice cap with mitered returns."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone"]
    public static let budget = 8_500
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 28, elevation: -6, distance: 1.0)

    /// Lintel width (m); the cornice overhangs it by `capOverhang` each side.
    public var width: Float = 1.2
    /// Lintel height (m).
    public var lintelHeight: Float = 0.26
    /// Lintel projection from the wall (m).
    public var lintelDepth: Float = 0.06
    /// Keystone width at the top and bottom (m).
    public var keyTop: Float = 0.2
    public var keyBottom: Float = 0.15
    /// Keystone drop below the lintel soffit (m).
    public var keyDrop: Float = 0.04
    /// Cornice overhang past the lintel ends (m).
    public var capOverhang: Float = 0.04
    /// Rain streak and soot strength.
    public var weathering: Float = 0.5
    public var material: MaterialKey = "stone.limestone"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, H = lintelHeight
        // Lintel with a slightly chamfered face.
        var lp = ArchProfile()
        lp.step(lintelDepth - 0.006); lp.line(0.006, 0.006); lp.fillet(H - 0.012); lp.line(-0.006, 0.006)
        m.add(ArchTrimKit.sweep(lp, length: W, material: material))
        // Keystone: tapered block dropping below the soffit and rising into the cornice bed.
        let kh = H + keyDrop + 0.02
        let key: [V2] = [V2(-keyBottom / 2, 0), V2(keyBottom / 2, 0), V2(keyTop / 2, kh), V2(-keyTop / 2, kh)]
        let kd = lintelDepth + 0.025
        m.add(Prim.extrude(key, depth: kd, bevel: 0.006, bevelSegments: 2, material: material + ":D2C8B2"),
              Xform(translation: V3(0, -keyDrop, kd / 2)))
        // Cornice cap: fillet, cyma reversa, corona, cyma recta.
        var cp = ArchProfile()
        cp.step(lintelDepth + 0.03); cp.fillet(0.012)
        cp.cymaReversa(0.03, 0.025); cp.step(0.03); cp.fillet(0.05)
        cp.step(0.006); cp.fillet(0.008); cp.cymaRecta(0.04, 0.03); cp.fillet(0.01)
        m.add(ArchTrimKit.returnedRun(cp, length: W + 2 * capOverhang, material: material), Xform(translation: V3(0, H, 0)))
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        return LODModel(ArchTrimKit.ground(m))
    }
}
