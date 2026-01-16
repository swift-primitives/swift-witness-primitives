// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-witness-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(
            name: "Witness Primitives",
            targets: ["Witness Primitives"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Witness Primitives"
        ),
        .testTarget(
            name: "Witness Primitives Tests",
            dependencies: [
                "Witness Primitives",
            ],
            path: "Tests/Witness Primitives Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .strictMemorySafety(),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
