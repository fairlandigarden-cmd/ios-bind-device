// swift-tools-version:5.5
import PackageDescription
let package = Package(
    name: "IGardenSdkIOS",
    products: [
        .library(name: "IGardenSdkIOS", targets: ["IGardenSdkIOS"])
    ],
    targets: [
        .binaryTarget(
            name: "IGardenSdkIOS",
            path: "./IGardenSdkIOS.xcframework"
        )
    ]
)
