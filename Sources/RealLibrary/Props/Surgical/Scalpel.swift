import simd
import Foundation

/// Disposable safety scalpel with a #10 blade (retractable-shield class, ~156 mm shielded): flat molded
/// white handle 119 mm long with a fish-scale ribbed thumb grip at the back and a moulded 3 cm ruler scale;
/// #10 carbon-steel blade (7.2 mm wide, curved belly, mirror-ground edge bevel) set into the handle nose;
/// translucent blue polycarbonate shield sleeve with a closed nose, ridged thumb tab and lock bump. The
/// shield slides along X: forward it guards the blade (shielded), back over the handle it exposes it.
public struct Scalpel: RealArticulated {
    public static let id = "scalpel"
    public static let summary = "Disposable safety scalpel with a #10 blade: ribbed molded handle and a translucent blue shield that slides over the blade."
    public static let tags = ["prop", "medical", "surgical", "handheld", "tool", "plastic", "metal", "articulated"]
    public static let budget = 4_100
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 46, distance: 0.34, studio: true)

    public var handle: MaterialKey = "plastic.medical"
    public var shield: MaterialKey = "plastic.scalpel-shield"
    public var blade: MaterialKey = "metal.surgical"
    public var edge: MaterialKey = "metal.surgical-mirror"
    /// Shield travel from shielded to exposed (m).
    public var shieldTravel: Float = 0.046
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [2.5])
        let yc: Float = 0.005
        let hx0: Float = -0.075, hx1: Float = 0.044
        func hw(_ x: Float) -> Float {
            let u = (x - hx0) / (hx1 - hx0)
            var w: Float = 0.0090 + 0.0010 * sin(u * .pi) - 0.0016 * max(0, u - 0.75) / 0.25
            if x < hx0 + 0.004 { let v = (hx0 + 0.004 - x) / 0.004; w *= sqrt(max(0.1, 1 - v * v)) }
            return w
        }
        func hh(_ x: Float) -> Float {
            let u = (x - hx0) / (hx1 - hx0)
            var h: Float = 0.0050 + 0.0006 * sin(u * .pi) - 0.0010 * max(0, u - 0.8) / 0.2
            if x < hx0 + 0.003 { let v = (hx0 + 0.003 - x) / 0.003; h *= sqrt(max(0.2, 1 - v * v)) }
            return h
        }
        func topY(_ x: Float, _ z: Float) -> Float {
            let r = min(0.999, abs(2 * z / hw(x)))
            return yc + hh(x) / 2 * pow(1 - pow(r, 4), 0.25)
        }

        // MARK: handle
        for l in 0..<2 {
            let n = l == 0 ? 30 : 16
            let xs: [Float] = (0...n).map { k in hx0 + (hx1 - hx0) * Float(k) / Float(n) }
            let path = xs.map { V3($0, yc, 0) }
            rig.base[l].add(SurgKit.loft(path, material: handle) { _, i in SurgKit.section(hw(xs[i]), hh(xs[i]), n: l == 0 ? 16 : 12, exponent: 4) })
        }
        // Fish-scale grip ribs on the thumb rest.
        var ribs = Surface(material: handle)
        for k in 0..<7 {
            let x0 = -0.0695 + Float(k) * 0.0024
            let pts: [V3] = (0...6).map { j in
                let z = -0.0034 + 0.0068 * Float(j) / 6, q = z / 0.0034
                let x = x0 + 0.0014 * (1 - q * q)
                return V3(x, topY(x, z) - 0.00008, z)
            }
            ribs.append(SurgKit.bar(pts, w: { _ in 0.0007 }, h: { _ in 0.0005 }, sides: 6, exponent: 3, material: handle))
        }
        rig.base[0].add(ribs)
        // Moulded ruler scale: 3 cm with mm ticks along the right edge of the top face.
        var ticks = Surface(material: "plastic.matte:2E3238")
        for mm in 0...30 {
            let x = -0.044 + Float(mm) * 0.001
            let len: Float = mm % 10 == 0 ? 0.0028 : (mm % 5 == 0 ? 0.002 : 0.0012)
            let z0: Float = 0.0036, z1 = z0 - len, hwid: Float = 0.00011
            let a = ticks.add(V3(x - hwid, topY(x, z0) + 0.00004, z0), .up, V2(x - hwid, z0))
            let b = ticks.add(V3(x + hwid, topY(x, z0) + 0.00004, z0), .up, V2(x + hwid, z0))
            let c = ticks.add(V3(x + hwid, topY(x, z1) + 0.00004, z1), .up, V2(x + hwid, z1))
            let d = ticks.add(V3(x - hwid, topY(x, z1) + 0.00004, z1), .up, V2(x - hwid, z1))
            ticks.quad(a, b, c, d)
        }
        ticks.computeTangents()
        rig.base[0].add(ticks)

        // MARK: #10 blade
        let spine: [V2] = [V2(0.040, 0.0026), V2(0.068, 0.0026), V2(0.0722, 0.0022)]
        let edgeLine: [V2] = [V2(0.0765, 0.0014), V2(0.0748, 0.0002), V2(0.0725, -0.0012), V2(0.0695, -0.0025), V2(0.0655, -0.0037),
                              V2(0.0605, -0.0045), V2(0.0555, -0.0047), V2(0.0505, -0.0044), V2(0.0460, -0.0037), V2(0.0425, -0.0031),
                              V2(0.040, -0.0030)]
        // Bevel line 1.1 mm in from the edge (toward the spine).
        let bevel: [V2] = edgeLine.indices.map { i in
            let a = edgeLine[max(0, i - 1)], b = edgeLine[min(edgeLine.count - 1, i + 1)]
            let t = simd_normalize(b - a), nrm = V2(t.y, -t.x)     // left of travel = blade interior
            let inset: Float = i == 0 ? 0.0003 : 0.0011
            return edgeLine[i] + nrm * inset
        }
        let bt: Float = 0.0004
        let bodyPlate = SurgKit.plate(Shape2D.deduped(spine + bevel), y0: yc - bt / 2, y1: yc + bt / 2, bevel: 0.00006, material: blade)
        var strip = SurgKit.plate(Shape2D.deduped(bevel.reversed() + edgeLine), y0: yc - bt / 2, y1: yc + bt / 2, bevel: 0, material: edge)
        // Grind: squeeze the thickness to a 0.05 mm edge.
        strip.deform { p in
            let d = edgeLine.map { simd_distance($0, V2(p.x, p.z)) }.min() ?? 1
            return d < 1e-5 ? V3(p.x, yc + (p.y - yc) * 0.15, p.z) : p
        }
        rig.base[0].add(bodyPlate); rig.base[0].add(strip)
        rig.base[1].add(SurgKit.plate(Shape2D.deduped(spine + edgeLine), y0: yc - bt / 2, y1: yc + bt / 2, bevel: 0, material: blade))
        // Size mark etched near the heel.
        rig.base[0].add(Prim.roundedBox(V3(0.0036, 0.00003, 0.0011), radius: 0.00001, bevelSegments: 1, material: "metal.steel:4A4D52"),
                        Xform(translation: V3(0.0475, yc + bt / 2 + 0.000016, 0.0011)))

        // MARK: shield
        rig.part("shield", pivot: V3(0, yc, 0), joint: .slide(axis: V3(-1, 0, 0), 0...shieldTravel, duration: 0.35))
        let sx0: Float = -0.006, sx1: Float = 0.0815, wall: Float = 0.0007
        func sw(_ x: Float) -> Float { 0.0118 - 0.0008 * max(0, x - 0.05) / (sx1 - 0.05) }
        func sh(_ x: Float) -> Float { 0.0076 - 0.0024 * smoothstep(0.044, sx1, x) }
        for l in 0..<2 {
            let n = l == 0 ? 10 : 5, sides = l == 0 ? 16 : 10
            let xs: [Float] = (0...n).map { k in sx0 + (sx1 - sx0) * Float(k) / Float(n) }
            let path = xs.map { V3($0, yc, 0) }
            let outer = SurgKit.loft(path, material: shield) { _, i in SurgKit.section(sw(xs[i]), sh(xs[i]), n: sides, exponent: 5) }
            let inner = SurgKit.loft(path.map { $0 + V3(0.0003, 0, 0) }, material: shield) { _, i in
                SurgKit.section(sw(xs[i]) - 2 * wall, sh(xs[i]) - 2 * wall, n: sides, exponent: 5) }.flipped()
            // Open rear rim between the skins.
            let o = SurgKit.section(sw(sx0), sh(sx0), n: sides, exponent: 5), ii = SurgKit.section(sw(sx0) - 2 * wall, sh(sx0) - 2 * wall, n: sides, exponent: 5)
            let ring = { (s: [V2], dx: Float) in s.map { V3(sx0 + dx, yc + $0.y, -$0.x) } }
            let rim = Prim.loft([ring(o, 0), ring(ii, 0.0003)], material: shield)
            rig.add(outer, to: "shield", lods: l...l); rig.add(inner, to: "shield", lods: l...l); rig.add(rim, to: "shield", lods: l...l)
        }
        // Ridged thumb tab and the lock bump on top of the shield.
        let topS = yc + sh(0) / 2
        rig.add(Prim.roundedBox(V3(0.013, 0.0012, 0.0074), radius: 0.0005, bevelSegments: 2, material: shield),
                Xform(translation: V3(0.006, topS + 0.0004, 0)), to: "shield")
        for k in 0..<5 {
            rig.add(Prim.roundedBox(V3(0.0007, 0.0007, 0.0066), radius: 0.0003, bevelSegments: 1, material: shield),
                    Xform(translation: V3(0.0012 + Float(k) * 0.0024, topS + 0.0011, 0)), to: "shield", lods: 0...0)
        }
        rig.add(Prim.roundedBox(V3(0.0035, 0.0007, 0.0035), radius: 0.0003, bevelSegments: 1, material: shield),
                Xform(translation: V3(0.026, topS + 0.0001, 0)), to: "shield", lods: 0...0)

        rig.states = [RigState("shielded"), RigState("exposed", ["shield": shieldTravel])]
        SurgKit.settle(&rig, tilt: Xform(rotation: simd_quatf(angle: 0.017, axis: V3(0, 0, 1))), aoHeight: 0.006)
        return rig
    }
}
