# Changelog

## Unreleased

- Library layout for contributors: one asset per file under `Nature/`, `Props/<Theme>/`, `Structures/`;
  per-kind registries; scenes in `Scenes/` behind `RealSceneBuilder` and `SceneCatalog.all`.
- `RealAsset.author`, `RealAsset.preview` (`PreviewHint`), controlled tag vocabulary (`AssetTag`).
- Materials split into `RealMaterials/Library/<Family>.swift`; Metal programs split into
  `Shaders/<Family>Shaders.swift` with dispatch generated from `TextureProgram`.
- Building helpers (`plank`, `board`, `turned`, `groundAO`, `catmull`, `Xform.jittered`) are public.
- `RealScene.add`, `RealScene.field`, `RealScene.worstCaseTriangles`, `RealInstancing.Options.trees`,
  `.groundCover(cull:)`.
- CLI: `realforge new` (asset, scene, material scaffolding), `realforge thumbs`; CLI split into files.
- Contract tests for assets, scenes and materials; CI with a stale-`CATALOG.md` check.
- Scene thumbnails moved to `docs/scenes/`. `prop-yard` grid sizes itself to `Props.all`.
- Docs: AGENTS.md, CONTRIBUTING.md, docs/IDEAS.md, guides for assets, scenes and materials.

## 0.1.0

- 21 assets, 3 scenes, 29 materials, ShaderGraph materials, sky, instancing, LOD, CLI.
