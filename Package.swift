// swift-tools-version: 6.1

import PackageDescription

#if !canImport(Darwin)
let cSoupTargets: [Target] = [
    .systemLibrary(
        name: "CSoup",
        path: "Sources/CSoup",
        pkgConfig: "libsoup-3.0",
        providers: [
            .apt(["libsoup-3.0-dev"]),
            .yum(["libsoup3-devel"]),
        ]
    )
]
let lumaCoreSoupDeps: [Target.Dependency] = ["CSoup"]
#else
let cSoupTargets: [Target] = []
let lumaCoreSoupDeps: [Target.Dependency] = []
#endif

let package = Package(
    name: "luma",
    platforms: [
        .macOS(.v15),
        .iOS("26.0"),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "LumaCore", targets: ["LumaCore"]),
        .executable(name: "luma-bundle-compiler", targets: ["LumaBundleCompiler"]),
    ],
    dependencies: [
        .package(url: "https://github.com/frida/frida-swift", branch: "main"),
        .package(url: "https://github.com/apple/swift-crypto", .upToNextMajor(from: "3.0.0")),
        .package(url: "https://github.com/groue/GRDB.swift", .upToNextMajor(from: "7.0.0")),
        .package(url: "https://github.com/radareorg/SwiftyR2", branch: "main"),
    ],
    targets: cSoupTargets + [
        .target(
            name: "LumaCore",
            dependencies: [
                .product(name: "Frida", package: "frida-swift"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "SwiftyR2", package: "SwiftyR2"),
            ] + lumaCoreSoupDeps,
            path: "Sources/LumaCore",
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .executableTarget(
            name: "LumaBundleCompiler",
            dependencies: [
                .product(name: "Frida", package: "frida-swift"),
            ],
            path: "Sources/LumaBundleCompiler",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
