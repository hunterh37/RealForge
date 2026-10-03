import simd
import Foundation
import RealityKit
import RealKit

/// Every prop on a concrete pad, packed in rows by footprint so large props (canoe, dumpster) do not
/// overlap their neighbors. Visual regression scene.
public struct PropYard: RealSceneBuilder {
    public static let id = "prop-yard"
    public static let summary = "Every prop on a concrete pad, packed in rows by footprint. Visual regression scene for props."
    public static let tags = ["test", "prop"]

    /// Clear gap between neighboring props in meters.
    public var gap: Float = 0.9
    public init() {}
    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        // Grid grows with the library: every new prop shows up here with no edits.
        let yaw: Float = 25
        let built = Props.all.map { $0.init().build(seed: seed) }
        // Footprint radius around the origin after any yaw: farthest bounding-box corner in XZ.
        let radii = built.map { m -> Float in
            let b = m.levels[0].bounds
            return max(0.3, [V2(b.min.x, b.min.z), V2(b.min.x, b.max.z), V2(b.max.x, b.min.z), V2(b.max.x, b.max.z)].map { simd_length($0) }.max() ?? 0.3)
        }
        // Shelf packing, largest first (at the back): rows of roughly equal width, each row as deep as its
        // largest prop.
        let area = radii.reduce(Float(0)) { $0 + pow(2 * $1 + gap, 2) }
        let rowWidth = max(6, area.squareRoot() * 1.1)
        var rows: [[Int]] = [[]]
        var x: Float = 0
        let order = built.indices.sorted { radii[$0] > radii[$1] || (radii[$0] == radii[$1] && $0 < $1) }
        for i in order {
            let w = 2 * radii[i] + gap
            if x + w > rowWidth && !rows[rows.count - 1].isEmpty { rows.append([]); x = 0 }
            rows[rows.count - 1].append(i); x += w
        }
        var spots = [V2](repeating: .zero, count: built.count)
        var z: Float = 0
        for row in rows {
            let depth = (row.map { radii[$0] }.max() ?? 0.3) * 2 + gap
            let width = row.reduce(Float(0)) { $0 + 2 * radii[$1] + gap }
            var cx = -width / 2
            for i in row {
                cx += radii[i] + gap / 2
                spots[i] = V2(cx, z + depth / 2)
                cx += radii[i] + gap / 2
            }
            z += depth
        }
        let w = rowWidth + 2, d = z + 2
        var pad = Model(name: "pad")
        pad.add(Prim.terrain(size: V2(w, d), segments: 8, material: "concrete.smooth") { _ in 0 })
        scene.add(pad)
        for i in built.indices {
            scene.singles.append(.init(asset: built[i], at: place(spots[i].x, spots[i].y - z / 2, yaw: yaw)))
        }
        let back = max(w, d)
        scene.camera = .init(eye: V3(0, back * 0.5, back * 0.8), target: V3(0, 0, d * 0.1), fov: 50)
        scene.farGround = "concrete.smooth"
        return scene
    }
}
