import simd

// Articulated assets. A `Rig` is static base geometry plus moving parts on joints (hinges, slides,
// swivels), parts with alternate geometry (lamp off/on, screen off/on), lights that follow a part
// option, and named states ("closed", "open") that set every joint and option at once.
//
// Geometry is authored in asset space at rest (every joint at 0, every option 0), exactly as a static
// prop is built. A part names its pivot frame; RealKit uploads each part once, with the pivot baked
// out, and animates only the part entity's transform. `posed(_:)` bakes any state into a static
// LODModel for thumbnails, tests and instanced fields.

/// One degree of freedom between a part and its parent.
public struct Joint: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// Fixed attachment (a part that only carries options or children).
        case fixed
        /// Rotation about `axis` through the pivot, value in degrees.
        case revolute
        /// Translation along `axis`, value in meters.
        case prismatic
    }
    public var kind: Kind
    /// Unit axis in the pivot frame.
    public var axis: V3
    /// Allowed values (degrees or meters). States are clamped into it.
    public var range: ClosedRange<Float>
    /// Seconds for a full sweep of `range` when animated (shorter moves take proportionally less, with
    /// a floor of 35 %).
    public var duration: Float
    /// Follow another joint: value = ratio * other + offset. Used for linked parts (bin lid from the
    /// pedal, bi-parting doors, page fans).
    public var mimic: Mimic?

    public struct Mimic: Sendable, Equatable {
        public var joint: String
        public var ratio: Float
        public var offset: Float
        public init(_ joint: String, ratio: Float = 1, offset: Float = 0) { self.joint = joint; self.ratio = ratio; self.offset = offset }
    }

    public init(_ kind: Kind, axis: V3 = .up, range: ClosedRange<Float> = 0...0, duration: Float? = nil, mimic: Mimic? = nil) {
        self.kind = kind; self.axis = simd_normalize(axis); self.range = range; self.mimic = mimic
        self.duration = duration ?? (kind == .prismatic ? 0.5 : 0.9)
    }

    public static let fixed = Joint(.fixed)
    public static func hinge(axis: V3 = .up, _ range: ClosedRange<Float>, duration: Float? = nil) -> Joint { Joint(.revolute, axis: axis, range: range, duration: duration) }
    public static func slide(axis: V3, _ range: ClosedRange<Float>, duration: Float? = nil) -> Joint { Joint(.prismatic, axis: axis, range: range, duration: duration) }

    /// Motion of the part frame relative to its rest pose for a joint value.
    public func motion(_ v: Float) -> Xform {
        switch kind {
        case .fixed: return .identity
        case .revolute: return Xform(rotation: simd_quatf(angle: radians(v), axis: axis))
        case .prismatic: return Xform(translation: axis * v)
        }
    }
}

/// A moving or switchable piece of a rig.
public struct RigPart: Sendable {
    public var name: String
    /// Parent part name (nil = rig root). Parents are declared before children.
    public var parent: String?
    /// Joint frame in asset space at rest: translation is the pivot point, rotation orients the axis.
    public var pivot: Xform
    public var joint: Joint
    /// Option 0 geometry per LOD, in asset space at rest.
    public var levels: [Model]
    /// Alternate geometry per option index 1..., each per LOD (lamp lit, screen on).
    public var alternates: [[Model]] = []

    public var optionCount: Int { 1 + alternates.count }
    public func option(_ i: Int) -> [Model] { i == 0 ? levels : alternates[i - 1] }
}

/// A light that is part of an asset: a lamp's bulb, a monitor's glow. Position and direction are in
/// asset space at rest; the light rides on `part` and is on while that part shows `option`.
public struct RigLight: Sendable {
    public enum Kind: Sendable, Equatable {
        case point
        /// Cone half-angles in degrees.
        case spot(inner: Float, outer: Float)
    }
    public var name: String
    public var kind: Kind
    public var part: String?
    /// Light is on while `part` shows this option (nil = always on).
    public var option: Int?
    public var position: V3
    public var direction: V3
    /// Linear RGB.
    public var color: V3
    /// Lumens (RealityKit units).
    public var intensity: Float
    public var attenuationRadius: Float
    public var castsShadow: Bool
    public init(name: String, kind: Kind = .point, part: String? = nil, option: Int? = nil, position: V3, direction: V3 = V3(0, -1, 0),
                color: V3 = V3(1, 0.86, 0.7), intensity: Float = 800, attenuationRadius: Float = 4, castsShadow: Bool = false) {
        self.name = name; self.kind = kind; self.part = part; self.option = option; self.position = position
        self.direction = simd_normalize(direction); self.color = color; self.intensity = intensity
        self.attenuationRadius = attenuationRadius; self.castsShadow = castsShadow
    }
}

/// A named pose: joint values (degrees or meters) and part options. Joints and options a state does
/// not mention sit at 0.
public struct RigState: Sendable, Equatable {
    public var name: String
    public var joints: [String: Float]
    public var options: [String: Int]
    public init(_ name: String, _ joints: [String: Float] = [:], options: [String: Int] = [:]) {
        self.name = name; self.joints = joints; self.options = options
    }
}

/// A part option chosen by a joint value: option = number of `thresholds` at or below |value|.
/// A gas knob lights its burner (`thresholds: [10]`), a faucet lever opens the stream; with two
/// thresholds `[10, 200]` a knob gives off (0), high (1) and low (2).
public struct RigOptionLink: Sendable, Equatable {
    public var part: String
    public var joint: String
    public var thresholds: [Float]
    public init(part: String, joint: String, thresholds: [Float]) { self.part = part; self.joint = joint; self.thresholds = thresholds }
    public func option(_ value: Float) -> Int { thresholds.filter { abs(value) >= $0 }.count }
}

/// An articulated asset: static base + jointed parts + states. See the file header.
public struct Rig: Sendable {
    public var name: String
    /// Static geometry per LOD.
    public var base: [Model]
    public var switchDistances: [Float]
    public var parts: [RigPart] = []
    public var lights: [RigLight] = []
    public var states: [RigState] = []
    /// Options driven by joint values (`setJoints` and taps switch them; states set them explicitly).
    public var optionLinks: [RigOptionLink] = []
    /// State used by `posed()` and by new entities. Defaults to the first state.
    public var defaultState: String?

    /// - Parameters: lods: LOD count; every part gets this many levels.
    public init(name: String, lods: Int = 1, switchDistances: [Float] = []) {
        precondition(switchDistances.count == max(0, lods - 1))
        self.name = name
        base = (0..<lods).map { _ in Model(name: name) }
        self.switchDistances = switchDistances
    }

    public var lodCount: Int { base.count }
    public var stateNames: [String] { states.map(\.name) }
    public var initialState: String { defaultState ?? states.first?.name ?? "rest" }

    // MARK: authoring

    /// Declares a part and returns its index. Add geometry with `add(_:to:)` in asset space.
    @discardableResult
    public mutating func part(_ name: String, parent: String? = nil, pivot: V3, frame: simd_quatf = .identity, joint: Joint, options: Int = 1) -> Int {
        precondition(!parts.contains { $0.name == name }, "duplicate part \(name)")
        precondition(parent == nil || parts.contains { $0.name == parent }, "parent \(parent!) must be declared before \(name)")
        let empty = (0..<lodCount).map { _ in Model(name: name) }
        parts.append(RigPart(name: name, parent: parent, pivot: Xform(translation: pivot, rotation: frame), joint: joint,
                             levels: empty, alternates: (1..<max(1, options)).map { _ in empty }))
        return parts.count - 1
    }

    public func index(_ part: String) -> Int? { parts.firstIndex { $0.name == part } }

    /// Adds a surface to a part's option (asset space at rest). `lods` picks the levels it appears in
    /// (default: every level).
    public mutating func add(_ s: Surface, _ x: Xform = .identity, to part: String, option: Int = 0, lods: ClosedRange<Int>? = nil) {
        guard let i = index(part) else { preconditionFailure("unknown part \(part)") }
        for l in lods ?? 0...(lodCount - 1) where l < lodCount {
            if option == 0 { parts[i].levels[l].add(s, x) } else { parts[i].alternates[option - 1][l].add(s, x) }
        }
    }

    /// Adds a model to a part option at one LOD.
    public mutating func add(_ m: Model, to part: String, option: Int = 0, lod: Int) {
        guard let i = index(part) else { preconditionFailure("unknown part \(part)") }
        if option == 0 { parts[i].levels[lod].add(m) } else { parts[i].alternates[option - 1][lod].add(m) }
    }

    /// Replaces a part option's geometry for one LOD.
    public mutating func set(_ m: Model, part: String, option: Int = 0, lod: Int) {
        guard let i = index(part) else { preconditionFailure("unknown part \(part)") }
        if option == 0 { parts[i].levels[lod] = m } else { parts[i].alternates[option - 1][lod] = m }
    }

    // MARK: posing

    /// Joint values for a state (clamped, mimics resolved, unknown names ignored).
    public func values(_ state: String) -> [String: Float] {
        values(states.first { $0.name == state }?.joints ?? [:])
    }

    public func values(_ requested: [String: Float]) -> [String: Float] {
        var v: [String: Float] = [:]
        for p in parts where p.joint.mimic == nil {
            let r = p.joint.range
            v[p.name] = min(max(requested[p.name] ?? clampZero(r), r.lowerBound), r.upperBound)
        }
        // Mimics may follow other mimics; resolve in declaration order, then once more.
        for _ in 0..<2 {
            for p in parts { if let m = p.joint.mimic { v[p.name] = (v[m.joint] ?? 0) * m.ratio + m.offset } }
        }
        return v
    }

    public func options(_ state: String) -> [String: Int] { states.first { $0.name == state }?.options ?? [:] }

    /// Options implied by `optionLinks` for joint values (only linked parts appear).
    public func linkedOptions(_ values: [String: Float]) -> [String: Int] {
        var o: [String: Int] = [:]
        for l in optionLinks { o[l.part] = l.option(values[l.joint] ?? 0) }
        return o
    }

    private func clampZero(_ r: ClosedRange<Float>) -> Float { min(max(0, r.lowerBound), r.upperBound) }

    /// Transform from a part's rest pose to its posed pose, in asset space (geometry at rest maps
    /// through it). Parents first.
    public func partTransforms(_ values: [String: Float]) -> [Xform] {
        var frames: [Xform] = []   // posed joint frames, asset space
        var out: [Xform] = []
        for p in parts {
            let parentFrame: Xform, parentRest: Xform
            if let pn = p.parent, let pi = index(pn) { parentFrame = frames[pi]; parentRest = parts[pi].pivot }
            else { parentFrame = .identity; parentRest = .identity }
            let local = parentRest.inverse.then(p.pivot)                // pivot relative to parent pivot at rest
            let frame = p.joint.motion(values[p.name] ?? 0).then(local).then(parentFrame)
            frames.append(frame)
            out.append(p.pivot.inverse.then(frame))
        }
        return out
    }

    /// Joint frame of each part relative to its parent's frame at a value (what the runtime entity uses).
    public func localJointTransform(_ i: Int, value: Float) -> Xform {
        let p = parts[i]
        let parentRest = p.parent.flatMap(index).map { parts[$0].pivot } ?? .identity
        return p.joint.motion(value).then(parentRest.inverse.then(p.pivot))
    }

    /// Static LODModel of a state (default: the initial state).
    public func posed(_ state: String? = nil) -> LODModel {
        let s = state ?? initialState
        return posed(values: values(s), options: options(s))
    }

    public func posed(values: [String: Float], options: [String: Int] = [:]) -> LODModel {
        let xf = partTransforms(values)
        var levels: [Model] = []
        for l in 0..<lodCount {
            var m = Model(name: name)
            m.add(base[l])
            for (i, p) in parts.enumerated() {
                let o = min(options[p.name] ?? 0, p.optionCount - 1)
                m.add(p.option(o)[l], xf[i])
            }
            levels.append(m)
        }
        return LODModel(levels: levels, switchDistances: switchDistances)
    }

    /// Part geometry with the pivot baked out (part-local frame), per option and LOD.
    public func localGeometry(_ i: Int) -> [[Model]] {
        let inv = parts[i].pivot.inverse
        return (0..<parts[i].optionCount).map { o in parts[i].option(o).map { $0.transformed(inv) } }
    }

    /// Problems with the rig definition (empty = valid). Tests run this on every articulated asset.
    public func validate() -> [String] {
        var issues: [String] = []
        if states.count < 2 { issues.append("needs at least two states") }
        if Set(stateNames).count != states.count { issues.append("duplicate state names") }
        if let d = defaultState, !stateNames.contains(d) { issues.append("defaultState \(d) is not a state") }
        for p in parts {
            if p.levels.count != lodCount || p.alternates.contains(where: { $0.count != lodCount }) { issues.append("\(p.name): LOD count") }
            if let m = p.joint.mimic, index(m.joint) == nil { issues.append("\(p.name): mimics unknown joint \(m.joint)") }
            if p.joint.kind != .fixed && p.joint.range.lowerBound == p.joint.range.upperBound && p.joint.mimic == nil {
                issues.append("\(p.name): zero range")
            }
        }
        for s in states {
            for (k, v) in s.joints {
                guard let i = index(k) else { issues.append("state \(s.name): unknown joint \(k)"); continue }
                let j = parts[i].joint
                if j.mimic != nil { issues.append("state \(s.name): \(k) is a mimic joint") }
                if !j.range.contains(v) { issues.append("state \(s.name): \(k) = \(v) outside \(j.range)") }
            }
            for (k, v) in s.options {
                guard let i = index(k) else { issues.append("state \(s.name): unknown part \(k)"); continue }
                if v < 0 || v >= parts[i].optionCount { issues.append("state \(s.name): \(k) option \(v) out of range") }
            }
        }
        for k in optionLinks {
            guard let i = index(k.part) else { issues.append("link: unknown part \(k.part)"); continue }
            if index(k.joint) == nil { issues.append("link \(k.part): unknown joint \(k.joint)") }
            if k.thresholds.count >= parts[i].optionCount { issues.append("link \(k.part): \(k.thresholds.count) thresholds for \(parts[i].optionCount) options") }
            for s in states where (options(s.name)[k.part] ?? 0) != k.option(values(s.name)[k.joint] ?? 0) {
                issues.append("state \(s.name): \(k.part) option disagrees with link from \(k.joint)")
            }
        }
        for l in lights {
            if let p = l.part, index(p) == nil { issues.append("light \(l.name): unknown part \(p)") }
            if let o = l.option, let p = l.part, let i = index(p), o >= parts[i].optionCount { issues.append("light \(l.name): option \(o)") }
        }
        // Distinct states must differ.
        for (i, a) in states.enumerated() { for b in states[(i + 1)...] where values(a.name) == values(b.name) && options(a.name) == options(b.name) {
            issues.append("states \(a.name) and \(b.name) are identical")
        }}
        return issues
    }
}

public extension Xform {
    /// Rigid inverse (pivots carry no scale).
    var inverse: Xform {
        let r = rotation.inverse
        return Xform(translation: r.act(-translation) / scale, rotation: r, scale: V3(repeating: 1) / scale)
    }
    /// `self` followed by `next` (apply self first). Exact for uniform scale.
    func then(_ next: Xform) -> Xform {
        Xform(translation: next.point(translation), rotation: next.rotation * rotation, scale: next.scale * scale)
    }
}
