// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "MinerTimer",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.0.0"),
        .package(url: "https://github.com/sroebert/mqtt-nio.git", from: "2.8.0")
    ],
    targets: [
        .executableTarget(
            name: "MinerTimer",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics"),
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