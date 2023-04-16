// swift-tools-version: 5.7

import PackageDescription

let dependencies: [Package.Dependency]

if Context.environment["ALLUI_ENV"] == "LOCAL" {
    dependencies = [.package(name: "CoreUI", path: "../CoreUI")]
} else {
    dependencies = [
        .package(url: "https://github.com/Everything-as-UI/CoreUI.git", branch: "main")
    ]
}

let package = Package(
    name: "DocumentUI",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "DocumentUI", targets: ["DocumentUI"])
    ],
    dependencies: dependencies,
    targets: [
        .target(name: "DocumentUI",
                dependencies: [.product(name: "CommonUI", package: "CoreUI")],
                exclude: ["TextDocumentBuilders.swift.gyb.swift"]),
        .testTarget(name: "DocumentUITests", dependencies: ["DocumentUI"])
    ]
)
