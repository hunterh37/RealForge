import SwiftUI
import RealKit
import RealLibrary

/// Render settings editor. Live settings apply at once; build-time ones offer a scene reload.
struct PerformanceView: View {
    @Environment(DemoModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Picker("Tier", selection: Binding(get: { model.perf.tier }, set: { if let t = $0 { model.select(t) } })) {
                    ForEach(RealPerformance.Tier.allCases) { Text($0.rawValue.capitalized).tag(Optional($0)) }
                    if model.perf.tier == nil { Text("Custom").tag(RealPerformance.Tier?.none) }
                }
                .pickerStyle(.segmented)
                Toggle("Adaptive \(Int(model.perf.targetFPS)) fps governor", isOn: bind(\.adaptive))
                Toggle("Stats overlay in scene", isOn: $model.showHUD)
                if model.needsRebuild {
                    Button("Reload scene to apply build settings") { model.builtWith = nil; model.rebuildToken += 1 }
                        .buttonStyle(.borderedProminent)
                }
            } footer: {
                Text(tierNote).font(.footnote)
            }

            Section("Live") { StatsGrid() }

            Section("LOD and culling (live)") {
                slider("LOD bias", \.lodBias, 0.3...2.5, "%.2f")
                slider("Draw distance", \.drawDistance, 0...800, "%.0f m", zero: "unlimited")
                slider("Small-object cull", \.detailCullDistance, 0...60, "%.0f m", zero: "off")
                slider("Ground cover range", \.groundCoverDistance, 0.25...1.5, "%.2fx")
            }
            Section("Instance density (rebuild)") {
                slider("Ground cover density", \.fieldDensity, 0.2...1, "%.0f%%", scale: 100)
                slider("Distant thinning", \.distantThinning, 0...0.8, "%.0f%%", scale: 100)
            }
            Section("Shadows (live)") {
                Toggle("Sun shadows", isOn: bind(\.shadows))
                slider("Shadow distance", \.shadowDistanceScale, 0.2...2.5, "%.2fx")
                Stepper("Casters up to LOD \(model.perf.shadowCasterMaxLOD)", value: bind(\.shadowCasterMaxLOD), in: 0...3)
                slider("Min caster size", \.minShadowCasterSize, 0...1.5, "%.2f m", zero: "all")
            }
            Section("Shading (rebuild)") {
                Toggle("Foliage wind", isOn: bind(\.wind))
                Toggle("Leaf translucency", isOn: bind(\.translucency))
                Toggle("Aerial fog", isOn: bind(\.fog))
                Toggle("Anti-tiling", isOn: bind(\.antiTile))
                Toggle("Terrain splat blend", isOn: bind(\.splat))
                Toggle("Per-instance color variation", isOn: bind(\.instanceVariation))
                Toggle("Snow and moss layer", isOn: bind(\.snowLayer))
                Toggle("Water flow normals", isOn: bind(\.waterFlow))
            }
            Section("Textures and scene (rebuild)") {
                Picker("Max texture", selection: bind(\.maxTextureSize)) {
                    ForEach([512, 1024, 2048, 4096], id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                slider("Texture scale", \.textureScale, 0.25...2, "%.2fx")
                Toggle("Batch all static props", isOn: bind(\.forceBatching))
                Stepper("Scene lights \(model.perf.maxSceneLights)", value: bind(\.maxSceneLights), in: 0...32)
                slider("Skybox resolution", \.skyboxScale, 0.25...2, "%.2fx")
            }
            Section {
                Button("Reset to Balanced") { model.select(.balanced) }
            }
        }
        .navigationTitle("Performance")
    }

    private var tierNote: String {
        switch model.perf.tier {
        case .battery: "Half textures, 140 m draw distance, sparse grass, LOD0-only shadows, no wind. Long sessions."
        case .performance: "Steady 90 fps in dense outdoor scenes: LOD bias 0.75, 75% grass, batching, small casters off."
        case .balanced: "Library default. Renders and tests use it."
        case .ultra: "2K textures, LODs held 35% longer, LOD2 shadow casters, 1.5x shadow distance."
        case .cinematic: "4K textures, LOD bias 2. For captures; expect dropped frames on device."
        case nil: "Custom settings."
        }
    }

    private func bind<T: Equatable>(_ kp: WritableKeyPath<RealPerformance, T>) -> Binding<T> {
        Binding(get: { model.perf[keyPath: kp] }, set: { v in model.set { $0[keyPath: kp] = v } })
    }

    private func slider(_ title: String, _ kp: WritableKeyPath<RealPerformance, Float>, _ range: ClosedRange<Float>, _ fmt: String,
                        scale: Float = 1, zero: String? = nil) -> some View {
        let v = model.perf[keyPath: kp]
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(v == 0 && zero != nil ? zero! : String(format: fmt, v * scale)).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: bind(kp), in: range)
        }
    }
}

/// Live numbers from `RealityHD.stats`.
struct StatsGrid: View {
    var stats = RealityHD.stats
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
            GridRow { cell("fps", String(format: "%.0f", stats.fps)); cell("frame", String(format: "%.1f ms", stats.frameMs)); cell("worst", String(format: "%.1f ms", stats.worstFrameMs)) }
            GridRow { cell("triangles", "\(stats.triangles / 1000)k"); cell("draws", "\(stats.drawCalls)"); cell("instances", "\(stats.instances)") }
            GridRow { cell("casters", "\(stats.shadowCasters)"); cell("LOD switch/s", "\(stats.lodSwitches)"); cell("adaptive", String(format: "%.2f", stats.adaptiveScale)) }
            GridRow { cell("meshes", "\(stats.meshEntities)"); cell("textures", "\(stats.textureMB) MB"); Color.clear.gridCellUnsizedAxes([.horizontal, .vertical]) }
        }
        .font(.callout.monospacedDigit())
    }
    private func cell(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(k).font(.caption2).foregroundStyle(.secondary)
            Text(v)
        }
    }
}

/// Head-locked overlay shown inside the immersive space.
struct StatsHUD: View {
    var stats = RealityHD.stats
    var body: some View {
        Text(stats.summary)
            .font(.system(size: 18, weight: .medium, design: .monospaced))
            .padding(.horizontal, 16).padding(.vertical, 10)
            .glassBackgroundEffect()
    }
}
