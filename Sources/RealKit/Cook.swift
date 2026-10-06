import Foundation
import RealityKit
import RealCore
import RealMaterials

/// Cookable, sliceable food on a `ModelEntity` (RealityHD 6). Holds the CPU mesh so the piece can be
/// cut again, the cap recipe for cut faces, and the heat state that drives the cook shader.
public struct RealFoodComponent: Component, Sendable {
    /// LOD 0 in entity space (origin at the piece's bounds center).
    public var model: Model
    public var kind: Cook.Kind
    /// Cut-face fill per surface material (nil entry = leave open).
    public var caps: [MaterialKey: SliceCap]
    /// Materials that are cut faces: they show core doneness instead of surface doneness.
    public var interior: Set<MaterialKey>
    public var thermal: FoodThermal
    /// kg/m^3 (meat ~1050, onion ~950, carrot ~1030).
    public var density: Float
    /// Times this lineage has been cut.
    public var cuts: Int = 0
    /// Name of the source asset (`chicken-breast`).
    public var source: String
    /// Fat coating from the pan (0...1): glossier surface.
    public var oil: Float = 0

    public init(model: Model, kind: Cook.Kind, caps: [MaterialKey: SliceCap], source: String, density: Float = 1030, temperature: Float = 4) {
        self.model = model; self.kind = kind; self.caps = caps; self.source = source; self.density = density
        interior = Set(caps.values.map(\.material))
        let b = model.bounds
        thermal = FoodThermal(profile: Cook.profile(kind), extent: b.max - b.min, temperature: temperature)
    }

    /// Mass in kg from the closed mesh volume.
    public var mass: Float { max(0.001, model.volume * density) }
}

@MainActor
public enum RealCook {
    /// Registers components. Called by `RealKitSetup.register()`.
    public static func register() { RealFoodComponent.registerComponent() }

    /// Builds a cookable, physical food entity from a closed LOD0 model. The model is recentered on its
    /// bounds center; `offset` returns that shift so callers can keep the asset's resting position.
    public static func food(_ model: Model, kind: Cook.Kind, caps: [MaterialKey: SliceCap], source: String,
                            density: Float = 1030, physics: Bool = true) async throws -> ModelEntity {
        let b = model.bounds
        let c = (b.min + b.max) / 2
        let centered = model.transformed(Xform(translation: -c))
        var shifted: [MaterialKey: SliceCap] = [:]
        for (k, v) in caps { var v = v; v.origin -= c; shifted[k] = v }
        let comp = RealFoodComponent(model: centered, kind: kind, caps: shifted, source: source, density: density)
        let e = try await entity(comp, physics: physics)
        e.position = c
        return e
    }

    /// Entity for an existing food state (used after cuts).
    static func entity(_ comp: RealFoodComponent, physics: Bool) async throws -> ModelEntity {
        let m = comp.model.finalized()
        let surfaces = m.surfaces.filter { !$0.isEmpty }
        var mats: [any RealityKit.Material] = []
        for s in surfaces { mats.append(await RealMaterialCache.shared.cookMaterialAsync(s.material)) }
        let e = ModelEntity(mesh: try await MeshResource(from: try m.lowLevelMesh()), materials: mats)
        e.name = comp.source
        e.components.set(comp)
        if physics { e.realFoodPhysics() }
        e.components.set(InputTargetComponent())
        e.realApplyCook()
        return e
    }

    /// Cut-face recipe from a food asset's cap materials and core center (asset space).
    public static func caps(for model: Model, coreCenter: V3, capMaterial: (MaterialKey) -> MaterialKey?) -> [MaterialKey: SliceCap] {
        var out: [MaterialKey: SliceCap] = [:]
        for s in model.surfaces {
            guard let cm = capMaterial(s.material) else { continue }
            let tile = MaterialLibrary.spec(for: cm).tileSize
            out[s.material] = SliceCap(material: cm, origin: coreCenter, uvOffset: V2(repeating: tile > 0 ? tile / 2 : 0.5))
        }
        return out
    }
}

public extension ModelEntity {
    /// Collision from the convex hull and a dynamic body with mass from the mesh volume.
    func realFoodPhysics() {
        guard let f = components[RealFoodComponent.self] else { return }
        let pts = f.model.surfaces.flatMap(\.positions)
        let hull = pts.count >= 4 ? ShapeResource.generateConvex(from: Self.hullSample(pts)) : ShapeResource.generateBox(size: SIMD3(repeating: 0.01))
        components.set(CollisionComponent(shapes: [hull], mode: .default, filter: .default))
        let mat = PhysicsMaterialResource.generate(staticFriction: 0.85, dynamicFriction: 0.7, restitution: 0.02)
        var body = PhysicsBodyComponent(shapes: [hull], mass: f.mass, material: mat, mode: .dynamic)
        body.linearDamping = 0.6
        body.angularDamping = 1.2
        components.set(body)
    }

    /// Hull input capped at 256 points (stride over the mesh) to keep generation fast on device.
    static func hullSample(_ p: [V3]) -> [SIMD3<Float>] {
        guard p.count > 256 else { return p }
        let step = Double(p.count) / 256
        return (0..<256).map { p[Int(Double($0) * step)] }
    }

    /// Pushes the heat state into the cook shader: outer surfaces show surface doneness, cut faces core
    /// doneness; browning per object-space face; oil sheen.
    func realApplyCook() {
        guard let f = components[RealFoodComponent.self], var mc = model else { return }
        let th = f.thermal
        let surfaces = f.model.surfaces.filter { !$0.isEmpty }
        var changed = false
        for i in mc.materials.indices where i < surfaces.count {
            guard var g = mc.materials[i] as? ShaderGraphMaterial else { continue }
            let inside = f.interior.contains(surfaces[i].material)
            let d = inside ? th.coreDoneness : th.surfaceDoneness
            // Cut faces only brown where they met the pan; their face weights pick that up as well.
            try? g.setParameter(name: "Doneness", value: .float(d))
            try? g.setParameter(name: "BrownPos", value: .simd3Float(th.browningPos))
            try? g.setParameter(name: "BrownNeg", value: .simd3Float(th.browningNeg))
            try? g.setParameter(name: "Oil", value: .float(f.oil))
            mc.materials[i] = g
            changed = true
        }
        if changed { model = mc }
    }

    /// Cuts this food entity with a world-space plane. Returns the two pieces (already parented where
    /// this entity was, nudged 1.5 mm apart, with split heat state) and removes this entity, or nil when
    /// the plane misses or a piece would be a sliver under `minVolume` m^3.
    @discardableResult
    func realSlice(_ worldPlane: SlicePlane, minVolume: Float = 2e-7) async throws -> (ModelEntity, ModelEntity)? {
        guard let f = components[RealFoodComponent.self] else { return nil }
        let toLocal = transformMatrix(relativeTo: nil).inverse
        let local = worldPlane.transformed(toLocal)
        let (a, b) = f.model.sliced(by: local) { f.caps[$0] }
        guard !a.surfaces.isEmpty, !b.surfaces.isEmpty, a.volume > minVolume, b.volume > minVolume else { return nil }
        let wasPhysical = components.has(PhysicsBodyComponent.self)
        var out: [ModelEntity] = []
        for (half, sign) in [(a, Float(-1)), (b, Float(1))] {
            let bb = half.bounds
            let c = (bb.min + bb.max) / 2
            var comp = f
            comp.model = half.transformed(Xform(translation: -c))
            comp.caps = f.caps.mapValues { var v = $0; v.origin -= c; return v }
            comp.interior = f.interior
            comp.cuts = f.cuts + 1
            comp.thermal = f.thermal.piece(extent: bb.max - bb.min)
            let e = try await RealCook.entity(comp, physics: wasPhysical)
            e.name = name
            let nudge = local.normal * (0.0015 * sign)
            e.transform = Transform(matrix: transformMatrix(relativeTo: parent) * Transform(translation: c + nudge).matrix)
            parent?.addChild(e)
            out.append(e)
        }
        removeFromParent()
        return (out[0], out[1])
    }
}

public extension RealCook {
    /// Liquid or batter surface inside a round vessel: a shallow lens of radius 1 m and thickness
    /// 2 cm at the origin; scale X/Z to the vessel's inner radius at the fill height and place it there.
    /// Cook-shader material, so batter and sauces can set and brown.
    static func fill(material: MaterialKey, segments: Int = 40) async throws -> ModelEntity {
        var s = Prim.superellipsoid(V3(2, 0.02, 2), exponent: 3.2, subdivisions: max(8, segments / 4), material: material)
        s.finalize()
        var m = Model(name: "fill")
        m.add(s)
        let e = ModelEntity(mesh: try await MeshResource(from: try m.lowLevelMesh()), materials: [await RealMaterialCache.shared.cookMaterialAsync(material)])
        e.name = "fill"
        return e
    }
}
