import simd
import Foundation

/// Telescoping pocket reflex hammer (Babinski / Queen Square disc class) lying on the table: chrome
/// outer tube 9 mm x 130 mm with a knurled grip and domed end cap, 5.6 mm chrome inner rod that pulls
/// out 110 mm, a forked mount at the rod tip with a vertical hinge pin, and a 50 mm disc head (chrome
/// hub, 12 mm black rubber rim) on a short tongue. Stowed, the rod is in and the head is folded 90
/// degrees beside the handle; extended pulls the rod; ready swings the head straight ahead.
public struct ReflexHammer: RealArticulated {
    public static let id = "reflex-hammer"
    public static let summary = "Telescoping Babinski-style reflex hammer: chrome two-stage handle and a rubber-rimmed disc head on a folding mount."
    public static let tags = ["prop", "medical", "handheld", "articulated", "tool", "metal", "rubber"]
    public static let budget = 3_550
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 34, distance: 0.6, studio: true)

    /// Outer tube radius (m).
    public var radius: Float = 0.0045
    /// Telescope travel (m).
    public var travel: Float = 0.11
    /// Head disc diameter (m).
    public var discDiameter: Float = 0.05
    /// Rubber rim tint (sRGB hex).
    public var rubberColor: UInt32 = 0x1E1E1F
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rng = SeededRNG(seed: seed)
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [2.5])
        let R = radius, yc = radius
        let chrome: MaterialKey = "metal.chrome", knurl: MaterialKey = "metal.knurl-chrome"
        let rubber: MaterialKey = "rubber:" + String(format: "%06X", rubberColor)
        let oz: Float = 0.024, ox: Float = 0.004             // recentre the stowed footprint
        let toX = simd_quatf(degrees: -90, axis: V3(0, 0, 1))   // lathe +Y -> +X
        func axial(_ prof: [V2], _ sg: Int, _ mat: MaterialKey) -> Surface {
            Prim.lathe(prof, segments: sg, seamTile: 0.028, material: mat).transformed(Xform(translation: V3(ox, yc, oz), rotation: toX))
        }
        let x0: Float = -0.085, x1: Float = 0.045
        let segs = [20, 10]

        // MARK: outer tube
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let sg = segs[l]
            // Domed end cap with a seam line, smooth band, knurl, smooth neck, mouth collar.
            var p: [V2] = [V2(0, x0), V2(0.0022, x0 + 0.0004), V2(0.0038, x0 + 0.0016), V2(R, x0 + 0.0042), V2(R, x0 + 0.009)]
            if l == 0 { p += [V2(R - 0.0003, x0 + 0.0095), V2(R, x0 + 0.010)] }
            p += [V2(R, x0 + 0.014)]
            m.add(axial(p, sg, chrome))
            m.add(axial([V2(R, x0 + 0.014), V2(R + 0.0001, x0 + 0.0145), V2(R + 0.0001, -0.002), V2(R, -0.0015)], sg, l == 0 ? knurl : chrome))
            m.add(axial([V2(R, -0.0015), V2(R, x1 - 0.004), V2(R + 0.0006, x1 - 0.0032), V2(R + 0.0006, x1 - 0.0006), V2(R + 0.0001, x1),
                         V2(0.0031, x1), V2(0.0029, x1 - 0.002)], sg, chrome))
            rig.base[l] = m
        }
        // Owner's name tape wrapped round the grip (story detail): one label tile across it.
        var tape = Surface(material: "label.biomed")
        let tw: Float = 0.016, th: Float = 0.006, tx0: Float = -0.052 + ox, rr = R + 0.00025
        let cols = 8
        for j in 0...1 { for i in 0...cols {
            let a = -0.4 + (Float(i) / Float(cols) - 0.5) * th / rr * 2.4 + .pi / 2
            let pos = V3(tx0 + Float(j) * tw, yc + rr * sin(a), oz + rr * cos(a))
            _ = tape.add(pos, V3(0, sin(a), cos(a)), V2(Float(j), Float(i) / Float(cols)) * 0.012)
        }}
        for i in 0..<UInt32(cols) { tape.quad(i, i + UInt32(cols) + 1, i + UInt32(cols) + 2, i + 1) }
        tape.computeTangents()

        // MARK: inner rod (slides +X)
        let r2: Float = 0.0028, rodTip = x1 + 0.013
        rig.part("tele", pivot: V3(x1 + ox, yc, oz), joint: .slide(axis: V3(1, 0, 0), 0...travel, duration: 0.5))
        for l in 0..<2 {
            rig.add(axial([V2(r2, x1 - 0.12), V2(r2, rodTip - 0.006), V2(r2 + 0.0004, rodTip - 0.005)], segs[l], chrome), to: "tele", lods: l...l)
        }
        // Fork mount at the rod tip, hinge pin vertical.
        let pivotX = rodTip + 0.004 + ox
        let fork = Prim.roundedBox(V3(0.012, 0.0075, 0.0078), radius: 0.0018, bevelSegments: 2, material: chrome)
        rig.add(fork, Xform(translation: V3(rodTip - 0.001 + ox, yc, oz)), to: "tele")
        rig.add(Prim.cylinder(radius: 0.0016, height: 0.0084, bevel: 0.0005, segments: 10, bevelSegments: 1, material: chrome),
                Xform(translation: V3(pivotX, yc - 0.0042, oz)), to: "tele", lods: 0...0)

        // MARK: head, authored ready (straight ahead), stored folded +90 about Y (toward -Z).
        let D = discDiameter, T: Float = 0.012
        let dc = V3(pivotX + 0.0085 + D / 2, T / 2 + 0.0001, oz)
        var headL: [Model] = [Model(name: "head"), Model(name: "head")]
        for l in 0..<2 {
            let sg = l == 0 ? 36 : 16
            // Rubber rim: rounded torus-like band.
            var rim: [V2] = []
            let n = l == 0 ? 8 : 4
            for k in 0...n {
                let a = -Float.pi / 2 + Float(k) / Float(n) * .pi
                rim.append(V2(D / 2 - T / 2 + T / 2 * cos(a) * 0.9, T / 2 * sin(a)))
            }
            let rimS = Prim.lathe([V2(D / 2 - T * 0.62, -T / 2 + 0.0004)] + rim + [V2(D / 2 - T * 0.62, T / 2 - 0.0004)], segments: sg, seamTile: 0.04, material: rubber)
            headL[l].add(rimS, Xform(translation: dc))
            // Chrome hub: two shallow domes meeting the rubber.
            let hub = Prim.lathe([V2(0, T / 2 - 0.0002), V2(0.008, T / 2 - 0.0005), V2(D / 2 - T * 0.6, T / 2 - 0.0012), V2(D / 2 - T * 0.6, -T / 2 + 0.0012),
                                  V2(0.008, -T / 2 + 0.0005), V2(0, -T / 2 + 0.0002)].reversed(), segments: sg, seamTile: 0.04, material: "rubber:262627")
            headL[l].add(hub, Xform(translation: dc))
            // Chrome rivet bosses through the centre, both faces.
            for sgn: Float in [-1, 1] {
                headL[l].add(Prim.cylinder(radius: 0.0062, height: 0.0008, bevel: 0.0004, segments: l == 0 ? 20 : 10, bevelSegments: 1, material: chrome),
                             Xform(translation: dc + V3(0, sgn * (T / 2 - 0.0007), 0), rotation: sgn > 0 ? .identity : simd_quatf(degrees: 180, axis: V3(1, 0, 0))))
            }
            // Tongue from the hinge knuckle to the rim.
            headL[l].add(Prim.roundedBox(V3(0.0145, 0.0042, 0.0064), radius: 0.0015, bevelSegments: l == 0 ? 2 : 1, material: chrome),
                         Xform(translation: V3(pivotX + 0.0065, yc, oz)))
            headL[l].add(Prim.cylinder(radius: 0.003, height: 0.0045, bevel: 0.0006, segments: l == 0 ? 14 : 8, bevelSegments: 1, material: chrome),
                         Xform(translation: V3(pivotX, yc - 0.00225, oz)))
        }
        // Wear: the rim face greyed where it strikes (seeded arc of lighter rubber).
        let a0 = rng.float(-0.4...0.4)
        var scuff = Surface(material: "rubber:3A3A3B")
        let arcN = 10
        for k in 0...arcN {
            let a = a0 + (Float(k) / Float(arcN) - 0.5) * 1.3
            for (j, y) in [-T * 0.22, T * 0.22].enumerated() {
                let rr2 = D / 2 + 0.00012
                _ = scuff.add(dc + V3(rr2 * cos(a), y, rr2 * sin(a)), V3(cos(a), 0, sin(a)), V2(Float(k) * 0.004, Float(j) * 0.005))
            }
        }
        for k in 0..<UInt32(arcN) { scuff.quad(k * 2, k * 2 + 1, k * 2 + 3, k * 2 + 2) }
        scuff.computeTangents()
        headL[0].add(scuff)

        let q = simd_quatf(degrees: 90, axis: V3(0, 1, 0))
        let pv = V3(pivotX, yc, oz)
        let foldX = Xform(translation: pv - q.act(pv), rotation: q)
        rig.part("head", parent: "tele", pivot: pv, joint: .hinge(axis: V3(0, 1, 0), -90...0, duration: 0.45))
        for l in 0..<2 { rig.add(headL[l].transformed(foldX), to: "head", lod: l) }

        groundAO(&rig, height: 0.008, floor: 0.6)
        rig.base[0].add(tape)
        rig.states = [RigState("stowed"), RigState("extended", ["tele": travel]), RigState("ready", ["tele": travel, "head": -90])]
        return rig
    }
}
