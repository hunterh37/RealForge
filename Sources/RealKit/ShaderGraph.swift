import Foundation
import RealityKit

/// Emits RealityKit ShaderGraph USDA (MaterialX node ids as authored by Reality Composer Pro) and loads
/// it with `ShaderGraphMaterial(named:from:)`. Used where PhysicallyBasedMaterial can't go: vertex wind
/// on foliage and bark, and back-lit leaf translucency.
struct USDAGraph {
    private(set) var body = ""
    private var n = 0
    let mat: String

    init(material: String) { mat = material }

    /// Adds a node; returns its output path. `inputs`: (type, name, value) where value is either a
    /// literal (e.g. "0.5") or a connection path starting with "<".
    mutating func node(_ id: String, _ inputs: [(String, String, String)], out: String) -> String {
        n += 1
        let name = "N\(n)"
        var s = "        def Shader \"\(name)\"\n        {\n            uniform token info:id = \"\(id)\"\n"
        for (t, k, v) in inputs {
            if v.hasPrefix("<") { s += "            \(t) inputs:\(k).connect = \(v)\n" }
            else { s += "            \(t) inputs:\(k) = \(v)\n" }
        }
        s += "            \(out) outputs:out\n        }\n"
        body += s
        return "</Root/\(mat)/\(name).outputs:out>"
    }

    /// Separate node: returns paths for each component output.
    mutating func separate(_ id: String, _ inType: String, _ input: String, _ comps: [String]) -> [String] {
        n += 1
        let name = "N\(n)"
        var s = "        def Shader \"\(name)\"\n        {\n            uniform token info:id = \"\(id)\"\n"
        s += "            \(inType) inputs:in.connect = \(input)\n"
        for c in comps { s += "            float outputs:\(c)\n" }
        s += "        }\n"
        body += s
        return comps.map { "</Root/\(mat)/\(name).outputs:\($0)>" }
    }

    func param(_ p: String) -> String { "</Root/\(mat).inputs:\(p)>" }

    mutating func texture(_ param: String, _ uv: String, color: Bool) -> String {
        let id = color ? "ND_RealityKitTexture2D_color4" : "ND_RealityKitTexture2D_vector4"
        let t = color ? "color4f" : "float4"
        return node(id, [("asset", "file", self.param(param)), ("string", "u_wrap_mode", "\"repeat\""), ("string", "v_wrap_mode", "\"repeat\""),
                         ("string", "mag_filter", "\"linear\""), ("string", "min_filter", "\"linear\""), ("string", "mip_filter", "\"linear\""),
                         ("int", "max_anisotropy", "8"), ("float2", "texcoord", uv), ("\(t)", "default", color ? "(0.5, 0.5, 0.5, 1)" : "(0.5, 0.5, 1, 1)")],
                    out: t)
    }

    /// Triplanar sample of a texture: returns float4/color4 output path blended by |n|^4 weights.
    mutating func triplanar(_ param: String, color: Bool, scale: String) -> String {
        let pos = node("ND_position_vector3", [("string", "space", "\"object\"")], out: "float3")
        let nrm = node("ND_normal_vector3", [("string", "space", "\"object\"")], out: "float3")
        let p = separate("ND_separate3_vector3", "float3", pos, ["outx", "outy", "outz"])
        let n = separate("ND_separate3_vector3", "float3", nrm, ["outx", "outy", "outz"])
        func uv(_ a: String, _ b: String) -> String {
            let v = node("ND_combine2_vector2", [("float", "in1", a), ("float", "in2", b)], out: "float2")
            return node("ND_multiply_vector2FA", [("float2", "in1", v), ("float", "in2", scale)], out: "float2")
        }
        let sx = texture(param, uv(p[2], p[1]), color: color)
        let sy = texture(param, uv(p[0], p[2]), color: color)
        let sz = texture(param, uv(p[0], p[1]), color: color)
        func w(_ c: String) -> String {
            let a = node("ND_absval_float", [("float", "in", c)], out: "float")
            let a2 = mul(a, a); return mul(a2, a2)
        }
        let wx = w(n[0]), wy = w(n[1]), wz = w(n[2])
        let sum = add(add(wx, wy), add(wz, "0.0001"))
        let t = color ? "color4" : "vector4", ty = color ? "color4f" : "float4"
        func scaled(_ s: String, _ k: String) -> String {
            node("ND_multiply_\(t)FA", [("\(ty)", "in1", s), ("float", "in2", node("ND_divide_float", [("float", "in1", k), ("float", "in2", sum)], out: "float"))], out: ty)
        }
        let ax = scaled(sx, wx), ay = scaled(sy, wy), az = scaled(sz, wz)
        let s1 = node("ND_add_\(t)", [("\(ty)", "in1", ax), ("\(ty)", "in2", ay)], out: ty)
        return node("ND_add_\(t)", [("\(ty)", "in1", s1), ("\(ty)", "in2", az)], out: ty)
    }

    mutating func mul(_ a: String, _ b: String) -> String { node("ND_multiply_float", [("float", "in1", a), ("float", "in2", b)], out: "float") }
    mutating func add(_ a: String, _ b: String) -> String { node("ND_add_float", [("float", "in1", a), ("float", "in2", b)], out: "float") }
    mutating func sin(_ a: String) -> String { node("ND_sin_float", [("float", "in", a)], out: "float") }
}

public struct RealShaderOptions: Hashable, Sendable {
    public var cutout = false
    public var metallicMap = false
    public var aoMap = true
    /// Vertex wind driven by uv1 = (weight, phase).
    public var wind = false
    /// Fake subsurface: leaves glow with transmitted sun when seen against it.
    public var translucency = false
    /// Break up visible tiling on large surfaces: blend a second, rotated/scaled sample plus a
    /// macro-scale brightness modulation from the same texture.
    public var antiTile = false
    /// Moss/snow/dust on upward-facing surfaces (world normal), broken up by texture luminance.
    public var topLayer = false
    /// Exponential distance fog toward the sky's horizon color (aerial perspective).
    public var fog = true
    /// Object-space triplanar projection for color/roughness/AO (rocks: no stretching on steep facets).
    public var triplanar = false
    public init() {}
}

public enum RealShaderGraph {
    public static func usda(_ o: RealShaderOptions) -> String {
        let name = "RealSurface"
        var g = USDAGraph(material: name)
        let uv0 = g.node("ND_texcoord_vector2", [("int", "index", "0")], out: "float2")
        let uv = g.node("ND_multiply_vector2FA", [("float2", "in1", uv0), ("float", "in2", g.param("UVScale"))], out: "float2")
        let base = o.triplanar ? g.triplanar("BaseColor", color: true, scale: g.param("UVScale")) : g.texture("BaseColor", uv, color: true)
        let bc = g.separate("ND_separate4_color4", "color4f", base, ["outr", "outg", "outb", "outa"])
        var rgb = g.node("ND_combine3_color3", [("float", "in1", bc[0]), ("float", "in2", bc[1]), ("float", "in3", bc[2])], out: "color3f")
        var uvB: String?
        if o.antiTile {
            // Second sample: different scale + offset (repeat period ~ 1/0.37 tiles, incommensurate).
            let s2 = g.node("ND_multiply_vector2FA", [("float2", "in1", uv), ("float", "in2", "0.37")], out: "float2")
            let uv2 = g.node("ND_add_vector2", [("float2", "in1", s2), ("float2", "in2", "(0.31, 0.67)")], out: "float2")
            uvB = uv2
            let b2 = g.separate("ND_separate4_color4", "color4f", g.texture("BaseColor", uv2, color: true), ["outr", "outg", "outb", "outa"])
            let rgb2 = g.node("ND_combine3_color3", [("float", "in1", b2[0]), ("float", "in2", b2[1]), ("float", "in3", b2[2])], out: "color3f")
            // Macro: very low frequency luminance variation.
            let s3 = g.node("ND_multiply_vector2FA", [("float2", "in1", uv), ("float", "in2", "0.047")], out: "float2")
            let b3 = g.separate("ND_separate4_color4", "color4f", g.texture("BaseColor", s3, color: true), ["outr", "outg", "outb", "outa"])
            let macro = g.add("0.55", g.mul(g.add(b3[0], b3[1]), "1.6"))
            let mixed = g.node("ND_mix_color3", [("color3f", "fg", rgb2), ("color3f", "bg", rgb), ("float", "mix", "0.45")], out: "color3f")
            rgb = g.node("ND_multiply_color3FA", [("color3f", "in1", mixed), ("float", "in2", macro)], out: "color3f")
        }
        var tint = g.node("ND_multiply_color3", [("color3f", "in1", rgb), ("color3f", "in2", g.param("Tint"))], out: "color3f")
        // Baked vertex AO (uv2.x): darkens albedo in crowns/crevices, and multiplies texture AO below.
        let uv1s = g.node("ND_texcoord_vector2", [("int", "index", "1")], out: "float2")
        let vao = g.separate("ND_separate2_vector2", "float2", uv1s, ["outx", "outy"])[1]
        let aoTint = g.node("ND_mix_float", [("float", "fg", vao), ("float", "bg", "1"), ("float", "mix", "0.4")], out: "float")
        tint = g.node("ND_multiply_color3FA", [("color3f", "in1", tint), ("float", "in2", aoTint)], out: "color3f")
        var topMask: String?
        if o.topLayer {
            let wn = g.node("ND_normal_vector3", [("string", "space", "\"world\"")], out: "float3")
            let ny = g.separate("ND_separate3_vector3", "float3", wn, ["outx", "outy", "outz"])[1]
            let lum = g.add(g.mul(bc[0], "0.6"), g.mul(bc[1], "1.2"))
            let m0 = g.add(ny, g.mul(g.add(lum, "-0.25"), "1.4"))
            let m1 = g.node("ND_smoothstep_float", [("float", "in", m0), ("float", "low", g.param("TopLow")), ("float", "high", g.add(g.param("TopLow"), "0.25"))], out: "float")
            let mask = g.mul(m1, g.param("TopAmount"))
            topMask = mask
            let topCol = g.node("ND_multiply_color3FA", [("color3f", "in1", g.param("TopColor")), ("float", "in2", g.add("0.6", g.mul(lum, "1.2")))], out: "color3f")
            tint = g.node("ND_mix_color3", [("color3f", "fg", topCol), ("color3f", "bg", tint), ("float", "mix", mask)], out: "color3f")
        }
        var fogF: String?
        if o.fog {
            let wp = g.node("ND_position_vector3", [("string", "space", "\"world\"")], out: "float3")
            let cam = g.node("ND_realitykit_cameraposition_vector3", [], out: "float3")
            let dv = g.node("ND_subtract_vector3", [("float3", "in1", wp), ("float3", "in2", cam)], out: "float3")
            let dist = g.node("ND_magnitude_vector3", [("float3", "in", dv)], out: "float")
            let e = g.node("ND_exp_float", [("float", "in", g.mul(g.mul(dist, g.param("FogDensity")), "-1"))], out: "float")
            let f = g.add("1", g.mul(e, "-1"))
            fogF = f
            tint = g.node("ND_multiply_color3FA", [("color3f", "in1", tint), ("float", "in2", g.add("1", g.mul(f, "-1")))], out: "color3f")
        }
        var nt = g.texture("Normal", uv, color: false)
        if let uvB {
            let nt2 = g.texture("Normal", uvB, color: false)
            nt = g.node("ND_mix_vector4", [("float4", "fg", nt2), ("float4", "bg", nt), ("float", "mix", "0.45")], out: "float4")
        }
        // RG8 normal: reconstruct z = sqrt(1 - x^2 - y^2) in tangent space.
        let nc = g.separate("ND_separate4_vector4", "float4", nt, ["outx", "outy", "outz", "outw"])
        let nx = g.add(g.mul(nc[0], "2"), "-1"), ny = g.add(g.mul(nc[1], "2"), "-1")
        let nzz = g.add("1", g.mul(g.add(g.mul(nx, nx), g.mul(ny, ny)), "-1"))
        let nz = g.node("ND_sqrt_float", [("float", "in", g.node("ND_max_float", [("float", "in1", nzz), ("float", "in2", "0")], out: "float"))], out: "float")
        let normal = g.node("ND_combine3_vector3", [("float", "in1", nx), ("float", "in2", ny), ("float", "in3", nz)], out: "float3")
        let rt = g.separate("ND_separate4_vector4", "float4", o.triplanar ? g.triplanar("Roughness", color: false, scale: g.param("UVScale")) : g.texture("Roughness", uv, color: false), ["outx", "outy", "outz", "outw"])
        var rough = rt[0]
        if let topMask { rough = g.node("ND_mix_float", [("float", "fg", "0.95"), ("float", "bg", rough), ("float", "mix", topMask)], out: "float") }
        var surfaceInputs: [(String, String, String)] = [
            ("color3f", "baseColor", tint), ("float3", "normal", normal), ("float", "roughness", rough),
            ("float", "specular", g.param("Specular")),
        ]
        if o.aoMap {
            let at = g.separate("ND_separate4_vector4", "float4", o.triplanar ? g.triplanar("AO", color: false, scale: g.param("UVScale")) : g.texture("AO", uv, color: false), ["outx", "outy", "outz", "outw"])
            surfaceInputs.append(("float", "ambientOcclusion", g.mul(at[0], vao)))
        } else {
            surfaceInputs.append(("float", "ambientOcclusion", vao))
        }
        if o.metallicMap {
            let mt = g.separate("ND_separate4_vector4", "float4", g.texture("Metallic", uv, color: false), ["outx", "outy", "outz", "outw"])
            surfaceInputs.append(("float", "metallic", mt[0]))
        }
        if o.cutout {
            surfaceInputs.append(("float", "opacity", bc[3]))
            surfaceInputs.append(("float", "opacityThreshold", g.param("OpacityThreshold")))
        }
        var emissive: String?
        if o.translucency {
            // Transmission ~ saturate(dot(viewDir, sunDir))^4: view direction from camera to fragment.
            let wp = g.node("ND_position_vector3", [("string", "space", "\"world\"")], out: "float3")
            let cam = g.node("ND_realitykit_cameraposition_vector3", [], out: "float3")
            let dv = g.node("ND_subtract_vector3", [("float3", "in1", wp), ("float3", "in2", cam)], out: "float3")
            let vdir = g.node("ND_normalize_vector3", [("float3", "in", dv)], out: "float3")
            let d = g.node("ND_dotproduct_vector3", [("float3", "in1", vdir), ("float3", "in2", g.param("SunDirection"))], out: "float")
            let cl = g.node("ND_clamp_float", [("float", "in", d), ("float", "low", "0"), ("float", "high", "1")], out: "float")
            let p4 = g.node("ND_power_float", [("float", "in1", cl), ("float", "in2", "4")], out: "float")
            let k = g.mul(p4, g.param("Translucency"))
            emissive = g.node("ND_multiply_color3FA", [("color3f", "in1", tint), ("float", "in2", k)], out: "color3f")
        }
        if let fogF {
            let haze = g.node("ND_multiply_color3FA", [("color3f", "in1", g.param("FogColor")), ("float", "in2", fogF)], out: "color3f")
            emissive = emissive.map { g.node("ND_add_color3", [("color3f", "in1", $0), ("color3f", "in2", haze)], out: "color3f") } ?? haze
        }
        if let emissive { surfaceInputs.append(("color3f", "emissiveColor", emissive)) }
        let surface = g.node("ND_realitykit_pbr_surfaceshader", surfaceInputs + [("bool", "hasPremultipliedAlpha", "0")], out: "token")

        var vertex: String?
        if o.wind {
            let uv1 = g.node("ND_texcoord_vector2", [("int", "index", "1")], out: "float2")
            let w = g.separate("ND_separate2_vector2", "float2", uv1, ["outx", "outy"])
            let wp = g.node("ND_position_vector3", [("string", "space", "\"world\"")], out: "float3")
            let p = g.separate("ND_separate3_vector3", "float3", wp, ["outx", "outy", "outz"])
            let t = g.mul(g.node("ND_time_float", [], out: "float"), g.param("WindSpeed"))
            let weight = w[0]
            // Per-branch phase from world position (uv1.y carries baked AO).
            let phase = g.mul(g.add(p[0], g.mul(p[2], "1.7")), "0.9")
            // Primary sway: slow, coherent across the tree, phase-shifted through the world.
            let sArg = g.add(g.add(t, phase), g.add(g.mul(p[0], "0.13"), g.mul(p[2], "0.09")))
            let gust = g.add("1", g.mul(g.sin(g.add(g.mul(t, "0.31"), g.mul(p[0], "0.05"))), "0.45"))
            let sway = g.mul(g.mul(g.mul(g.sin(sArg), g.mul(weight, weight)), g.param("WindStrength")), gust)
            // Flutter: fast, per-leaf, small.
            let fArg = g.add(g.mul(t, "7.1"), g.add(g.mul(phase, "5"), g.add(g.mul(p[0], "4.1"), g.mul(p[1], "3.3"))))
            let flutter = g.mul(g.mul(g.sin(fArg), weight), g.mul(g.param("WindStrength"), g.param("Flutter")))
            let dir = g.separate("ND_separate3_vector3", "float3", g.param("WindDirection"), ["outx", "outy", "outz"])
            let ox = g.add(g.mul(sway, dir[0]), flutter)
            let oy = g.mul(flutter, "0.7")
            let oz = g.add(g.mul(sway, dir[2]), g.mul(flutter, "-0.6"))
            let off = g.node("ND_combine3_vector3", [("float", "in1", ox), ("float", "in2", oy), ("float", "in3", oz)], out: "float3")
            vertex = g.node("ND_realitykit_geometrymodifier_vertexshader", [("float3", "modelPositionOffset", off)], out: "token")
        }

        var header = """
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
                asset inputs:BaseColor = @@
                asset inputs:Normal = @@
                asset inputs:Roughness = @@
                asset inputs:AO = @@
                asset inputs:Metallic = @@
                float inputs:UVScale = 1
                color3f inputs:Tint = (1, 1, 1)
                float inputs:Specular = 0.5
                float inputs:OpacityThreshold = 0.5
                float inputs:WindStrength = 0.05
                float inputs:WindSpeed = 1.3
                float inputs:Flutter = 0.3
                float3 inputs:WindDirection = (0.8, 0, 0.6)
                float3 inputs:SunDirection = (0, -1, 0)
                float inputs:Translucency = 0.6
                color3f inputs:FogColor = (0.6, 0.65, 0.7)
                float inputs:FogDensity = 0.01
                color3f inputs:TopColor = (0.05, 0.09, 0.02)
                float inputs:TopAmount = 1
                float inputs:TopLow = 0.55
                token outputs:mtlx:surface.connect = \(surface)

        """
        if let vertex { header += "        token outputs:realitykit:vertex.connect = \(vertex)\n" }
        return header + "\n" + g.body + "    }\n}\n"
    }

    @MainActor private static var templates: [RealShaderOptions: ShaderGraphMaterial] = [:]

    /// Compiled template per option set (each load parses USDA once); materials are cheap copies.
    @MainActor public static func material(_ o: RealShaderOptions) async throws -> ShaderGraphMaterial {
        if let m = templates[o] { return m }
        let data = Data(usda(o).utf8)
        let m = try await ShaderGraphMaterial(named: "/Root/RealSurface", from: data)
        templates[o] = m
        return m
    }
}
