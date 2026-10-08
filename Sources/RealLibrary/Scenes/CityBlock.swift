import simd
import Foundation
import RealKit

/// One street of generated buildings in eight styles side by side (brownstones, Georgian, Italianate,
/// Haussmann, Art Deco, Beaux-Arts, Modernist), composed from a `CitySpec` with street trees and lamps.
public struct CityBlock: RealSceneBuilder {
    public static let id = "city-block"
    public static let summary = "Street of procedurally generated buildings in eight styles, sidewalks, asphalt road, street trees and lamps."
    public static let tags = ["urban", "street", "outdoor", "showcase"]
    public static let author = "realityhd"
    public init() {}

    /// The district blueprint (lots, road, buildings) the scene composes.
    public static func district(seed: UInt64 = 1) -> CitySpec {
        var city = CitySpec.street(columns: 33, lotDepth: 6)
        city.seed = seed
        // (style, width cells, floors, depth m, roof)
        let row: [(String, Int, Int, Float, RoofType?)] = [
            ("brownstone", 2, 4, 13, nil), ("brownstone", 2, 4, 13, nil), ("georgian", 4, 3, 11, .hip), ("italianate", 3, 4, 13, nil),
            ("haussmann", 6, 6, 14, nil), ("art-deco", 5, 9, 14, nil), ("beaux-arts", 5, 5, 14, nil), ("modernist", 4, 8, 12, nil), ("federal", 2, 3, 10, .gable),
        ]
        var col = 0
        for (i, (style, w, floors, depth, roof)) in row.enumerated() {
            let st = ArchStyle.named(style)!
            var b = BuildingSpec(footprint: .rect(width: Float(w) * city.cellSize - 0.02, depth: depth), floors: floors, style: style, seed: UInt64(i + 1))
            b.name = "\(style)-\(i)"
            b.roof = roof
            b.bayWidth = style == "modernist" ? 1.5 : (w <= 2 ? 2.0 : 3.0)
            if st.groundWindow == .storefront { b.groundFloorHeight = 4.4 }
            if style == "haussmann" { b.typicalFloorHeight = 3.2 }
            if style == "brownstone" { b.facades = [FacadeOverride(facade: 0, bays: 3, doorBays: [0])] }
            let setback: Float = style == "brownstone" ? 2.9 : (st.groundRaise > 0.3 ? 0.9 : 0)
            city.addLot(CityLot(column: col, row: 0, width: w, depth: 6, building: nil, facing: .south, setback: setback), spec: b)
            col += w
        }
        return city
    }

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        let city = Self.district(seed: seed)
        let layout = CityLayout(city)
        layout.compose(into: &scene)
        var rng = SeededRNG(seed: seed &+ 5)
        let sw = layout.cellRect(0, 6)
        scene.field(Bollard(), seed: seed, transforms: stride(from: Float(-40), through: 40, by: 7).map { place($0 + rng.float(-0.2...0.2), sw.max.y - 0.35, y: 0.15).matrix }, options: .props)
        scene.add(FireHydrant(), at: place(-21, sw.max.y - 0.5, y: 0.15, yaw: 20), seed: seed &+ 1)
        scene.add(TrashCan(), at: place(8, sw.max.y - 0.6, y: 0.15), seed: seed &+ 2)
        scene.add(Mailbox(), at: place(-6, sw.max.y - 0.6, y: 0.15, yaw: 180), seed: seed &+ 3)
        let far = layout.cellRect(0, 10)
        for x in stride(from: Float(-42), through: 42, by: 9) {
            scene.add(ParkBench(), at: place(x + 4, far.center.y + 0.6, y: 0.12, yaw: 180), seed: seed &+ 4)
        }
        scene.farGround = "ground.meadow"
        scene.lighting = .init(sky: SunSky(elevation: 32, azimuth: 205, turbidity: 2.4))
        let eyeZ = layout.cellRect(0, 10).center.y - 1
        scene.camera = .init(eye: V3(-34, 1.7, eyeZ + 2), target: V3(6, 8, layout.cellRect(0, 5).center.y), fov: 66)
        return scene
    }
}
