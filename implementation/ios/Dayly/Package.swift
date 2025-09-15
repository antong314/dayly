// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Dayly",
    platforms: [
        .iOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/supabase-community/supabase-swift.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "Dayly",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "."
        )
    ]
)
