// Metal source compiled at runtime (device.makeLibrary(source:)), so the package builds with plain
// `swift build` and needs no .metallib resource step. Compiled once per process (~40 ms), then cached.
//
// Adding a texture program:
// 1. Write `S myProgram(float2 uv, constant RFParams &P)` in the family file (`<Family>Shaders.swift`) (or a new one listed in
//    `programSources`). It must tile: use the periodic noise helpers in CommonShaders.swift.
// 2. Add `case myProgram` at the end of `TextureProgram`. The Swift case name is the Metal function name;
//    `evaluate()` is generated from `TextureProgram.allCases`, so there is no switch to edit.

/// Program families, in compile order. Append new family sources here.
let programSources: [String] = [metalBark, metalFoliage, metalStone, metalBuilt, metalPlant, metalIndustrial, metalGround, metalConifer, metalRock, metalFabric, metalWater, metalCraft, metalOffice, metalSports, metalMedical, metalAnatomy, metalWoodshopShop, metalWoodshopTools, metalPantry, metalKitchen, metalCookware, metalFood, metalLandscaping]

/// `evaluate()` dispatch, one case per `TextureProgram`.
var metalDispatch: String {
    let cases = TextureProgram.allCases.map { "        case \($0.rawValue): return \($0)(uv, P);" }.joined(separator: "\n")
    return """
    S evaluate(float2 uv, constant RFParams &P) {
        switch (P.kind) {
    \(cases)
            default: return defaults();
        }
    }
    """
}

let realityHDMetalSource: String = ([metalCommon] + programSources + [metalDispatch, metalKernels, metalSky]).joined(separator: "\n\n")
