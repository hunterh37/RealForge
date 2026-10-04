import Foundation
import RealityKit
import RealCore
import RealMaterials

/// Live anatomical hand overlay driven by tracked joint positions.
///
/// Bones are rigid meshes built once (`HandBones`) and posed per frame from `HandFrames`; muscles,
/// tendons, vessels, nerves and the soft-tissue envelope are rebuilt per frame (`HandSoftTissue`)
/// into a `LowLevelMesh` updated in place.
///
/// Modes: `.xray` radiograph look (glowing cortical rims, faint soft-tissue shadow), `.muscle`
/// opaque dissection (bone, cartilage, muscle, tendon, vessels, nerves), `.both` x-ray bones under
/// see-through soft tissue.
@MainActor
public final class RealHandAnatomy {
    public enum Mode: String, CaseIterable, Sendable { case off, xray, muscle, both }

    public let chirality: Chirality
    public let root = Entity()
    public private(set) var mode: Mode = .off
    /// 0 = raw joints, 0.9 = heavy smoothing. Applied per update.
    public var smoothing: Float = 0.45
    /// Soft-tissue tessellation (1 full).
    public var detail: Float

    private let bones: HandBones
    private var boneEntities: [[ModelEntity]] = []
    private let carpus = ModelEntity(), forearm = ModelEntity()
    private var anatomicalBoneMaterials: [ObjectIdentifier: [any RealityKit.Material]] = [:]
    private var xrayBone: (any RealityKit.Material)?
    private var xrayFlesh: (any RealityKit.Material)?
    private let tissue = DynamicMesh(name: "soft-tissue")
    private let envelope = DynamicMesh(name: "envelope")
    private var tissueOpaque: [MaterialKey: any RealityKit.Material] = [:]
    private var tissueGlass: [MaterialKey: any RealityKit.Material] = [:]
    private var smoothed: [V3]?
    private let cache: RealMaterialCache

    /// Builds the bone meshes off the main actor, then the entities. Use this from apps.
    public static func load(chirality: Chirality, detail: Float = 1, materials: RealMaterialCache? = nil) async -> RealHandAnatomy {
        let d = max(0.5, detail)
        let bones = await Task.detached(priority: .userInitiated) { HandBones(detail: d).forHand(chirality) }.value
        return RealHandAnatomy(chirality: chirality, bones: bones, detail: detail, materials: materials)
    }

    public convenience init(chirality: Chirality, detail: Float = 1, materials: RealMaterialCache? = nil) {
        self.init(chirality: chirality, bones: HandBones(detail: max(0.5, detail)).forHand(chirality), detail: detail, materials: materials)
    }

    /// `bones` must already be `forHand(chirality)`.
    public init(chirality: Chirality, bones: HandBones, detail: Float = 1, materials: RealMaterialCache? = nil) {
        self.chirality = chirality
        self.detail = detail
        let materials = materials ?? .shared
        self.cache = materials
        self.bones = bones
        root.name = "hand-anatomy-\(chirality == .right ? "right" : "left")"
        for row in bones.digits {
            var es: [ModelEntity] = []
            for m in row {
                let e = (try? m.modelEntity(materials: materials)) ?? ModelEntity()
                root.addChild(e); es.append(e)
            }
            boneEntities.append(es)
        }
        if let c = try? bones.carpus.modelEntity(materials: materials) { carpus.model = c.model }
        if let f = try? bones.forearm.modelEntity(materials: materials) { forearm.model = f.model }
        root.addChild(carpus); root.addChild(forearm)
        root.addChild(tissue.entity); root.addChild(envelope.entity)
        root.isEnabled = false
    }

    /// Generates textures and shader graphs up front so switching modes never hitches.
    public func prepare() async {
        let keys = [HandBones.boneKey, HandBones.cartilageKey]
        await cache.warm(keys)
        var byKey: [MaterialKey: any RealityKit.Material] = [:]
        for k in keys { byKey[k] = await cache.materialAsync(k) }
        func mats(_ m: Model) -> [any RealityKit.Material] { m.surfaces.filter { !$0.isEmpty }.map { byKey[$0.material] ?? cache.material($0.material) } }
        for (d, row) in bones.digits.enumerated() {
            for (s, m) in row.enumerated() { anatomicalBoneMaterials[ObjectIdentifier(boneEntities[d][s])] = mats(m) }
        }
        anatomicalBoneMaterials[ObjectIdentifier(carpus)] = mats(bones.carpus)
        anatomicalBoneMaterials[ObjectIdentifier(forearm)] = mats(bones.forearm)
        let opaque = HandSoftTissue.Keys(), glass = HandSoftTissue.Keys.glass
        for k in [opaque.muscle, opaque.tendon, opaque.vein, opaque.artery, opaque.nerve] { tissueOpaque[k] = await cache.materialAsync(k) }
        for (o, g) in zip([opaque.muscle, opaque.tendon, opaque.vein, opaque.artery, opaque.nerve], [glass.muscle, glass.tendon, glass.vein, glass.artery, glass.nerve]) {
            tissueGlass[o] = await cache.materialAsync(g)
        }
        xrayBone = try? await RealXray.material(.bone)
        xrayFlesh = try? await RealXray.material(.flesh)
        apply()
    }

    public func setMode(_ m: Mode) { mode = m; apply() }

    private func apply() {
        root.isEnabled = mode != .off
        let xrayBones = mode == .xray || mode == .both
        for e in allBoneEntities {
            guard var model = e.model else { continue }
            if xrayBones, let x = xrayBone { model.materials = Array(repeating: x, count: model.materials.count) }
            else if let m = anatomicalBoneMaterials[ObjectIdentifier(e)] { model.materials = m }
            e.model = model
            e.components.set(ModelSortGroupComponent(group: Self.sortGroup, order: xrayBones ? 1 : 0))
        }
        tissue.entity.isEnabled = mode == .muscle || mode == .both
        envelope.entity.isEnabled = mode == .xray || mode == .both
        tissue.entity.components.set(ModelSortGroupComponent(group: Self.sortGroup, order: 2))
        envelope.entity.components.set(ModelSortGroupComponent(group: Self.sortGroup, order: 3))
        lastLayers = nil
    }

    private static let sortGroup = ModelSortGroup(depthPass: nil)
    private var lastLayers: HandSoftTissue.Layers?
    private var allBoneEntities: [ModelEntity] { boneEntities.flatMap { $0 } + [carpus, forearm] }

    /// Poses the overlay. `pose` must be in the space of `root`'s parent.
    public func update(_ pose: HandPose) {
        guard mode != .off else { return }
        var p = pose
        if let prev = smoothed, smoothing > 0 {
            let a = 1 - min(0.95, smoothing)
            for i in p.positions.indices {
                // Snap on large jumps (tracking reacquired) instead of sliding across the room.
                if simd_distance(prev[i], p.positions[i]) < 0.08 { p.positions[i] = lerp(prev[i], p.positions[i], a) }
            }
        }
        smoothed = p.positions
        let f = HandFrames(p)
        let k = f.scale
        for d in Digit.allCases {
            for s in 0..<boneEntities[d.rawValue].count {
                let along = f.length(d, s) / bones.referenceLengths[d.rawValue][s]
                boneEntities[d.rawValue][s].transform = Transform(matrix: f.bone(d, s).matrix(scale: V3(k, along, k)))
            }
        }
        carpus.transform = Transform(matrix: f.palm.matrix(scale: V3(repeating: k)))
        forearm.transform = Transform(matrix: f.forearm.matrix(scale: V3(repeating: k)))

        if tissue.entity.isEnabled {
            let glass = mode == .both
            let st = HandSoftTissue(keys: HandSoftTissue.Keys(), detail: detail)
            let model = st.build(f, layers: .anatomy)
            let mats = model.surfaces.map { s -> any RealityKit.Material in
                (glass ? tissueGlass[s.material] : tissueOpaque[s.material]) ?? cache.material(glass ? s.material + "-glass" : s.material)
            }
            tissue.update(model, materials: mats, materialSignature: glass ? 1 : 0)
        }
        if envelope.entity.isEnabled {
            let st = HandSoftTissue(detail: detail)
            let model = st.build(f, layers: .envelope)
            let m: any RealityKit.Material = xrayFlesh ?? SimpleMaterial(color: .init(white: 0.6, alpha: 0.15), isMetallic: false)
            envelope.update(model, materials: model.surfaces.map { _ in m }, materialSignature: 2)
        }
    }

    /// Drops the smoothing history (after tracking loss).
    public func resetSmoothing() { smoothed = nil }
}

/// A ModelEntity backed by a LowLevelMesh whose contents are rewritten each frame. The mesh is
/// recreated only when the vertex or index count or the material list changes.
@MainActor
final class DynamicMesh {
    let entity = ModelEntity()
    private var mesh: LowLevelMesh?
    private var vCap = 0, iCap = 0
    private var signature: [String] = []

    init(name: String) { entity.name = name }

    func update(_ model: Model, materials: [any RealityKit.Material], materialSignature: Int) {
        let surfaces = model.surfaces.filter { !$0.isEmpty }
        let vCount = surfaces.reduce(0) { $0 + $1.vertexCount }, iCount = surfaces.reduce(0) { $0 + $1.indices.count }
        guard vCount > 0 else { entity.model = nil; return }
        let sig = surfaces.map(\.material) + ["\(materialSignature)"]
        let rebuild = mesh == nil || vCount > vCap || iCount > iCap || sig != signature
        if rebuild {
            let attrs: [LowLevelMesh.Attribute] = [
                .init(semantic: .position, format: .float3, offset: 0), .init(semantic: .normal, format: .float3, offset: 12),
                .init(semantic: .tangent, format: .float3, offset: 24), .init(semantic: .bitangent, format: .float3, offset: 36),
                .init(semantic: .uv0, format: .float2, offset: 48), .init(semantic: .uv1, format: .float2, offset: 56),
                .init(semantic: .uv2, format: .float2, offset: 64),
            ]
            vCap = Int(Double(vCount) * 1.1) + 64; iCap = Int(Double(iCount) * 1.1) + 192
            let desc = LowLevelMesh.Descriptor(vertexCapacity: vCap, vertexAttributes: attrs,
                                               vertexLayouts: [.init(bufferIndex: 0, bufferStride: MemoryLayout<RFVertex>.stride)],
                                               indexCapacity: iCap, indexType: .uint32)
            guard let m = try? LowLevelMesh(descriptor: desc) else { return }
            mesh = m
            signature = sig
        }
        guard let mesh else { return }
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { raw in
            let v = raw.bindMemory(to: RFVertex.self)
            var k = 0
            for s in surfaces {
                let hasT = s.tangents.count == s.vertexCount
                for i in 0..<s.vertexCount {
                    let n = s.normals[i]
                    let t4 = hasT ? s.tangents[i] : V4(n.anyPerpendicular, 1)
                    let t = SIMD3(t4.x, t4.y, t4.z)
                    v[k] = RFVertex(s.positions[i], n, t, simd_cross(n, t) * t4.w, s.uvs[i], SIMD2(0, s.occlusion[i]), 0)
                    k += 1
                }
            }
        }
        var parts: [LowLevelMesh.Part] = []
        mesh.withUnsafeMutableIndices { raw in
            let idx = raw.bindMemory(to: UInt32.self)
            var base: UInt32 = 0, k = 0
            for (pi, s) in surfaces.enumerated() {
                let start = k
                for i in s.indices { idx[k] = i + base; k += 1 }
                let b = s.bounds
                parts.append(LowLevelMesh.Part(indexOffset: start * 4, indexCount: s.indices.count, topology: .triangle,
                                               materialIndex: pi, bounds: BoundingBox(min: b.min, max: b.max)))
                base += UInt32(s.vertexCount)
            }
        }
        mesh.parts.replaceAll(parts)
        if rebuild, let res = try? MeshResource(from: mesh) {
            entity.model = ModelComponent(mesh: res, materials: materials)
        }
    }
}

/// Radiograph-style see-through material: unlit, brightest where the surface turns away from the
/// viewer, as projected cortical bone is brightest at its edges on an x-ray.
public enum RealXray {
    public struct Look: Sendable {
        public var tint: SIMD3<Float>
        public var core: Float, rim: Float, power: Float, opacity: Float
        public static let bone = Look(tint: SIMD3(0.78, 0.9, 1.0), core: 0.16, rim: 1.15, power: 2.2, opacity: 0.9)
        public static let flesh = Look(tint: SIMD3(0.3, 0.5, 0.78), core: 0.025, rim: 0.42, power: 3.2, opacity: 0.55)
        public init(tint: SIMD3<Float>, core: Float, rim: Float, power: Float, opacity: Float) {
            self.tint = tint; self.core = core; self.rim = rim; self.power = power; self.opacity = opacity
        }
    }

    static func usda() -> String {
        let name = "Xray"
        var g = USDAGraph(material: name)
        let wn = g.node("ND_normal_vector3", [("string", "space", "\"world\"")], out: "float3")
        let vd = g.node("ND_realitykit_viewdirection_vector3", [], out: "float3")
        let c = g.node("ND_absval_float", [("float", "in", g.node("ND_dotproduct_vector3", [("float3", "in1", wn), ("float3", "in2", vd)], out: "float"))], out: "float")
        let m = g.add("1", g.mul(g.node("ND_min_float", [("float", "in1", c), ("float", "in2", "1")], out: "float"), "-1"))
        let rim = g.node("ND_power_float", [("float", "in1", m), ("float", "in2", g.param("Power"))], out: "float")
        let intensity = g.add(g.param("Core"), g.mul(rim, g.param("Rim")))
        let color = g.node("ND_multiply_color3FA", [("color3f", "in1", g.param("Tint")), ("float", "in2", intensity)], out: "color3f")
        let op = g.node("ND_clamp_float", [("float", "in", g.mul(intensity, g.param("OpacityScale"))), ("float", "low", "0"), ("float", "high", "1")], out: "float")
        let surface = g.node("ND_realitykit_unlit_surfaceshader", [("color3f", "color", color), ("float", "opacity", op),
                                                                   ("bool", "applyPostProcessToneMap", "0"), ("bool", "hasPremultipliedAlpha", "0")], out: "token")
        return """
        #usda 1.0
        (
            defaultPrim = "Root"
            metersPerUnit = 1
            upAxis = "Y"
        )

        def Xform "Root"
        {
            def Material "\(name)"
            {
                color3f inputs:Tint = (0.8, 0.9, 1)
                float inputs:Core = 0.15
                float inputs:Rim = 1
                float inputs:Power = 2
                float inputs:OpacityScale = 0.9
                token outputs:mtlx:surface.connect = \(surface)

        """ + "\n" + g.body + "    }\n}\n"
    }

    @MainActor private static var template: ShaderGraphMaterial?

    @MainActor public static func material(_ look: Look) async throws -> ShaderGraphMaterial {
        if template == nil { template = try await ShaderGraphMaterial(named: "/Root/Xray", from: Data(usda().utf8)) }
        var m = template!
        try m.setParameter(name: "Tint", value: .color(cgLinear(look.tint)))
        try m.setParameter(name: "Core", value: .float(look.core))
        try m.setParameter(name: "Rim", value: .float(look.rim))
        try m.setParameter(name: "Power", value: .float(look.power))
        try m.setParameter(name: "OpacityScale", value: .float(look.opacity))
        m.writesDepth = false
        m.faceCulling = .back
        return m
    }
}
