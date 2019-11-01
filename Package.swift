// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "IceCream",
    platforms: [
        .macOS(.v10_12), .iOS(.v10), .tvOS(.v10), .watchOS(.v3)
    ],
    products: [
        .library(
            name: "IceCream",
            targets: ["IceCream"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/realm/realm-cocoa", 
            from: "3.20.0"
        )
    ],
    targets: [
        .target(
            name: "IceCream",
            dependencies: ["RealmSwift", "Realm"],
            path: ".", 
            sources: ["IceCream"])
    ],
    swiftLanguageVersions: [.v5]
)
