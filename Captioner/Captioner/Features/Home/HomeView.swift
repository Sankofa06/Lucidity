// HomeView.swift
// Start screen: onboarding steps and the video picker.
//
// Presentation only. Picking a video hands the PhotosPicker item to
// `EditorViewModel.importVideo(from:)`, which runs the caption pipeline.

import PhotosUI
import SwiftUI

struct HomeView: View {
    let viewModel: EditorViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var isShowingHelp = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto captions for your videos")
                        .font(.largeTitle.bold())
                    Text("Animated, word-by-word captions in seconds. Transcribed privately on your iPhone.")
                        .foregroundStyle(.secondary)
                }

                ForEach(HelpContent.steps) { step in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: step.symbolName)
                            .font(.title3)
                            .frame(width: 32)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title).font(.headline)
                            Text(step.detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                PhotosPicker(selection: $pickerItem, matching: .videos) {
                    Label("Choose Video", systemImage: "video.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(20)
        }
        .navigationTitle("Captioner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Help", systemImage: "questionmark.circle") { isShowingHelp = true }
            }
        }
        .sheet(isPresented: $isShowingHelp) { HelpView() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            // Clear the selection so picking the same video again still fires.
            pickerItem = nil
            Task { await viewModel.importVideo(from: item) }
        }
    }
}
