# Articulated assets

An articulated asset has moving parts and named states: a door (closed, ajar, open), a filing
cabinet (each drawer open), a laptop (closed, open, on), a lamp (off, on). It conforms to
`RealArticulated` and implements `rig(seed:) -> Rig`. `build(seed:)` comes for free: the default state
baked into a static `LODModel`, so thumbnails, the prop yard, budgets and instancing treat it like any
other asset.

## Rig

```swift
public struct PedalBin: RealArticulated {
    public func rig(seed: UInt64) -> Rig {
        var rig = Rig(name: Self.id, lods: 2, switchDistances: [6])
        rig.base[0].add(body, xform)                                   // static geometry per LOD
        rig.part("pedal", pivot: V3(0, 0.03, 0.14), joint: .hinge(axis: V3(1, 0, 0), -12...0))
        rig.part("lid", pivot: V3(0, 0.62, -0.15),
                 joint: Joint(.revolute, axis: V3(1, 0, 0), range: -78...0, mimic: .init("pedal", ratio: 6.5)))
        rig.add(pedalSurface, xform, to: "pedal")                      // asset space, at rest
        rig.add(lidSurface, xform, to: "lid")
        rig.states = [RigState("closed"), RigState("open", ["pedal": -12])]
        groundAO(&rig, height: 0.1)
        return rig
    }
}
```

- Geometry is authored in asset space at rest (every joint 0, every option 0), the same way a static
  prop is built. The rig bakes each part's pivot out at upload.
- `.hinge(axis:range)` rotates in degrees about the axis through `pivot`; `.slide(axis:range)` moves in
  meters. Right-hand rule. `frame:` rotates the pivot frame when an axis is easier to state locally.
- `parent:` chains parts (window tilt, then sash turn, then handle). Declare parents first.
- `mimic` makes a joint follow another linearly: bin lid from pedal, bi-parting elevator doors
  (ratio -1), a slide's middle member (ratio 0.5), page fans in a book. States never set mimic joints.
- `options:` gives a part alternate geometry (lamp bulb off/on, screen off/desktop). `RigLight` adds a
  point or spot light that rides on a part and is on while that part shows a given option.
- `RigState(name, joints, options:)`. The first state is the default unless `defaultState` says
  otherwise. Unmentioned joints and options sit at 0.
- `lods: 0...0` on `rig.add` keeps small detail out of LOD1.

## Runtime

```swift
let cabinet = try await RealityHD.articulated("filing-cabinet", state: "closed", interactive: true)
cabinet.setArticulation("drawer2-open")            // animated (eased; durations from the joints)
cabinet.setJoints(["drawer3": 0.3])                // direct values, mimics follow
cabinet.nextArticulation()
// SwiftUI: tap a part to swing that joint between closed and its most-open state
.gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { $0.entity.realToggle() })
```

Each part is one entity (`joint:<name>`) whose transform is the joint pose; meshes are uploaded once.
`RealArticulationSystem` only touches joints with a tween in progress. LOD switching covers the whole
hierarchy from the root (`RealLODComponent` on the root, `lod<n>` children under every part).

In scenes: `scene.addLive(asset, at:, seed:, state:, interactive:)` keeps it live;
`scene.add(asset, at:, seed:, state:)` bakes one state into a static single (batched);
`scene.field(asset, seed:, state:, transforms:)` instances one baked state (rows of chairs).

## Checking

```sh
swift run -q realityhd states <id>                  # out/states/<id>.png, every state through the live rig
swift run -q realityhd render <id> --state open     # one baked state
swift test --filter ArticulationTests               # validate(), budgets per state, determinism
```

`Rig.validate()` reports: fewer than two states, identical states, values outside joint ranges, unknown
joints/options, mimic targets that do not exist, lights on unknown parts.
