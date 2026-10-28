// RootView.swift
// Switches between the start screen, progress, and the editor.
//
// Reads `EditorViewModel.phase` and shows the matching screen, plus a shared
// alert for `errorMessage`. Created by `CaptionerApp`.

import SwiftUI

struct RootView: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        NavigationStack {
            switch viewModel.phase {
            case .empty:
                HomeView(viewModel: viewModel)
            case .working(let message):
                WorkingView(message: message)
            case .editing:
                EditorView(viewModel: viewModel)
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

/// Full-screen progress indicator for import and transcription.
struct WorkingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .font(.headline)
            Text("Long videos take a little while. Keep the app open.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Captioner")
    }
}
