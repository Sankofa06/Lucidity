// CaptionerApp.swift
// App entry point and composition root for Captioner.
//
// Creates the single `EditorViewModel` with its production services and hands
// it to `RootView`. SwiftUI calls this at launch.

import SwiftUI

@main
struct CaptionerApp: App {
    @State private var viewModel = EditorViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
        }
    }
}
