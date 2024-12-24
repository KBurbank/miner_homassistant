// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "MinerTimer",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "MinerTimer", targets: ["MinerTimer"])
    ],
    targets: [
        .executableTarget(
            name: "MinerTimer",
            dependencies: [],
            exclude: [
                "Legacy/extend_time.sh",
                "Legacy/config2.sh",
                "Legacy/minertimer.sh",
                "Legacy/config.sh",
                "Info.plist"
            ]
        )
    ]
) 