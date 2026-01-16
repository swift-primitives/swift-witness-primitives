// swift-tools-version: 6.2

import PackageDescription
import CompilerPluginSupport

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
        .library(
            name: "Witness Macros",
            targets: ["Witness Macros"]
        ),
        .library(
            name: "Witness Primitives Test Support",
            targets: ["Witness Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        .package(path: "../swift-algebra-primitives"),
        .package(path: "../swift-finite-primitives"),
    ],
    targets: [
        .target(
            name: "Witness Primitives"
        ),
        .target(
            name: "Witness Macros",
            dependencies: [
                "Witness Primitives",
                "Witness Macros Implementation",
                .product(name: "Algebra Primitives", package: "swift-algebra-primitives"),
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
            ]
        ),
        .macro(
            name: "Witness Macros Implementation",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Witness Primitives Test Support",
            dependencies: [
                "Witness Primitives",
                "Witness Macros",
                .product(name: "Algebra Primitives", package: "swift-algebra-primitives"),
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "Witness Primitives Tests",
            dependencies: [
                "Witness Primitives",
                "Witness Macros",
                "Witness Primitives Test Support",
                .product(name: "Algebra Primitives", package: "swift-algebra-primitives"),
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
