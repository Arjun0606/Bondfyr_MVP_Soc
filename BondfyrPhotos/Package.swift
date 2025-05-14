// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BondfyrPhotos",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "BondfyrPhotos",
            targets: ["BondfyrPhotos"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BondfyrPhotos",
            dependencies: []),
        .testTarget(
            name: "BondfyrPhotosTests",
            dependencies: ["BondfyrPhotos"]),
    ]
) 