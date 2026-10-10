// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RealityHD",
    platforms: [.visionOS(.v26), .macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "RealityHD", targets: ["RealCore", "RealMaterials", "RealKit", "RealLibrary"]),
        .library(name: "RealityHDAnimals", targets: ["AnimalCore", "AnimalKit", "RealityHDAnimals"]),
        .executable(name: "realityhd", targets: ["realityhd"]),
        .executable(name: "animalpreview", targets: ["animalpreview"]),
    ],
    targets: [
        // Geometry: smooth-shaded, UV'd, tangent-space meshes. No RealityKit; tests run anywhere.
        .target(name: "RealCore"),
        // GPU texture synthesis (Metal compute, runtime-compiled) -> PBR texture sets.
        .target(name: "RealMaterials", dependencies: ["RealCore"]),
        // RealityKit bridge: LowLevelMesh upload, material cache, sky/IBL/sun, LOD, instancing, wind.
        .target(name: "RealKit", dependencies: ["RealCore", "RealMaterials"]),
        // Asset catalog: trees, rocks, ground, props, scenes.
        .target(name: "RealLibrary", dependencies: ["RealCore", "RealMaterials", "RealKit"]),
        // CLI: list, stats, offscreen PNG preview via RealityRenderer.
        .executableTarget(name: "realityhd", dependencies: ["RealCore", "RealMaterials", "RealKit", "RealLibrary"]),
        // Animals: species, rigs, flight, behavior, habitat, journal. Headless (no RealityKit).
        .target(name: "AnimalCore", dependencies: ["RealCore", "RealMaterials", "RealKit", "RealLibrary"]),
        // Animals on RealityKit: rig entities, WildlifeWorld, hand landing, procedural voices.
        .target(name: "AnimalKit", dependencies: ["AnimalCore", "RealCore", "RealMaterials", "RealKit", "RealLibrary"]),
        // Umbrella: `import RealityHDAnimals`.
        .target(name: "RealityHDAnimals", dependencies: ["AnimalCore", "AnimalKit"]),
        .executableTarget(name: "animalpreview", dependencies: ["AnimalCore", "AnimalKit", "RealCore", "RealMaterials", "RealKit", "RealLibrary"]),
        .testTarget(name: "AnimalCoreTests", dependencies: ["AnimalCore", "RealCore", "RealLibrary", "RealKit", "RealMaterials"]),
        .testTarget(name: "AnimalKitTests", dependencies: ["AnimalCore", "AnimalKit"]),
        .testTarget(name: "RealityHDTests", dependencies: ["RealCore", "RealLibrary", "RealKit", "RealMaterials"]),
    ],
    swiftLanguageModes: [.v5]
)
