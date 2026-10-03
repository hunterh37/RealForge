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
    /// Texture sets loaded from `RealTextureDiskCache` vs generated on the GPU (since launch).
    public private(set) var diskHits = 0, synthesized = 0
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
        guard useShaderGraph, s.program != nil, s.mode != .emissive else { return material(key) }
        do {
            let m = try await buildGraph(s)
            graph[key] = m
            return m
        } catch {
            return material(key)
        }
    }

    /// ShaderGraph material with per-instance hue/value jitter (instanced fields). Shares textures
    /// with the plain variant. Falls back to the plain material when ShaderGraph is off.
    /// - Parameters: hue: max hue shift in turns (0.02 = 7 degrees); value: max relative brightness change.
    public func materialAsync(_ key: MaterialKey, hueJitter hue: Float, valueJitter value: Float) async -> any RealityKit.Material {
        guard hue > 0 || value > 0 else { return await materialAsync(key) }
        let vk = "\(key)#jitter\(hue),\(value)"
        if let m = graph[vk] { return m }
        let s = spec(key)
        guard useShaderGraph, s.program != nil, s.mode != .emissive else { return material(key) }
        do {
            let m = try await buildGraph(s, jitter: SIMD2(hue, value))
            graph[vk] = m
            return m
        } catch {
            return material(key)
        }
    }

    /// PhysicallyBasedMaterial copies with the base color scaled by `value` (PBR fallback for jitter).
    public func material(_ key: MaterialKey, brightness value: Float) -> any RealityKit.Material {
        let base = material(key)
        guard value != 1, var m = base as? PhysicallyBasedMaterial else { return base }
        m.baseColor.tint = .init(SIMD3(repeating: value) * spec(key).baseColorTintBase(textured: m.baseColor.texture != nil))
        return m
    }

    /// Pre-generate (e.g. behind a loading state) so first frames don't hitch.
    public func warm(_ keys: [MaterialKey]) async { for k in keys { _ = await materialAsync(k) } }

    /// Blocks until all queued texture work has finished on the GPU (benchmarks).
    public func waitForGPU() {
        guard let cb = TextureSynth.shared?.queue.makeCommandBuffer() else { return }
        cb.commit(); cb.waitUntilCompleted()
    }

    public func purge() { pbr.removeAll(); graph.removeAll(); tex.removeAll(); alphaViews.removeAll(); alphaBacking.removeAll(); textureBytes = 0 }

    // MARK: textures

    private func lowLevel(_ fmt: MTLPixelFormat, _ n: Int, swizzle: MTLTextureSwizzleChannels? = nil) throws -> LowLevelTexture {
        // Swizzled textures can't be shader-writable; they are filled by blit copy instead.
        try LowLevelTexture(descriptor: .init(textureType: .type2D, pixelFormat: fmt, width: n, height: n,
                                              mipmapLevelCount: TextureSynth.mipCount(n),
                                              textureUsage: swizzle == nil ? [.shaderRead, .shaderWrite] : [.shaderRead],
                                              swizzle: swizzle ?? .init(red: .red, green: .green, blue: .blue, alpha: .alpha)))
    }

    public func textures(_ s: MaterialSpec) throws -> RealTextures? {
        if let t = tex[s.key] { return t }
        guard let synth = TextureSynth.shared, s.program != nil else { return nil }
        let n = RealQuality.pixels(for: s)
        // Normals stored as RG8 (half the memory of RGBA8); blue reads as 1 and shaders renormalize.
        let albedo = try lowLevel(.rgba8Unorm_srgb, n), normal = try lowLevel(.rg8Unorm, n, swizzle: .init(red: .red, green: .green, blue: .one, alpha: .one)), rough = try lowLevel(.r8Unorm, n)
        let ao = s.hasAOMap ? try lowLevel(.r8Unorm, n) : nil
        let metal = s.hasMetallicMap ? try lowLevel(.r8Unorm, n) : nil
        guard let cb = synth.queue.makeCommandBuffer() else { throw TextureSynth.SynthError.encode }
        let dAlbedo = albedo.replace(using: cb), dNormal = normal.replace(using: cb), dRough = rough.replace(using: cb)
        let dAO = ao?.replace(using: cb), dMetal = metal?.replace(using: cb)
        let targets = [dAlbedo, dNormal, dRough] + [dAO, dMetal].compactMap { $0 }
        if let cached = RealTextureDiskCache.load(s, n: n),
           RealTextureDiskCache.encodeLoad(cached, s, n: n, into: targets, device: synth.device, commandBuffer: cb) {
            diskHits += 1
        } else {
            let scratchNormal = synth.makeTexture(.rg8Unorm, n)
            let set = TextureSet(albedo: dAlbedo, normal: scratchNormal, roughness: dRough, ao: dAO, metallic: dMetal)
            try synth.encode(s, into: set, commandBuffer: cb)
            if let blit = cb.makeBlitCommandEncoder() {
                for level in 0..<scratchNormal.mipmapLevelCount {
                    let w = max(1, n >> level)
                    blit.copy(from: scratchNormal, sourceSlice: 0, sourceLevel: level, sourceOrigin: MTLOrigin(), sourceSize: MTLSize(width: w, height: w, depth: 1),
                              to: dNormal, destinationSlice: 0, destinationLevel: level, destinationOrigin: MTLOrigin())
                }
                blit.endEncoding()
            }
            RealTextureDiskCache.encodeStore(s, n: n, textures: [dAlbedo, scratchNormal, dRough] + [dAO, dMetal].compactMap { $0 },
                                             device: synth.device, commandBuffer: cb)
            synthesized += 1
        }
        cb.commit()
        let all = [albedo, normal, rough] + [ao, metal].compactMap { $0 }
        textureBytes += all.reduce(0) { acc, t in
            acc + t.descriptor.width * t.descriptor.height * (t.descriptor.pixelFormat == .r8Unorm ? 1 : t.descriptor.pixelFormat == .rg8Unorm ? 2 : 4) * 4 / 3
        }
        let t = RealTextures(albedo: try TextureResource(from: albedo), normal: try TextureResource(from: normal),
                             roughness: try TextureResource(from: rough), ao: try ao.map { try TextureResource(from: $0) },
                             metallic: try metal.map { try TextureResource(from: $0) }, backing: all)
        tex[s.key] = t
        return t
    }

    /// Albedo copy swizzled to (a, a, a, a), for the PBR opacity slot. Cached by texture identity.
    private var alphaViews: [ObjectIdentifier: TextureResource] = [:]
    private func alphaView(_ t: RealTextures) throws -> TextureResource {
        let src = t.backing[0]
        if let r = alphaViews[ObjectIdentifier(src)] { return r }
        guard let synth = TextureSynth.shared, let cb = synth.queue.makeCommandBuffer() else { throw TextureSynth.SynthError.encode }
        let n = src.descriptor.width
        let dst = try lowLevel(src.descriptor.pixelFormat, n, swizzle: .init(red: .alpha, green: .alpha, blue: .alpha, alpha: .alpha))
        guard let blit = cb.makeBlitCommandEncoder() else { throw TextureSynth.SynthError.encode }
        let from = src.read(), to = dst.replace(using: cb)
        for level in 0..<from.mipmapLevelCount {
            let w = max(1, n >> level)
            blit.copy(from: from, sourceSlice: 0, sourceLevel: level, sourceOrigin: MTLOrigin(), sourceSize: MTLSize(width: w, height: w, depth: 1),
                      to: to, destinationSlice: 0, destinationLevel: level, destinationOrigin: MTLOrigin())
        }
        blit.endEncoding()
        cb.commit()
        let r = try TextureResource(from: dst)
        alphaViews[ObjectIdentifier(src)] = r
        alphaBacking.append(dst)
        textureBytes += n * n * 4 * 4 / 3
        return r
    }
    private var alphaBacking: [LowLevelTexture] = []

    // MARK: builders

    private func buildPBR(_ s: MaterialSpec) throws -> any RealityKit.Material {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: .init(s.baseColor))
        m.roughness = .init(floatLiteral: s.roughness)
        m.metallic = .init(floatLiteral: s.metallic)
        m.specular = .init(floatLiteral: s.specular)
        if s.clearcoat > 0 { m.clearcoat = .init(floatLiteral: s.clearcoat) }
        if s.twoSided { m.faceCulling = .none }
        if s.mode == .transparent { m.blending = .transparent(opacity: .init(floatLiteral: s.opacity)) }
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
                // PhysicallyBasedMaterial reads opacity from the red channel: give it a copy of the albedo
                // whose swizzle routes alpha to every channel.
                let a = (try? alphaView(t)).map { MaterialParameters.Texture($0) } ?? .init(t.albedo)
                m.blending = .transparent(opacity: .init(scale: 1, texture: a))
                m.opacityThreshold = 0.5
            }
            // PhysicallyBasedMaterial samples with v flipped relative to ShaderGraph texcoords; flip back
            // so atlases (foliage cards) stand upright and tiled maps match the ShaderGraph path.
            let k: Float = s.tileSize > 0 ? 1 / s.tileSize : 1
            m.textureCoordinateTransform = .init(offset: SIMD2(0, s.tileSize > 0 ? 0 : 1), scale: SIMD2(k, -k))
        }
        return m
    }

    private func buildGraph(_ s: MaterialSpec, jitter: SIMD2<Float> = .zero) async throws -> any RealityKit.Material {
        guard let t = try textures(s) else { throw TextureSynth.SynthError.encode }
        var o = RealShaderOptions()
        o.cutout = s.mode == .cutout; o.aoMap = t.ao != nil; o.metallicMap = t.metallic != nil
        o.wind = s.wind > 0; o.translucency = s.translucency > 0; o.antiTile = s.antiTile
        o.topLayer = s.topAmount > 0; o.fog = RealAtmosphere.fogDensity > 0; o.triplanar = s.triplanar
        o.instanceJitter = jitter != .zero
        o.transparent = s.mode == .transparent
        o.flowNormals = s.mode == .transparent && s.flow > 0
        let splatSpec = s.splat.map { spec($0) }
        let t2 = try splatSpec.flatMap { try textures($0) }
        o.splat = t2 != nil
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
        if o.transparent {
            try m.setParameter(name: "Opacity", value: .float(s.opacity))
            try m.setParameter(name: "ShallowColor", value: .color(cgLinear(SIMD3(s.colorB.x, s.colorB.y, s.colorB.z))))
            try m.setParameter(name: "Flow", value: .float(s.flow))
        }
        if let t2, let splatSpec {
            try m.setParameter(name: "BaseColor2", value: .textureResource(t2.albedo))
            try m.setParameter(name: "Normal2", value: .textureResource(t2.normal))
            try m.setParameter(name: "Roughness2", value: .textureResource(t2.roughness))
            try m.setParameter(name: "UVScale2", value: .float(splatSpec.tileSize > 0 ? 1 / splatSpec.tileSize : 1))
            try m.setParameter(name: "SplatSoftness", value: .float(max(0.01, s.splatSoftness)))
            try m.setParameter(name: "SplatHeight", value: .float(s.splatHeight))
        }
        if o.instanceJitter {
            try m.setParameter(name: "HueJitter", value: .float(jitter.x))
            try m.setParameter(name: "ValueJitter", value: .float(jitter.y))
        }
        if s.twoSided { m.faceCulling = .none }
        return m
    }
}

extension MaterialSpec {
    /// Linear tint the PBR builder puts on the base color (white when textured).
    func baseColorTintBase(textured: Bool) -> SIMD3<Float> { textured ? SIMD3(repeating: 1) : baseColor }
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
