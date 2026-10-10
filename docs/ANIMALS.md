# RealityHD-Animals

Procedural, rigged, animated animals for RealityKit, built on RealityHD. No mesh, texture or audio files ship.

- 10 birds: eastern bluebird, northern cardinal, blue jay, American goldfinch, American robin, black-capped
  chickadee, Baltimore oriole, mourning dove, ruby-throated hummingbird, cedar waxwing.
- 4 ground animals: eastern cottontail, eastern gray squirrel, eastern chipmunk, European hedgehog.
- Each bird is a `Rig` of about 40 joints with individual feather cards (primaries, secondaries, coverts, tail).
  Wings fold, flap, flare and hover; legs grip; jaw, lids and crest move.
- Birds fly in, flare and land on perches taken from the props' own geometry (feeder tray, bath rim, fence
  rails, arch tops, tree branches), feed, drink, sing, preen, hop and leave. An open palm held still brings
  trusting birds in to land on it.
- Habitat score, visit scheduler, journal with trust levels and rewards.

Modules: `AnimalCore` (headless logic and geometry), `AnimalKit` (RealityKit rigs, `WildlifeWorld`, procedural
voices), `RealityHDAnimals` (umbrella), `animalpreview` (contact sheets).

```swift
import RealityHDAnimals
let world = WildlifeWorld(journal: saved)
yardRoot.addChild(world.root)
world.setPlacements(items)                       // perches and habitat from placed props
world.tick(dt: dt, input: .init(head: head, headSpeed: v, palm: palmReading))
```

Texture programs `plumageBody`, `plumageHead`, `plumageFeather`, `furCoat`, `quillCoat` live in RealityHD
(`FaunaShaders.swift`). Preview: `swift run animalpreview eastern-bluebird --pose up`.
