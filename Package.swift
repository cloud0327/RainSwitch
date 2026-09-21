// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RainSwitchChecks",
    platforms: [.macOS(.v14)],
    products: [],
    targets: [
        .target(name: "RainSwitchCore", path: "RainSwitch",
                exclude: ["RainSwitchApp.swift", "SettingsView.swift", "Info.plist", "RainSwitch.entitlements", "Assets.xcassets", "AppIcon-master.png"],
                sources: ["Crossfade.swift", "Playback.swift", "TrackStore.swift"]),
        .testTarget(name: "RainSwitchTests", dependencies: ["RainSwitchCore"], path: "Tests")
    ]
)
