// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let dependencies: [Package.Dependency]

let env = Context.environment["USER"]
let isDevelop = env == "K-o-D-e-N"
if isDevelop {
    dependencies = [
        .package(name: "CoreUI", path: "../CoreUI"),
    ]
} else {
    dependencies = [
        .package(url: "https://github.com/Everything-as-UI/CoreUI.git", branch: "main")
    ]
}

let package = Package(
    name: "DocumentUI",
    platforms: [.macOS(.v12), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "DocumentUI", targets: ["DocumentUI"])
    ],
    dependencies: dependencies,
    targets: [
        .target(name: "DocumentUI", dependencies: [.product(name: "CommonUI", package: "CoreUI")], exclude: ["TextDocumentBuilders.swift.gyb.swift"]),
        .testTarget(name: "DocumentUITests", dependencies: ["DocumentUI"])
    ]
)
