// ExportBar.swift
// Bottom bar for exporting the captioned video and the subtitle file.
//
// Presentation only. Export buttons call the view model; once an export
// exists, its button becomes a share button. From the share sheet, "Save
// Video" puts the result in Photos. Any edit clears previous exports, and a
// video export that finishes after an edit is discarded before it can be shared.

import SwiftUI

struct ExportBar: View {
    let viewModel: EditorViewModel

    var body: some View {
        HStack(spacing: 12) {
            if let url = viewModel.exportedVideoURL {
                ShareLink(item: url) {
                    Label("Share Video", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    Task { await viewModel.exportVideo() }
                } label: {
                    Group {
                        if viewModel.isExporting {
                            ProgressView()
                        } else {
                            Label("Export Video", systemImage: "film")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isExporting || viewModel.cues.isEmpty)
            }

            if let url = viewModel.exportedSubtitleURL {
                ShareLink(item: url) {
                    Label("Share .srt", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            } else {
                Button("Export .srt", systemImage: "captions.bubble") {
                    viewModel.exportSubtitles()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.cues.isEmpty)
            }
        }
        .controlSize(.large)
        .padding()
        .background(.bar)
    }
}
