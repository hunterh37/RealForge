import simd
import Foundation

/// Glovebox owner's manual: black vinyl cover, silver title block, page edges, ribbon marker. Lies flat on its back cover.
public struct OwnersManual: RealAsset {
    public static let id = "owners-manual"
    public static let summary = "Glovebox owner's manual, 15 x 21 cm, 14 mm thick, black vinyl cover with a silver title block, page edges, and a ribbon bookmark."
    public static let tags = ["prop", "book", "paper", "vehicle", "handheld"]
    public static let budget = 3500
    public static let author = "realityhd"

    /// Width (X), thickness (Y), height (Z) of the closed book in meters.
    public var size = V3(0.15, 0.014, 0.21)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = size.x, T = size.y, H = size.z, c: Float = 0.0012
        // Covers (front on top) and a rounded spine.
        m.add(Prim.roundedBox(V3(W, c, H), radius: 0.0006, bevelSegments: 1, material: "leather.black"), Xform(translation: V3(0, c / 2, 0)))
        m.add(Prim.roundedBox(V3(W, c, H), radius: 0.0006, bevelSegments: 1, material: "leather.black"), Xform(translation: V3(0, T - c / 2, 0)))
        m.add(Prim.roundedBox(V3(0.004, T, H), radius: 0.0018, bevelSegments: 2, material: "leather.black"), Xform(translation: V3(-W / 2 + 0.002, T / 2, 0)))
        // Page block, slightly inset on three sides.
        m.add(Prim.roundedBox(V3(W - 0.012, T - 2 * c - 0.0006, H - 0.006), radius: 0.0004, bevelSegments: 1, material: "paper.pages"), Xform(translation: V3(0.003, T / 2, 0)))
        // Title block, make mark and rule on the front cover.
        m.add(Prim.roundedBox(V3(W - 0.04, 0.0006, 0.034), radius: 0.0002, bevelSegments: 1, material: "metal.satin-aluminum"), Xform(translation: V3(0.004, T + 0.0003, H / 2 - 0.045)))
        m.add(Prim.roundedBox(V3(0.06, 0.0007, 0.006), radius: 0.0002, bevelSegments: 1, material: "plastic.black"), Xform(translation: V3(0.004, T + 0.0006, H / 2 - 0.045)))
        m.add(Prim.roundedBox(V3(0.07, 0.0006, 0.003), radius: 0.0002, bevelSegments: 1, material: "metal.satin-aluminum"), Xform(translation: V3(0.004, T + 0.0003, -H / 2 + 0.04)))
        // Debossed cover frame as a thin rim.
        m.add(Prim.roundedBox(V3(W - 0.014, 0.0004, 0.0008), radius: 0.0002, bevelSegments: 1, material: "plastic.black"), Xform(translation: V3(0.0, T + 0.0002, H / 2 - 0.012)))
        m.add(Prim.roundedBox(V3(W - 0.014, 0.0004, 0.0008), radius: 0.0002, bevelSegments: 1, material: "plastic.black"), Xform(translation: V3(0.0, T + 0.0002, -H / 2 + 0.012)))
        // Ribbon bookmark hanging out the bottom edge.
        m.add(Prim.roundedBox(V3(0.006, 0.0008, 0.05), radius: 0.0002, bevelSegments: 1, material: "fabric.webbing"), Xform(translation: V3(0.03, 0.006, -H / 2 - 0.022), rotation: simd_quatf(degrees: 6, axis: .up)))
        groundAO(&m, height: 0.02, floor: 0.6)
        return LODModel(m)
    }
}
