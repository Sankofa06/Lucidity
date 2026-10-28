// CueListView.swift
// Scrollable list of every caption, plus the sheet for editing one.
//
// Presentation only. Tapping a row jumps playback to that caption; the pencil
// opens `CueEditSheet`. The row on screen right now is highlighted.

import CaptionerKit
import SwiftUI

struct CueListView: View {
    let cues: [CaptionCue]
    let activeCueID: CaptionCue.ID?
    let onSelect: (CaptionCue) -> Void
    let onEdit: (CaptionCue) -> Void

    var body: some View {
        if cues.isEmpty {
            ContentUnavailableView("No Captions", systemImage: "captions.bubble", description: Text("Every caption was deleted. Tap New to start over."))
        } else {
            List(cues) { cue in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(SubRipFormatter.timestamp(cue.start).prefix(8))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(cue.text)
                        .fontWeight(cue.id == activeCueID ? .bold : .regular)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Edit", systemImage: "pencil") { onEdit(cue) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                }
                .contentShape(Rectangle())
                .onTapGesture { onSelect(cue) }
                .listRowBackground(cue.id == activeCueID ? Color.accentColor.opacity(0.15) : nil)
            }
            .listStyle(.plain)
        }
    }
}

/// Text editor for one caption. Saving blank text deletes the caption.
struct CueEditSheet: View {
    let cue: CaptionCue
    let onSave: (String) -> Void
    @State private var text: String
    @Environment(\.dismiss) private var dismiss

    init(cue: CaptionCue, onSave: @escaping (String) -> Void) {
        self.cue = cue
        self.onSave = onSave
        _text = State(initialValue: cue.text)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Caption", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                Text("Clear the text and save to delete this caption.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Edit Caption")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
