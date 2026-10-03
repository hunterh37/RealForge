---
name: realityhd-brief
description: Turn a prop request, a reference photo or a product page into a RealityHD brief (briefs/<id>.json) with real dimensions, a part list, material keys, style, budget and the reference camera. Use before modeling any new prop, or when a user supplies a photo to match. Triggers on "brief", "spec this prop", "here is a photo of", "/realityhd-brief".
---

# RealityHD brief

```sh
swift run -q realityhd brief <id> --theme <Folder> --name "<plain name>"
swift run -q realityhd context materials          # keys to choose from
```

Fill `briefs/<id>.json`:

| field | how |
|---|---|
| `id` | kebab-case, permanent once merged; check `realityhd list` |
| `summary` | one sentence, at most 160 chars, ends with a period; becomes `RealAsset.summary` |
| `tags` | `prop` first, then theme and material tags from `AssetTag.vocabulary` |
| `size` | overall meters [x width, y height, z depth] as it will stand, including handles and cables; look the real object up |
| `tolerance` | 0.08 default; 0.15 for soft or posable things |
| `parts` | 5-10 parts a viewer can point at, with their defining shape ("scroll-rolled arm fronts") |
| `materials` | existing keys; mark planned ones and build them with `realityhd-material` |
| `style` | era, finish, condition, where it shows wear |
| `budget` | LOD0 triangles, about 20 percent over the expected count, cap 15000 |
| `references` | photos under `briefs/refs/<id>/` (gitignored by default; commit only licensed images) |
| `view` | [azimuth, elevation] of the main photo when known, else leave out and gate with `--fit-view` |
| `threshold` | 0.85; raise to 0.9 for hero props |

From a photo: estimate size from a known feature (door handle 1 m high, A4 sheet, brick 215 mm),
list parts in reading order top to bottom, sample colors as sRGB hex for material tints.

When the first gate shows the brief was physically wrong (pose, measured extent), correct `size`
and record why in `notes`.
