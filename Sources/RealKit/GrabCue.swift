import Foundation
import RealityKit

// Gaze cue for grabbables (visionOS 26): a small white dot above each object picked up by hand,
// invisible until the eyes rest on the object. The dot is an unlit shader-graph sphere whose opacity
// is the system hover intensity; it shares a hover group with the object's root and parts, so looking
// at any of them lights it. The app never sees gaze; the system drives the hover state.

#if os(visionOS)
@MainActor
public enum RealGrabCue {
    static let entityName = "grab-cue"
    static var material: ShaderGraphMaterial?

    /// Shader graph: unlit white, opacity = hover intensity.
    static let usda = """
    #usda 1.0
    (
        defaultPrim = "Root"
        metersPerUnit = 1
        upAxis = "Y"
    )
    def Xform "Root"
    {
        def Material "GrabCue"
        {
            token outputs:mtlx:surface.connect = </Root/GrabCue/UnlitSurface.outputs:out>
            token outputs:realitykit:vertex
            def Shader "HoverState"
            {
                uniform token info:id = "ND_realitykit_hover_state"
                float outputs:intensity
                bool outputs:isActive
                float3 outputs:position
                float outputs:timeSinceHoverStart
            }
            def Shader "UnlitSurface"
            {
                uniform token info:id = "ND_realitykit_unlit_surfaceshader"
                bool inputs:applyPostProcessToneMap = 0
                color3f inputs:color = (1, 1, 1)
                bool inputs:hasPremultipliedAlpha = 0
                float inputs:opacity.connect = </Root/GrabCue/HoverState.outputs:intensity>
                float inputs:opacityThreshold = 0
                token outputs:out
            }
        }
    }
    """

    static func loadMaterial() async throws -> ShaderGraphMaterial {
        if let material { return material }
        let m = try await ShaderGraphMaterial(named: "/Root/GrabCue", from: Data(usda.utf8))
        material = m
        return m
    }

    /// Grabbables built after this call get a shader hover effect (set through
    /// `ManipulationComponent.configureEntity`; replacing the component afterwards traps in the
    /// manipulation gesture on visionOS 26.2). Call before building the scene.
    public static func enable() {
        RealGrabStyle.hoverEffect = .shader(.init(fadeInDuration: 0.12, fadeOutDuration: 0.25))
    }

    /// Adds a gaze dot to every grabbable under `root` (entities carrying `RealGrabComponent`).
    /// Returns the number of objects cued.
    @discardableResult
    public static func attach(under root: Entity) async throws -> Int {
        let mat = try await loadMaterial()
        var roots: [Entity] = []
        func collect(_ e: Entity) {
            if e.components.has(RealGrabComponent.self) { roots.append(e); return }
            for c in e.children { collect(c) }
        }
        collect(root)
        for e in roots { add(to: e, material: mat) }
        return roots.count
    }

    /// Dot above the object's bounds. With `enable()` the root's hover effect is a shader effect, which
    /// drives the hover state of shader-graph materials in its subtree (the dot). Components untouched.
    public static func add(to e: Entity, material: ShaderGraphMaterial) {
        guard e.findEntity(named: entityName) == nil else { return }
        let b = e.visualBounds(relativeTo: e)
        guard !b.isEmpty else { return }
        let diag = simd_length(b.extents)
        let r = min(max(diag * 0.015, 0.005), 0.012)
        let dot = ModelEntity(mesh: .generateSphere(radius: r), materials: [material])
        dot.name = entityName
        dot.position = SIMD3(b.center.x, b.max.y + r + 0.02, b.center.z)
        dot.components.set(DynamicLightShadowComponent(castsShadow: false))
        e.addChild(dot)
    }
}
#endif
