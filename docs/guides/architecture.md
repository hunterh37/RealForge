# Procedural buildings and districts

Source: `Sources/RealLibrary/Architecture/`. Everything an app saves (specs, styles, plans, city
blueprints) is Codable and Sendable. Same spec and seed build identical geometry.

```swift
var spec = BuildingSpec(footprint: .l(width: 20, depth: 16, legWidth: 8, barDepth: 9), floors: 4, style: "haussmann", seed: 3)
spec.facades = [FacadeOverride(facade: 0, bays: 7, doorBays: [3], windowTypes: [0: .storefront])]
spec.materials[.wall] = "rock.sandstone"
let b = BuildingGenerator.build(spec)
b.exterior            // LODModel: LOD0/1 with real openings, LOD2 solid shell
b.interiors           // [Model], one per floor: slabs, interior walls with door holes, thresholds, casings, stairs
b.combined()          // one LODModel for a scene (what `generated-building` returns)
b.plans               // [FloorPlan]: rooms, walls with openings, doors, stair core
print(b.schedule.summary)
```

## Spec

`BuildingSpec` fields: `footprint` (`.rect`, `.l`, `.u`, `.courtyard`, `.polygon`), `floors`,
`groundFloorHeight` / `typicalFloorHeight`, `bayWidth`, `roof` (`.flat` with parapet, `.gable`, `.hip`,
`.mansard`, `.gambrel`; nil takes the style's), `roofPitch`, `style`, `customStyle`, `facades`
(per-facade bay count, door bays, window type per floor, blank bays), `materials` (per `MaterialSlot`),
`pieces` (asset ids per `FacadeSlot`), `roomOverrides` (edited room lists per floor), `groundRaise`,
`interiors`, `openDoors`, `seed`. `spec.json()` / `BuildingSpec.from(json:)` save blueprints.

Facade indices follow `FootprintShape(spec.footprint).edges`: outer ring first, starting with the
front (+Z) edge for named shapes, then courtyard rings. Default bay counts round to odd numbers so the
door and corridor-end windows sit on the center bay.

## Styles

`ArchStyle.presets`: georgian, federal, italianate, beaux-arts, art-deco, haussmann, brownstone,
modernist. A style holds a palette, materials per slot, default roof, window types for ground and
upper floors, opening ratios (width of bay, height of floor), muntin grid, trim depth, surround,
door surround, corner treatment, cornice profile and blocks, belt and balcony floors, base height,
ground raise (stoop height) and the glazing target band. Styles use existing material keys with tints.

## Floor plans

`FloorPlanner(spec:)` lays out each rectangular wing: double-loaded corridor at 9 m deep or more,
single-loaded from 5.5 m, an enfilade below that. The stair core (switchback, 4.9 m or more along the
wing) sits at the start of the largest wing on every floor; corridor connectors join wings. Room strips
split by BSP on the bay grid so partitions land between windows. Typical floors share one layout.

`FloorPlan.deriveInterior` turns any room list into walls and doors: shared edges become one wall per
room pair, rooms get a door to an adjacent corridor, corridors meet through passages, and rooms not
reachable from the stair get a door to a reachable neighbor. Edit rooms (rename, resize, retype) and pass
them back through `spec.roomOverrides[floor]`.

## Facade pieces

`FacadePieceProvider` builds pieces per `FacadeSlot`: opening slots (`window`, `door`,
`windowSurround`, `doorSurround`, `corner`) in the opening frame (origin at the opening's bottom center
on the outer wall face, x along the facade, z out), run slots (`baseCourse`, `beltCourse`, `cornice`,
`attic`) as a `FacadeProfile` swept with mitered corners, and floor-band hooks (`groundFloor`,
`typicalFloor`). `FacadePieceRegistry` resolves `spec.pieces[slot]` by id: a registered builder, then a
catalog asset (scaled into the opening, or tiled along a run), then `ProceduralFacade`.

```swift
var reg = FacadePieceRegistry()
reg.register("double-hung-window") { ctx in myWindow(width: ctx.width, height: ctx.height) }
let b = BuildingGenerator(provider: reg).build(spec.with { $0.pieces[.window] = "double-hung-window" })
```

## Schedule

`BuildingSchedule`: `doorCount` (exterior + interior), `passages`, `windowsByType`, `windowCount`,
`rooms` (net area per room), `roomCount`, `grossFloorArea`, `netFloorArea`, `facadeArea`,
`glazingArea`, `glazingRatio`, `summary`.

## Districts

`CitySpec` is a grid of `CityCell` (road, sidewalk, lot, park, plaza) with `CityLot`s holding
building specs. `CitySpec.street(columns:)` makes one street; `addLot(_:spec:)` places a building.
`CityLayout(spec).compose(into: &scene)` adds the ground (asphalt, dashed center line, curbs, paving,
lawn), the buildings and street trees and lamps. Scene `city-block` (`CityBlock.district()`) shows
nine buildings in eight styles.

Cost: `generated-building` default is about 20k tris at LOD0 with interiors. `city-block` worst case
is about 770k (LOD and culling bring the street to a fraction of that).
