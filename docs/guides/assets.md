# Writing an asset

An asset is a `RealAsset` value type: static metadata plus `build(seed:) -> LODModel`. Geometry is
generated on the CPU in milliseconds; materials are referenced by key and synthesized on the GPU.

## Kinds and folders

| Kind (`tags[0]`) | Folder | Registry | Budget cap | Examples |
|---|---|---|---|---|
| `nature` | `Nature/<Group>/` | `Nature.all` | 60k | trees, rocks, ground, grass, flowers |
| `prop` | `Props/<Theme>/` | `Props.all` | 15k | furniture, containers, street furniture, tools |
| `structure` | `Structures/<Theme>/` | `Structures.all` | 30k | fences, walls, stairs, sheds, bridges |

Theme folders group by setting (`Street`, `Containers`, `Construction`, `Kitchen`). Create a folder
when a theme pack starts; `realforge new prop <id> --theme Construction` does it.

## Anatomy

```swift
/// Builder's wheelbarrow, 1.45 m long: steel tray, tubular frame, pneumatic wheel.
public struct Wheelbarrow: RealAsset {
    public static let id = "wheelbarrow"
    public static let summary = "Builder's wheelbarrow: pressed steel tray, tubular frame, rubber wheel, wooden grips."
    public static let tags = ["prop", "construction", "metal", "tool"]
    public static let budget = 8_000
    public static let author = "your-handle"
    public static let preview = PreviewHint(azimuth: 120, elevation: 18)   // optional

    public var trayColor: UInt32 = 0x2E6B3A      // knobs scenes can tune
    public var trayDepth: Float = 0.32
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // ... Prim / plank / board / turned / tube calls, each with a material key ...
        groundAO(&m)
        return LODModel(m)
    }
}
```

Every stored property is a knob. Name it, document it with `///`, give it a real-world default. Scenes
and apps edit knobs with `Wheelbarrow().with { $0.trayColor = 0x8C1F1F }`.

## Patterns in the existing library

| Need | Read |
|---|---|
| Lathe body, grooves, hoops | `Props/Containers/Barrel.swift` |
| Tinted paint with a key suffix | `Props/Containers/OilDrum.swift` (`"metal.painted:\(hex)"`) |
| Boards and frames, per-part jitter | `Props/Containers/WoodenCrate.swift`, `Props/Industrial/Pallet.swift` |
| Bent tubes, cast iron | `Props/Furniture/ParkBench.swift` (`catmull`, `Prim.tube`) |
| Emissive parts | `Props/Street/StreetLamp.swift` (`glass.lamp`) |
| Displaced solid with LODs | `Nature/Rocks/Boulder.swift` (`Prim.cubeSphere`, 3 LODs) |
| Instanced cards with wind | `Nature/Ground/GrassClump.swift` |
| New tree species | `Nature/Trees/Species.swift` (`TreeSpecies`), then a 9-line asset like `OakTree.swift` |

## Photoreal checklist

Lighting does most of the work, so geometry and materials have to give it something to catch.

- Real dimensions. Look up the object; put sizes in the summary or doc comment.
- Bevel every hard edge (`Prim.roundedBox(radius:)`, `plank(bevel:)`). Specular highlights on edges are
  what make CG read as a real object.
- Nothing CAD-perfect: `xform.jittered(&rng)` on assembled parts, per-board width and gap variation,
  slight lean on posts.
- Wear where hands and weather reach: material knobs (`paintedMetal` chips and dirt, `woodPlank`
  weathering), darker AO in crevices.
- Contact shadow: `groundAO(&m)` for props, baked occlusion toward the base for nature.
- Cavity AO: `surface.bakeCavityAO()` on concave shapes (`groundAO` calls it).
- Material scale: UVs are meters, so a 1 m board shows one wood repeat at `tileSize = 1`. Check the
  render; grain lines should be millimeters apart.
- Wood grain along the board: build boards along +X with `plank`/`board`; lathes take `grainVertical`.
- No coplanar faces (z-fighting) and no visible open edges. Inset overlapping parts by 1 to 2 mm.
- Seeds vary size, wear placement and part counts within believable ranges (`rng.vary(x, 0.1)`).

## LODs and budgets

`budget` is the LOD0 triangle ceiling; tests fail above it. Set it about 20 percent over the actual
count so small tweaks don't fail CI.

- Props under ~5k triangles ship one level: `LODModel(m)`.
- Anything heavier, or anything that scenes instance by the dozen, ships 2 to 3 levels with
  `LODModel(levels:switchDistances:)`. Each level at most half the previous. Drop bevel segments,
  small parts and lathe segments first.
- Structures that tile (fences, rails, walls) snap on a 0.5 m grid along X with the origin at one end's
  base center, so scenes can repeat them with `place(x + i * length, z)`.

## Wind and foliage

Set `extra.x` per vertex (0 at the anchor, 1 at the tip) on anything that should sway, and use a
material with `wind > 0`. Foliage uses alpha cards with an atlas material (`tileSize = 0`, UVs 0...1),
and crown-sphere normals for volumetric shading; `TreeGenerator` shows both.

## Checking it

```sh
swift test --filter AssetContractTests
swift run -q realforge render wheelbarrow                    # out/wheelbarrow.png
swift run -q realforge render wheelbarrow --az 210 --el 35 --sky golden
swift run -q realforge render wheelbarrow --lod 1            # each LOD
swift run -q realforge stats wheelbarrow
swift run -q realforge thumbs wheelbarrow && swift run -q realforge catalog
```
