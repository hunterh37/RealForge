import Foundation
import Metal
import CoreGraphics
import simd
import RealCore
import CryptoKit

/// Global quality knobs. Set once at app start, before building materials.
public enum RealQuality {
    /// Multiplier on every material's base resolution (1024 -> 512 at 0.5). Clamped to 128...4096.
    nonisolated(unsafe) public static var textureScale: Float = 1
    /// Upper bound on any generated texture side.
    nonisolated(unsafe) public static var maxTextureSize: Int = 1024

    public enum Preset: Sendable { case performance, balanced, ultra }
    /// performance: 512 max (~25 MB for a full forest). balanced: 1024 (default). ultra: 2048 ground/bark.
    public static func apply(_ p: Preset) {
        switch p {
        case .performance: textureScale = 0.5; maxTextureSize = 512
        case .balanced: textureScale = 1; maxTextureSize = 1024
        case .ultra: textureScale = 1; maxTextureSize = 2048
        }
    }
    public static func pixels(for spec: MaterialSpec) -> Int {
        let raw = Float(spec.resolution) * textureScale
        var p = 128
        while p * 2 <= Int(raw) && p * 2 <= maxTextureSize { p *= 2 }
        return p
    }
}

/// Textures for one material. Albedo is RGBA8 sRGB (alpha used by cutout foliage); others are R8/RGBA8.
public struct TextureSet {
    public var albedo: MTLTexture
    public var normal: MTLTexture
    public var roughness: MTLTexture
    public var ao: MTLTexture?
    public var metallic: MTLTexture?
    public init(albedo: MTLTexture, normal: MTLTexture, roughness: MTLTexture, ao: MTLTexture?, metallic: MTLTexture?) {
        self.albedo = albedo; self.normal = normal; self.roughness = roughness; self.ao = ao; self.metallic = metallic
    }
}

struct RFParams {
    var kind: Int32; var seed: UInt32; var size: Int32; var alphaMode: Int32
    var colorA: SIMD4<Float>; var colorB: SIMD4<Float>; var colorC: SIMD4<Float>
    var f: SIMD4<Float>
    var normalStrength: Float; var flipGreen: Float; var pad0: Float = 0; var pad1: Float = 0
}

public struct SkyParams {
    public var sunDir: SIMD3<Float>
    public var sunIntensity: Float
    public var turbidity: Float
    public var groundAlbedo: Float
    public var width: Int32
    public var height: Int32
    public var drawSun: Int32
    public var exposure: Float
    var pad0: Float = 0, pad1: Float = 0
    public init(sunDir: SIMD3<Float>, sunIntensity: Float = 22, turbidity: Float = 2, groundAlbedo: Float = 1,
                width: Int = 1024, drawSun: Bool, exposure: Float = 1) {
        self.sunDir = simd_normalize(sunDir); self.sunIntensity = sunIntensity; self.turbidity = turbidity
        self.groundAlbedo = groundAlbedo; self.width = Int32(width); self.height = Int32(width / 2)
        self.drawSun = drawSun ? 1 : 0; self.exposure = exposure
    }
}

/// Runtime-compiled Metal texture synthesis. Generating a 1024² PBR set takes ~1-3 ms of GPU time,
/// so assets ship as code (zero bytes of textures in the app bundle) and build on load.
public final class TextureSynth: @unchecked Sendable {
    public static let shared: TextureSynth? = try? TextureSynth()

    public let device: MTLDevice
    public let queue: MTLCommandQueue
    let material: MTLComputePipelineState
    let normal: MTLComputePipelineState
    let alphaDown: MTLComputePipelineState
    let alphaCount: MTLComputePipelineState
    let alphaApply: MTLComputePipelineState
    let sky: MTLComputePipelineState
    /// Normal-map green sign. Flip to -1 if bumps read inverted on a platform.
    nonisolated(unsafe) public static var flipGreen: Float = 1

    public init(device: MTLDevice? = MTLCreateSystemDefaultDevice()) throws {
        guard let device, let queue = device.makeCommandQueue() else { throw SynthError.noMetal }
        self.device = device; self.queue = queue
        let opts = MTLCompileOptions()
        opts.mathMode = .fast
        let lib = try device.makeLibrary(source: realityHDMetalSource, options: opts)
        func pipe(_ n: String) throws -> MTLComputePipelineState {
            guard let f = lib.makeFunction(name: n) else { throw SynthError.missingFunction(n) }
            return try device.makeComputePipelineState(function: f)
        }
        material = try pipe("rf_material"); normal = try pipe("rf_normal"); alphaDown = try pipe("rf_alpha_down"); alphaCount = try pipe("rf_alpha_count"); alphaApply = try pipe("rf_alpha_apply"); sky = try pipe("rf_sky")
    }

    public enum SynthError: Error { case noMetal, missingFunction(String), encode }

    /// SHA-256 of the Metal source: changes whenever any texture program changes (disk cache key).
    public static let sourceFingerprint: String = SHA256.hash(data: Data(realityHDMetalSource.utf8)).map { String(format: "%02x", $0) }.joined()

    // MARK: textures

    public static func mipCount(_ n: Int) -> Int { Int(log2(Double(n))) + 1 }

    public func makeTexture(_ fmt: MTLPixelFormat, _ n: Int, mips: Bool = true, storage: MTLStorageMode = .private) -> MTLTexture {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: fmt, width: n, height: n, mipmapped: mips)
        d.usage = [.shaderRead, .shaderWrite]
        d.storageMode = storage
        return device.makeTexture(descriptor: d)!
    }

    /// Allocates a set the caller owns (CLI dumps, tests). RealKit instead encodes into LowLevelTextures.
    public func makeSet(for spec: MaterialSpec, size n: Int) -> TextureSet {
        TextureSet(albedo: makeTexture(.rgba8Unorm_srgb, n), normal: makeTexture(.rg8Unorm, n), roughness: makeTexture(.r8Unorm, n),
                   ao: spec.hasAOMap ? makeTexture(.r8Unorm, n) : nil, metallic: spec.hasMetallicMap ? makeTexture(.r8Unorm, n) : nil)
    }

    /// Encode generation + mip chains for `spec` into `set` (all square, same size, mipmapped).
    public func encode(_ spec: MaterialSpec, into set: TextureSet, commandBuffer cb: MTLCommandBuffer) throws {
        guard let program = spec.program else { return }
        let n = set.albedo.width
        var p = RFParams(kind: program.rawValue, seed: spec.seed, size: Int32(n), alphaMode: spec.mode == .cutout || (spec.mode == .emissive && spec.opacity < 1) ? 1 : 0,
                         colorA: spec.colorA, colorB: spec.colorB, colorC: spec.colorC, f: spec.knobs,
                         normalStrength: spec.normalStrength, flipGreen: Self.flipGreen)
        let height = makeTexture(.r16Float, n, mips: false)
        let scratchR = spec.hasAOMap ? nil : makeTexture(.r8Unorm, n, mips: false)
        let scratchM = spec.hasMetallicMap ? nil : makeTexture(.r8Unorm, n, mips: false)
        guard let enc = cb.makeComputeCommandEncoder() else { throw SynthError.encode }
        enc.setComputePipelineState(material)
        enc.setTexture(set.albedo, index: 0); enc.setTexture(height, index: 1); enc.setTexture(set.roughness, index: 2)
        enc.setTexture(set.ao ?? scratchR, index: 3); enc.setTexture(set.metallic ?? scratchM, index: 4)
        enc.setBytes(&p, length: MemoryLayout<RFParams>.stride, index: 0)
        dispatch(enc, material, n, n)
        enc.setComputePipelineState(normal)
        enc.setTexture(height, index: 0); enc.setTexture(set.normal, index: 1)
        enc.setBytes(&p, length: MemoryLayout<RFParams>.stride, index: 0)
        dispatch(enc, normal, n, n)
        // Coverage-preserving alpha mips for cutout foliage.
        if spec.mode == .cutout && set.albedo.mipmapLevelCount > 1 {
            let levels = set.albedo.mipmapLevelCount
            // counts: per level 16 scale buckets; level 0 slot 16 holds its texel count.
            let stride = 17
            var zero = [UInt32](repeating: 0, count: levels * stride)
            zero[16] = UInt32(n * n)
            let counts = device.makeBuffer(bytes: &zero, length: zero.count * 4, options: .storageModeShared)!
            func view(_ l: Int) -> MTLTexture { set.albedo.makeTextureView(pixelFormat: set.albedo.pixelFormat, textureType: .type2D, levels: l..<(l + 1), slices: 0..<1)! }
            enc.setComputePipelineState(alphaCount)
            enc.setTexture(view(0), index: 0); enc.setBuffer(counts, offset: 0, index: 0)
            dispatch(enc, alphaCount, n, n)
            for level in 1..<levels {
                let src = view(level - 1), dst = view(level)
                enc.memoryBarrier(scope: .textures)
                enc.setComputePipelineState(alphaDown)
                enc.setTexture(src, index: 0); enc.setTexture(dst, index: 1)
                dispatch(enc, alphaDown, dst.width, dst.height)
                enc.memoryBarrier(scope: .textures)
                enc.setComputePipelineState(alphaCount)
                enc.setTexture(dst, index: 0); enc.setBuffer(counts, offset: level * stride * 4, index: 0)
                dispatch(enc, alphaCount, dst.width, dst.height)
                enc.memoryBarrier(scope: .buffers)
                enc.setComputePipelineState(alphaApply)
                enc.setTexture(dst, index: 0)
                enc.setBuffer(counts, offset: 0, index: 0); enc.setBuffer(counts, offset: level * stride * 4, index: 1)
                dispatch(enc, alphaApply, dst.width, dst.height)
            }
        }
        enc.endEncoding()
        guard let blit = cb.makeBlitCommandEncoder() else { throw SynthError.encode }
        var mipped = [set.normal, set.roughness] + [set.ao, set.metallic].compactMap { $0 }
        if spec.mode != .cutout { mipped.append(set.albedo) }
        for t in mipped where t.mipmapLevelCount > 1 { blit.generateMipmaps(for: t) }
        blit.endEncoding()
    }

    func dispatch(_ enc: MTLComputeCommandEncoder, _ ps: MTLComputePipelineState, _ w: Int, _ h: Int) {
        let tw = ps.threadExecutionWidth, th = max(1, ps.maxTotalThreadsPerThreadgroup / tw)
        enc.dispatchThreads(MTLSize(width: w, height: h, depth: 1), threadsPerThreadgroup: MTLSize(width: tw, height: th, depth: 1))
    }

    /// Synchronous convenience: generate a set into owned textures.
    public func generate(_ spec: MaterialSpec, size: Int? = nil) throws -> TextureSet {
        let set = makeSet(for: spec, size: size ?? RealQuality.pixels(for: spec))
        guard let cb = queue.makeCommandBuffer() else { throw SynthError.encode }
        try encode(spec, into: set, commandBuffer: cb)
        cb.commit(); cb.waitUntilCompleted()
        return set
    }

    // MARK: sky

    /// Equirectangular HDR sky (RGBA16F), shared storage so it can be read back into a CGImage.
    public func skyTexture(_ params: SkyParams) throws -> MTLTexture {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: Int(params.width), height: Int(params.height), mipmapped: false)
        d.usage = [.shaderRead, .shaderWrite]; d.storageMode = .shared
        guard let tex = device.makeTexture(descriptor: d), let cb = queue.makeCommandBuffer(), let enc = cb.makeComputeCommandEncoder() else { throw SynthError.encode }
        var p = params
        enc.setComputePipelineState(sky); enc.setTexture(tex, index: 0)
        enc.setBytes(&p, length: MemoryLayout<SkyParams>.stride, index: 0)
        dispatch(enc, sky, Int(params.width), Int(params.height))
        enc.endEncoding(); cb.commit(); cb.waitUntilCompleted()
        return tex
    }

    // MARK: readback

    /// Reads mip 0 of a texture into a CGImage (8-bit sRGB for color, 16F linear for HDR).
    public func cgImage(_ tex: MTLTexture) -> CGImage? {
        let w = tex.width, h = tex.height
        var src = tex
        if tex.storageMode == .private {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: tex.pixelFormat, width: w, height: h, mipmapped: false)
            d.storageMode = .shared; d.usage = [.shaderRead]
            guard let t = device.makeTexture(descriptor: d), let cb = queue.makeCommandBuffer(), let b = cb.makeBlitCommandEncoder() else { return nil }
            b.copy(from: tex, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(), sourceSize: MTLSize(width: w, height: h, depth: 1), to: t, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin())
            b.endEncoding(); cb.commit(); cb.waitUntilCompleted()
            src = t
        }
        switch src.pixelFormat {
        case .rgba16Float:
            var data = [UInt16](repeating: 0, count: w * h * 4)
            src.getBytes(&data, bytesPerRow: w * 8, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
            let cs = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
            let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder16Little.rawValue)
            guard let prov = CGDataProvider(data: Data(bytes: data, count: data.count * 2) as CFData) else { return nil }
            return CGImage(width: w, height: h, bitsPerComponent: 16, bitsPerPixel: 64, bytesPerRow: w * 8, space: cs, bitmapInfo: info, provider: prov, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        case .rg8Unorm:
            var data = [UInt8](repeating: 0, count: w * h * 2)
            src.getBytes(&data, bytesPerRow: w * 2, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
            var rgba = [UInt8](repeating: 255, count: w * h * 4)
            for i in 0..<(w * h) {
                let x = Float(data[i * 2]) / 127.5 - 1, y = Float(data[i * 2 + 1]) / 127.5 - 1
                rgba[i * 4] = data[i * 2]; rgba[i * 4 + 1] = data[i * 2 + 1]
                rgba[i * 4 + 2] = UInt8(max(0, min(255, ((1 - x * x - y * y).squareRoot().isNaN ? 0 : (1 - x * x - y * y).squareRoot()) * 127.5 + 127.5)))
            }
            guard let prov = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
            return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.linearSRGB)!,
                           bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: prov, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        case .r8Unorm:
            var data = [UInt8](repeating: 0, count: w * h)
            src.getBytes(&data, bytesPerRow: w, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
            guard let prov = CGDataProvider(data: Data(data) as CFData) else { return nil }
            return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0), provider: prov, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        default:
            var data = [UInt8](repeating: 0, count: w * h * 4)
            src.getBytes(&data, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
            let srgb = src.pixelFormat == .rgba8Unorm_srgb
            let cs = srgb ? CGColorSpace(name: CGColorSpace.sRGB)! : CGColorSpace(name: CGColorSpace.linearSRGB)!
            guard let prov = CGDataProvider(data: Data(data) as CFData) else { return nil }
            return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: cs,
                           bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: prov, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        }
    }
}
