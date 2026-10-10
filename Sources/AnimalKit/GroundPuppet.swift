import Foundation
import RealityKit
import RealKit
import RealCore
import AnimalCore

@MainActor
public struct GroundTemplate {
    public let built: GroundRig
    let schema: Rig
    let entity: Entity
}

/// One live ground animal: holder at the center of mass, rig below.
@MainActor
public final class GroundPuppet {
    public let species: GroundSpecies
    public let built: GroundRig
    public let holder = Entity()
    public let model: Entity
    private var joints: [Entity?]
    private var rest: [Xform]
    private var defs: [Joint]
    private var last: [Float]
    private let specs: [BirdJointSpec]

    init(template: GroundTemplate) {
        species = template.built.profile.species
        built = template.built
        model = template.entity.clone(recursive: true)
        specs = built.joints
        var js: [Entity?] = [], rs: [Xform] = [], ds: [Joint] = []
        for sp in specs {
            js.append(model.findEntity(named: "joint:\(sp.name)"))
            let i = template.schema.index(sp.name)!
            rs.append(template.schema.localJointTransform(i, value: 0))
            ds.append(template.schema.parts[i].joint)
        }
        joints = js; rest = rs; defs = ds
        last = [Float](repeating: .nan, count: specs.count)
        holder.name = "ground:\(species.rawValue)"
        model.position = [0, -built.comHeight, 0]
        holder.addChild(model)
    }

    public func apply(_ pose: GroundPose) {
        for i in 0..<specs.count {
            let r = specs[i].range
            let v = min(max(pose.values[i], r.lowerBound), r.upperBound)
            if abs(v - last[i]) < 1e-3 { continue }
            last[i] = v
            guard let e = joints[i] else { continue }
            let x = defs[i].motion(v).then(rest[i])
            e.transform = Transform(scale: x.scale, rotation: x.rotation, translation: x.translation)
        }
    }
}

@MainActor
public enum GroundFactory {
    private static var templates: [GroundSpecies: GroundTemplate] = [:]
    private static var building: [GroundSpecies: Task<GroundTemplate, Error>] = [:]

    public static func template(_ s: GroundSpecies) async throws -> GroundTemplate {
        if let t = templates[s] { return t }
        if let task = building[s] { return try await task.value }
        let task = Task { @MainActor () -> GroundTemplate in
            let profile = s.profile
            AnimalMaterials.register(profile)
            let built = await Task.detached(priority: .userInitiated) { GroundRigBuilder.build(profile) }.value
            let entity = try await built.rig.entityAsync(name: s.rawValue, state: "stand", interactive: false)
            return GroundTemplate(built: built, schema: built.rig.schema, entity: entity)
        }
        building[s] = task
        defer { building[s] = nil }
        let t = try await task.value
        templates[s] = t
        return t
    }

    public static func puppet(_ s: GroundSpecies) async throws -> GroundPuppet { GroundPuppet(template: try await template(s)) }
}
