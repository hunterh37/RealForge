import Foundation
import Metal
import CoreGraphics
import RealityKit
import RealCore
import RealMaterials

/// Global wind + sun parameters baked into ShaderGraph materials at creation.
@MainActor
public enum RealWind {
    public static var direction: SIMD3<Float> = simd_normalize(SIMD3(0.8, 0, 0.6))
    public static var speed: Float = 1.3
    /// Multiplier on every material's wind amplitude (0 freezes foliage, saves nothing on GPU).
    public static var strength: Float = 1
    /// Direction light travels (sun -> scene). Set by RealEnvironment.
    public static var sunTravel: SIMD3<Float> = SIMD3(0, -1, 0)
}

/// Aerial perspective applied by every ShaderGraph material (set by RealEnvironment from the sky).
@MainActor
public enum RealAtmosphere {
    /// Linear RGB haze color (emissive units).
    public static var fogColor: SIMD3<Float> = SIMD3(0.55, 0.6, 0.66)
    /// Extinction per meter. 0.008 = light haze at 100 m; 0 disables.
    public static var fogDensity: Float = 0.008
}

/// GPU-resident textures of one material, shared by its PBR and ShaderGraph variants.
@MainActor
public struct RealTextures {
    public var albedo: TextureResource
    public var normal: TextureResource
    public var roughness: TextureResource
    public var ao: TextureResource?
    public var metallic: TextureResource?
    let backing: [LowLevelTexture]
}

/// One material per key, process-wide. Textures are synthesized on the GPU straight into
/// LowLevelTextures (no CPU copy, no bundle assets), mipmapped, and shared by every entity using the key.
///
/// - `material(_:)` returns a PhysicallyBasedMaterial immediately (static assets, previews).
/// - `materialAsync(_:)` returns a ShaderGraphMaterial with vertex wind + leaf translucency when the
///   spec asks for it, falling back to PBR.
@MainActor
public final class RealMaterialCache {
    public static let shared = RealMaterialCache()

    private var pbr: [MaterialKey: any RealityKit.Material] = [:]
    private var graph: [MaterialKey: any RealityKit.Material] = [:]
    private var tex: [MaterialKey: RealTextures] = [:]
    /// Approximate GPU bytes held by generated textures (mips included).
    public private(set) var textureBytes: Int = 0
    public var overrides: [MaterialKey: MaterialSpec] = [:]
    /// Set false to force PhysicallyBasedMaterial everywhere (no wind, no translucency).
    public var useShaderGraph = true

    public init() {}

    public func spec(_ key: MaterialKey) -> MaterialSpec { overrides[key] ?? MaterialLibrary.spec(for: key) }

    public func material(_ key: MaterialKey) -> any RealityKit.Material {
        if let m = graph[key] ?? pbr[key] { return m }
        let m = (try? buildPBR(spec(key))) ?? SimpleMaterial(color: .gray, isMetallic: false)
        pbr[key] = m
        return m
    }

    public func materialAsync(_ key: MaterialKey) async -> any RealityKit.Material {
        if let m = graph[key] { return m }
        let s = spec(key)
        guard useShaderGraph, s.program != nil else { return material(key) }
        do {
            let m = try await buildGraph(s)
            graph[key] = m
            return m
        } catch {
            return material(key)
        }
    }

    /// Pre-generate (e.g. behind a loading state) so first frames don't hitch.
    public func warm(_ keys: [MaterialKey]) async { for k in keys { _ = await materialAsync(k) } }

    public func purge() { pbr.removeAll(); graph.removeAll(); tex.removeAll(); textureBytes = 0 }

    // MARK: textures

    private func lowLevel(_ fmt: MTLPixelFormat, _ n: Int) throws -> LowLevelTexture {
        try LowLevelTexture(descriptor: .init(textureType: .type2D, pixelFormat: fmt, width: n, height: n,
                                              mipmapLevelCount: TextureSynth.mipCount(n), textureUsage: [.shaderRead, .shaderWrite]))
    }

    public func textures(_ s: MaterialSpec) throws -> RealTextures? {
        if let t = tex[s.key] { return t }
        guard let synth = TextureSynth.shared, s.program != nil else { return nil }
        let n = RealQuality.pixels(for: s)
        let albedo = try lowLevel(.rgba8Unorm_srgb, n), normal = try lowLevel(.rgba8Unorm, n), rough = try lowLevel(.r8Unorm, n)
        let ao = s.hasAOMap ? try lowLevel(.r8Unorm, n) : nil
        let metal = s.hasMetallicMap ? try lowLevel(.r8Unorm, n) : nil
        guard let cb = synth.queue.makeCommandBuffer() else { throw TextureSynth.SynthError.encode }
        let set = TextureSet(albedo: albedo.replace(using: cb), normal: normal.replace(using: cb), roughness: rough.replace(using: cb),
                             ao: ao?.replace(using: cb), metallic: metal?.replace(using: cb))
        try synth.encode(s, into: set, commandBuffer: cb)
        cb.commit()
        let all = [albedo, normal, rough] + [ao, metal].compactMap { $0 }
        textureBytes += all.reduce(0) { acc, t in
            acc + t.descriptor.width * t.descriptor.height * (t.descriptor.pixelFormat == .r8Unorm ? 1 : 4) * 4 / 3
        }
        let t = RealTextures(albedo: try TextureResource(from: albedo), normal: try TextureResource(from: normal),
                             roughness: try TextureResource(from: rough), ao: try ao.map { try TextureResource(from: $0) },
                             metallic: try metal.map { try TextureResource(from: $0) }, backing: all)
        tex[s.key] = t
        return t
    }

    // MARK: builders

    private func buildPBR(_ s: MaterialSpec) throws -> any RealityKit.Material {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: .init(s.baseColor))
        m.roughness = .init(floatLiteral: s.roughness)
        m.metallic = .init(floatLiteral: s.metallic)
        m.specular = .init(floatLiteral: s.specular)
        if s.clearcoat > 0 { m.clearcoat = .init(floatLiteral: s.clearcoat) }
        if s.twoSided { m.faceCulling = .none }
        if s.mode == .emissive {
            m.emissiveColor = .init(color: .init(s.emissive))
            m.emissiveIntensity = s.emissiveIntensity
        }
        if let t = try textures(s) {
            m.baseColor = .init(tint: .white, texture: .init(t.albedo))
            m.normal = .init(texture: .init(t.normal))
            m.roughness = .init(scale: 1, texture: .init(t.roughness))
            if let ao = t.ao { m.ambientOcclusion = .init(texture: .init(ao)) }
            if let mt = t.metallic { m.metallic = .init(scale: 1, texture: .init(mt)) }
            if s.mode == .cutout {
                m.blending = .transparent(opacity: .init(scale: 1, texture: .init(t.albedo)))
                m.opacityThreshold = 0.5
            }
            if s.tileSize > 0 { m.textureCoordinateTransform = .init(scale: SIMD2(repeating: 1 / s.tileSize)) }
        }
        return m
    }

    private func buildGraph(_ s: MaterialSpec) async throws -> any RealityKit.Material {
        guard let t = try textures(s) else { throw TextureSynth.SynthError.encode }
        var o = RealShaderOptions()
        o.cutout = s.mode == .cutout; o.aoMap = t.ao != nil; o.metallicMap = t.metallic != nil
        o.wind = s.wind > 0; o.translucency = s.translucency > 0; o.antiTile = s.antiTile
        o.topLayer = s.topAmount > 0; o.fog = RealAtmosphere.fogDensity > 0
        var m = try await RealShaderGraph.material(o)
        try m.setParameter(name: "BaseColor", value: .textureResource(t.albedo))
        try m.setParameter(name: "Normal", value: .textureResource(t.normal))
        try m.setParameter(name: "Roughness", value: .textureResource(t.roughness))
        if let ao = t.ao { try m.setParameter(name: "AO", value: .textureResource(ao)) }
        if let mt = t.metallic { try m.setParameter(name: "Metallic", value: .textureResource(mt)) }
        try m.setParameter(name: "UVScale", value: .float(s.tileSize > 0 ? 1 / s.tileSize : 1))
        try m.setParameter(name: "Specular", value: .float(s.specular))
        try m.setParameter(name: "WindStrength", value: .float(s.wind * RealWind.strength))
        try m.setParameter(name: "WindSpeed", value: .float(RealWind.speed))
        try m.setParameter(name: "WindDirection", value: .simd3Float(RealWind.direction))
        try m.setParameter(name: "SunDirection", value: .simd3Float(RealWind.sunTravel))
        try m.setParameter(name: "Translucency", value: .float(s.translucency))
        if o.fog {
            try m.setParameter(name: "FogDensity", value: .float(RealAtmosphere.fogDensity))
            try m.setParameter(name: "FogColor", value: .color(cgLinear(RealAtmosphere.fogColor)))
        }
        if o.topLayer {
            try m.setParameter(name: "TopColor", value: .color(cgLinear(SIMD3(s.topColor.x, s.topColor.y, s.topColor.z))))
            try m.setParameter(name: "TopAmount", value: .float(s.topAmount))
            try m.setParameter(name: "TopLow", value: .float(s.topLow))
        }
        if s.twoSided { m.faceCulling = .none }
        return m
    }
}

extension RealityKit.Material.Color {
    /// From linear RGB (specs store linear values).
    convenience init(_ v: SIMD3<Float>) {
        let cg = CGColor(colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!, components: [CGFloat(v.x), CGFloat(v.y), CGFloat(v.z), 1])!
        #if canImport(UIKit)
        self.init(cgColor: cg)
        #else
        self.init(cgColor: cg)!
        #endif
    }
}

public extension Model {
    /// Async variant: foliage/bark get ShaderGraph wind materials.
    @MainActor
    func modelEntityAsync(materials: RealMaterialCache? = nil) async throws -> ModelEntity {
        let cache = materials ?? .shared
        let keys = self.surfaces.filter { !$0.isEmpty }.map(\.material)
        var mats: [any RealityKit.Material] = []
        for k in keys { mats.append(await cache.materialAsync(k)) }
        let e = ModelEntity(mesh: try meshResource(), materials: mats)
        e.name = name
        return e
    }
}

func cgLinear(_ v: SIMD3<Float>) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!, components: [CGFloat(v.x), CGFloat(v.y), CGFloat(v.z), 1])!
}
