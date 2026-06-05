// TaskPickerView.swift
// Task-first picker for Mira chat orchestration.
//
// The chat workspace owns the selected task binding. This view only renders the
// first task decision and keeps model lists out of the top level.

import SwiftUI

struct TaskPickerView: View {
    @Binding var selectedTask: ChatTask

    private let tasks: [ChatTask] = [
        .chat(.free),
        .chat(.group),
        .chat(.compare),
        .createMedia,
        .inspect,
        .workflow
    ]

    var body: some View {
        MiraCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Task")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MiraTheme.text)
                    Spacer()
                    AdvisorChip(title: "Choose")
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    ForEach(tasks, id: \.self) { task in
                        Button {
                            selectedTask = task
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: task.symbolName)
                                Text(task.title)
                                    .lineLimit(1)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedTask == task ? MiraTheme.background : MiraTheme.text)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(selectedTask == task ? MiraTheme.accent : MiraTheme.elevated, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
