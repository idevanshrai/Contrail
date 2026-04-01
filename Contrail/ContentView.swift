//
//  ContentView.swift
//  Contrail
//

import SwiftUI

/// The main navigation shell — minimal dark sidebar inspired by FocusFlights.
struct ContentView: View {

    enum Destination: String, CaseIterable, Identifiable {
        case journey    = "Journey"
        case inProgress = "In Progress"
        case history    = "History"
        case trends     = "Trends"
        case settings   = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .journey:    return "airplane"
            case .inProgress: return "play.circle.fill"
            case .history:    return "clock.arrow.circlepath"
            case .trends:     return "chart.line.uptrend.xyaxis"
            case .settings:   return "gearshape"
            }
        }
    }

    @State private var selection: Destination? = .journey
    @State private var activeSession: ActiveSessionInfo?
    @State private var showingBoarding = false

    /// Persists the last airport IATA code. Defaults to Berlin (BER) on first launch.
    @AppStorage("lastAirportIATA") private var lastAirportIATA: String = "BER"

    /// Persists the user's preferred map style.
    @AppStorage("preferredMapStyle") var preferredMapStyle: String = "imagery"

    @StateObject private var airportService = AirportDataService()

    /// The resolved departure airport — last destination or BER fallback.
    private var departureAirport: Airport {
        airportService.airportByIATA(lastAirportIATA)
            ?? Airport(id: 0, name: "Berlin Brandenburg", iataCode: "BER",
                       latitude: 52.3667, longitude: 13.5033, country: "DE", municipality: "Berlin")
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .background(ContrailTheme.darkNavy)
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(.dark)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App brand with icon
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .shadow(color: ContrailTheme.glowAmber.opacity(0.3), radius: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Contrail")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(ContrailTheme.contrailWhite)
                    Text("Focus Timer")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(ContrailTheme.mutedText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)

            // Navigation items
            VStack(spacing: 2) {
                ForEach(Destination.allCases) { dest in
                    sidebarButton(dest)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            // Active session indicator
            if activeSession != nil {
                HStack(spacing: 8) {
                    Circle()
                        .fill(ContrailTheme.arrivedGreen)
                        .frame(width: 8, height: 8)
                    Text("Flight in progress")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ContrailTheme.mutedText)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(minWidth: 180, maxWidth: 200)
        .background(ContrailTheme.sidebarBg)
    }

    private func sidebarButton(_ dest: Destination) -> some View {
        Button {
            // If tapping "In Progress" with an active session, switch to timer
            if dest == .inProgress && activeSession != nil {
                selection = .inProgress
            } else if dest == .inProgress && activeSession == nil {
                // Don't navigate if no session
                return
            } else {
                selection = dest
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: dest.icon)
                    .font(.system(size: 14))
                    .frame(width: 22)
                    .foregroundStyle(
                        selection == dest ? ContrailTheme.skyBlue : ContrailTheme.mutedText
                    )
                Text(dest.rawValue)
                    .font(.system(size: 13, weight: selection == dest ? .semibold : .regular))
                    .foregroundStyle(
                        selection == dest ? ContrailTheme.contrailWhite : ContrailTheme.mutedText
                    )
                Spacer()

                // Badge for in-progress
                if dest == .inProgress && activeSession != nil {
                    Circle()
                        .fill(ContrailTheme.glowAmber)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                selection == dest
                    ? ContrailTheme.surfaceNavy
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(dest == .inProgress && activeSession == nil ? 0.4 : 1.0)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .journey, .none:
            if showingBoarding, let info = activeSession {
                BoardingView(sessionInfo: info) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showingBoarding = false
                        selection = .inProgress
                    }
                }
            } else if activeSession != nil {
                timerDetail
            } else {
                MapPickerView(
                    departure: departureAirport,
                    preferredMapStyle: preferredMapStyle
                ) { info in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        activeSession = info
                        showingBoarding = true
                    }
                }
            }

        case .inProgress:
            if activeSession != nil {
                timerDetail
            } else {
                noActiveSessionView
            }

        case .history:
            StatsView()

        case .trends:
            TrendsView()

        case .settings:
            SettingsView()
        }
    }

    private var timerDetail: some View {
        TimerView(sessionInfo: activeSession!) {
            lastAirportIATA = activeSession!.destination.iataCode
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                activeSession = nil
                selection = .history
            }
        }
    }

    private var noActiveSessionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(ContrailTheme.mutedText.opacity(0.4))
            Text("No flight in progress")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ContrailTheme.mutedText)
            Text("Start a journey from the map to begin focusing")
                .font(.system(size: 13))
                .foregroundStyle(ContrailTheme.mutedText.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ContrailTheme.darkNavy)
    }
}

/// Info passed from the map picker to the timer.
struct ActiveSessionInfo {
    let departure: Airport
    let destination: Airport
    let duration: TimeInterval
}

#Preview {
    ContentView()
}
