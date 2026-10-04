import SwiftUI
import RealKit
import RealLibrary

/// Scenes exposed by the demo. Each id is a `SceneCatalog` id.
enum DemoScene: String, CaseIterable, Identifiable, Codable, Hashable {
    case forestGlade = "forest-glade"
    case parkPath = "park-path"
    case constructionLot = "construction-lot"
    case farmyard = "farmyard"
    case lakesideCamp = "lakeside-camp"
    case autumnWoods = "autumn-woods"
    case alpineMeadow = "alpine-meadow"
    case canyonRoad = "canyon-road"
    case winterForest = "winter-forest"
    case ballpark = "ballpark"
    case openOffice = "open-office"
    case executiveOffice = "executive-office"
    case officeLobby = "office-lobby"
    case conferenceRoom = "conference-room"
    case officePlaza = "office-plaza"
    case hospital = "hospital"
    case hospitalLobby = "hospital-lobby"
    case erRoom = "er-room"
    case operatingRoom = "operating-room"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .forestGlade: "Forest Glade"
        case .parkPath: "Park Path"
        case .constructionLot: "Construction Lot"
        case .farmyard: "Farmyard"
        case .lakesideCamp: "Lakeside Camp"
        case .autumnWoods: "Autumn Woods"
        case .alpineMeadow: "Alpine Meadow"
        case .canyonRoad: "Canyon Road"
        case .winterForest: "Winter Forest"
        case .ballpark: "Ballpark"
        case .openOffice: "Open Office"
        case .executiveOffice: "Executive Office"
        case .officeLobby: "Office Lobby"
        case .conferenceRoom: "Conference Room"
        case .officePlaza: "Office Plaza"
        case .hospital: "Hospital"
        case .hospitalLobby: "Hospital Lobby"
        case .erRoom: "ER Room"
        case .operatingRoom: "Operating Room"
        }
    }
    var detail: String {
        switch self {
        case .forestGlade: "Mixed forest ringing a grassy glade, camp props along the edge."
        case .parkPath: "Asphalt walkway with benches, lamps, bins, shade trees and grass."
        case .constructionLot: "Fenced building site: brick shell with scaffold, mixer, sandbags, cones on the street."
        case .farmyard: "Red barn corner, rail-fence paddock, hay bales and trough, grass and wildflower fields."
        case .lakesideCamp: "Tent, fire ring and canoe on a pond bank, ringed by spruce, pine and birch."
        case .autumnWoods: "Red maple, gold aspen, beech and oak over leaf litter, a dirt path winding through."
        case .alpineMeadow: "Flower meadow and pebble stream below a cliff band, conifers and peaks behind."
        case .canyonRoad: "Desert highway between sandstone buttes, saguaro and dunes."
        case .winterForest: "Snowy clearing in spruce and fir, drifts, fallen log and a woodpile."
        case .ballpark: "Stand in the batter's box: clay infield, striped turf, dugouts, bleachers, light towers."
        case .openOffice: "Bench desks, task chairs and screens under LED troffers, sun through ribbon windows. Tap doors, drawers, chairs."
        case .executiveOffice: "Walnut desk, banker's lamp, open book, bookcases, golden sun. Tap the lamp, book, laptop, drawers."
        case .officeLobby: "Terrazzo lobby, marble reception, elevator bank, glass street front. Tap the elevators and door."
        case .conferenceRoom: "Boardroom table, mesh chairs, wall display, glass partition and door."
        case .officePlaza: "Plaza between curtain-wall office blocks, maples in planters, benches and lamps."
        case .hospital: "ER floor: waiting lobby, treatment corridor, ER room and operating room. Pinch instruments to pick them up."
        case .hospitalLobby: "Waiting and intake lobby: kiosks, nurse station, beam seating, doors to treatment. Tap doors and kiosks."
        case .erRoom: "ER treatment room: stretcher, vitals monitor, IV pump, exam table, instrument counter. Grab the stethoscope."
        case .operatingRoom: "Operating room: surgical table under LED lights, anesthesia boom, draped back table with instruments."
        }
    }
    /// Sky picked when the scene is opened from the menu.
    var defaultSky: DemoSky? { self == .canyonRoad ? .golden : nil }
    /// Interiors and the plaza carry their own sun and probe; the menu sky is ignored for them.
    var usesSceneLighting: Bool { [.openOffice, .executiveOffice, .officeLobby, .conferenceRoom, .officePlaza, .hospital, .hospitalLobby, .erRoom, .operatingRoom].contains(self) }
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

    /// Package render settings, applied and saved on every edit (`RealityHD.performance`).
    var perf: RealPerformance = RealityHD.performance {
        didSet { RealityHD.performance = perf; perf.save() }
    }
    /// Settings the open scene was built with.
    var builtWith: RealPerformance?
    /// Bumped to rebuild the open scene in place.
    var rebuildToken = 0
    var showHUD = UserDefaults.standard.bool(forKey: "demo.hud") {
        didSet { UserDefaults.standard.set(showHUD, forKey: "demo.hud") }
    }

    /// Build-time settings changed since the open scene was built.
    var needsRebuild: Bool { open != nil && builtWith.map { perf.needsRebuild(from: $0) } == true }

    func select(_ tier: RealPerformance.Tier) {
        let adaptive = perf.adaptive
        perf = RealPerformance(tier).with { $0.adaptive = adaptive || $0.adaptive }
    }

    /// Edits one setting; the tier label drops to Custom.
    func set(_ edit: (inout RealPerformance) -> Void) {
        var p = perf
        edit(&p)
        guard p != perf else { return }
        p.tier = RealPerformance(p.tier ?? .balanced).with { $0.adaptive = p.adaptive } == p ? p.tier : nil
        perf = p
    }
}

@main
struct RealityHDDemoApp: App {
    @State private var model: DemoModel
    @State private var style: ImmersionStyle = .full

    init() {
        // Saved settings, then launch overrides: -tier battery|performance|balanced|ultra|cinematic -adaptive YES -hud YES
        RealityHD.setup(restoring: RealPerformance.defaultsKey, fallback: .balanced)
        let d = UserDefaults.standard
        if let t = d.string(forKey: "tier").flatMap(RealPerformance.Tier.init(rawValue:)) { RealityHD.performance = RealPerformance(t) }
        if d.object(forKey: "adaptive") != nil { RealityHD.performance.adaptive = d.bool(forKey: "adaptive") }
        if d.object(forKey: "hud") != nil { d.set(d.bool(forKey: "hud"), forKey: "demo.hud") }
        _model = State(initialValue: DemoModel())
    }

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
