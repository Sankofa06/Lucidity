// swift-tools-version:6.0
// Package.swift
// Swift package manifest for CaptionerKit, Captioner's pure domain layer.
//
// Declares a Foundation-only library with no Apple-platform frameworks so the
// caption timing, grouping, editing, and subtitle logic can be built and tested
// with `swift test` on macOS or Linux. The Captioner app target links this
// package through `Captioner/project.yml`.

import PackageDescription

let package = Package(
    name: "CaptionerKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    products: [
        .library(name: "CaptionerKit", targets: ["CaptionerKit"])
    ],
    targets: [
        .target(name: "CaptionerKit"),
        .testTarget(name: "CaptionerKitTests", dependencies: ["CaptionerKit"])
    ]
)
