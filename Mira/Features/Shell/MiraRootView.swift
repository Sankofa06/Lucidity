// MiraRootView.swift
// Root responsive shell for Mira's chat-first workspace.
//
// Hosts the rail, active content area, and Inspector. The app entry point
// creates the state this view reads and mutates.

import SwiftUI

struct MiraRootView: View {
    @Bindable var appState: MiraAppState

    var body: some View {
        GeometryReader { geometry in
            let layout = MiraResponsiveLayout(width: geometry.size.width)

            ZStack {
                MiraTheme.background
                    .ignoresSafeArea()

                if layout.showsRailInline {
                    HStack(spacing: 0) {
                        MiraRailView(selectedSection: $appState.selectedSection)
                        activeWorkspace(layout: layout)
                    }
                } else {
                    activeWorkspace(layout: layout)
                }
            }
        }
    }

    @ViewBuilder
    private func activeWorkspace(layout: MiraResponsiveLayout) -> some View {
        if layout.showsInspectorInline {
            HStack(spacing: 0) {
                selectedContent
                InspectorView(appState: appState)
                    .frame(width: layout.inspectorWidth)
            }
        } else {
            selectedContent
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch appState.selectedSection {
        case .chat:
            ChatWorkspaceView(appState: appState)
        case .projects:
            ProjectHubView(appState: appState)
        case .personas:
            PersonaHubView(appState: appState)
        case .teams:
            TeamHubView(appState: appState)
        case .library:
            LibraryHubView(appState: appState)
        case .sources:
            ModelSourcesHubView(appState: appState)
        case .machines:
            MachinesHubView(appState: appState)
        case .settings:
            SettingsHubView(appState: appState)
        }
    }
}
