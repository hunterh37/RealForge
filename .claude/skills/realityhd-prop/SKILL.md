---
name: realityhd-prop
description: Build a photoreal RealityHD prop end to end (brief, scaffold, Swift build(seed:), lint, vision gate, sign-off, thumbnail, catalog). Use for any request to add, model, create or improve a prop, furniture piece, container, tool, fixture or decor object in this package, with or without a reference photo. Triggers on "new prop", "add a <thing> asset", "model a <thing>", "make it photoreal", "/realityhd-prop".
---

# RealityHD prop

Target: a prop that passes `realityhd gate` at its brief threshold (default 0.85) with an honest
verdict, in as few tokens as possible. Every CLI step prints one stat line; read files only when a
step names them.

## 0. Context (one call, no source browsing)

```sh
swift build -q && swift run -q realityhd context prop
```

This prints conventions, the geometry API, prop material keys (nature families hidden), existing
props by theme and the loop commands. After the brief exists, `context materials <family>` or
`context prop --brief <id>` reprints only the families the brief uses. Do not read `CATALOG.md`. Read one existing prop only if the API listing is not enough, and only the part needed:
`grep -n "func \|// " <file>` then Read with offset/limit
(`Props/Kitchen/CopperKettle.swift` lathe + tubes, `Props/Travel/VintageSuitcase.swift` extrude +
hardware + stitching + LOD1, `Props/Furniture/ChesterfieldArmchair.swift` tufted upholstery,
`Props/Furniture/BentwoodChair.swift` sweeps with grain along the path, `Props/Garden/StoneLantern.swift`
lofted stone, `Props/Workshop/ToolChest.swift` panels, pulls, casters, detail/lite LODs).

## 1. Brief

Run the `realityhd-brief` skill, or write `briefs/<id>.json` directly:
`swift run -q realityhd brief <id> --theme <Folder> --name "<name>"`, then fill `size` (real meters,
look the object up), `parts` (what a viewer can point at), `materials` (keys from the context list,
or new ones planned with `realityhd-material`), `style`, `budget`, `references`.

## 2. Scaffold and build

```sh
swift run -q realityhd new prop <id> --brief briefs/<id>.json
```

Write `build(seed:)`. Rules that decide the score:

- Size from the brief; centre X/Z, base at y = 0 (`m.bounds` then shift, as the kettle does).
- Pick the primitive by part shape: turned parts `turned`/`Prim.lathe`; flat parts with a profile
  `Prim.extrude` (fillet corners with `Shape2D.rounded`); rods, frames, rims, handles `Prim.sweep`
  (`grainAlongPath: true` for wood); changing sections `Prim.loft` + `Prim.ring`; cushions and caps
  `Prim.superellipsoid`; springs `Prim.helix`; upholstery `tuftedPanel` + `buttons`.
- Hardware helpers: `rivet`, `rivetRow`, `hexBolt`, `stitches`, `barHandle`, `chain`, `caster`.
- Bevel every edge at its real radius (1-10 mm). Inset touching parts 1-2 mm.
- Wear lives in materials: pick a worn variant (`leather.oxblood-worn`, `metal.enamel`,
  `metal.brass-aged`) for the parts hands and weather reach, a cleaner one elsewhere.
- One story detail per prop (chip, capacity mark, stain mismatch, fallen ring) lifts `wear` and
  `construction`.
- Over ~8k tris: return `LODModel(levels: [full, lite], switchDistances: [5])`, lite without
  stitches, rivets, bolts.
- Knobs: `public var` with `///` doc for dimensions, colors and material keys.

## 3. Loop

```sh
swift build -q 2>&1 | grep -E "error:|warning:" | sort -u; swift run -q realityhd lint <id>   # deduped diagnostics, then lint
swift run -q realityhd gate <id> [--ref briefs/refs/<id>/a.jpg]
```

Then run the `realityhd-gate` skill: Read `out/gate/<id>/sheet.png` (and `compare.png`), write the
verdict, gate with `--verdict`. On fail apply the top 1-3 fixes and gate again.

Token rules for the fix loop:
- Apply fixes with Edit on the affected lines; do not re-Read the whole prop file between runs.
  Locate parts with `grep -n "<part>" <file>`.
- Mid-loop checks of a local fix: `gate <id> --views hero,detail` (2 panels). The first gate run, any
  run whose verdict is scored for the final number, and `--signoff` use the full sheet.
- Do not Read `compare.png` again unless the fix changed the silhouette. Stop after 6
iterations and report the lowest criteria instead of inflating scores.

## 4. Ship

```sh
swift run -q realityhd gate <id> --verdict out/gate/<id>/verdict.json --no-sheet --signoff
swift run -q realityhd thumbs <id> && swift run -q realityhd catalog && swift test
```

`briefs/signoff/<id>.json` is committed; `QualityGate.signoffsAreCurrent` fails when the geometry
changes afterwards, so any later edit means a new gate run.

## Common fixes

| Sheet shows | Fix |
|---|---|
| Strap or band standing on edge | sweep profile axes swapped: profile x follows `up`, y the binormal |
| Hidden panel | single-sided grid facing inward; check the rotation sign, not the material |
| Texture scale wrong (lint `texel`) | small tube/lathe: lower `seamTile`; terrain: UVs must be meters |
| Kinked bends | fewer control points; build arcs analytically, then `catmull` |
| NaN crash in `recomputeNormals` | duplicate outline points: build outlines without repeats (`Shape2D.deduped`) |
| Plastic look | raise roughness, add normal strength, use a worn variant |
| Floating or sunk | lint `floating`/`sunk`; shift by `-bounds.min.y` |
