import simd
import Foundation

/// Vintage naturalist's field journal, 15 x 21 cm and 3 cm thick: worn tan leather covers over an
/// ivory page block with deckled, foxed edges, brass corner guards, an elastic closure band and a
/// ribbon marker. The front `cover` hinges open at the spine.
public struct FieldJournal: RealArticulated {
    public static let id = "field-journal"
    public static let summary = "Naturalist field journal, 15 x 21 cm: worn leather covers, ivory page block, brass corners, band; articulated cover."
    public static let tags = ["prop", "book", "leather", "paper", "antique", "handheld", "articulated"]
    public static let budget = 7_000
    public static let preview = PreviewHint(azimuth: 30, elevation: 40, distance: 1.0, studio: true)

    public var size = V3(0.15, 0.03, 0.21)
    public var leather: MaterialKey = "leather.oxblood-worn:6A4A30"
    public var pages: MaterialKey = "paper.pages:E6D8B8"
    public var brass: MaterialKey = "metal.brass-aged"
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [3])
        let w = size.x, t = size.y, d = size.z, c: Float = 0.0028     // cover board thickness
        let spineX = -w / 2
        rig.part("cover", pivot: V3(spineX, t - c / 2, 0), joint: .hinge(axis: V3(0, 0, 1), 0...178, duration: 0.6))
        for lod in 0..<2 {
            let L = lod...lod
            let board = Prim.roundedBox(V3(w, c, d), radius: 0.0012, bevelSegments: lod == 0 ? 2 : 1, material: leather)
            rig.base[lod].add(board, Xform(translation: V3(0, c / 2, 0)))
            // Page block, inset from the covers.
            rig.base[lod].add(Prim.roundedBox(V3(w - 0.008, t - 2 * c - 0.0006, d - 0.008), radius: 0.0015, bevelSegments: lod == 0 ? 2 : 1, material: pages),
                              Xform(translation: V3(0.002, t / 2, 0)))
            rig.base[lod].add(Prim.roundedBox(V3(w - 0.012, 0.0004, d - 0.012), radius: 0.0002, bevelSegments: 1, material: "paper.sheet:EFE2C2"),
                              Xform(translation: V3(0.002, t - c - 0.0004, 0)))
            // Rounded spine.
            var spine: [V3] = []
            for i in 0...10 { let a = Float(i) / 10 * .pi; spine.append(V3(spineX - sin(a) * 0.004, t / 2 - cos(a) * (t / 2 - c / 2), 0)) }
            rig.base[lod].add(Prim.sweep(Shape2D.rect(d, c), along: spine, up: V3(0, 0, 1), caps: true, material: leather))
            // Front cover with brass corners.
            rig.add(board, Xform(translation: V3(0, t - c / 2, 0)), to: "cover", lods: L)
            if lod == 0 {
                for sz: Float in [1, -1] {
                    let corner = Prim.roundedBox(V3(0.016, c + 0.0012, 0.016), radius: 0.0006, bevelSegments: 1, material: brass)
                    rig.add(corner, Xform(translation: V3(w / 2 - 0.0075, t - c / 2, sz * (d / 2 - 0.0075))), to: "cover", lods: L)
                    rig.base[0].add(corner, Xform(translation: V3(w / 2 - 0.0075, c / 2, sz * (d / 2 - 0.0075))))
                }
                // Blind-tooled border on the cover and a stamped oval label.
                rig.add(Prim.torus(major: 0.022, minor: 0.0006, segments: 40, sides: 4, minorY: 0.0003, material: "metal.brass-aged:8A6A30"),
                        Xform(translation: V3(0.006, t + 0.0001, -0.03), scale: V3(1.2, 1, 0.8)), to: "cover", lods: L)
                // Ribbon marker hanging out at the foot.
                rig.base[0].add(Prim.sweep(Shape2D.rect(0.006, 0.0004), along: [V3(0.02, t - c - 0.001, -d / 2 + 0.01), V3(0.024, t * 0.6, -d / 2 - 0.006), V3(0.03, 0.002, -d / 2 - 0.035)],
                                           up: V3(0, 1, 0), caps: true, material: "fabric.canvas:7A1E1A"))
            }
            // Elastic closure band around the book (on the base so it stays when opened).
            let bandX: Float = w / 2 - 0.025
            var band: [V3] = []
            for (y, z) in [(-0.0005, -d / 2 - 0.0006), (t + 0.0005, -d / 2 - 0.0006), (t + 0.0005, d / 2 + 0.0006), (-0.0005, d / 2 + 0.0006)] as [(Float, Float)] { band.append(V3(bandX, y, z)) }
            band.append(band[0])
            rig.base[lod].add(Prim.sweep(Shape2D.rect(0.0008, 0.008), along: band, up: V3(1, 0, 0), caps: true, material: "fabric.webbing:2E2420"))
        }
        rig.states = [RigState("closed"), RigState("open", ["cover": 175])]
        groundAO(&rig, height: 0.03, floor: 0.6)
        return rig
    }
}
