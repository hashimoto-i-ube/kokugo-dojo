// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "KokugoDojo",
    defaultLocalization: "ja",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "KokugoDojo", targets: ["KokugoDojo"])
    ],
    targets: [
        .target(
            name: "KokugoCore",
            path: "Sources/KokugoCore"
        ),
        .executableTarget(
            name: "KokugoDojo",
            dependencies: ["KokugoCore"],
            path: "Sources/KokugoDojo"
        ),
        .testTarget(
            name: "KokugoCoreTests",
            dependencies: ["KokugoCore"],
            path: "Tests/KokugoCoreTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
