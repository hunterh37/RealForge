import simd
import Foundation

/// Type K 15 A removable-buttonhead cutout fuse link, out of its bag on the ground: a tin-plated copper
/// buttonhead and washer, the orange auxiliary tube over the fusible element, a short crimped sleeve and
/// a 23 in (584 mm) tinned stranded copper leader lying in a loose S. The lineman threads the leader
/// down through the cutout's fuse tube and wraps it round the lower trunnion stud.
public struct FuseLink: RealAsset {
    public static let id = "fuse-link"
    public static let summary = "Type K 15 A removable-buttonhead fuse link: tin-plated button, orange sheath tube over the element, tinned copper stranded leader."
    public static let tags = ["prop", "utility", "electrical", "handheld", "metal"]
    public static let budget = 8000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 0, elevation: 55, distance: 1.0, studio: true)

    /// Auxiliary tube length (m).
    public var tubeLength: Float = 0.15
    /// Leader (pigtail) length (m).
    public var leaderLength: Float = 0.584
    /// Tube color (sRGB hex).
    public var tubeColor: UInt32 = 0xE98A2A
    public var leader: MaterialKey = "metal.tinned-copper"
    public var button: MaterialKey = "metal.aluminum-brushed"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let tr: Float = 0.0046, y0: Float = 0.0095
        let tubeMat: MaterialKey = "plastic.orange:" + String(format: "%06X", tubeColor)
        // Along +X: buttonhead at x = 0, tube to x = tubeLength. Built along +Y, then laid down.
        var head = Model(name: "head")
        head.add(Prim.lathe([V2(0, -0.0105), V2(0.0045, -0.0105), V2(0.0058, -0.0095), V2(0.0058, -0.003), V2(0.0042, -0.0018), V2(0.0042, 0)],
                            segments: 20, material: button))
        head.add(Prim.cylinder(radius: 0.0095, height: 0.0013, bevel: 0.0004, segments: 24, material: button), Xform(translation: V3(0, -0.0018, 0)))
        // Orange auxiliary tube, slightly chamfered ends.
        head.add(Prim.lathe([V2(0.0026, 0), V2(tr - 0.0004, 0), V2(tr, 0.0008), V2(tr, tubeLength - 0.0008), V2(tr - 0.0004, tubeLength), V2(0.0026, tubeLength)],
                            segments: 18, seamTile: 0.1, material: tubeMat))
        // Clear printed rating sleeve.
        head.add(Prim.lathe([V2(tr + 0.0003, 0.055), V2(tr + 0.0003, 0.07)], segments: 18, material: "plastic.orange:F0B070"))
        // Crimp sleeve where the leader leaves the tube.
        head.add(Prim.lathe([V2(0.0022, tubeLength), V2(0.0032, tubeLength), V2(0.0032, tubeLength + 0.012), V2(0.0024, tubeLength + 0.014)],
                            segments: 12, material: "metal.tinned-copper"))
        // Laid out as it came out of the bag: buttonhead to the right, tube pointing -X, leader in an S.
        let k: Float = leaderLength / 1260
        func w(_ px: Float, _ py: Float) -> V3 { V3((px - 250) * k, 0.0024, (py - 300) * k) }
        let bx = w(428, 200)
        let lay = Xform(translation: V3(bx.x, y0, bx.z), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1)))
        m.add(head, lay)
        let x0 = bx.x - tubeLength - 0.014
        var ctrl: [V3] = [V3(x0, y0, bx.z), V3(x0 - 0.006, 0.006, bx.z + 0.002)]
        let pts2: [V2] = [V2(36, 222), V2(110, 245), V2(300, 252), V2(415, 270), V2(432, 300), V2(400, 330), V2(250, 350), V2(110, 380), V2(76, 405), V2(140, 412), V2(300, 414), V2(482, 425)]
        for p in pts2 { var q = w(p.x, p.y); q.x += rng.float(-0.003...0.003); q.z += rng.float(-0.003...0.003); ctrl.append(q) }
        var path = catmull(ctrl, per: 8)
        // Trim to the leader length.
        var acc: Float = 0, cut = path.count
        for i in 1..<path.count { acc += simd_length(path[i] - path[i - 1]); if acc > leaderLength { cut = i; break } }
        path = Array(path[0..<cut])
        // Strands: seven-wire bundle as three twisted sub-tubes around a core.
        m.add(Prim.tube(path, radii: path.map { _ in 0.0023 }, sides: 6, seamTile: 0.02, material: leader))
        var frames: [V3] = []
        for i in 0..<path.count {
            let t = i < path.count - 1 ? simd_normalize(path[i + 1] - path[i]) : simd_normalize(path[i] - path[i - 1])
            frames.append(t)
        }
        acc = 0
        for k in 0..<3 {
            var sp: [V3] = []
            var s: Float = 0
            for i in 0..<path.count {
                if i > 0 { s += simd_length(path[i] - path[i - 1]) }
                let t = frames[i]
                let a = simd_normalize(simd_cross(t, .up)), b = simd_cross(a, t)
                let ang = s / 0.012 * 2 * .pi + Float(k) * 2 * .pi / 3
                sp.append(path[i] + (a * cos(ang) + b * sin(ang)) * 0.0016)
            }
            m.add(Prim.tube(catmull(sp, per: 2), radii: catmull(sp, per: 2).map { _ in 0.0012 }, sides: 4, seamTile: 0.02, material: leader))
        }
        // Frayed end: a few strand tips splayed.
        if let e = path.last, path.count > 2 {
            let t = simd_normalize(e - path[path.count - 2])
            for k in 0..<4 {
                let a = Float(k) * 1.6
                let d = simd_normalize(t + V3(cos(a), 0.3, sin(a)) * 0.35)
                m.add(Prim.tube([e, e + d * 0.008], radii: [0.0005, 0.0004], sides: 4, seamTile: 0.02, material: leader))
            }
        }
        groundAO(&m, height: 0.01, floor: 0.55)
        let b = m.bounds, c = (b.min + b.max) / 2
        var out = Model(name: Self.id); out.add(m, Xform(translation: V3(-c.x, -b.min.y, -c.z)))
        return LODModel(out)
    }
}
