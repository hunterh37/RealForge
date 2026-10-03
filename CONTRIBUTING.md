# Contributing

RealForge grows by small pull requests: one asset, one scene, one material or one engine change each.
Everything is Swift code that generates geometry and textures at load time, so a contribution is a
source file, a thumbnail and a regenerated `CATALOG.md`.

Coding agents: point yours at [AGENTS.md](AGENTS.md). It holds the same workflow in command form.

## Setup

Xcode 26 (Swift 6.2 tools) on macOS 26 with a Metal GPU.

```sh
git clone https://github.com/hunterh37/RealForge.git && cd RealForge
swift build && swift test
swift run -q realforge list
swift run -q realforge render park-bench    # writes out/park-bench.png
```

## Picking work

- [docs/IDEAS.md](docs/IDEAS.md) lists theme packs (assets, materials and a scene per theme) and engine
  work. Open an issue with the asset or scene template before starting anything large, so two people
  don't build the same pack.
- Issues labeled `asset`, `scene`, `material` and `engine` are open for claiming. Comment to claim one.

## Contribution types

| Type | Command | Guide | Touches |
|---|---|---|---|
| Prop, nature asset, structure | `realforge new prop <id> --theme <Folder>` | [assets](docs/guides/assets.md) | one file in `Sources/RealLibrary/<Kind>/<Theme>/`, registry line |
| Scene | `realforge new scene <id>` | [scenes](docs/guides/scenes.md) | one file in `Sources/RealLibrary/Scenes/`, registry line |
| Material on an existing program | `realforge new material <family.variant> --like <key>` | [materials](docs/guides/materials.md) | one entry in `Sources/RealMaterials/Library/<Family>.swift` |
| Texture program | by hand | [materials](docs/guides/materials.md) | `Shaders/<Family>Shaders.swift`, `TextureProgram` case, one material using it |
| Engine (RealCore, RealKit) | by hand | [DESIGN.md](DESIGN.md) | open an issue first |

Add `--author <github-handle>` to `realforge new` to be credited in `CATALOG.md`.

## Definition of done

`swift test` enforces most of this. Each failure message names the fix.

- Ids are kebab-case, unique across assets and scenes, and permanent once merged.
- `summary` is one finished sentence. `tags[0]` is the kind; every tag is in `Core/Tags.swift`
  (add new tags there in the same PR).
- Deterministic for a seed, finite geometry, base at y = 0, centered on X/Z, LOD0 within `budget`.
- Only `MaterialLibrary` keys. No image, mesh or USD files under `Sources/`.
- `docs/assets/<id>.png` or `docs/scenes/<id>.png` from `realforge thumbs <id>`.
- `CATALOG.md` regenerated (`realforge catalog`). CI fails when it is stale.
- Rendered and inspected: scale against a 1.8 m person, grounding, material scale, grain direction,
  bevels, no z-fighting, at two angles and the `golden` sky.

## Pull requests

Fill in the template: ids, the thumbnail, `realforge stats <id>` output. Keep unrelated changes out.
Reviewers check the render first, then the code. Expect requests about realism (bevels, wear, scale)
more than style.

## Code style

Swift 5 language mode, 4-space indent, 140-column soft limit, `///` doc comment on every public type
and on every knob a scene might tune. Value types, no singletons in generators, no `Date()` or system
randomness in `build(seed:)`. Comments state facts about the code.

## Licensing

Contributions are licensed under the MIT license ([LICENSE](LICENSE)). Model assets on generic
real-world objects. No trademarks, logos, brand liveries or copyrighted designs, and no geometry or
textures derived from third-party asset files or photos.

## Conduct

[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) applies to issues, pull requests and discussions.
