import SwiftUI

struct MenuView: View {
    @Environment(DemoModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    /// Capture mode: the window stays open (dismissing it recenters the simulator view) but draws nothing.
    @State private var hidden = UserDefaults.standard.bool(forKey: "hideMenu")

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section("Scenes") {
                    ForEach(DemoScene.allCases) { scene in
                        Button {
                            if let sky = scene.defaultSky { model.sky = sky }
                            Task { await enter(scene) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(scene.title).font(.headline)
                                    Text(scene.detail).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if model.open?.scene == scene { Image(systemName: "visionpro").foregroundStyle(.tint) }
                            }
                        }
                        .disabled(model.loading)
                    }
                }
                Section("Lighting") {
                    Picker("Sky", selection: $model.sky) {
                        ForEach(DemoSky.allCases) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Stepper("Seed \(model.seed)", value: $model.seed, in: 1...99)
                }
                if model.open != nil {
                    Section {
                        Button("Exit Scene", role: .destructive) { Task { await exit() } }
                    }
                }
                if !model.status.isEmpty {
                    Section { Text(model.status).font(.footnote.monospaced()).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("RealityHD")
        }
        .opacity(hidden ? 0 : 1)
        .glassBackgroundEffect(displayMode: hidden ? .never : .always)
        .persistentSystemOverlays(hidden ? .hidden : .automatic)
        .task {
            // Launch arguments for captures: -scene forest-glade -sky golden -seed 2 -yaw -30 -hideMenu YES
            let d = UserDefaults.standard
            guard let id = d.string(forKey: "scene"), let scene = DemoScene(rawValue: id) else { return }
            if let sky = d.string(forKey: "sky").flatMap(DemoSky.init(rawValue:)) ?? scene.defaultSky { model.sky = sky }
            if d.integer(forKey: "seed") > 0 { model.seed = UInt64(d.integer(forKey: "seed")) }
            await enter(scene, yaw: d.float(forKey: "yaw"))

        }
    }

    private func enter(_ scene: DemoScene, yaw: Float = 0) async {
        let config = SpaceConfig(scene: scene, sky: model.sky, seed: model.seed, yaw: yaw)
        if model.open != nil { await dismissSpace(); model.open = nil }
        switch await openSpace(id: "space", value: config) {
        case .opened: model.open = config
        case .userCancelled: model.status = "cancelled"
        case .error: model.status = "openImmersiveSpace failed"
        @unknown default: break
        }
    }

    private func exit() async {
        await dismissSpace()
        model.open = nil
    }
}
