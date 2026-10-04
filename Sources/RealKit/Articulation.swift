import Foundation
import RealityKit
import RealCore

#if canImport(UIKit)
import UIKit
typealias RealLightColor = UIColor
#else
import AppKit
typealias RealLightColor = NSColor
#endif

func lightColor(_ v: SIMD3<Float>) -> RealLightColor {
    #if canImport(UIKit)
    RealLightColor(cgColor: cgLinear(v))
    #else
    RealLightColor(cgColor: cgLinear(v)) ?? RealLightColor.white
    #endif
}

// Runtime for `Rig` (RealCore/Rig.swift). Each part is one entity whose transform is the joint pose;
// its meshes are uploaded once with the pivot baked out, so animating a door or drawer touches one
// Transform per frame and nothing else. Settled joints cost a component read per frame.
//
//   root  [RealArticulationComponent, RealLODComponent]
//   ├─ lod0, lod1          base meshes
//   └─ joint:door  [RealJointComponent]
//      ├─ lod0, lod1       part meshes (or opt0/lod0..., opt1/lod0... for parts with options)
//      ├─ light:bulb
//      └─ joint:handle ...

/// One animated joint. Lives on the part entity.
public struct RealJointComponent: Component {
    public var name: String
    public var joint: Joint
    /// Part frame relative to the parent part frame at value 0.
    public var rest: Xform
    public private(set) var value: Float
    var from: Float = 0, to: Float = 0, elapsed: Float = 0, duration: Float = 0
    public private(set) var moving = false

    public init(name: String, joint: Joint, rest: Xform, value: Float) {
        self.name = name; self.joint = joint; self.rest = rest; self.value = value
    }

    /// Starts a tween to `target` (or jumps there).
    public mutating func drive(to target: Float, animated: Bool) {
        let r = joint.range
        let t = min(max(target, r.lowerBound), r.upperBound)
        guard animated, t != value else { value = t; moving = false; return }
        let span = max(r.upperBound - r.lowerBound, 1e-4)
        from = value; to = t; elapsed = 0
        duration = joint.duration * max(0.35, abs(t - value) / span)
        moving = true
    }

    /// Advances the tween. Returns true while moving.
    mutating func step(_ dt: Float) -> Bool {
        guard moving else { return false }
        elapsed += dt
        let u = min(1, elapsed / max(duration, 1e-3))
        // Ease in-out (sine): starts and stops without a jolt, like a damped hinge or slide.
        value = from + (to - from) * (0.5 - 0.5 * cos(u * .pi))
        if u >= 1 { value = to; moving = false }
        return true
    }

    public var transform: Transform {
        let x = joint.motion(value).then(rest)
        return Transform(scale: x.scale, rotation: x.rotation, translation: x.translation)
    }
}

/// Rig schema and current state on an articulated root entity.
public struct RealArticulationComponent: Component {
    /// The rig without geometry (states, joints, options, lights).
    public let rig: Rig
    public internal(set) var state: String
    public init(rig: Rig, state: String) { self.rig = rig; self.state = state }
}

/// Moves every joint that has a tween in progress.
public struct RealArticulationSystem: System {
    static let query = EntityQuery(where: .has(RealJointComponent.self))
    public init(scene: RealityKit.Scene) {}
    public mutating func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        for e in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var j = e.components[RealJointComponent.self], j.moving else { continue }
            _ = j.step(dt)
            e.transform = j.transform
            e.components.set(j)
        }
    }
}

public extension Rig {
    /// Rig without geometry, for runtime lookups.
    var schema: Rig {
        var r = self
        r.base = base.map { Model(name: $0.name) }
        for i in r.parts.indices {
            r.parts[i].levels = r.parts[i].levels.map { Model(name: $0.name) }
            r.parts[i].alternates = r.parts[i].alternates.map { $0.map { Model(name: $0.name) } }
        }
        return r
    }

    /// Entity with one child entity per part (see the file header), posed in `state`.
    /// - Parameter interactive: add collision boxes and input targets so taps reach parts (`realToggle()`).
    /// - Parameter grabbable: the whole object can be picked up by hand (`ManipulationComponent` on
    ///   visionOS); parts keep their tap targets.
    @MainActor
    func entityAsync(name: String? = nil, state: String? = nil, materials: RealMaterialCache? = nil, interactive: Bool = false,
                     grabbable: Bool = false) async throws -> Entity {
        let root = Entity()
        root.name = name ?? self.name
        let start = state ?? initialState
        let vals = values(start), opts = options(start)
        let multiLOD = lodCount > 1

        func lodChildren(_ models: [Model], under parent: Entity) async throws {
            for (i, m) in models.enumerated() where m.triangleCount > 0 {
                let e = try await m.modelEntityAsync(materials: materials)
                e.name = "lod\(i)"
                e.isEnabled = i == 0
                e.realTagCost(m.cost(lod: i, size: models[0].boundsDiagonal))
                parent.addChild(e)
            }
        }

        try await lodChildren(base, under: root)
        var joints: [String: Entity] = [:]
        for (i, p) in parts.enumerated() {
            let e = Entity()
            e.name = "joint:\(p.name)"
            var jc = RealJointComponent(name: p.name, joint: p.joint, rest: localJointTransform(i, value: 0), value: 0)
            jc.drive(to: vals[p.name] ?? 0, animated: false)
            e.components.set(jc)
            e.transform = jc.transform
            let geo = localGeometry(i)
            if geo.count == 1 {
                try await lodChildren(geo[0], under: e)
            } else {
                let chosen = min(opts[p.name] ?? 0, geo.count - 1)
                for (o, levels) in geo.enumerated() {
                    let c = Entity()
                    c.name = "opt\(o)"
                    c.isEnabled = o == chosen
                    try await lodChildren(levels, under: c)
                    e.addChild(c)
                }
            }
            if interactive, p.joint.kind != .fixed, p.joint.mimic == nil, let b = geo[0].first?.bounds, b.max != b.min {
                Self.makeTarget(e, min: b.min, max: b.max)
            }
            (p.parent.flatMap { joints[$0] } ?? root).addChild(e)
            joints[p.name] = e
        }
        for l in lights {
            let e = Entity()
            e.name = "light:\(l.name)"
            let host = l.part.flatMap { joints[$0] } ?? root
            let inv = l.part.flatMap(index).map { parts[$0].pivot.inverse } ?? .identity
            let pos = inv.point(l.position), dir = inv.rotation.act(l.direction)
            l.configure(e)
            host.addChild(e)
            e.look(at: pos + dir, from: pos, relativeTo: host)
            e.isEnabled = Self.lightOn(l, opts)
        }
        root.components.set(RealArticulationComponent(rig: schema, state: start))
        if multiLOD {
            var b = base[0].bounds
            for p in parts where p.levels[0].triangleCount > 0 { let pb = p.levels[0].bounds; b = (simd_min(b.min, pb.min), simd_max(b.max, pb.max)) }
            root.components.set(RealLODComponent(switchDistances: switchDistances, center: (b.min + b.max) / 2))
        }
        if grabbable {
            let b = restBounds
            root.makeGrabbable(min: b.min, max: b.max)
        } else if interactive, base[0].triangleCount > 0 {
            let b = base[0].bounds
            Self.makeTarget(root, min: b.min, max: b.max)
        }
        return root
    }

    static func lightOn(_ l: RigLight, _ opts: [String: Int]) -> Bool {
        guard let p = l.part, let o = l.option else { return true }
        return (opts[p] ?? 0) == o
    }

    @MainActor
    static func makeTarget(_ e: Entity, min lo: SIMD3<Float>, max hi: SIMD3<Float>) {
        let size = simd_max(hi - lo, SIMD3(repeating: 0.01))
        e.components.set(CollisionComponent(shapes: [ShapeResource.generateBox(size: size).offsetBy(translation: (lo + hi) / 2)], mode: .trigger, filter: .default))
        e.components.set(InputTargetComponent())
        #if os(visionOS)
        e.components.set(HoverEffectComponent())
        #endif
    }
}

public extension RigLight {
    /// Sets the RealityKit light component(s) on `e` (aim it with `look(at:from:relativeTo:)`).
    @MainActor
    func configure(_ e: Entity) {
        switch kind {
        case .point:
            e.components.set(PointLightComponent(color: lightColor(color), intensity: intensity, attenuationRadius: attenuationRadius))
        case .spot(let inner, let outer):
            var s = SpotLightComponent(color: lightColor(color), intensity: intensity, innerAngleInDegrees: inner,
                                       outerAngleInDegrees: outer, attenuationRadius: attenuationRadius)
            s.attenuationFalloffExponent = 2
            e.components.set(s)
            if castsShadow { e.components.set(SpotLightComponent.Shadow()) }
        }
    }
}

@MainActor
public extension Entity {
    /// Nearest articulated root at or above this entity.
    var articulationRoot: Entity? {
        var e: Entity? = self
        while let c = e { if c.components.has(RealArticulationComponent.self) { return c }; e = c.parent }
        return nil
    }

    /// State names of the articulated asset this entity belongs to.
    var articulationStates: [String] { articulationRoot?.components[RealArticulationComponent.self]?.rig.stateNames ?? [] }
    /// Current state name (the last one set).
    var articulationState: String? { articulationRoot?.components[RealArticulationComponent.self]?.state }

    /// Moves every joint to a named state and switches part options and lights.
    func setArticulation(_ state: String, animated: Bool = true) {
        guard let root = articulationRoot, var a = root.components[RealArticulationComponent.self], a.rig.stateNames.contains(state) else { return }
        a.state = state
        root.components.set(a)
        root.applyJoints(a.rig.values(state), rig: a.rig, animated: animated)
        root.applyOptions(a.rig.options(state), rig: a.rig)
    }

    /// Sets joint values directly (degrees or meters); joints not named keep their target. Mimics follow.
    func setJoints(_ values: [String: Float], animated: Bool = true) {
        guard let root = articulationRoot, let a = root.components[RealArticulationComponent.self] else { return }
        var current: [String: Float] = [:]
        for p in a.rig.parts where p.joint.mimic == nil {
            if let j = root.findEntity(named: "joint:\(p.name)")?.components[RealJointComponent.self] { current[p.name] = j.moving ? j.to : j.value }
        }
        for (k, v) in values { current[k] = v }
        root.applyJoints(a.rig.values(current), rig: a.rig, animated: animated)
    }

    /// Cycles to the next state.
    func nextArticulation(animated: Bool = true) {
        guard let root = articulationRoot, let a = root.components[RealArticulationComponent.self] else { return }
        let names = a.rig.stateNames
        guard let i = names.firstIndex(of: a.state) else { return }
        setArticulation(names[(i + 1) % names.count], animated: animated)
    }

    /// Tap handler: on a part, swings that joint between its closed and most-open state values; on the
    /// body, cycles states. Use with `SpatialTapGesture().targetedToAnyEntity()`.
    func realToggle(animated: Bool = true) {
        var e: Entity? = self
        while let c = e, !c.components.has(RealArticulationComponent.self) {
            if let j = c.components[RealJointComponent.self], j.joint.kind != .fixed, j.joint.mimic == nil,
               let root = c.articulationRoot, let a = root.components[RealArticulationComponent.self] {
                let stateValues = a.rig.states.map { a.rig.values($0.name)[j.name] ?? 0 }
                let closed = stateValues.min { abs($0) < abs($1) } ?? 0
                let open = stateValues.max { abs($0) < abs($1) } ?? j.joint.range.upperBound
                let goal = abs((j.moving ? j.to : j.value) - closed) < abs(open - closed) * 0.5 ? open : closed
                // Options follow the state that holds this joint at the goal (a lamp shade lifting also lights it).
                if let s = a.rig.states.first(where: { a.rig.values($0.name)[j.name] == goal }), !a.rig.options(s.name).isEmpty {
                    root.applyOptions(a.rig.options(s.name), rig: a.rig)
                }
                setJoints([j.name: goal], animated: animated)
                return
            }
            e = c.parent
        }
        nextArticulation(animated: animated)
    }

    private func applyJoints(_ values: [String: Float], rig: Rig, animated: Bool) {
        for p in rig.parts where p.joint.kind != .fixed {
            guard let e = findEntity(named: "joint:\(p.name)"), var j = e.components[RealJointComponent.self] else { continue }
            j.drive(to: values[p.name] ?? 0, animated: animated)
            e.components.set(j)
            if !animated { e.transform = j.transform }
        }
    }

    private func applyOptions(_ options: [String: Int], rig: Rig) {
        for p in rig.parts where p.optionCount > 1 {
            guard let e = findEntity(named: "joint:\(p.name)") else { continue }
            let o = options[p.name] ?? 0
            for c in e.children where c.name.hasPrefix("opt") { c.isEnabled = c.name == "opt\(o)" }
        }
        for l in rig.lights { findEntity(named: "light:\(l.name)")?.isEnabled = Rig.lightOn(l, options) }
    }
}
