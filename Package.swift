// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RealForge",
    platforms: [.visionOS(.v26), .macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "RealForge", targets: ["RealCore", "RealMaterials", "RealKit", "RealLibrary"]),
        .executable(name: "realforge", targets: ["realforge"]),
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
        .executableTarget(name: "realforge", dependencies: ["RealCore", "RealMaterials", "RealKit", "RealLibrary"]),
        .testTarget(name: "RealForgeTests", dependencies: ["RealCore", "RealLibrary"]),
    ],
    swiftLanguageModes: [.v5]
)
