import simd
import Foundation
import RealityKit
import RealKit

/// Every prop on a concrete pad, in a grid. Visual regression scene.
public struct PropYard: RealSceneBuilder {
    public static let id = "prop-yard"
    public static let summary = "Every prop on a concrete pad in a grid. Visual regression scene for props."
    public static let tags = ["test", "prop"]

    public var spacing: Float = 3
    public init() {}
    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        // Grid grows with the library: every new prop shows up here with no edits.
        let props = Props.all, cols = max(1, Int(Float(props.count).squareRoot().rounded(.up)))
        let rows = (props.count + cols - 1) / cols
        let w = Float(cols) * spacing + 2, d = Float(rows) * spacing + 2
        var pad = Model(name: "pad")
        pad.add(Prim.terrain(size: V2(w, d), segments: 8, material: "concrete.smooth") { _ in 0 })
        scene.add(pad)
        for (i, t) in props.enumerated() {
            let x = (Float(i % cols) - Float(cols - 1) / 2) * spacing, z = (Float(i / cols) - Float(rows - 1) / 2) * spacing
            scene.singles.append(.init(asset: t.init().build(seed: seed), at: place(x, z, yaw: 25)))
        }
        let back = max(w, d)
        scene.camera = .init(eye: V3(0, back * 0.39, back * 0.72), target: V3(0, 0.3, -0.5), fov: 50)
        scene.farGround = "concrete.smooth"
        return scene
    }
}
