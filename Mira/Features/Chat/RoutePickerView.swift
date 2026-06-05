// RoutePickerView.swift
// Searchable smart route picker shell for Mira.
//
// The picker displays public-safe route fixtures for the first build and will
// later hydrate from configured machines, cloud providers, and source metadata.

import SwiftUI

struct RoutePickerView: View {
    @Bindable var appState: MiraAppState
    @State private var searchText = ""

    private var filteredRoutes: [SmartRoute] {
        let routes = appState.inventory.routes
        guard !searchText.isEmpty else { return routes }
        return routes.filter {
            $0.friendlyName.localizedCaseInsensitiveContains(searchText)
                || $0.modelName.localizedCaseInsensitiveContains(searchText)
                || ($0.userAlias ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        MiraCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Smart Routes")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MiraTheme.text)
                    Spacer()
                    MiraChip(title: "\(filteredRoutes.count)", symbolName: "point.3.connected.trianglepath.dotted")
                }

                TextField("Search routes, machines, models, capabilities", text: $searchText)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(MiraTheme.elevated, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(MiraTheme.text)

                VStack(spacing: 10) {
                    ForEach(filteredRoutes) { route in
                        RouteRow(route: route, isSelected: route.id == appState.selectedRoute?.id) {
                            appState.selectedRoute = route
                        }
                    }
                }
            }
        }
    }
}

private struct RouteRow: View {
    let route: SmartRoute
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(route.userAlias ?? route.friendlyName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MiraTheme.text)
                        Text(route.modelName)
                            .font(.caption)
                            .foregroundStyle(MiraTheme.secondaryText)
                    }
                    Spacer()
                    MiraChip(title: route.health.title, symbolName: "circle.fill", tint: route.health == .ready ? MiraTheme.success : MiraTheme.info)
                }

                FlowChips(capabilities: Array(route.capabilities).sorted { $0.rawValue < $1.rawValue })
            }
            .padding(12)
            .background(isSelected ? MiraTheme.accent.opacity(0.14) : MiraTheme.elevated, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? MiraTheme.accent.opacity(0.45) : MiraTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct FlowChips: View {
    let capabilities: [RouteCapability]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(capabilities) { capability in
                    MiraChip(title: capability.rawValue, tint: MiraTheme.info)
                }
            }
        }
    }
}
