import simd
import Foundation

/// Three-sided canted bay window: 1.45 m centre unit and two 0.7 m side units at 45 degrees, each a
/// double-hung window (two-over-two sashes, frame, sill), corner posts, a paneled apron on two
/// carved brackets, frieze and cornice, and a copper-clad hip roof back to the wall. Wall plane at
/// z = -depth/2, the bay projects +Z; base y = 0 is the foot of the brackets.
public struct BayWindow: RealAsset {
    public static let id = "bay-window"
    public static let summary = "Three-sided bay window: angled side units and center unit with double-hung sashes, paneled base, roof with copper cap and seat board."
    public static let tags = ["structure", "architecture", "facade", "window", "wood", "glass"]
    public static let budget = 30_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 10, distance: 1.0, studio: true)

    /// Centre face width (m).
    public var centerWidth: Float = 1.45
    /// Side face width (m), canted at `angle`.
    public var sideWidth: Float = 0.7
    /// Cant of the side faces (degrees from the wall).
    public var angle: Float = 45
    /// Apron (paneled base) height (m).
    public var apron: Float = 0.7
    /// Window zone height (m).
    public var windowHeight: Float = 1.45
    /// Lites per sash (columns, rows).
    public var lites: (Int, Int) = (2, 1)
    public var trimMaterial: MaterialKey = "wood.painted-exterior:EAE6DA"
    public var sashMaterial: MaterialKey = "wood.painted-exterior:2B2F2C"
    public var roofMaterial: MaterialKey = "metal.copper-patina"
    public var glass: MaterialKey = "glass.pane"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let a = angle * .pi / 180
        let Wc = centerWidth, Ws = sideWidth
        let proj = Ws * sin(a)
        let zw = -(proj + 0.1) / 2
        let tm = trimMaterial
        let y0: Float = 0.25, yA = y0 + apron, yW = yA + windowHeight, yC = yW + 0.3
        // Plan corners: wall left, front left, front right, wall right.
        let p0 = V2(-(Wc / 2 + Ws * cos(a)), zw), p1 = V2(-Wc / 2, zw + proj), p2 = V2(Wc / 2, zw + proj), p3 = V2(Wc / 2 + Ws * cos(a), zw)
        let faces: [(V2, V2)] = [(p0, p1), (p1, p2), (p2, p3)]

        for (fi, (a2, b2)) in faces.enumerated() {
            let c = (a2 + b2) / 2, w = simd_distance(a2, b2)
            let dir = simd_normalize(b2 - a2)
            let yaw = atan2(-dir.y, dir.x)                         // local +X along the face
            let q = simd_quatf(angle: yaw, axis: .up)
            let X = Xform(translation: V3(c.x, 0, c.y), rotation: q)
            var f: [Surface] = []
            // Apron: framed raised panel.
            f.append(HK.box(V3(w, apron, 0.08), V3(0, y0 + apron / 2, -0.02), tm, r: 0.004))
            f += FK.raisedPanel(w: w - 0.2, h: apron - 0.2, t: 0.04, at: V3(0, y0 + apron / 2, 0.03), mat: tm, raise: 0.035)
            // Sill with drip nose.
            f.append(HK.box(V3(w + 0.03, 0.05, 0.14), V3(0, yA + 0.025, 0.03), tm, r: 0.01))
            // Window frame and two sashes (upper outside, lower inside).
            let fw: Float = 0.08, ow = w - 2 * fw - 0.04
            for sx: Float in [-1, 1] { f.append(FK.vbox(V3(fw, windowHeight - 0.05, 0.1), V3(sx * (w / 2 - fw / 2), yA + 0.05 + (windowHeight - 0.05) / 2, 0), tm)) }
            f.append(HK.box(V3(w, 0.1, 0.1), V3(0, yW - 0.05, 0), tm, r: 0.004))
            let sh = (windowHeight - 0.2) / 2 + 0.02
            for s in FK.sash(w: ow, h: sh, t: 0.035, mat: sashMaterial, glass: glass, muntins: lites) { f.append(s.transformed(Xform(translation: V3(0, yW - 0.1 - sh, 0.01)))) }
            for s in FK.sash(w: ow, h: sh, t: 0.035, bottom: 0.07, mat: sashMaterial, glass: glass, muntins: lites) { f.append(s.transformed(Xform(translation: V3(0, yA + 0.05, -0.03)))) }
            // Frieze above the window.
            f.append(HK.box(V3(w, 0.2, 0.08), V3(0, yW + 0.1, -0.005), tm, r: 0.004))
            for s in f { m.add(s, X.jittered(&rng, deg: 0, offset: 0.0002)) }
            _ = fi
        }
        // Corner posts at the two front corners.
        for p in [p1, p2] {
            m.add(FK.vbox(V3(0.1, yW - y0, 0.1), V3(p.x, y0 + (yW - y0) / 2, p.y - 0.01), tm, r: 0.012))
        }
        // Cornice: three stepped bands following the plan outline.
        func band(y: Float, h: Float, out: Float) {
            for (a2, b2) in faces {
                let dir = simd_normalize(b2 - a2), n = V2(dir.y, -dir.x) * -1
                let a3 = a2 + n * out - dir * (out * 0.42), b3 = b2 + n * out + dir * (out * 0.42)
                let c = (a3 + b3) / 2, w = simd_distance(a3, b3)
                let yaw = atan2(-dir.y, dir.x)
                m.add(HK.box(V3(w, h, 0.06 + out), V3(0, 0, 0), tm, r: min(0.012, h * 0.4)),
                      Xform(translation: V3(c.x, y + h / 2, c.y) - V3(n.x, 0, n.y) * ((0.06 + out) / 2 - out), rotation: simd_quatf(angle: yaw, axis: .up)))
            }
        }
        band(y: yW + 0.2, h: 0.04, out: 0.04)
        band(y: yW + 0.24, h: 0.06, out: 0.09)
        // Hip roof from the eave outline back to the wall, copper.
        let eave: Float = 0.12, yE = yC, yR = yC + 0.35
        var roof = Surface(material: roofMaterial)
        let e0 = p0 + V2(-eave * 0.4, 0), e1 = p1 + V2(-eave * 0.4, eave), e2 = p2 + V2(eave * 0.4, eave), e3 = p3 + V2(eave * 0.4, 0)
        let eaves = [e0, e1, e2, e3]
        let ridge = eaves.map { V2($0.x * 0.7, zw) }
        for i in 0..<3 {
            HK.quad(&roof, V3(eaves[i].x, yE, eaves[i].y), V3(eaves[i + 1].x, yE, eaves[i + 1].y),
                    V3(ridge[i + 1].x, yR, ridge[i + 1].y), V3(ridge[i].x, yR, ridge[i].y)) { V2($0.x, $0.z + $0.y) }
        }
        roof.computeTangents()
        m.add(roof); m.add(roof.flipped())
        // Roof edge roll and wall flashing.
        m.add(HK.pipe(eaves.map { V3($0.x, yE, $0.y) }, r: 0.015, sides: 6, mat: roofMaterial))
        m.add(HK.box(V3(2 * abs(ridge[0].x) + 0.1, 0.12, 0.01), V3(0, yR + 0.04, zw + 0.005), roofMaterial, r: 0.003))
        // Two carved brackets under the apron at the front corners.
        for p in [p1, p2] {
            // Curved strut from a wall plate up to the corner under the apron.
            let path = (0...10).map { i -> V3 in
                let t = Float(i) / 10
                return V3(p.x, 0.04 + (y0 - 0.06) * sqrt(t), zw + 0.03 + (p.y - 0.05 - zw - 0.03) * t)
            }
            m.add(Prim.sweep(Shape2D.roundedRect(0.07, 0.05, radius: 0.01, segments: 2), along: path, up: V3(1, 0, 0), material: tm))
            m.add(HK.box(V3(0.12, y0 + 0.02, 0.03), V3(p.x, (y0 + 0.02) / 2, zw + 0.015), tm, r: 0.008))
            m.add(HK.box(V3(0.1, 0.03, p.y - zw), V3(p.x, y0 - 0.015, (p.y + zw) / 2), tm, r: 0.008))
        }
        // Floor of the bay (soffit board) under the apron.
        var soffit = Surface(material: tm)
        HK.quad(&soffit, V3(p0.x, y0, p0.y), V3(p3.x, y0, p3.y), V3(p2.x, y0, p2.y), V3(p1.x, y0, p1.y)) { V2($0.x, $0.z) }
        soffit.computeTangents()
        m.add(soffit); m.add(soffit.flipped())

        groundAO(&m, height: 0.2, floor: 0.75)
        return LODModel(m)
    }
}
