import simd
import Foundation

/// Anesthesia machine: current Draeger Fabius / GE Aisys class workstation, warm off-white housings, grey trim, purple absorber granules, a strip of tape on the vaporizer.. Parts: off-white cart body on four casters with a work surface, three drawers under the work surface, ventilator bellows in a transparent dome, flowmeter bank with glass tubes and knobs, vaporizer on a mount bar with a concentration dial, CO2 absorber, inspiratory and expiratory valves, APL valve, corrugated breathing hose loop with Y-piece and reservoir bag, monitor on an arm with an off / vitals screen, gas cylinders on the back.
public struct AnesthesiaMachine: RealAsset {
    public static let id = "anesthesia-machine"
    public static let summary = "Anesthesia workstation: cart body with three drawers, flowmeters, vaporizer, bellows in a clear dome, breathing circuit and a monitor arm."
    public static let tags = ["prop", "medical", "surgical", "articulated", "electronics", "plastic", "metal"]
    public static let budget = 15000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.86, 1.72, 0.8)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: plastic.medical plastic.medical-grey metal.casework plastic.clear rubber.tubing screen.off screen.vitals emissive.led-green. Gate: realityhd gate anesthesia-machine. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "plastic.medical"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
