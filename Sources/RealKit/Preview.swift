import Foundation
import Metal
import CoreGraphics
import RealityKit
import RealMaterials

/// Offscreen rendering through RealityRenderer: thumbnails in apps, PNG previews in the CLI, and the
/// visual check an agent runs before committing an asset.
@MainActor
public final class RealPreview {
    public let renderer: RealityRenderer
    public let camera = Entity()
    let device: MTLDevice

    public init(environment: RealEnvironment?) throws {
        renderer = try RealityRenderer()
        device = TextureSynth.shared?.device ?? MTLCreateSystemDefaultDevice()!
        camera.components.set(PerspectiveCameraComponent(near: 0.03, far: 3000, fieldOfViewInDegrees: 45))
        renderer.entities.append(camera)
        renderer.activeCamera = camera
        renderer.cameraSettings.colorBackground = .color(CGColor(red: 0.5, green: 0.6, blue: 0.75, alpha: 1))
        renderer.cameraSettings.antialiasing = .multisample4X
        renderer.cameraSettings.isToneMappingEnabled = true
        if let environment {
            renderer.lighting.resource = environment.resource
            renderer.lighting.intensityExponent = environment.iblExposure
            renderer.entities.append(environment.root)
        }
    }

    public func add(_ e: Entity) { renderer.entities.append(e) }

    public func look(from eye: SIMD3<Float>, at target: SIMD3<Float>, fov: Float = 45) {
        // Near plane scales with the view distance so life-size insects (mm) frame without clipping.
        let near = min(0.03, max(0.0002, simd_distance(eye, target) * 0.05))
        camera.components.set(PerspectiveCameraComponent(near: near, far: 3000, fieldOfViewInDegrees: fov))
        camera.look(at: target, from: eye, relativeTo: nil)
    }

    /// Frames an entity's visual bounds from a 3/4 view.
    public func frame(_ e: Entity, azimuth: Float = 35, elevation: Float = 12, distanceScale: Float = 1.25, fov: Float = 40) {
        let b = e.visualBounds(relativeTo: nil)
        let c = b.center, r = max(0.003, simd_length(b.extents) * 0.5)
        let d = r / tan(fov * .pi / 360) * distanceScale
        let az = azimuth * .pi / 180, el = elevation * .pi / 180
        let eye = c + SIMD3(sin(az) * cos(el), sin(el), cos(az) * cos(el)) * d
        look(from: eye, at: c, fov: fov)
    }

    /// Renders `frames` frames (lets streaming textures and shadows settle) and returns the last.
    public func render(width: Int, height: Int, frames: Int = 4, deltaTime: Double = 1.0 / 60) async throws -> CGImage? {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
        d.usage = [.renderTarget, .shaderRead, .shaderWrite]
        d.storageMode = .private
        guard let tex = device.makeTexture(descriptor: d) else { return nil }
        let out = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: tex))
        for _ in 0..<frames {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                do {
                    try renderer.updateAndRender(deltaTime: deltaTime, cameraOutput: out, onComplete: { _ in c.resume() })
                } catch { c.resume() }
            }
        }
        return Self.tonemapped(tex, device: device)
    }

    /// HDR target -> 8-bit sRGB CGImage (RealityRenderer already applies its tone mapping; this clamps
    /// and encodes).
    static func tonemapped(_ tex: MTLTexture, device: MTLDevice) -> CGImage? {
        let w = tex.width, h = tex.height
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: w, height: h, mipmapped: false)
        d.storageMode = .shared
        guard let shared = device.makeTexture(descriptor: d), let q = device.makeCommandQueue(), let cb = q.makeCommandBuffer(),
              let b = cb.makeBlitCommandEncoder() else { return nil }
        b.copy(from: tex, to: shared)
        b.endEncoding(); cb.commit(); cb.waitUntilCompleted()
        var half = [Float16](repeating: 0, count: w * h * 4)
        shared.getBytes(&half, bytesPerRow: w * 8, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        var px = [UInt8](repeating: 255, count: w * h * 4)
        for i in 0..<(w * h) {
            for c in 0..<3 {
                var v = Float(half[i * 4 + c])
                v = max(0, min(1, v))
                v = v <= 0.0031308 ? v * 12.92 : 1.055 * pow(v, 1 / 2.4) - 0.055
                px[i * 4 + c] = UInt8(max(0, min(255, v * 255 + 0.5)))
            }
        }
        guard let prov = CGDataProvider(data: Data(px) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: prov, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
