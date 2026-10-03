import SwiftUI
import RealKit
import RealLibrary

/// Scenes exposed by the demo. Each id is a `SceneCatalog` id.
enum DemoScene: String, CaseIterable, Identifiable, Codable, Hashable {
    case forestGlade = "forest-glade"
    case parkPath = "park-path"
    var id: String { rawValue }
    var title: String { self == .forestGlade ? "Forest Glade" : "Park Path" }
    var detail: String {
        switch self {
        case .forestGlade: "Mixed forest ringing a grassy glade, camp props along the edge."
        case .parkPath: "Asphalt walkway with benches, lamps, bins, shade trees and grass."
        }
    }
}

enum DemoSky: String, CaseIterable, Identifiable, Codable, Hashable {
    case morning, midday, afternoon, golden
    var id: String { rawValue }
    var sunSky: SunSky {
        switch self {
        case .morning: .morning
        case .midday: .midday
        case .afternoon: .afternoon
        case .golden: .goldenHour
        }
    }
}

struct SpaceConfig: Codable, Hashable {
    var scene: DemoScene
    var sky: DemoSky
    var seed: UInt64
    /// Extra heading in degrees (clockwise) applied after the scene's camera hint.
    var yaw: Float = 0
}

@Observable @MainActor
final class DemoModel {
    var sky: DemoSky = .afternoon
    var seed: UInt64 = 1
    var open: SpaceConfig?
    var loading = false
    var status = ""
}

@main
struct RealForgeDemoApp: App {
    @State private var model = DemoModel()
    @State private var style: ImmersionStyle = .full

    init() { RealForge.setup(.balanced) }

    var body: some Scene {
        WindowGroup(id: "menu") {
            MenuView().environment(model)
        }
        .windowStyle(.plain)
        .defaultSize(width: 560, height: 640)

        ImmersiveSpace(id: "space", for: SpaceConfig.self) { $config in
            if let config { ImmersiveSceneView(config: config).environment(model) }
        }
        .immersionStyle(selection: $style, in: .full)
    }
}
