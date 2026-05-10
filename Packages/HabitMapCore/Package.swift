// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HabitMapCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "HabitMapCore", targets: ["HabitMapCore"])
    ],
    targets: [
        .target(
            name: "HabitMapCore",
            path: "Sources/HabitMapCore"
        )
    ]
)
