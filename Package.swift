// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "IceCream",
    platforms: [
        .macOS(.v10_12), .iOS(.v11), .tvOS(.v10), .watchOS(.v3)
    ],
    products: [
        .library(
            name: "IceCream",
            targets: ["IceCream"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/realm/realm-cocoa", 
            from: "5.4.4"
        )
    ],
    targets: [
        .target(
            name: "IceCream",
            dependencies: ["RealmSwift", "Realm"],
            path: "IceCream",
            sources: ["Classes"])
    ],
    swiftLanguageVersions: [.v5]
)
