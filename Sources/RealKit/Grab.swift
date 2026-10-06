import Foundation
import RealityKit
import RealCore

// Hand grab for props (RealityHD 5). On visionOS 26 an entity made grabbable gets a solid collision
// box over its whole extent and a `ManipulationComponent`: pinch it (direct or from a distance) to
// pick it up, move and turn it; on release it stays where it was put. Articulated parts keep their
// own tap targets, so a pinch on the body moves the whole object and a tap on a part toggles it.
// Other platforms (the macOS CLI) keep the collision box and skip manipulation.

/// Grab settings stored on a grabbable root.
public struct RealGrabComponent: Component {
    public enum Release: Sendable { case stay, reset }
    public var release: Release
    /// Pose before the first grab (for `resetGrab()`).
    public var home: Transform?
    public init(release: Release = .stay, home: Transform? = nil) { self.release = release; self.home = home }
}

#if os(visionOS)
@MainActor
public enum RealGrabStyle {
    /// Hover effect handed to `ManipulationComponent.configureEntity` for every grabbable.
    /// `RealGrabCue.enable()` switches it to a shader effect that drives the gaze dot.
    public static var hoverEffect: HoverEffectComponent.HoverEffect = .spotlight(.default)
    /// false: no `ManipulationComponent`; the app moves grabbables with its own drag gesture
    /// (`Entity.grabDragChanged`). ManipulationComponent traps in Drift on visionOS 26.2 devices when
    /// the RealityView also carries a tap gesture.
    public static var useManipulation = true
}
#endif

@MainActor
public extension Entity {
    /// Makes this entity pickable by hand. `min`/`max` bound everything it carries (local space).
    func makeGrabbable(min lo: SIMD3<Float>, max hi: SIMD3<Float>, release: RealGrabComponent.Release = .stay) {
        let size = simd_max(hi - lo, SIMD3(repeating: 0.012))
        let shape = ShapeResource.generateBox(size: size).offsetBy(translation: (lo + hi) / 2)
        components.set(RealGrabComponent(release: release, home: transform))
        #if os(visionOS)
        guard RealGrabStyle.useManipulation else {
            components.set(CollisionComponent(shapes: [shape], mode: .default, filter: .default))
            components.set(InputTargetComponent(allowedInputTypes: .all))
            components.set(HoverEffectComponent(RealGrabStyle.hoverEffect))
            return
        }
        ManipulationComponent.configureEntity(self, hoverEffect: RealGrabStyle.hoverEffect, allowedInputTypes: .all, collisionShapes: [shape])
        if var m = components[ManipulationComponent.self] {
            m.releaseBehavior = release == .stay ? .stay : .reset
            m.dynamics.scalingBehavior = .none
            components.set(m)
        }
        #else
        components.set(CollisionComponent(shapes: [shape], mode: .default, filter: .default))
        components.set(InputTargetComponent())
        #endif
    }

    /// Makes this entity grabbable using the visual bounds of its subtree.
    func makeGrabbable(release: RealGrabComponent.Release = .stay) {
        let b = visualBounds(relativeTo: self)
        guard !b.isEmpty else { return }
        makeGrabbable(min: b.min, max: b.max, release: release)
    }

    /// True when this entity or an ancestor can be picked up.
    var grabRoot: Entity? {
        var e: Entity? = self
        while let c = e { if c.components.has(RealGrabComponent.self) { return c }; e = c.parent }
        return nil
    }

    /// Puts a grabbed object back where it started.
    func resetGrab() {
        guard let root = grabRoot, let home = root.components[RealGrabComponent.self]?.home else { return }
        root.transform = home
    }
}

public extension Rig {
    /// Asset-space bounds of the rig at rest: base plus every part, LOD0.
    var restBounds: (min: V3, max: V3) {
        var lo = V3(repeating: .greatestFiniteMagnitude), hi = -lo
        func grow(_ m: Model) { guard m.triangleCount > 0 else { return }; let b = m.bounds; lo = simd_min(lo, b.min); hi = simd_max(hi, b.max) }
        if let b = base.first { grow(b) }
        for p in parts { if let m = p.levels.first { grow(m) } }
        if lo.x > hi.x { return (V3(repeating: 0), V3(repeating: 0)) }
        return (lo, hi)
    }
}
