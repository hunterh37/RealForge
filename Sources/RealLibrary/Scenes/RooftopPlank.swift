import simd
import Foundation
import RealityKit
import RealKit

/// Height-exposure set piece: a 30 cm scaffold board spanning the gap between the parapets of two
/// 40-storey curtain-wall towers set corner to corner, with a boarded steel deck on each roof level with the board. Around
/// them a downtown grid of instanced office blocks (low near the towers so the drop reads, a taller
/// skyline toward the haze), paved lots, asphalt streets with lane markings and traffic. No trees.
///
/// Scene units: street at y = 0, walking surface at `walkY`. Apps that put the participant's floor at
/// y = 0 translate the scene root by `-start`.
public struct RooftopPlank: RealSceneBuilder {
    public static let id = "rooftop-plank"
    public static let summary = "Scaffold board across the gap between two 40-storey glass towers, steel decks on both roofs, a downtown grid and traffic 150 m below."
    public static let tags = ["urban", "outdoor", "showcase"]
    public static let author = "hunter"

    /// Clear gap between the two facades (m). The walk is this plus the two copings.
    public var gap: Float = 4.6
    public var floors = 40
    public var plankWidth: Float = 0.3
    public var plankThick: Float = 0.05
    /// City grid: lot pitch and radius (m).
    public var pitch: Float = 50
    public var radius: Float = 640
    public init() {}

    /// Tower footprint (square) and how far the two footprints overlap along X. The board runs in the
    /// overlap strip, so one side of it looks straight down past the near tower's corner to the street.
    public var towerSize: Float = 24
    public var overlap: Float = 3
    var tower: OfficeBlock { OfficeBlock().with { $0.floors = floors; $0.width = towerSize; $0.depth = towerSize } }
    /// Tower centers sit at -/+ this X, the board at X = 0.
    var towerX: Float { (towerSize - overlap) / 2 }
    var roofY: Float { tower.groundHeight + Float(floors - 1) * tower.floorHeight }
    /// Top of the parapet coping.
    var copingTop: Float { roofY + 1.26 }
    /// Walking surface: top of the board and of both decks.
    public var walkY: Float { copingTop + plankThick }
    /// Where the participant starts: on the near deck, 0.6 m back from the board, facing -Z.
    public var start: V3 { V3(0, walkY, gap / 2 + 0.18 + 0.6) }
    /// Far end of the board (start of the far deck).
    public var finish: V3 { V3(0, walkY, -(gap / 2 + 0.18)) }

    public func build(seed: UInt64) -> RealScene {
        var scene = RealScene(name: Self.id)
        var rng = SeededRNG(seed: seed &+ 77)
        let D = towerSize
        // Hero towers, corner to corner, entrances facing away from the gap.
        scene.add(tower, at: place(-towerX, gap / 2 + D / 2, yaw: 0), seed: seed &+ 1)
        scene.add(tower, at: place(towerX, -(gap / 2 + D / 2), yaw: 180), seed: seed &+ 2)

        // Board: bears 0.17 m on each coping.
        var walk = Model(name: "plank")
        let len = gap + 0.34
        walk.add(plank(len, plankWidth, plankThick, bevel: 0.006, material: "wood.weathered"),
                 Xform(translation: V3(0, copingTop + plankThick / 2, 0), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 1, 0))))
        // Decks: boards on a galvanized frame, legs down to the roof slab (roof top = roofY + 0.4).
        let deckLen: Float = 3.4, deckW: Float = 2.2
        let legH = walkY - plankThick - (roofY + 0.4)
        for sgn: Float in [1, -1] {
            let z0 = sgn * (gap / 2 + 0.19)
            let zc = z0 + sgn * deckLen / 2
            var x = -deckW / 2 + 0.11
            while x < deckW / 2 {
                walk.add(plank(deckLen, 0.21, plankThick, bevel: 0.004, material: "wood.weathered"),
                         Xform(translation: V3(x, walkY - plankThick / 2, zc), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 1, 0))))
                x += 0.215
            }
            for bx: Float in [-deckW / 2 + 0.05, deckW / 2 - 0.05] {
                walk.add(Prim.roundedBox(V3(0.06, 0.08, deckLen), radius: 0.004, bevelSegments: 1, material: "metal.galvanized"),
                         Xform(translation: V3(bx, walkY - plankThick - 0.04, zc)))
                for dz: Float in [0.15, deckLen / 2, deckLen - 0.15] {
                    walk.add(Prim.cylinder(radius: 0.024, height: legH - 0.08, bevel: 0.003, segments: 10, material: "metal.galvanized"),
                             Xform(translation: V3(bx, roofY + 0.4, z0 + sgn * dz)))
                    walk.add(Prim.roundedBox(V3(0.15, 0.008, 0.15), radius: 0.002, bevelSegments: 1, material: "metal.galvanized"),
                             Xform(translation: V3(bx, roofY + 0.404, z0 + sgn * dz)))
                }
            }
        }
        for i in walk.surfaces.indices { walk.surfaces[i].bakeCavityAO(strength: 0.35, floor: 0.75) }
        scene.add(walk)

        // City grid. Lots inside the hero block stay empty; near lots stay low so the drop reads.
        // Height variants, each with its own facade so the skyline is not one building repeated.
        struct Look { var glass: MaterialKey; var frame: MaterialKey; var spandrel: MaterialKey }
        let looks: [Look] = [
            Look(glass: "glass.curtain", frame: "metal.anodized-black", spandrel: "metal.anodized-black"),
            Look(glass: "glass.curtain:2B2722", frame: "metal.painted:4A3F33", spandrel: "concrete.smooth"),
            Look(glass: "glass.curtain:1C2C36", frame: "metal.anodized", spandrel: "metal.anodized"),
            Look(glass: "glass.curtain:3A4148", frame: "metal.painted:C9C3B5", spandrel: "rock.granite-bare"),
        ]
        let shapes: [(floors: Int, w: Float, d: Float, look: Int)] = [
            (4, 26, 18, 3), (7, 30, 20, 1), (7, 28, 22, 0), (11, 28, 24, 3), (16, 26, 26, 2),
            (24, 32, 28, 0), (33, 32, 32, 1), (45, 34, 34, 2), (56, 36, 36, 0),
        ]
        let variants: [OfficeBlock] = shapes.map { sh in
            let l = looks[sh.look]
            return OfficeBlock().with {
                $0.floors = sh.floors; $0.width = sh.w; $0.depth = sh.d
                $0.glassMaterial = l.glass; $0.frameMaterial = l.frame; $0.spandrelMaterial = l.spandrel
            }
        }
        var lots: [[simd_float4x4]] = Array(repeating: [], count: variants.count)
        var pads = Model(name: "lots")
        let n = Int(radius / pitch)
        for i in -n...n { for j in -n...n {
            let c = V2(Float(i) * pitch, Float(j) * pitch)
            let r = simd_length(c)
            guard r <= radius else { continue }
            pads.add(Prim.terrain(size: V2(pitch - 13, pitch - 13), segments: 1, material: "paving.slab") { _ in 0.15 }, Xform(translation: V3(c.x, 0, c.y)))
            if i == 0 && abs(j) <= 1 { continue }                 // hero towers' block
            if rng.chance(0.12) { continue }                       // plaza or parking lot
            let pool: ClosedRange<Int> = r < 120 ? 0...4 : r < 300 ? 0...6 : 3...8
            var v = rng.int(pool)
            if r >= 300 && rng.chance(0.35) { v = max(v, rng.int(6...8)) }
            let yaw = Float(rng.int(0...3)) * 90
            let jitter = V2(rng.float(-2...2), rng.float(-2...2))
            lots[v].append(place(c.x + jitter.x, c.y + jitter.y, y: 0.12, yaw: yaw).matrix)
        }}
        for (k, v) in variants.enumerated() where !lots[k].isEmpty {
            scene.field(v, seed: seed &+ UInt64(100 + k), transforms: lots[k],
                        options: RealInstancing.Options.props.with { $0.cellSize = 640; $0.tintJitter = 0.06 })
        }
        scene.add(pads)

        // Lane markings and traffic on every street (streets run along X and Z between lot rows).
        var marks = Model(name: "markings")
        var cars: [MaterialKey: Model] = [:]
        let paints: [MaterialKey] = ["metal.painted:D8D8D4", "metal.painted:1C1D20", "metal.painted:7A7E84",
                                     "metal.painted:8C1C1A", "metal.painted:1F3A66", "metal.painted:D9B21C"]
        let extent = Float(n) * pitch
        for k in -n...(n - 1) {
            let s = (Float(k) + 0.5) * pitch
            for alongX in [true, false] {
                var t = -extent
                while t < extent {
                    let p = alongX ? V3(t, 0.01, s) : V3(s, 0.01, t)
                    if simd_length(V2(p.x, p.z)) < radius {
                        let size = alongX ? V2(3, 0.15) : V2(0.15, 3)
                        marks.add(Prim.terrain(size: size, segments: 1, material: "plastic.matte:E6E4DC") { _ in 0 }, Xform(translation: p))
                    }
                    t += 9
                }
                var u = -extent + rng.float(0...20)
                while u < extent {
                    let lane: Float = rng.chance(0.5) ? 2.2 : -2.2
                    let p = alongX ? V2(u, s + lane) : V2(s + lane, u)
                    if simd_length(p) < radius * 0.92 {
                        let yaw: Float = (alongX ? 90 : 0) + (lane > 0 ? 180 : 0)
                        let paint = paints[rng.int(0...paints.count - 1)]
                        cars[paint, default: Model(name: "cars")].add(Self.car(paint: paint), place(p.x, p.y, yaw: yaw))
                    }
                    u += rng.float(14...46)
                }
            }
        }
        scene.add(marks)
        for key in paints { if let m = cars[key] { scene.add(m) } }

        scene.farGround = "asphalt"
        var sky = SunSky(elevation: 34, azimuth: 215, turbidity: 2.6)
        sky.fogDensity = 0.0022
        sky.shadowDistance = 60
        scene.lighting = .init(sky: sky)
        scene.camera = .init(eye: start + V3(0, 1.65, 0), target: V3(0, walkY - 30, -gap * 4), fov: 70)
        scene.spots = [.init("street", eye: V3(25, 1.7, 25), target: V3(0, 120, 0)),
                       .init("mid-plank", eye: V3(0, walkY + 1.65, 0), target: V3(0, 0, -6))]
        return scene
    }

    /// Sedan for traffic seen from 150 m: body box and dark glasshouse, 24 triangles.
    static func car(paint: MaterialKey) -> Model {
        var m = Model(name: "car")
        m.add(cuboid(V3(1.8, 0.72, 4.5), material: paint), Xform(translation: V3(0, 0.62, 0)))
        m.add(cuboid(V3(1.6, 0.5, 2.3), material: "plastic.gloss:15181C"), Xform(translation: V3(0, 1.22, -0.15)))
        return m
    }
}
