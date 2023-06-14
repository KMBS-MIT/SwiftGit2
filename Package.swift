// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "SwiftGit2",
  platforms: [
    .macOS(.v13),
  ],
  products: [
    .library(
      name: "SwiftGit2",
      targets: ["SwiftGit2"]),
  ],
  dependencies: [
    //    .package(url: "https://github.com/Quick/Quick", from: "2.2.0"),
    //    .package(url: "https://github.com/Quick/Nimble", from: "8.0.8"),
    //    .package(url: "https://github.com/marmelroy/Zip.git", from: "2.0.0"),
  ],
  targets: [
    .target(
      name: "SwiftGit2",
      dependencies: ["Clibgit2"],
      path: "SwiftGit2"
    ),
    .binaryTarget(
      name: "Clibgit2",
      url: "https://github.com/KMBS-MIT/SwiftGit2/releases/download/v2.0.0/Clibgit2.xcframework.zip",
      checksum: "357e069659afbaae10e8c66f2da17c6495788f6629bb81540f0f9ce64b145a9d"
    ),
    //    .testTarget(
    //      name: "SwiftGit2Tests",
    //      dependencies: ["SwiftGit2", "Quick", "Nimble", "Zip"],
    //      path: "SwiftGit2Tests",
    //      exclude: ["Info.plist"],
    //      resources: [
    //        .copy("Fixtures/repository-with-status.zip"),
    //        .copy("Fixtures/Mantle.zip"),
    //        .copy("Fixtures/simple-repository.zip"),
    //        .copy("Fixtures/detached-head.zip"),
    //      ]
    //    ),
  ]
)

