// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "MinerTimer",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/sroebert/mqtt-nio.git", from: "2.8.1")
    ],
    targets: [
        .target(
            name: "MinerTimer",
            dependencies: [
                .product(name: "MQTTNIO", package: "mqtt-nio")
            ],
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