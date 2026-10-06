import simd
import Foundation

/// 25 ft x 1 in tape measure standing on its flat base: 76 x 77 mm yellow ABS case 40 mm wide with a
/// black rubber armor band and side frames around the yellow hub bosses, three case screws, chrome spring
/// belt clip, black thumb lock on the front, rubber nose bumper with the blade slot. The blade (25.4 mm
/// wide, 0.15 mm thick, 2.2 mm concave cup) carries the `label.tape-rule` print: 1/16 in ticks, inch
/// numerals, red 16 in stud boxes. Riveted steel end hook with a 8 mm tab.
///
/// Static asset with a live knob: `extension` (0...2 m) pulls the hook out from its rest against the nose;
/// the game rebuilds the entity when the reading changes. Short pulls stand out straight; longer ones sag
/// onto the bench between the mouth and the hook. Tool frame: blade exits toward +X; `rest` turns the tape
/// 180 degrees about Y (blade toward -X, numerals upright from the +Z side).
public struct TapeMeasure: RealAsset {
    public static let id = "tape-measure"
    public static let summary = "25 ft x 1 in tape measure: rubber-armored yellow case, chrome belt clip, thumb lock, printed yellow blade with hook; extension knob 0-2 m."
    public static let tags = ["prop", "workshop", "tool", "handheld", "plastic", "rubber", "metal"]
    public static let budget = 9_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 28, elevation: 30, distance: 0.36)

    /// How far the hook is pulled out from rest (m), 0...2. 0 = hook resting against the nose.
    public var `extension`: Float = 0
    /// Blade cup depth across the width (m).
    public var cup: Float = 0.0022
    public var shell: MaterialKey = "plastic.tape-case"
    public var armor: MaterialKey = "rubber"
    public var blade: MaterialKey = "label.tape-rule"
    public var bladeBack: MaterialKey = "plastic.gloss:E3B81A"
    public var hook: MaterialKey = "metal.steel"
    public var clip: MaterialKey = "metal.chrome"
    public var lock: MaterialKey = "plastic.tool:1A1A1B"
    public init() {}

    static let W: Float = 0.0254, bladeT: Float = 0.00015, mouthY: Float = 0.0060, nose: Float = 0.0378
    static let hookRest: Float = 0.0185, tabT: Float = 0.0011, tabDrop: Float = 0.0058

    var ext: Float { max(0, min(2, self.extension)) }
    /// Tool-frame x of the blade end (inside the hook tab).
    var tipX: Float { Self.nose + Self.hookRest + ext }

    func rest() -> Xform { Xform(translation: V3(0, 0, 0), rotation: simd_quatf(angle: .pi, axis: V3(0, 1, 0))) }

    /// Blade bottom-center height along tool x.
    func bladeY(_ x: Float) -> Float {
        let s = x - Self.nose, toTip = tipX - x
        let k = smoothstep(0.25, 0.6, ext)
        let sag = smoothstep(0.0, 0.13, s) * smoothstep(0.0, 0.11, toTip)
        return Self.mouthY - (Self.mouthY - 0.0003) * sag * k
    }

    /// Bottom tip of the hook tab (the point that catches the stock edge), asset space.
    public var hookTip: V3 { rest().point(V3(tipX + Self.tabT / 2 + 0.0001, bladeY(tipX) - Self.tabDrop, 0)) }
    /// Center of the hand hold (the case), asset space.
    public var grip: V3 { rest().point(V3(-0.002, 0.040, 0)) }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)

        // MARK: case: yellow shell, rubber band, side frames, hubs
        let corners: [V2] = [V2(-0.038, 0.0015), V2(0.0345, 0.0015), V2(0.0345, 0.0765), V2(-0.038, 0.0765)]
        let outline = HTKit.fillet(corners, radii: [0.010, 0.004, 0.020, 0.027], segments: 9)
        m.add(Prim.extrude(outline, depth: 0.040, bevel: 0.0042, bevelSegments: 3, material: shell))
        m.add(Prim.extrude(Shape2D.offset(outline, 0.0013), depth: 0.026, bevel: 0.0028, bevelSegments: 3, material: armor))
        let hubC = V2(-0.003, 0.040)
        for side: Float in [-1, 1] {
            let z = side * 0.0203
            let frame = HTKit.plate(outer: Shape2D.offset(outline, -0.0046), holes: [HTKit.ellipse(hubC, a: 0.0245, b: 0.0245, n: 28)],
                                    depth: 0.0016, bevel: 0.0006, segments: 1, material: armor)
            m.add(frame, Xform(translation: V3(0, 0, z)))
            var hub = Prim.cylinder(radius: 0.0232, height: 0.0024, bevel: 0.0008, segments: 28, bevelSegments: 2, material: shell)
            hub.deform { q in V3(q.x, q.y + 0.0007 * (1 - (q.x * q.x + q.z * q.z) / (0.0232 * 0.0232)) * smoothstep(0.001, 0.0024, q.y), q.z) }
            m.add(hub, Xform(translation: V3(hubC.x, hubC.y, z - side * 0.0010), rotation: simd_quatf(angle: side * .pi / 2, axis: V3(1, 0, 0))))
            // Molded ring and center boss on the hub.
            m.add(Prim.torus(major: 0.0175, minor: 0.0006, segments: 28, sides: 5, material: armor),
                  Xform(translation: V3(hubC.x, hubC.y, side * 0.0218), rotation: simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))))
            m.add(Prim.cylinder(radius: 0.0065, height: 0.0012, bevel: 0.0005, segments: 20, bevelSegments: 1, material: armor),
                  Xform(translation: V3(hubC.x, hubC.y, side * 0.0212), rotation: simd_quatf(angle: side * .pi / 2, axis: V3(1, 0, 0))))
            // Molded grip ribs on the armor along the back.
            for k in 0..<4 {
                let y = 0.026 + Float(k) * 0.0075
                m.add(Prim.roundedBox(V3(0.0018, 0.0028, 0.0012), radius: 0.0005, bevelSegments: 1, material: armor),
                      Xform(translation: V3(-0.0312, y, side * 0.0213)))
            }
        }
        // Case screws on the clip side (tool +Z), around the hub.
        for k in 0..<3 {
            let a = Float(k) / 3 * 2 * .pi + 0.5
            let c = hubC + V2(cos(a), sin(a)) * 0.0275
            if c.y < 0.006 { continue }
            m.add(Prim.cylinder(radius: 0.0023, height: 0.0009, bevel: 0.0004, segments: 14, bevelSegments: 1, material: "metal.anodized-black"),
                  Xform(translation: V3(c.x, c.y, 0.0207), rotation: simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))))
        }

        // Capacity mark molded into the viewer-side hub (tool -Z): black-filled "25" above the boss.
        let R: Float = 0.0232
        var mark = HTInk(material: "plastic.matte:141414", normal: V3(0, 0, -1)) { q in
            let d = q - hubC, rr = min(1, simd_length_squared(d) / (R * R))
            return V3(q.x, q.y, -(0.0217 + 0.0007 * (1 - rr)) - 0.00008)
        }
        mark.number(25, center: hubC + V2(0, 0.0118), u: V2(-1, 0), v: V2(0, 1), h: 0.0072, w: 0.0011)
        m.add(mark.finished())

        // MARK: nose bumper with the blade slot
        m.add(Prim.roundedBox(V3(0.0085, 0.0150, 0.0350), radius: 0.0022, bevelSegments: 2, material: armor),
              Xform(translation: V3(Self.nose - 0.0043, 0.0003 + 0.0075, 0)))
        m.add(Prim.roundedBox(V3(0.0008, 0.0036, 0.0282), radius: 0.0003, bevelSegments: 1, material: "plastic.matte:0C0C0D"),
              Xform(translation: V3(Self.nose - 0.0001, Self.mouthY + 0.0010, 0)))

        // MARK: thumb lock on the front face
        let lockX: Float = 0.0350, lockY: Float = 0.050
        m.add(Prim.roundedBox(V3(0.0060, 0.0150, 0.0160), radius: 0.0022, bevelSegments: 2, material: lock),
              Xform(translation: V3(lockX, lockY, 0), rotation: simd_quatf(degrees: -12, axis: V3(0, 0, 1))))
        for k in 0..<4 {
            m.add(Prim.roundedBox(V3(0.0012, 0.0010, 0.0130), radius: 0.0004, bevelSegments: 1, material: lock),
                  Xform(translation: V3(lockX + 0.0030 + Float(k) * 0.0004, lockY - 0.0045 + Float(k) * 0.0030, 0), rotation: simd_quatf(degrees: -12, axis: V3(0, 0, 1))))
        }

        // MARK: belt clip (tool +Z)
        let clipPath = catmull([V3(-0.006, 0.0650, 0.0206), V3(-0.006, 0.0615, 0.0234), V3(-0.006, 0.0500, 0.0243), V3(-0.006, 0.0300, 0.0243),
                                V3(-0.006, 0.0150, 0.0238), V3(-0.006, 0.0090, 0.0250), V3(-0.006, 0.0060, 0.0268)], per: 4)
        let strip = Shape2D.roundedRect(0.0160, 0.0011, radius: 0.0005, segments: 2)
        m.add(Prim.sweep(strip, along: clipPath, up: V3(1, 0, 0), material: clip))
        m.add(Prim.superellipsoid(V3(0.0062, 0.0062, 0.0022), exponent: 2.4, subdivisions: 6, material: clip),
              Xform(translation: V3(-0.006, 0.0600, 0.0245)))

        // MARK: blade: cupped strip from inside the mouth to the hook
        let x0 = Self.nose - 0.004, x1 = tipX
        var xs: [Float] = []
        var x = x0
        while x < x1 {
            xs.append(x)
            let nearEnd = min(x - x0, x1 - x) < 0.15
            x += nearEnd ? 0.01 : 0.12
        }
        xs.append(x1)
        let (top, back) = cuppedStrip(xs: xs, z0: -Self.W / 2, z1: Self.W / 2, lift: 0, thick: Self.bladeT, across: 8, topUV: true)
        m.add(top); m.add(back)

        // MARK: end hook: cupped top plate, two rivets, tab
        let hx = xs.filter { $0 >= x1 - 0.017 }
        let plateXs = [x1 - 0.017] + hx.filter { $0 > x1 - 0.017 + 0.001 }
        let (ht, hb) = cuppedStrip(xs: plateXs.count >= 2 ? plateXs : [x1 - 0.017, x1], z0: -0.0112, z1: 0.0112, lift: Self.bladeT + 0.00008,
                                   thick: 0.0007, across: 6, topUV: false)
        var hookTop = ht; hookTop.material = hook
        var hookBack = hb; hookBack.material = hook
        m.add(hookTop); m.add(hookBack)
        for rx: Float in [x1 - 0.012, x1 - 0.005] {
            let yTop = bladeY(rx) + Self.bladeT + 0.0008 + cup * 0
            for rz: Float in [-0.0001] {
                m.add(Prim.superellipsoid(V3(0.0032, 0.0012, 0.0032), exponent: 2.2, subdivisions: 4, material: hook),
                      Xform(translation: V3(rx, yTop, rz)))
            }
        }
        let yEnd = bladeY(x1)
        let tabTop = yEnd + cup + 0.0016, tabBot = yEnd - Self.tabDrop
        m.add(Prim.roundedBox(V3(Self.tabT, tabTop - tabBot, 0.0270), radius: 0.0004, bevelSegments: 2, material: hook),
              Xform(translation: V3(x1 + Self.tabT / 2 + 0.0001, (tabTop + tabBot) / 2, 0)))
        _ = rng.float()

        let r = rest()
        var out = Model(name: Self.id)
        for s in m.surfaces { out.add(s, r) }
        groundAO(&out, height: 0.02, floor: 0.6)
        return LODModel(out)
    }

    /// Cupped strip following the blade line over `xs`, across z0...z1: top face (UV u = distance from the
    /// hook end, v = z - z0 when `topUV`), plus underside and edges in a second surface.
    func cuppedStrip(xs: [Float], z0: Float, z1: Float, lift: Float, thick: Float, across: Int, topUV: Bool) -> (Surface, Surface) {
        let W = Self.W
        func pt(_ x: Float, _ z: Float, _ off: Float) -> V3 {
            let q = 2 * z / W
            return V3(x, bladeY(x) + cup * q * q + off, z)
        }
        let end = tipX
        var top = Surface(material: blade), bot = Surface(material: bladeBack)
        let cols = across + 1
        for x in xs { for j in 0...across {
            let z = z0 + (z1 - z0) * Float(j) / Float(across)
            let uv = topUV ? V2(end - x + 0.0011, z - z0) : V2(x, z)
            _ = top.add(pt(x, z, lift + thick), .up, uv)
            _ = bot.add(pt(x, z, lift), .up, V2(x, z))
        }}
        for i in 0..<(xs.count - 1) { for j in 0..<across {
            let a = UInt32(i * cols + j), b = a + 1, c = a + UInt32(cols) + 1, d = a + UInt32(cols)
            top.quad(a, b, c, d)
            bot.quad(a, d, c, b)
        }}
        // Edges along both long sides and the two ends.
        func edgeStrip(_ p0: [V3], _ p1: [V3]) {
            let base = UInt32(bot.positions.count)
            for k in p0.indices { _ = bot.add(p0[k], .up, V2(Float(k) * 0.01, 0)); _ = bot.add(p1[k], .up, V2(Float(k) * 0.01, thick)) }
            for k in 0..<(p0.count - 1) {
                let a = base + UInt32(2 * k)
                bot.quad(a, a + 2, a + 3, a + 1)
                bot.quad(a, a + 1, a + 3, a + 2)
            }
        }
        edgeStrip(xs.map { pt($0, z0, lift) }, xs.map { pt($0, z0, lift + thick) })
        edgeStrip(xs.map { pt($0, z1, lift) }, xs.map { pt($0, z1, lift + thick) })
        let zs = (0...across).map { z0 + (z1 - z0) * Float($0) / Float(across) }
        edgeStrip(zs.map { pt(xs.last!, $0, lift) }, zs.map { pt(xs.last!, $0, lift + thick) })
        top.recomputeNormals(weldSeams: false); top.computeTangents()
        bot.recomputeNormals(weldSeams: false); bot.computeTangents()
        return (top, bot)
    }
}
