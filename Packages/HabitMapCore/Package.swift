// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HabitMapCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "HabitMapCore", targets: ["HabitMapCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0")
    ],
    targets: [
        .target(
            name: "HabitMapCore",
            path: "Sources/HabitMapCore"
        ),
        .testTarget(
            name: "HabitMapCoreTests",
            dependencies: [
                "HabitMapCore",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "Tests/HabitMapCoreTests",
            exclude: ["__Snapshots__"]
        )
    ]
)
