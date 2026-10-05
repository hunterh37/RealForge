import simd
import Foundation
import RealityKit
import RealKit

/// Layout of `cooking-counter` for apps (scene root space, meters). The counter run lies along X
/// against the north wall (-Z); the viewer stands at `viewer` facing -Z.
public enum CookingCounterLayout {
    /// Countertop surface height.
    public static let counterTopY: Float = 0.91
    /// Counter depth from the wall to the front edge.
    public static let counterDepth: Float = BaseCabinet().depth
    /// Wall face of the run (cabinet backs).
    public static let wallZ: Float = -1.7
    /// Z of the counter front edge.
    public static let counterFrontZ: Float = wallZ + counterDepth
    /// Run extent along X (cabinets and range).
    public static let runMinX: Float = -1.95
    public static let runMaxX: Float = 1.81
    /// Center of the clear prep area on the counter surface (y = counterTopY), directly in front of the viewer.
    public static let prepCenter = V3(0, counterTopY, counterFrontZ - counterDepth / 2)
    /// Clear prep area extent (x, z).
    public static let prepSize = V2(0.86, 0.58)
    /// Viewer feet (y = 0), 0.55 m back from the counter front, facing -Z.
    public static let viewer = V3(0, 0, counterFrontZ + 0.55)
    /// Eye height used by the scene camera.
    public static let eyeHeight: Float = 1.6

    /// Range placement: asset origin in scene space, yaw 0 (front faces +Z toward the viewer).
    public static let rangeOrigin = V3(0.83, 0, wallZ + KitchenRange().depth / 2)
    public static let rangeYaw: Float = 0
    /// Pan positions on the burners (grate top), scene space, knob order.
    public static var burnerCenters: [V3] { KitchenRange().burnerCenters.map { $0 + rangeOrigin } }
    /// Sink bowl opening center on the counter plane and the faucet deck hole, scene space.
    public static let sinkCabinetX: Float = -0.9
    public static var sinkCenter: V3 { BaseCabinet().with { $0.sinkCutout = true }.sinkCenter + V3(sinkCabinetX, 0, wallZ + counterDepth / 2) }

    /// Entity names of the live parts (`scene.findEntity(named:)`).
    public static let rangeName = "range"
    public static let hoodName = "range-hood"
    public static let faucetName = "faucet"
    public static let prepCabinetName = "cabinet-prep"
    public static let sinkCabinetName = "cabinet-sink"
    public static let cabinetNames = ["cabinet-left", "cabinet-sink", "cabinet-prep", "cabinet-right"]
    public static let wallCabinetNames = ["wall-cabinet-left", "wall-cabinet-prep", "wall-cabinet-right"]
}

/// Kitchen wall run seen by a standing cook: 4.2 x 3.4 m room, 2.7 m ceiling, oak plank floor. Along
/// the north wall, left to right: base cabinet, sink base with an undermount sink and pull-down faucet
/// under a window, the clear 90 cm prep counter in front of the viewer, a 30 in gas range under a
/// chimney hood, and a base cabinet; shaker wall cabinets above, subway tile backsplash. The prep
/// counter and the range top are empty for the app's cookware and food. Every fixture is live.
public struct CookingCounter: RealSceneBuilder {
    public static let id = "cooking-counter"
    public static let summary = "Kitchen wall run for a cooking sim: quartz counters, sink under a window, clear prep area, gas range and hood, shaker cabinets, subway tile."
    public static let tags = ["kitchen", "interior", "showcase"]
    public static let author = "realityhd"

    public var size = V3(4.2, 2.7, 3.4)
    /// Cabinet paint tint (sRGB hex), nil = white.
    public var cabinetColor: UInt32? = nil
    public init() {}

    typealias L = CookingCounterLayout
    static let window = (x: Float(-0.9), width: Float(0.9), sill: Float(1.07), head: Float(2.13))
    static let wallCabY: Float = 1.37

    /// A flat wall panel with world-space UVs (x, y), facing +Z at `z`.
    static func wallPanel(x0: Float, x1: Float, y0: Float, y1: Float, z: Float, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let n = V3(0, 0, 1)
        let a = s.add(V3(x0, y0, z), n, V2(x0, y0)), b = s.add(V3(x1, y0, z), n, V2(x1, y0))
        let c = s.add(V3(x1, y1, z), n, V2(x1, y1)), d = s.add(V3(x0, y1, z), n, V2(x0, y1))
        s.quad(a, b, c, d)
        s.computeTangents()
        return s
    }

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        let D = size.z, H = size.y, wz = L.wallZ
        precondition(abs(wz + D / 2) < 1e-4, "layout wallZ must match the room depth")
        var room = Room(size: size)
        room.floor = "floor.oak-plank"
        room.wall = "paint.wall:ECE7DD"
        room.ceiling = .flat
        room.skirting = "wood.painted-shaker"
        room.skirtingHeight = 0.1
        room.openings = [.init(.north, offset: Self.window.x, width: Self.window.width, sill: Self.window.sill, head: Self.window.head)]
        scene.add(room.shell(), bake: true)
        scene.add(room.ceilingModel())

        // Window over the sink.
        let win = OfficeWindow().with {
            $0.width = Self.window.width; $0.height = Self.window.head - Self.window.sill
            $0.frameMaterial = "wood.painted-shaker"; $0.handleMaterial = "metal.brushed-nickel"; $0.sillMaterial = "stone.quartz"; $0.sillDepth = 0.12
        }
        scene.add(win, at: place(Self.window.x, -D / 2 - room.wallThickness / 2, y: Self.window.sill), seed: seed &+ 1, state: "closed")

        // Base run (backs on the wall), left to right.
        func cabinet(_ w: Float, sink: Bool = false) -> BaseCabinet {
            BaseCabinet().with { $0.width = w; $0.sinkCutout = sink; $0.color = cabinetColor; $0.countertop = false }
        }
        let runs: [(String, Float, Float, Bool)] = [("cabinet-left", -1.65, 0.6, false), ("cabinet-sink", L.sinkCabinetX, 0.9, true),
                                                    ("cabinet-prep", 0, 0.9, false), ("cabinet-right", 1.51, 0.6, false)]
        for (i, (name, x, w, sink)) in runs.enumerated() {
            let c = cabinet(w, sink: sink)
            scene.addLive(c, at: place(x, wz + (c.depth) / 2), seed: seed &+ UInt64(10 + i), state: "closed", name: name)
        }
        // Filler between the left cabinet and the west wall.
        var trim = Model(name: "kitchen-trim")
        trim.add(Prim.roundedBox(V3(size.x / 2 + L.runMinX, 0.88 - 0.1, 0.019), radius: 0.002, bevelSegments: 1, material: "wood.painted-shaker"),
                 Xform(translation: V3((-size.x / 2 + L.runMinX) / 2, 0.1 + 0.39, wz + 0.604 - 0.0095)))
        // Continuous quartz tops (3 cm, eased, 2.5 cm overhang): west wall to the range with the sink
        // cutout, and range to the run end.
        let slabY = L.counterTopY - 0.03, cz = wz + L.counterDepth / 2
        let leftX0 = -size.x / 2, leftX1 = L.rangeOrigin.x - KitchenRange().width / 2
        let sinkTop = BaseCabinet().with { $0.sinkCutout = true }
        let lc = (leftX0 + leftX1) / 2
        var leftSlab = KitchenFit.counterSlab(width: leftX1 - leftX0 - 0.002, depth: L.counterDepth, thickness: 0.03, ease: 0.003, corner: 0.003,
                                              hole: (V2(L.sinkCenter.x - lc, L.sinkCenter.z - cz), sinkTop.sinkSize, sinkTop.sinkRadius), material: "stone.quartz")
        leftSlab.bakeCavityAO(strength: 0.3)
        trim.add(leftSlab, Xform(translation: V3(lc, slabY, cz)))
        let rightX0 = L.rangeOrigin.x + KitchenRange().width / 2
        var rightSlab = KitchenFit.counterSlab(width: L.runMaxX - rightX0 - 0.002, depth: L.counterDepth, thickness: 0.03, ease: 0.003, corner: 0.003, material: "stone.quartz")
        rightSlab.bakeCavityAO(strength: 0.3)
        trim.add(rightSlab, Xform(translation: V3((rightX0 + L.runMaxX) / 2, slabY, cz)))
        // Sink and faucet.
        let sinkCab = BaseCabinet().with { $0.sinkCutout = true }
        let sink = KitchenSink()
        let sc = L.sinkCenter
        scene.add(sink, at: place(sc.x, sc.z, y: sc.y - sinkCab.counterThickness - sink.flangeTopY), seed: seed &+ 20)
        let hole = V3(sc.x, L.counterTopY, sc.z - sinkCab.sinkSize.y / 2 - 0.05)
        scene.addLive(KitchenFaucet(), at: place(hole.x - KitchenFaucet.deckHole.x, hole.z - KitchenFaucet.deckHole.z, y: hole.y), seed: seed &+ 21, state: "off", name: L.faucetName)

        // Range and hood.
        let range = KitchenRange()
        scene.addLive(range, at: place(L.rangeOrigin.x, L.rangeOrigin.z, yaw: L.rangeYaw), seed: seed &+ 30, state: "off", name: L.rangeName)
        let hoodY = range.cooktopY + 0.75
        let hood = RangeHood().with { $0.chimneyHeight = H - hoodY - 0.055 - 0.26 }
        scene.addLive(hood, at: place(L.rangeOrigin.x, wz + hood.depth / 2, y: hoodY), seed: seed &+ 31, state: "lights-on", name: L.hoodName)

        // Wall cabinets (none over the window or the range).
        let walls: [(String, Float, Float)] = [("wall-cabinet-left", -1.65, 0.6), ("wall-cabinet-prep", 0, 0.9), ("wall-cabinet-right", 1.51, 0.6)]
        for (i, (name, x, w)) in walls.enumerated() {
            let c = WallCabinet().with { $0.width = w; $0.color = cabinetColor }
            scene.addLive(c, at: place(x, wz + c.depth / 2, y: Self.wallCabY), seed: seed &+ UInt64(40 + i), state: "closed", name: name)
            // Under-cabinet LED strip.
            trim.add(cuboid(V3(w - 0.08, 0.004, 0.014), material: "emissive.panel"), Xform(translation: V3(x, Self.wallCabY + 0.02, wz + 0.3 - 0.06)))
            scene.lights.append(RigLight(name: "under-cabinet-\(i + 1)", kind: .spot(inner: 55, outer: 85), position: V3(x, Self.wallCabY + 0.01, wz + 0.24),
                                         direction: V3(0, -1, 0.25), color: V3(1, 0.88, 0.74), intensity: 500, attenuationRadius: 1.6, castsShadow: false))
        }
        // Subway tile backsplash from the counter to the wall cabinets (to the hood behind the range,
        // to the sill under the window).
        let tz = wz + 0.004
        let top = L.counterTopY
        let splash: [(Float, Float, Float)] = [(L.runMinX, -1.35, Self.wallCabY), (-1.35, -0.45, Self.window.sill), (-0.45, 0.45, Self.wallCabY),
                                               (0.45, 1.21, hoodY + 0.02), (1.21, L.runMaxX, Self.wallCabY)]
        for (x0, x1, y1) in splash {
            trim.add(Self.wallPanel(x0: x0, x1: x1, y0: top, y1: y1, z: tz, material: "tile.subway"))
            // Tile edge: thin bullnose return at the open sides.
        }
        trim.add(cuboid(V3(L.runMaxX - L.runMinX, 0.008, 0.009), material: "tile.subway"), Xform(translation: V3((L.runMinX + L.runMaxX) / 2, top - 0.004 + 0.004, tz - 0.0045)))
        trim.add(cuboid(V3(0.009, Self.wallCabY - top, 0.009), material: "tile.subway"), Xform(translation: V3(L.runMaxX - 0.0045, (top + Self.wallCabY) / 2, tz - 0.0045)))
        scene.add(trim, bake: false)

        // Recessed ceiling downlights (plaster), two over the run.
        for x: Float in [-0.9, 0.9] {
            var can = Model(name: "downlight")
            can.add(Prim.lathe([V2(0.075, 0), V2(0.07, -0.002), V2(0.06, -0.002)], segments: 28, material: "metal.powdercoat:F2F2F0"), Xform(translation: V3(x, H, -0.8)))
            can.add(Prim.lathe([V2(0.06, -0.002), V2(0.001, -0.004)], segments: 24, material: "emissive.panel"), Xform(translation: V3(x, H + 0.002, -0.8)))
            scene.add(can)
            scene.lights.append(RigLight(name: "downlight-\(x < 0 ? "left" : "right")", kind: .spot(inner: 30, outer: 65), position: V3(x, H - 0.02, -0.8),
                                         direction: V3(0, -1, -0.35), color: V3(1, 0.86, 0.7), intensity: 3000, attenuationRadius: 5, castsShadow: x < 0))
        }

        // Garden outside the window.
        scene.add(MapleTree(), at: place(-2.6, -7.5, yaw: 40), seed: seed &+ 60)
        scene.add(BeechTree(), at: place(3.2, -11, yaw: 200), seed: seed &+ 61)
        for (i, x) in [Float(-2.4), 0.6].enumerated() { scene.add(Shrub(), at: place(x, -4.2, yaw: Float(i) * 70), seed: seed &+ UInt64(62 + i)) }
        scene.farGround = "ground.yard"
        scene.lighting = .init(sky: SunSky(elevation: 32, azimuth: 160, turbidity: 2.6), interior: InteriorLight.warm.with { $0.exposure = -0.25; $0.walls = SIMD3(0.55, 0.5, 0.44) }, fog: 0)
        scene.bake = .interior
        scene.batchStatics = true
        let eye = L.viewer + V3(0, L.eyeHeight, 0)
        scene.camera = .init(eye: eye, target: V3(0.15, L.counterTopY - 0.05, L.wallZ + 0.1), fov: 70)
        scene.spots = [RealScene.Spot("cook", eye: eye, target: V3(0, L.counterTopY, L.wallZ))]
        return scene
    }
}
