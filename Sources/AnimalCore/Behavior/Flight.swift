import Foundation
import simd
import RealCore

/// Rigid-body state of a flying or perched bird. Position is the center of mass.
public struct FlightBody: Sendable {
    public var position: V3
    public var velocity: V3 = .zero
    /// Radians, 0 faces -Z.
    public var yaw: Float
    /// Body pitch above horizontal, degrees (world).
    public var pitch: Float
    /// Bank, degrees (positive banks right).
    public var roll: Float = 0
    public var yawRate: Float = 0
    /// Wingbeat phase 0...1.
    public var phase: Float = 0

    public var horizontalSpeed: Float { simd_length(V2(velocity.x, velocity.z)) }
    public var speed: Float { simd_length(velocity) }

    public init(position: V3, yaw: Float, pitch: Float) { self.position = position; self.yaw = yaw; self.pitch = pitch }
}

/// Steering limits of a species in cruise.
public struct FlightSpec: Sendable {
    public var cruise: Float
    public var accel: Float = 7
    /// Radians per second at cruise speed.
    public var turnRate: Float = 2.6
    public var climb: Float = 3.2
    public var descend: Float = 3.8
    public var wingbeatHz: Float

    public init(_ p: BirdProfile, speedScale: Float = AnimalTuning.flightSpeedScale) {
        cruise = p.behavior.cruise * speedScale
        wingbeatHz = p.behavior.wingbeatHz
        let small = max(0, 1 - p.anatomy.length / 0.4)
        turnRate = 2.2 + 1.6 * small
        accel = 6 + 4 * small
    }
}

/// Global feel knobs.
public enum AnimalTuning {
    /// Real songbirds cross a yard in a second. Scaling cruise speed keeps flight readable in a headset.
    nonisolated(unsafe) public static var flightSpeedScale: Float = 0.55
    /// Multiplier on every visit rate.
    nonisolated(unsafe) public static var visitRate: Float = 1
}

public enum BirdFlight {
    /// Steers `b` toward `target` for `dt` seconds. Returns the flap effort (0...1) the maneuver needs.
    /// `arrive` slows the bird inside that radius so it reaches the target at `minSpeed`.
    @discardableResult
    public static func steer(_ b: inout FlightBody, toward target: V3, speed: Float, spec: FlightSpec, dt: Float,
                             arrive: Float = 0, minSpeed: Float = 0.3) -> Float {
        let to = target - b.position
        let dist = simd_length(to)
        guard dist > 1e-4 else { return 0.4 }
        let flat = V2(to.x, to.z)
        let flatDist = simd_length(flat)
        var want = speed
        if arrive > 0, dist < arrive { want = max(minSpeed, speed * dist / arrive) }

        // Heading.
        let desiredYaw = flatDist > 0.02 ? yaw(of: V3(to.x, 0, to.z)) : b.yaw
        let err = wrapAngle(desiredYaw - b.yaw)
        let sp = max(b.horizontalSpeed, 0.4)
        let maxRate = spec.turnRate * min(1.4, max(0.5, sp / max(spec.cruise, 0.1)) + 0.3)
        let rate = max(-maxRate, min(maxRate, err * 5))
        b.yawRate += (rate - b.yawRate) * min(1, dt * 8)
        b.yaw = wrapAngle(b.yaw + b.yawRate * dt)

        // Speed.
        let cur = b.horizontalSpeed
        let a = want > cur ? spec.accel : spec.accel * 1.4
        let newSpeed = cur + max(-a * dt, min(a * dt, want - cur))
        // Vertical velocity toward the target height, smoothed.
        let climbTo = max(-spec.descend, min(spec.climb, to.y * 1.8 + (to.y > 0 ? 0.3 : 0) * 0))
        var vy = b.velocity.y + (climbTo - b.velocity.y) * min(1, dt * 3.5)
        // Do not dive faster than the horizontal speed allows (birds glide, they do not drop).
        vy = max(vy, -max(0.6, newSpeed * 1.1))
        let f = forward(yaw: b.yaw)
        b.velocity = V3(f.x * newSpeed, vy, f.z * newSpeed)
        b.position += b.velocity * dt

        // Attitude.
        let climbAngle = degrees(atan2(vy, max(newSpeed, 0.5)))
        let targetPitch = max(-35, min(42, climbAngle * 0.7 + 6))
        b.pitch += (targetPitch - b.pitch) * min(1, dt * 5)
        let bank = max(-55, min(55, -b.yawRate * max(newSpeed, 0.5) * 5.5 * (180 / .pi) / 9.8 * 0.9))
        b.roll += (bank - b.roll) * min(1, dt * 6)
        return max(0.35, min(1, 0.55 + climbAngle / 55 + (want - cur) / 6))
    }

    /// Advances the wingbeat phase.
    public static func advanceWings(_ b: inout FlightBody, hz: Float, effort: Float, dt: Float) {
        b.phase = (b.phase + dt * hz * (0.75 + 0.5 * effort)).truncatingRemainder(dividingBy: 1)
    }

    @inline(__always) static func degrees(_ r: Float) -> Float { r * 180 / .pi }
}

/// Cubic Hermite landing path from the current flight state to a perch, with a flare at the end.
public struct LandingPlan: Sendable {
    public var p0: V3, p1: V3
    public var v0: V3, v1: V3
    public var duration: Float
    public var yaw0: Float, yaw1: Float
    public var pitch0: Float
    public var elapsed: Float = 0

    /// `target` is the center-of-mass position at touchdown. `facing` is the heading at rest.
    public init(from b: FlightBody, target: V3, facing: Float?, restPitch: Float) {
        p0 = b.position; p1 = target
        let dist = simd_length(target - b.position)
        let v = max(b.speed, 1.0)
        duration = max(0.9, min(4.2, 2.1 * dist / v))
        // Arrive from the side the bird is coming from, descending steeply and slowly.
        var dir = V3(target.x - b.position.x, 0, target.z - b.position.z)
        dir = simd_length(dir) > 1e-3 ? simd_normalize(dir) : forward(yaw: b.yaw)
        yaw0 = b.yaw
        yaw1 = facing ?? yaw(of: dir)
        v0 = b.velocity
        let end = facing.map { forward(yaw: $0) } ?? dir
        v1 = end * 0.35 + V3(0, -0.35, 0)
        pitch0 = b.pitch
    }

    public var progress: Float { min(1, elapsed / duration) }
    public var done: Bool { elapsed >= duration }

    /// Advances the plan and returns position, velocity, yaw, pitch and flare amount (0...1).
    public mutating func step(_ dt: Float, restPitch: Float) -> (pos: V3, vel: V3, yaw: Float, pitch: Float, flare: Float) {
        elapsed = min(duration, elapsed + dt)
        let s = elapsed / duration
        let T = duration
        let s2 = s * s, s3 = s2 * s
        let h00 = 2 * s3 - 3 * s2 + 1, h10 = s3 - 2 * s2 + s, h01 = -2 * s3 + 3 * s2, h11 = s3 - s2
        let pos = p0 * h00 + v0 * (T * h10) + p1 * h01 + v1 * (T * h11)
        let d00 = 6 * s2 - 6 * s, d10 = 3 * s2 - 4 * s + 1, d01 = -6 * s2 + 6 * s, d11 = 3 * s2 - 2 * s
        let vel = (p0 * d00 + v0 * (T * d10) + p1 * d01 + v1 * (T * d11)) / T
        let flare = smoothstep(0.5, 0.92, s)
        let yawBlend = smoothstep(0.35, 0.95, s)
        let hs = V2(vel.x, vel.z)
        let travelYaw = simd_length(hs) > 0.15 ? yaw(of: V3(vel.x, 0, vel.z)) : yaw0
        let y = travelYaw + wrapAngle(yaw1 - travelYaw) * yawBlend
        let climb = BirdFlight.degrees(atan2(vel.y, max(simd_length(hs), 0.4)))
        let pitchFlight = max(-30, min(35, climb * 0.7 + 6))
        let pitch = pitchFlight + (max(52, restPitch + 12) - pitchFlight) * flare
        return (pos, vel, y, pitch, flare)
    }
}
