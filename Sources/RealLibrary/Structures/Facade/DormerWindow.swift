import simd
import Foundation

/// Gable dormer on a 40-degree shingled roof patch: clapboard front wall and triangular side cheeks,
/// a two-over-two double-hung window with casing and sill, a gable roof with asphalt shingle courses,
/// fascia and rake trim, aluminum step flashing where the cheeks meet the main roof. The main roof's
/// eave faces +Z; base y = 0 is the eave line of the roof patch.
public struct DormerWindow: RealAsset {
    public static let id = "dormer-window"
    public static let summary = "Gable dormer on a roof slope: double-hung window in a clapboard-sided dormer with shingled gable roof, trim and flashing."
    public static let tags = ["structure", "architecture", "roof", "window", "wood", "glass"]
    public static let budget = 29_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 34, elevation: 16, distance: 1.0, studio: true)

    /// Dormer width, outside of the cheeks (m).
    public var width: Float = 1.2
    /// Window sash opening (m).
    public var windowSize = V2(0.75, 1.0)
    /// Main roof pitch (degrees).
    public var pitch: Float = 40
    /// Dormer roof rise above the wall plate (m).
    public var dormerRise: Float = 0.4
    /// Width of the main roof patch around the dormer (m).
    public var patchWidth: Float = 2.4
    public var trimMaterial: MaterialKey = "wood.painted-exterior"
    public var sidingMaterial: MaterialKey = "wood.painted-exterior:9FAEB0"
    public var shingleMaterial: MaterialKey = "roofing.shingle-granule"
    public var flashingMaterial: MaterialKey = "metal.galvanized"
    public var glass: MaterialKey = "glass.pane"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let t = tan(pitch * .pi / 180)
        let zE: Float = 1.0, zBack: Float = -1.4
        func roofY(_ z: Float) -> Float { (zE - z) * t }
        let W = width, hw = W / 2
        let zF: Float = 0.55
        let yB = roofY(zF), yP = yB + windowSize.y + 0.42      // front wall bottom, wall plate
        let yR = yP + dormerRise
        let tm = trimMaterial

        // Main roof patch: shingle courses as overlapping strips, sheathing edge under.
        let patchLen = (zE - zBack) / cos(pitch * .pi / 180)
        let rot = simd_quatf(angle: atan(t), axis: V3(1, 0, 0)) * simd_quatf(degrees: 180, axis: .up)
        let course: Float = 0.14
        var u: Float = 0
        while u < patchLen - 0.01 {
            let p = V3(0, 0, zE) + rot.act(V3(0, 0, u))
            m.add(HK.box(V3(patchWidth, 0.006, course + 0.06), V3(0, 0, 0), shingleMaterial, r: 0.002, seg: 1),
                  Xform(translation: p + rot.act(V3(0, 0.006, course / 2)), rotation: rot * simd_quatf(degrees: -1.5, axis: V3(1, 0, 0))))
            // 3-tab keyway slots, offset half a tab every course.
            let off: Float = Int(u / course) % 2 == 0 ? 0 : 0.17
            var sx = -patchWidth / 2 + 0.17 + off
            while sx < patchWidth / 2 - 0.05 {
                m.add(cuboid(V3(0.008, 0.002, 0.11), material: "plastic.matte:1E1E1E"),
                      Xform(translation: p + rot.act(V3(-sx, 0.0135, 0.03)) , rotation: rot * simd_quatf(degrees: -1.5, axis: V3(1, 0, 0))))
                sx += 0.34
            }
            u += course
        }
        m.add(HK.box(V3(patchWidth, 0.02, patchLen), V3(0, -0.012, patchLen / 2), "wood.plywood", r: 0.002, seg: 1), Xform(translation: V3(0, 0, zE), rotation: rot))
        m.add(HK.box(V3(patchWidth + 0.02, 0.15, 0.025), V3(0, -0.06, zE + 0.012), tm, r: 0.004))

        // Front wall: clapboards around the window opening.
        let ow = windowSize.x + 0.1, oh = windowSize.y + 0.06
        let oy0 = yB + 0.22
        var y = yB
        let lap: Float = 0.1
        while y < yP - 0.01 {
            let h = min(lap + 0.015, yP - y)
            let inOpening = y + h > oy0 && y < oy0 + oh
            let parts: [(Float, Float)] = inOpening ? [(-hw, -ow / 2 - 0.08), (ow / 2 + 0.08, hw)] : [(-hw, hw)]
            for (a, b) in parts {
                m.add(HK.box(V3(b - a, h, 0.018), V3((a + b) / 2, y + h / 2, zF + 0.009), sidingMaterial, r: 0.003),
                      Xform(rotation: simd_quatf(degrees: -2.5, axis: V3(1, 0, 0))).jittered(&rng, deg: 0, offset: 0))
            }
            y += lap
        }
        // Window: casing, frame, sashes, sill.
        let cz = zF + 0.02
        m.add(FK.casing(openW: ow, openH: oh, width: 0.08, thick: 0.02, z: cz, y0: oy0, mat: tm, headHeight: 0.1))
        let sh = windowSize.y / 2 + 0.02
        for s in FK.sash(w: windowSize.x, h: sh, t: 0.035, mat: tm, glass: glass, muntins: (2, 1)) { m.add(s, Xform(translation: V3(0, oy0 + 0.03 + windowSize.y - sh, cz - 0.01))) }
        for s in FK.sash(w: windowSize.x, h: sh, t: 0.035, bottom: 0.07, mat: tm, glass: glass, muntins: (2, 1)) { m.add(s, Xform(translation: V3(0, oy0 + 0.03, cz - 0.05))) }
        m.add(HK.box(V3(ow + 0.24, 0.04, 0.09), V3(0, oy0 - 0.02, cz + 0.03), tm, r: 0.008))
        for sx: Float in [-1, 1] { m.add(FK.vbox(V3(0.08, yP - yB, 0.03), V3(sx * (hw - 0.04), yB + (yP - yB) / 2, zF + 0.025), tm, r: 0.004)) }

        // Cheeks: triangles from the front corners back to where the plate meets the main roof.
        let zC = zE - yP / t
        for sx: Float in [-1, 1] {
            let prof: [V2] = [V2(zF, yB), V2(zF, yP), V2(zC, yP)]
            let cheek = Prim.extrude(prof, depth: 0.02, bevel: 0.002, bevelSegments: 1, material: sidingMaterial)
            m.add(cheek, Xform(translation: V3(sx * (hw - 0.01), 0, 0), rotation: simd_quatf(degrees: -90, axis: .up)))
            // Step flashing along the cheek foot.
            var z = zF - 0.02
            while z > zC + 0.05 {
                m.add(HK.box(V3(0.004, 0.1, 0.14), V3(sx * (hw + 0.003), roofY(z) + 0.04, z - 0.07), flashingMaterial, r: 0.001, seg: 1))
                z -= 0.14
            }
        }
        // Dormer roof: two shingled planes from the ridge to the eaves, rake boards and fascia.
        let ov: Float = 0.12, zR0 = zF + ov
        let zR1 = zE - yR / t
        for sx: Float in [-1, 1] {
            let eave = V3(sx * (hw + ov), yP - ov * dormerRise / hw, 0)
            var roof = Surface(material: shingleMaterial)
            let a = V3(0, yR, zR0), b = V3(eave.x, eave.y, zR0), c = V3(eave.x, eave.y, zR1 + (yR - eave.y) / t), d = V3(0, yR, zR1)
            if sx > 0 { HK.quad(&roof, a, b, c, d) { V2($0.z, $0.y + abs($0.x)) } } else { HK.quad(&roof, a, d, c, b) { V2($0.z, $0.y + abs($0.x)) } }
            roof.computeTangents()
            m.add(roof); m.add(roof.flipped().transformed(Xform(translation: V3(0, -0.02, 0))))
            // Shingle course lines on the dormer roof.
            let slopeLen = simd_distance(V2(0, yR), V2(eave.x, eave.y))
            let n = Int(slopeLen / course)
            for k in 1..<max(2, n) {
                let f = Float(k) / Float(n)
                let p0 = a + (b - a) * f
                m.add(HK.box(V3(0.004, 0.008, zR0 - zR1 - 0.1), V3(0, 0, 0), shingleMaterial, r: 0.002, seg: 1),
                      Xform(translation: V3(p0.x, p0.y + 0.006, (zR0 + zR1) / 2 + 0.05), rotation: simd_quatf(angle: sx * atan(dormerRise / hw), axis: V3(0, 0, 1)) * simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
                let pm = a + (b - a) * (f - 0.5 / Float(n))
                var zs = zR0 - 0.1 - (k % 2 == 0 ? 0 : 0.17)
                while zs > zR1 + 0.15 {
                    m.add(cuboid(V3(0.1, 0.012, 0.008), material: "plastic.matte:1E1E1E"),
                          Xform(translation: V3(pm.x, pm.y + 0.004, zs), rotation: simd_quatf(angle: sx * atan(dormerRise / hw), axis: V3(0, 0, 1)) * simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
                    zs -= 0.34
                }
            }
            // Rake board along the front gable edge, fascia along the eave.
            let (rs, rx) = board(from: V3(0, yR + 0.01, zR0 + 0.01), to: V3(eave.x, eave.y + 0.01, zR0 + 0.01), width: 0.12, thick: 0.025, up: V3(0, 0, 1), bevel: 0.004, material: tm, extend: 0.02)
            m.add(rs, rx)
            let (fs, fx) = board(from: V3(eave.x, eave.y - 0.03, zR0), to: V3(eave.x, eave.y - 0.03, zF - 0.3), width: 0.1, thick: 0.02, up: V3(sx, 0, 0), bevel: 0.004, material: tm)
            m.add(fs, fx)
        }
        // Ridge cap.
        m.add(HK.box(V3(0.1, 0.02, zR0 - zR1), V3(0, yR + 0.008, (zR0 + zR1) / 2), shingleMaterial, r: 0.008))
        // Gable triangle (siding) above the wall plate.
        let tri = Prim.extrude([V2(-hw, yP), V2(hw, yP), V2(0, yR - 0.02)], depth: 0.02, bevel: 0.002, bevelSegments: 1, material: sidingMaterial)
        m.add(tri, Xform(translation: V3(0, 0, zF + 0.01)))
        m.add(HK.box(V3(W + 0.04, 0.05, 0.05), V3(0, yP, zF + 0.03), tm, r: 0.006))

        groundAO(&m, height: 0.15, floor: 0.75)
        let bb = m.bounds
        let c = Xform(translation: V3(0, -bb.min.y, -(bb.min.z + bb.max.z) / 2))
        return LODModel(m.transformed(c))
    }
}
