import Foundation
import RealCore

/// Raw palm reading in yard-local meters.
public struct PalmReading: Sendable, Equatable {
    public var center: V3
    /// Unit vector out of the palm.
    public var normal: V3
    /// Unit vector from wrist toward the fingers.
    public var fingers: V3
    /// Middle fingertip distance from the palm center (m); small for a fist.
    public var spread: Float
    public init(center: V3, normal: V3, fingers: V3, spread: Float) { self.center = center; self.normal = normal; self.fingers = fingers; self.spread = spread }
}

/// Turns palm readings into "the person is offering a hand": palm up, open, steady, away from the face.
public struct HandTracker: Sendable {
    private var last: V3?
    private var speed: Float = 0
    private var steady: Float = 0
    public private(set) var offer: HandOffer?
    /// Moving hand (not offered): its speed and position, for startling animals.
    public private(set) var motion: (speed: Float, position: V3)?

    public init() {}

    /// `head` is the head position in the same space. Call every frame with the palm of the hand being tracked, or nil.
    public mutating func update(dt: Float, palm: PalmReading?, head: V3, groundY: Float) {
        guard let p = palm, dt > 0 else {
            last = nil; speed = 0; steady = 0; offer = nil; motion = nil
            return
        }
        if let l = last {
            let inst = simd_distance(l, p.center) / dt
            speed += (inst - speed) * min(1, dt * 8)
        }
        last = p.center
        let palmUp = p.normal.y > 0.55
        let open = p.spread > 0.07
        let h = p.center.y - groundY
        let fromHead = simd_distance(p.center, head)
        let placed = h > 0.12 && p.center.y < head.y - 0.2 && fromHead > 0.3 && fromHead < 1.1
        let ok = palmUp && open && placed && speed < 0.3
        steady = ok ? steady + dt : max(0, steady - dt * 2)
        motion = (speed, p.center)
        if palmUp && open && placed {
            offer = HandOffer(palm: p.center, normal: p.normal, fingers: p.fingers, speed: speed, steady: steady)
        } else {
            offer = nil
        }
    }

    public var handSpeed: Float { speed }
}
