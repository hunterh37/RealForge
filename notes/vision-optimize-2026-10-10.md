# Optimize pass 2026-10-10

Validation: every asset (all LODs, all channels) and every scene (fields, singles, transforms) hashed
with FNV over x/y/z lanes. Baseline run 3x, each change compared to it. Perf commits: 0 hash diffs.

## Bugs (generation was nondeterministic across processes)
- Nature/Rocks/RockShape.swift rockCluster: AO spheres read `byN.values.first` (Dictionary order). Now highest subdivision.
  Affected rock-outcrop, scree-pile, mesa-rock, rock-pile, alpine-meadow, canyon-road.
- RealCore/Slice.swift chain: weld canon and loop start order came from Dictionary order. Sorted keys, tie-break by key.
- Scenes/HospitalLobby.swift:103, Scenes/HospitalFloor.swift:44: ceiling lights iterated `Set` fixture cells. Sorted like the other rooms.

## Perf (bit-identical output)
- Noise.perlin/worley: explicit Int32 lane conversion (generic SIMD init was the #2 hotspot).
- Noise.grad: table lookup in place of 12-way switch.
- Surface.tri/quad/computeTangents/bakeCavityAO: no array literals per triangle.
- facetted(): reserved capacity, no per-triangle map.
- InsectKit.delaunayFan: struct triangles, integer edge keys (was string keys and array literals in O(T^2) search).

## Release bench (realityhd bench)
- Asset generation total: 3698 ms -> 2217 ms.
- Scene generation total: 23014 ms -> 11123 ms (canyon-road 6985 -> 1801, alpine-meadow 6137 -> 1745).

## Tests
`swift test`: 86 tests; MaterialTests.everyKeyHasProgramOrScalars fails 3 issues on main too (tileSize 0), unrelated.

## Not changed
RealKit runtime systems (LOD slicing, shadow policy, stats walk) already throttled; no per-frame allocations found.
