//
//  ContentView.swift
//  Contrail
//

import SwiftUI

/// The main navigation shell using a sidebar for macOS-native navigation.
struct ContentView: View {

    enum Destination: String, CaseIterable, Identifiable {
        case newFlight = "New Flight"
        case stats = "Stats"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .newFlight: return "airplane.departure"
            case .stats:     return "chart.bar.fill"
            }
        }
    }

    @State private var selection: Destination? = .newFlight
    @State private var activeSession: ActiveSessionInfo?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .background(ContrailTheme.darkNavy)
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(Destination.allCases) { dest in
                Label(dest.rawValue, systemImage: dest.icon)
                    .tag(dest)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Contrail")
        .frame(minWidth: 180)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        if let activeSession {
            TimerView(sessionInfo: activeSession) {
                self.activeSession = nil
                selection = .stats
            }
        } else {
            switch selection {
            case .newFlight, .none:
                AirportPickerView { info in
                    activeSession = info
                }
            case .stats:
                StatsView()
            }
        }
    }
}

/// Info passed from the airport picker to the timer.
struct ActiveSessionInfo {
    let departure: Airport
    let destination: Airport
    let duration: TimeInterval
}

#Preview {
    ContentView()
}
