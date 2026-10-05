import simd
import Foundation

/// Scooped chocolate chunk cookie dough: a lumpy ball with a flattened base. Chocolate chunks on the
/// surface sit in pockets pressed into the dough (the dough shell dents under each chunk, so the two
/// closed shells touch without overlapping); chunks buried inside are cavities in the dough shell
/// filled by chocolate solids, so a cut shows dough and chocolate caps side by side.
public struct CookieDough: RealFood {
    public static let id = "cookie-dough"
    public static let summary = "Chocolate chunk cookie dough scoop, 4.5 cm: lumpy ball with flattened base, surface and buried chocolate chunks."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.batter
    public static let preview = PreviewHint(azimuth: 30, elevation: 30, distance: 0.16, studio: true)

    /// Ball diameter (m).
    public var diameter: Float = 0.042
    /// Surface and buried chunk counts.
    public var surfaceChunks = 12
    public var buriedChunks = 6
    /// Material keys.
    public var dough: MaterialKey = "food.cookie-dough"
    public var chocolate: MaterialKey = "food.chocolate-chunk"
    public init() {}

    public var coreCenter: V3 { V3(0, diameter * 0.8 / 2 + 0.002, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? {
        if key == dough { return dough }
        if key == chocolate { return chocolate }
        return nil
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let R = diameter / 2
        let lumps = (0..<22).map { _ in (rng.unitVector(), rng.float(-0.07...0.11), rng.float(0.12...0.35)) }
        let ph = (0..<3).map { _ in rng.float(0...6.28) }
        // Dough radius along a direction (before pockets): lumpy sphere, flattened base.
        func radius(_ d: V3) -> Float {
            var k: Float = 1 + 0.025 * sin(d.x * 9 + ph[0]) * sin(d.y * 8 + ph[1]) * sin(d.z * 10 + ph[2])
                + 0.012 * sin(d.x * 21 + d.y * 7 + ph[1]) * sin(d.z * 19 - d.y * 11 + ph[2]) + 0.007 * sin(d.y * 31 + d.x * 13 + ph[0])
            for (c, amp, w) in lumps { k += amp * smoothstep(1 - w, 1, simd_dot(d, c)) }
            return R * k
        }
        func flatten(_ p: V3) -> V3 {
            let floorY = -R * 0.8
            return p.y < floorY + 0.004 ? V3(p.x * 1.04, floorY + (p.y - floorY) * 0.25 + 0.003, p.z * 1.04) : p
        }
        // Surface chunks: directions in the upper 80 % of the ball.
        var chunkDirs: [V3] = []
        while chunkDirs.count < surfaceChunks {
            let d = rng.unitVector()
            if d.y > -0.3 && chunkDirs.allSatisfy({ simd_dot($0, d) < 0.86 }) { chunkDirs.append(d) }
        }
        let chunkSize = chunkDirs.map { _ in (rng.float(0.0028...0.0042), rng.float(0.0017...0.0024)) }
        var s = FoodMesh.revolve(edge: 0.0021, seamTile: 0.04, material: dough) { t in
            let a = Float.pi * t
            return V2(R * sin(a), -R * cos(a))
        }
        s.deform { p in
            let d = simd_normalize(p)
            var r = radius(d)
            // Pockets: dent the dough under each surface chunk (wider and deeper than the chunk).
            for (i, c) in chunkDirs.enumerated() {
                let (cw, ch) = chunkSize[i]
                let cosA = simd_dot(d, c)
                guard cosA > 0.5 else { continue }
                let rho = radius(c) * sqrt(max(0, 1 - cosA * cosA))
                let lim = cw * 1.25
                if rho < lim { r -= ch * 1.2 * sqrt(1 - (rho / lim) * (rho / lim)) }
            }
            return flatten(d * r)
        }
        var choc = Surface(material: chocolate)
        for (i, c) in chunkDirs.enumerated() {
            var r = rng.fork(i)
            let (cw, ch) = chunkSize[i]
            let base = radius(c)
            let up = c, side = simd_normalize(simd_cross(up, abs(up.y) < 0.9 ? V3(0, 1, 0) : V3(1, 0, 0)))
            let fwd = simd_cross(side, up)
            let ph = r.float(0...6.28)
            var blob = FoodMesh.revolve(edge: 0.0017, seamTile: 0.01, material: chocolate) { t in
                let a = Float.pi * t
                return V2(0.0035 * sin(a), -0.0035 * cos(a))
            }
            blob.deform { q0 in
                let q = q0 / 0.0035
                let ang = atan2(q.z, q.x)
                let k = 1 + 0.18 * sin(ang * 3 + ph) + 0.1 * sin(ang * 5 + ph * 2)
                // Faceted, angular chunk: squarish in plan, flatter on top.
                let lx = q.x * cw * k, lz = q.z * cw * k * 0.85
                let ly = q.y > 0 ? q.y * ch * 0.9 : q.y * ch
                let p = c * base + up * ly + side * lx + fwd * lz
                return flatten(p)
            }
            choc.append(blob)
        }
        // Buried chunks: chocolate solids inside the dough with matching cavities.
        var placed: [V3] = []
        var tries = 0
        while placed.count < buriedChunks && tries < 200 {
            tries += 1
            let p = rng.unitVector() * rng.float(0...R * 0.55)
            if p.y < -R * 0.4 || placed.contains(where: { simd_distance($0, p) < 0.009 }) { continue }
            placed.append(p)
        }
        for (i, p) in placed.enumerated() {
            var r = rng.fork(100 + i)
            let sz = V3(r.float(0.0025...0.004), r.float(0.0018...0.003), r.float(0.0025...0.004))
            let rot = simd_quatf(angle: r.float(0...6.28), axis: r.unitVector())
            var blob = FoodMesh.revolve(edge: 0.0018, seamTile: 0.01, material: chocolate) { t in
                let a = Float.pi * t
                return V2(0.0033 * sin(a), -0.0033 * cos(a))
            }
            blob.deform { q in p + rot.act(q / 0.0033 * sz) }
            choc.append(blob)
            s.append(blob.flipped().with(material: dough))
        }
        var m = Model(name: Self.id)
        m.add(FoodMesh.boxUV(s)); m.add(choc)
        let bb = m.bounds
        m = m.transformed(Xform(translation: V3(0, -bb.min.y, 0)))
        groundAO(&m, height: 0.01, floor: 0.6)
        return LODModel(m)
    }
}
