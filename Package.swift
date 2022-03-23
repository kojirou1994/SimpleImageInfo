// swift-tools-version:5.2

import PackageDescription

let package = Package(
  name: "SimpleImageInfo",
  products: [
    .library(name: "SimpleImageInfo", targets: ["SimpleImageInfo"]),
  ],
  dependencies: [
.package(url: "https://github.com/kojirou1994/IOUtility.git", from: "0.0.1"),
     .package(url: "https://github.com/kojirou1994/Precondition.git", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "SimpleImageInfo",
      dependencies: [
        .product(name: "IOModule", package: "IOUtility"),
        .product(name: "Precondition", package: "Precondition"),
      ]),
    .testTarget(
      name: "SimpleImageInfoTests",
      dependencies: [
        "SimpleImageInfo",
        .product(name: "IOStreams", package: "IOUtility"),
      ]),
  ]
)
