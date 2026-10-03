import Foundation
import Metal
import RealityKit
import RealCore
import RealMaterials

/// Physically based outdoor lighting: a ray-marched Rayleigh/Mie sky rendered on the GPU into an
/// equirect HDR, used both as image-based light and (optionally) as a visible skybox, plus a shadowed
/// directional sun aligned with the sky's sun position.
public struct SunSky: Sendable {
    /// Degrees above the horizon.
    public var elevation: Float = 38
    /// Degrees clockwise from -Z (north) toward +X.
    public var azimuth: Float = 135
    /// 1.6 = very clear, 3 = hazy, 6 = smoggy.
    public var turbidity: Float = 2.2
    /// Directional sun illuminance (RealityKit lux units). With `iblExposure` this sets the
    /// sun-to-sky balance: 9000 / -0.3 EV puts sunny-day shadows at roughly a third of lit ground
    /// (3000 / 0.9 left them at ~0.85, which read as overcast).
    public var sunLux: Float = 9000
    /// IBL exponent (EV) applied to the sky dome.
    public var iblExposure: Float = -0.3
    /// Shadow distance in meters (cascaded automatically).
    public var shadowDistance: Float = 40
    public var skyResolution: Int = 1024
    /// Aerial perspective: extinction per meter and haze brightness relative to the horizon sky.
    public var fogDensity: Float = 0.0035
    public var fogBrightness: Float = 1
    public init() {}
    public init(elevation: Float, azimuth: Float = 135, turbidity: Float = 2.2) { self.elevation = elevation; self.azimuth = azimuth; self.turbidity = turbidity }

    public static let morning = SunSky(elevation: 14, azimuth: 100, turbidity: 2.6)
    public static let midday = SunSky(elevation: 62, azimuth: 160, turbidity: 2.0)
    public static let afternoon = SunSky(elevation: 32, azimuth: 225, turbidity: 2.3)
    public static let goldenHour = SunSky(elevation: 6, azimuth: 250, turbidity: 3.2)

    /// Unit vector pointing from the scene toward the sun.
    public var sunDirection: SIMD3<Float> {
        let e = radians(elevation), a = radians(azimuth)
        return SIMD3(sin(a) * cos(e), sin(e), -cos(a) * cos(e))
    }
}

@MainActor
public final class RealEnvironment {
    public let root = Entity()
    public let ibl = Entity()
    public let sun = Entity()
    public private(set) var skybox: ModelEntity?
    public let resource: EnvironmentResource
    public let params: SunSky

    /// - Parameter skybox: add a visible sky dome (full immersion). Leave off in mixed reality.
    public init(_ p: SunSky = SunSky(), skybox: Bool = false, skyboxRadius: Float = 900) throws {
        guard let synth = TextureSynth.shared else { throw TextureSynth.SynthError.noMetal }
        params = p
        root.name = "RealEnvironment"
        // IBL: sky without the sun disk (the directional light carries the sun; avoids double counting).
        let iblTex = try synth.skyTexture(SkyParams(sunDir: p.sunDirection, turbidity: p.turbidity, width: p.skyResolution / 2, drawSun: false))
        guard let iblImage = synth.cgImage(iblTex) else { throw TextureSynth.SynthError.encode }
        // Horizon haze color drives aerial perspective in every ShaderGraph material.
        do {
            let w = iblTex.width, row = iblTex.height / 2 - max(1, iblTex.height / 60)
            var half = [Float16](repeating: 0, count: w * 4)
            iblTex.getBytes(&half, bytesPerRow: w * 8, from: MTLRegionMake2D(0, row, w, 1), mipmapLevel: 0)
            var acc = SIMD3<Float>.zero
            for x in 0..<w { acc += SIMD3(Float(half[x * 4]), Float(half[x * 4 + 1]), Float(half[x * 4 + 2])) }
            RealAtmosphere.fogColor = acc / Float(w) * p.fogBrightness
            RealAtmosphere.fogDensity = p.fogDensity
        }
        resource = try EnvironmentResource(equirectangular: iblImage, withName: "realforge.sky")
        ibl.name = "IBL"
        ibl.components.set(ImageBasedLightComponent(source: .single(resource), intensityExponent: p.iblExposure))
        root.addChild(ibl)

        sun.name = "Sun"
        var light = DirectionalLightComponent()
        light.intensity = p.sunLux * (0.35 + 0.65 * min(1, max(0, sin(radians(p.elevation)) * 2.5)))
        let warm = max(0, 1 - p.elevation / 25)
        light.color = .init(SIMD3(1, 0.93 - 0.2 * warm, 0.85 - 0.4 * warm))
        sun.components.set(light)
        var shadow = DirectionalLightComponent.Shadow()
        shadow.shadowProjection = .automatic(maximumDistance: p.shadowDistance)
        shadow.depthBias = 1.5
        sun.components.set(shadow)
        sun.look(at: .zero, from: p.sunDirection * 50, relativeTo: nil)
        RealWind.sunTravel = -p.sunDirection
        root.addChild(sun)

        if skybox {
            let skyTex = try synth.skyTexture(SkyParams(sunDir: p.sunDirection, turbidity: p.turbidity, width: p.skyResolution * 2, drawSun: true, exposure: 1.25))
            if let img = synth.cgImage(skyTex) {
                let tr = try TextureResource(image: img, withName: "realforge.skybox", options: .init(semantic: .hdrColor, mipmapsMode: .none))
                var m = UnlitMaterial()
                m.color = .init(tint: .white, texture: .init(tr))
                m.faceCulling = .none
                let e = ModelEntity(mesh: try Self.skyDome(radius: skyboxRadius).meshResource(), materials: [m])
                e.name = "Skybox"
                e.components.set(DynamicLightShadowComponent(castsShadow: false))
                root.addChild(e)
                self.skybox = e
            }
        }
    }

    /// Light every model under `entity` with this environment's IBL. Call after building content.
    public func illuminate(_ entity: Entity) {
        entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ibl))
        for c in entity.children { illuminate(c) }
    }

    /// Inward-facing sphere whose UVs match the GPU sky's equirect convention exactly.
    static func skyDome(radius: Float) -> Model {
        var s = Surface(material: "sky")
        let rings = 48, segs = 96
        for j in 0...rings {
            let v = Float(j) / Float(rings), elev = (v - 0.5) * .pi
            for i in 0...segs {
                let u = Float(i) / Float(segs), phi = (u - 0.5) * 2 * .pi
                let d = SIMD3(sin(phi) * cos(elev), sin(elev), -cos(phi) * cos(elev))
                s.add(d * radius, -d, SIMD2(u, v))
            }
        }
        let row = UInt32(segs + 1)
        for j in 0..<UInt32(rings) { for i in 0..<UInt32(segs) {
            let a = j * row + i
            s.quad(a, a + row, a + row + 1, a + 1)
        }}
        return Model(name: "sky", surfaces: [s])
    }
}
