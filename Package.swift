// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SCPermissionKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "SCPermissionKit",
            targets: ["SCPermissionKit"]
        )
    ],
    targets: [
        .target(
            name: "SCPermissionKit",
            path: "Next Permission",
            exclude: [
                "AppDelegate.h",
                "AppDelegate.m",
                "Assets.xcassets",
                "Base.lproj",
                "Info.plist",
                "SceneDelegate.h",
                "SceneDelegate.m",
                "ViewController.h",
                "ViewController.m",
                "main.m"
            ],
            sources: [
                "Permissions/SCPermissionCenter.m",
                "Permissions/SCPermissionCore.m"
            ],
            publicHeadersPath: "PackageHeaders",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("Network"),
                .linkedFramework("NetworkExtension"),
                .linkedFramework("Photos")
            ]
        ),
        .testTarget(
            name: "SCPermissionKitTests",
            dependencies: ["SCPermissionKit"],
            path: "PackageTests"
        )
    ]
)
