---
name: realityhd-gate
description: Run the RealityHD vision gate on an asset and judge it honestly - render the six-view sheet and reference comparison, score the 0-10 rubric, write verdict.json with concrete fixes, compute the final confidence score, and sign off or iterate. Use whenever an asset needs visual review, a quality score, side-by-side comparison with a reference photo, or final sign-off. Triggers on "gate", "vision check", "compare to reference", "score this asset", "sign off", "/realityhd-gate".
---

# RealityHD vision gate

```sh
swift run -q realityhd gate <id> [--ref photo.jpg] [--view az,el | --fit-view] [--seed n]
```

Writes `out/gate/<id>/`: `sheet.png` (hero, side, back, high, 2.2x detail, golden hour, stats header),
`compare.png` with a reference (reference | matched render | silhouette overlay: white both, red
reference only, cyan render only), `report.json`, `verdict.template.json`.

## Judge

1. Read `out/gate/<id>/sheet.png`. With a reference, also Read `compare.png` and the photo.
2. Read the brief: `briefs/<id>.json` (`parts`, `style`, `size`).
3. Score every criterion in `verdict.template.json` against these anchors (also in `report.json`):

| id | weight | 10 | 6 | 3 |
|---|---|---|---|---|
| silhouette | 1.2 | unmistakable from any angle | recognizable, generic | wrong shape language |
| proportion | 1.0 | matches a real one | one part visibly off | toy-like or stretched |
| construction | 1.3 | every brief part, real joinery and thickness | main parts only | placeholders |
| edges | 0.8 | all edges softened at real radii | major edges only | raw boxes |
| materials | 1.4 | photographic | right material, flat or wrong scale | wrong material |
| wear | 0.8 | tells a story, varies per part | uniform noise | none |
| grounding | 0.5 | planted, contact shadow | slight float, no AO | floating |
| artifacts | 1.0 | clean | one visible artifact | several |
| reference | 1.5 | same object (reference runs only) | same type, other details | other object |

Score what the pixels show. A part listed in the brief and missing from the sheet caps
`construction` at 6. Integers only. 8 = passes for a photo at a glance.

4. Write `out/gate/<id>/verdict.json`:

```json
{"scores": {"silhouette": 8, "...": 7}, "notes": {"materials": "one factual line"},
 "fixes": ["chesterfield arm fronts: add radial pleats", "brass: colorA D9B263 -> B8954E"], "judge": "agent"}
```

5. `swift run -q realityhd gate <id> --verdict out/gate/<id>/verdict.json --no-sheet`

## Score

final = 0.35 automated + 0.65 vision without a reference; 0.5 / 0.5 with one. Automated = lint,
size vs brief (Gaussian, 0.5 at the tolerance), and with a reference: silhouette IoU after view
search, Vision feature-print similarity, mean Lab color distance, aspect, detail energy. Pass needs
final >= threshold (brief, default 0.85), no criterion below 6, no lint errors.

On pass add `--signoff` to write `briefs/signoff/<id>.json`. On fail apply the first fixes and rerun
`gate <id>` (re-renders the sheet). `out/gate/<id>/history.jsonl` keeps every scored run.

## Headless judge (CI or second opinion)

```sh
python3 Scripts/vision_judge.py <id>            # writes verdict.json via the Claude API
swift run -q realityhd gate <id> --verdict out/gate/<id>/verdict.json --no-sheet
```

## Calibration

Self-match (an asset's own thumbnail as reference) scores silhouette 0.96, perceptual 0.95. An
unrelated prop scores perceptual below 0.1 and color near 0.1. Silhouette alone is weak: round objects
match each other from above, so view search caps elevation at 45 degrees.
