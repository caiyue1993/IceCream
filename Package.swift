// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "IceCream",
    platforms: [
        .macOS(.v10_12), .iOS(.v11), .tvOS(.v11), .watchOS(.v4)
    ],
    products: [
        .library(
            name: "IceCream",
            targets: ["IceCream"]
		)
    ],
    dependencies: [
    .package(
        name: "Realm",
        url: "https://github.com/realm/realm-cocoa",
        .upToNextMajor(from: "10.12.0")
    )
    ],
    targets: [
        .target(
            name: "IceCream",
            dependencies: [
				"Realm",
				.product(name: "RealmSwift", package: "Realm")
			],
            path: "IceCream/Classes"
		)
    ],
    swiftLanguageVersions: [.v5]
)
