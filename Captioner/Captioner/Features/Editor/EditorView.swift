// EditorView.swift
// The caption editor: video preview, transport, style and caption panels, export.
//
// Presentation only. Reads and mutates state through `EditorViewModel`; the
// only local state is which panel is showing and which cue is being edited.
// Shown by `RootView` once transcription finishes.

import CaptionerKit
import SwiftUI

struct EditorView: View {
    @Bindable var viewModel: EditorViewModel
    @State private var panel: Panel = .style
    @State private var editingCue: CaptionCue?
    @State private var isShowingHelp = false

    enum Panel: String, CaseIterable, Identifiable {
        case style = "Style"
        case captions = "Captions"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 12) {
            if let playback = viewModel.playback, let info = viewModel.videoInfo {
                preview(playback: playback, info: info)
                TransportBar(playback: playback)
            }

            Picker("Panel", selection: $panel) {
                ForEach(Panel.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Group {
                switch panel {
                case .style:
                    StylePanelView(viewModel: viewModel)
                case .captions:
                    CueListView(
                        cues: viewModel.cues,
                        activeCueID: viewModel.activeCue?.id,
                        onSelect: { viewModel.seek(toCue: $0) },
                        onEdit: { editingCue = $0 }
                    )
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .safeAreaInset(edge: .bottom) {
            ExportBar(viewModel: viewModel)
        }
        .navigationTitle("Edit Captions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("New", systemImage: "plus") { viewModel.startOver() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Help", systemImage: "questionmark.circle") { isShowingHelp = true }
            }
        }
        .sheet(isPresented: $isShowingHelp) { HelpView() }
        .sheet(item: $editingCue) { cue in
            CueEditSheet(cue: cue) { newText in
                viewModel.updateCue(id: cue.id, text: newText)
            }
        }
    }

    /// Video with the live caption overlay, framed to the video's exact
    /// aspect ratio so overlay fractions match the export. Tap to play/pause.
    private func preview(playback: PlaybackController, info: VideoInfo) -> some View {
        ZStack {
            PlayerSurface(player: playback.player)
            CaptionOverlayView(
                cue: viewModel.activeCue,
                highlightedWordIndex: viewModel.activeWordIndex,
                style: viewModel.style
            )
        }
        .aspectRatio(info.aspectRatio, contentMode: .fit)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxHeight: 420)
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture { playback.togglePlayback() }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(playback.isPlaying ? "Pause video" : "Play video")
    }
}

/// Play/pause and scrubber.
struct TransportBar: View {
    let playback: PlaybackController

    var body: some View {
        HStack(spacing: 12) {
            Button(playback.isPlaying ? "Pause" : "Play", systemImage: playback.isPlaying ? "pause.fill" : "play.fill") {
                playback.togglePlayback()
            }
            .labelStyle(.iconOnly)
            .font(.title3)

            Slider(
                value: Binding(get: { playback.currentTime }, set: { playback.seek(to: $0) }),
                in: 0...max(playback.duration, 0.1)
            )
            .accessibilityLabel("Playback position")

            Text(Self.format(playback.currentTime))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let whole = Int(max(0, seconds))
        let remainder = whole % 60
        return "\(whole / 60):\(remainder < 10 ? "0" : "")\(remainder)"
    }
}
