import Foundation
import Metal
import CoreGraphics
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

/// Procedural indoor light probe: what a point in the middle of a lit room sees. Ceiling with a grid of
/// bright luminaires, walls, floor, and a band of windows showing the sky on one side. Used as the IBL
/// (diffuse fill and glossy reflections) of interior scenes, while the sun still enters through real
/// window openings as the shadowed directional light.
public struct InteriorLight: Sendable {
    /// Linear RGB radiance of surfaces (relative units; 1 = diffuse white under ~500 lux).
    public var ceiling: SIMD3<Float> = SIMD3(0.62, 0.61, 0.6)
    public var walls: SIMD3<Float> = SIMD3(0.5, 0.48, 0.45)
    public var floor: SIMD3<Float> = SIMD3(0.34, 0.33, 0.31)
    /// Luminaire radiance and color (LED panels about 4000 K).
    public var fixtures: SIMD3<Float> = SIMD3(5.5, 5.3, 5.0)
    /// Luminaire grid pitch and panel size as fractions of the pitch (x across, y along).
    public var fixturePitch: Float = 0.38
    public var fixtureSize: SIMD2<Float> = SIMD2(0.32, 0.32)
    /// Windows: heading (degrees clockwise from -Z, matching `SunSky.azimuth`), angular width, sill and
    /// head elevations in degrees, and sky radiance through them.
    public var windowAzimuth: Float = 90
    public var windowWidth: Float = 150
    public var windowElevation: ClosedRange<Float> = -8...32
    public var windowSky: SIMD3<Float> = SIMD3(2.4, 2.7, 3.2)
    /// Ground seen through the windows (below the horizon).
    public var windowGround: SIMD3<Float> = SIMD3(0.5, 0.48, 0.42)
    /// IBL exposure (EV) for this probe.
    public var exposure: Float = -0.6
    public init() {}

    /// Open-plan office: LED troffers, light walls, carpet.
    public static let office = InteriorLight()
    /// Wood-panelled private office: warmer, darker, fewer fixtures.
    public static let warm = InteriorLight().with {
        $0.ceiling = SIMD3(0.55, 0.5, 0.44); $0.walls = SIMD3(0.42, 0.34, 0.26); $0.floor = SIMD3(0.16, 0.11, 0.08)
        $0.fixtures = SIMD3(4.2, 3.4, 2.4); $0.fixturePitch = 0.6; $0.fixtureSize = SIMD2(0.14, 0.14); $0.windowWidth = 70
    }
    /// Stone lobby: tall, bright, glazed front.
    public static let lobby = InteriorLight().with {
        $0.ceiling = SIMD3(0.7, 0.69, 0.67); $0.walls = SIMD3(0.55, 0.53, 0.5); $0.floor = SIMD3(0.42, 0.41, 0.4)
        $0.fixtures = SIMD3(6, 5.6, 5); $0.fixturePitch = 0.5; $0.fixtureSize = SIMD2(0.12, 0.12)
        $0.windowWidth = 170; $0.windowElevation = -10...55; $0.exposure = -0.4
    }

    /// Hospital ward, corridor or ER bay: 4000 K troffers, pale walls, light sheet vinyl, small windows.
    public static let clinical = InteriorLight().with {
        $0.ceiling = SIMD3(0.7, 0.71, 0.72); $0.walls = SIMD3(0.56, 0.58, 0.57); $0.floor = SIMD3(0.4, 0.39, 0.37)
        $0.fixtures = SIMD3(6.2, 6.2, 6.0); $0.fixturePitch = 0.34; $0.fixtureSize = SIMD2(0.3, 0.3)
        $0.windowWidth = 50; $0.windowElevation = 0...28; $0.exposure = -0.5
    }
    /// Operating room: no windows, dense 5000 K laminar-flow ceiling, green-grey tile, blue-grey floor.
    public static let operatingRoom = InteriorLight().with {
        $0.ceiling = SIMD3(0.8, 0.82, 0.85); $0.walls = SIMD3(0.46, 0.52, 0.5); $0.floor = SIMD3(0.3, 0.34, 0.36)
        $0.fixtures = SIMD3(7.5, 7.8, 8.2); $0.fixturePitch = 0.3; $0.fixtureSize = SIMD2(0.5, 0.5)
        $0.windowWidth = 0; $0.windowElevation = 0...0; $0.exposure = -0.55
    }

    public func with(_ edit: (inout InteriorLight) -> Void) -> InteriorLight { var c = self; edit(&c); return c }

    /// Radiance seen along a direction (scene space, +Y up).
    public func radiance(_ d: SIMD3<Float>) -> SIMD3<Float> {
        let el = asin(max(-1, min(1, d.y))) * 180 / .pi
        var az = atan2(d.x, -d.z) * 180 / .pi
        az = (az - windowAzimuth + 540).truncatingRemainder(dividingBy: 360) - 180
        if abs(az) < windowWidth / 2, windowElevation.contains(el) {
            // Mullions every ~12 degrees.
            let m = abs((az / 12).rounded() * 12 - az)
            if m > 0.6 { return el > 0 ? windowSky * (0.75 + 0.25 * min(1, el / 25)) : windowGround }
            return walls * 0.6
        }
        if d.y > 0.25 {
            // Ceiling plane at unit height: grid of panels in plane coordinates.
            let p = SIMD2(d.x, d.z) / d.y
            let c = p / fixturePitch
            let f = c - c.rounded(.down) - 0.5
            let lit = abs(f.x) < fixtureSize.x * 0.5 / fixturePitch * fixturePitch && abs(f.y) < fixtureSize.y * 0.5 / fixturePitch * fixturePitch
            let falloff = min(1, d.y * 1.6)
            return lit ? fixtures * falloff + ceiling * (1 - falloff) : ceiling * (0.85 + 0.15 * d.y)
        }
        if d.y < -0.2 { return floor * (0.9 + 0.1 * -d.y) }
        let t = (d.y + 0.2) / 0.45
        return walls * (0.9 + 0.2 * t)
    }

    /// Equirect HDR image (same layout as the GPU sky: u = 0.5 looks down -Z).
    public func image(width: Int = 512) -> CGImage? {
        let h = width / 2
        var px = [Float](repeating: 1, count: width * h * 4)
        for j in 0..<h {
            // Row 0 is the top of the image (zenith) in CGImage order.
            let elev = (0.5 - (Float(j) + 0.5) / Float(h)) * .pi
            for i in 0..<width {
                let phi = ((Float(i) + 0.5) / Float(width) - 0.5) * 2 * .pi
                let d = SIMD3(sin(phi) * cos(elev), sin(elev), -cos(phi) * cos(elev))
                let r = radiance(d)
                let k = (j * width + i) * 4
                px[k] = r.x; px[k + 1] = r.y; px[k + 2] = r.z
            }
        }
        let cs = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let prov = CGDataProvider(data: Data(bytes: px, count: px.count * 4) as CFData) else { return nil }
        return CGImage(width: width, height: h, bitsPerComponent: 32, bitsPerPixel: 128, bytesPerRow: width * 16, space: cs,
                       bitmapInfo: info, provider: prov, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
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
    /// Exposure (EV) of the active probe (sky or interior).
    public let iblExposure: Float

    /// - Parameters:
    ///   - skybox: add a visible sky dome (full immersion). Leave off in mixed reality.
    ///   - interior: light the scene with an indoor probe instead of the sky (the sun and skybox stay,
    ///     seen through window openings).
    public init(_ p: SunSky = SunSky(), skybox: Bool = false, skyboxRadius: Float = 900, interior: InteriorLight? = nil) throws {
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
        if let interior, let img = interior.image() {
            resource = try EnvironmentResource(equirectangular: img, withName: "realityhd.interior")
            iblExposure = interior.exposure
        } else {
            resource = try EnvironmentResource(equirectangular: iblImage, withName: "realityhd.sky")
            iblExposure = p.iblExposure
        }
        ibl.name = "IBL"
        ibl.components.set(ImageBasedLightComponent(source: .single(resource), intensityExponent: iblExposure))
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
        let perf = RealPerformance.active
        shadow.shadowProjection = .automatic(maximumDistance: max(2, p.shadowDistance * perf.shadowDistanceScale * RealPerformance.adaptiveScale))
        if perf.shadows { sun.components.set(shadow) }
        sun.components.set(RealSunComponent(baseShadowDistance: p.shadowDistance))
        sun.look(at: .zero, from: p.sunDirection * 50, relativeTo: nil)
        RealWind.sunTravel = -p.sunDirection
        root.addChild(sun)

        if skybox {
            let skyWidth = min(8192, max(512, Int(Float(p.skyResolution * 2) * RealPerformance.active.skyboxScale)))
            let skyTex = try synth.skyTexture(SkyParams(sunDir: p.sunDirection, turbidity: p.turbidity, width: skyWidth, drawSun: true, exposure: 1.25))
            if let img = synth.cgImage(skyTex) {
                let tr = try TextureResource(image: img, withName: "realityhd.skybox", options: .init(semantic: .hdrColor, mipmapsMode: .none))
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
