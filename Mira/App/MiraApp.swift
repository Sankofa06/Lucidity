// MiraApp.swift
// App entry point for the Mira iOS application.
//
// Defines the composition root for the first-build SwiftUI shell. It touches
// the root app state and hands it into the chat-first workspace. SwiftUI calls
// this file at launch, and the workspace consumes the created state.

import SwiftUI

@main
struct MiraApp: App {
    @State private var appState = MiraAppState()

    var body: some Scene {
        WindowGroup {
            MiraRootView(appState: appState)
        }
    }
}
