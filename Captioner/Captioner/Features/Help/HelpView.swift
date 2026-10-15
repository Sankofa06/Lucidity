// HelpView.swift
// In-app help: how it works, glossary, and tips.
//
// Presentation only; all text comes from `HelpContent`. Shown as a sheet from
// the Home and Editor toolbars.

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("How it works") {
                    ForEach(HelpContent.steps) { step in
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title).font(.headline)
                                Text(step.detail).font(.subheadline).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: step.symbolName)
                        }
                    }
                }
                Section("Glossary") {
                    ForEach(HelpContent.glossary) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.term).font(.headline)
                            Text(entry.definition).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Tips") {
                    ForEach(HelpContent.tips, id: \.self) { tip in
                        Text(tip).font(.subheadline)
                    }
                }
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
