# Changelog

## 3.0.0

Agent pipeline and photoreal props (see docs/V3.md).

- Quality gate: `realityhd gate` renders a six-view sheet, compares against a reference photo
  (Vision subject mask, silhouette IoU with camera search, feature-print similarity, Lab color,
  aspect, detail), lints geometry, scores a nine-criterion vision rubric and signs off
  (`briefs/signoff/<id>.json`, fingerprint-checked by tests). `Scripts/vision_judge.py` judges headless
  through the Claude API.
- CLI: `context`, `brief`, `lint`, `sheet`, `gate`; `new prop --brief`.
- Prop briefs (`briefs/<id>.json`, `PropBrief`), `GeometryLint`, `Rubric`, `Verdict`, `GateResult`, `Signoff`.
- Geometry kit: `Shape2D`, `Prim.extrude/sweep/loft/ring/superellipsoid/torus/helix/cylinder`, `Profile`,
  `Surface.deform/displace/subdivided/flipped`; hardware helpers `rivet`, `rivetRow`, `hexBolt`,
  `stitches`, `barHandle`, `chain`, `caster`, `panelWithBead`, `tuftedPanel`, `buttons`, `facing`, `resample`.
- Texture programs `leather`, `brushedMetal`, `polishedMetal`, `ceramicGlaze`, `caneWeave`; 29 craft material keys.
- Ten props: vintage-suitcase, chesterfield-armchair, bentwood-chair, anglepoise-lamp, copper-kettle,
  stoneware-crock, stone-lantern, ship-anchor, tool-chest, wicker-basket.
- `PreviewHint.studio` (concrete studio floor). Small lathes and tubes use their true circumference
  for U (no texture stretch on knobs and wires).
- Claude skills in `.claude/skills`: realityhd-prop, realityhd-brief, realityhd-gate, realityhd-material.
- Tags `leather`, `workshop`, `travel`, `antique`.

## Unreleased

- Library layout for contributors: one asset per file under `Nature/`, `Props/<Theme>/`, `Structures/`;
  per-kind registries; scenes in `Scenes/` behind `RealSceneBuilder` and `SceneCatalog.all`.
- `RealAsset.author`, `RealAsset.preview` (`PreviewHint`), controlled tag vocabulary (`AssetTag`).
- Materials split into `RealMaterials/Library/<Family>.swift`; Metal programs split into
  `Shaders/<Family>Shaders.swift` with dispatch generated from `TextureProgram`.
- Building helpers (`plank`, `board`, `turned`, `groundAO`, `catmull`, `Xform.jittered`) are public.
- `RealScene.add`, `RealScene.field`, `RealScene.worstCaseTriangles`, `RealInstancing.Options.trees`,
  `.groundCover(cull:)`.
- CLI: `realityhd new` (asset, scene, material scaffolding), `realityhd thumbs`; CLI split into files.
- Contract tests for assets, scenes and materials; CI with a stale-`CATALOG.md` check.
- Scene thumbnails moved to `docs/scenes/`. `prop-yard` grid sizes itself to `Props.all`.
- Docs: AGENTS.md, CONTRIBUTING.md, docs/IDEAS.md, guides for assets, scenes and materials.

## 0.1.0

- 21 assets, 3 scenes, 29 materials, ShaderGraph materials, sky, instancing, LOD, CLI.
