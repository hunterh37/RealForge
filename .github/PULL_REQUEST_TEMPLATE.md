<!-- One asset, scene, material or engine change per PR. -->

## What

<!-- id(s) added or changed, one line each. -->

## Render

<!-- Paste docs/assets/<id>.png or docs/scenes/<id>.png, plus any extra angle (--az/--el) or sky (--sky golden). -->

## Checklist

- [ ] `swift test` passes
- [ ] `swift run -q realforge render <id>` checked: scale, grounding, material scale, grain direction, bevels, no z-fighting
- [ ] `swift run -q realforge thumbs <id>` committed
- [ ] `swift run -q realforge catalog` committed
- [ ] `swift run -q realforge shaders` passes (ShaderGraph changes only)
- [ ] LOD0 within budget; `swift run -q realforge stats <id>` output pasted below
- [ ] No mesh, texture or image files under `Sources/` (everything is generated)

```
stats output
```
