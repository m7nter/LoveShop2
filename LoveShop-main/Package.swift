// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SecureVault",
    platforms: [.iOS(.v16)],
    targets: [
        .target(
            name: "SecureVault",
            path: "Sources/SecureVault",
            resources: [.process("../../Resources")]
        )
    ]
)
