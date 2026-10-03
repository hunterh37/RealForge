import SwiftUI

struct MenuView: View {
    @Environment(DemoModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section("Scenes") {
                    ForEach(DemoScene.allCases) { scene in
                        Button { Task { await enter(scene) } } label: {
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
            .navigationTitle("RealForge")
        }
        .task {
            // Launch argument `-scene forest-glade` opens a scene directly (simulator checks, demos).
            if let id = UserDefaults.standard.string(forKey: "scene"), let scene = DemoScene(rawValue: id) { await enter(scene) }
        }
    }

    private func enter(_ scene: DemoScene) async {
        let config = SpaceConfig(scene: scene, sky: model.sky, seed: model.seed)
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
