//
//  AirportPickerView.swift
//  Contrail
//

import SwiftUI

/// Searchable airport selector — pick departure and destination to start a focus session.
struct AirportPickerView: View {

    @StateObject private var airportService = AirportDataService()

    @State private var departureQuery = ""
    @State private var destinationQuery = ""
    @State private var selectedDeparture: Airport?
    @State private var selectedDestination: Airport?
    @State private var showDepartureResults = false
    @State private var showDestinationResults = false

    /// Called when the user taps "Board Flight"
    var onStartSession: (ActiveSessionInfo) -> Void

    private var canBoard: Bool {
        selectedDeparture != nil && selectedDestination != nil
            && selectedDeparture != selectedDestination
    }

    private var flightDuration: TimeInterval? {
        guard let dep = selectedDeparture, let dest = selectedDestination else { return nil }
        return FlightCalculator.flightDuration(from: dep, to: dest)
    }

    var body: some View {
        ZStack {
            ContrailTheme.darkNavy.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    header
                    airportSelectors
                    flightInfoCard
                    boardButton
                }
                .padding(40)
                .frame(maxWidth: 600)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "airplane")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(ContrailTheme.skyBlue)
                .rotationEffect(.degrees(-45))

            Text("Plan Your Flight")
                .font(ContrailTheme.titleFont)
                .foregroundStyle(ContrailTheme.contrailWhite)

            Text("Select your departure and destination to begin a focus session")
                .font(ContrailTheme.bodyFont)
                .foregroundStyle(ContrailTheme.mutedText)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Selectors

    private var airportSelectors: some View {
        VStack(spacing: 20) {
            airportField(
                label: "Departure",
                icon: "airplane.departure",
                query: $departureQuery,
                selection: $selectedDeparture,
                showResults: $showDepartureResults
            )

            // Swap button
            Button {
                let temp = selectedDeparture
                selectedDeparture = selectedDestination
                selectedDestination = temp
                departureQuery = selectedDeparture?.displayName ?? ""
                destinationQuery = selectedDestination?.displayName ?? ""
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ContrailTheme.skyBlue)
                    .frame(width: 36, height: 36)
                    .background(ContrailTheme.surfaceNavy)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(ContrailTheme.skyBlue.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)

            airportField(
                label: "Destination",
                icon: "airplane.arrival",
                query: $destinationQuery,
                selection: $selectedDestination,
                showResults: $showDestinationResults
            )
        }
    }

    private func airportField(
        label: String,
        icon: String,
        query: Binding<String>,
        selection: Binding<Airport?>,
        showResults: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(ContrailTheme.captionFont)
                .foregroundStyle(ContrailTheme.mutedText)

            TextField("Search airports…", text: query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(ContrailTheme.contrailWhite)
                .padding(12)
                .background(ContrailTheme.surfaceNavy)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            selection.wrappedValue != nil
                                ? ContrailTheme.skyBlue.opacity(0.4)
                                : ContrailTheme.contrailWhite.opacity(0.08),
                            lineWidth: 1
                        )
                )
                .onChange(of: query.wrappedValue) { _, newValue in
                    showResults.wrappedValue = !newValue.isEmpty && selection.wrappedValue == nil
                }

            if showResults.wrappedValue {
                let results = airportService.search(query: query.wrappedValue).prefix(8)
                if !results.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(results)) { airport in
                            Button {
                                selection.wrappedValue = airport
                                query.wrappedValue = airport.displayName
                                showResults.wrappedValue = false
                            } label: {
                                HStack {
                                    Text(airport.iataCode)
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundStyle(ContrailTheme.skyBlue)
                                        .frame(width: 44, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(airport.name)
                                            .font(.system(size: 13))
                                            .foregroundStyle(ContrailTheme.contrailWhite)
                                            .lineLimit(1)
                                        Text("\(airport.municipality), \(airport.country)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(ContrailTheme.mutedText)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if airport.id != results.last?.id {
                                Divider().background(ContrailTheme.contrailWhite.opacity(0.05))
                            }
                        }
                    }
                    .background(ContrailTheme.surfaceNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(ContrailTheme.contrailWhite.opacity(0.08), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Flight Info

    @ViewBuilder
    private var flightInfoCard: some View {
        if let dep = selectedDeparture, let dest = selectedDestination, dep != dest {
            let distance = FlightCalculator.haversineDistance(from: dep, to: dest)
            let duration = FlightCalculator.flightDuration(from: dep, to: dest)

            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dep.iataCode)
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(ContrailTheme.contrailWhite)
                        Text(dep.municipality)
                            .font(ContrailTheme.captionFont)
                            .foregroundStyle(ContrailTheme.mutedText)
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        Image(systemName: "airplane")
                            .font(.system(size: 16))
                            .foregroundStyle(ContrailTheme.skyBlue)
                        Text(String(format: "%.0f km", distance))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(ContrailTheme.mutedText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(dest.iataCode)
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(ContrailTheme.contrailWhite)
                        Text(dest.municipality)
                            .font(ContrailTheme.captionFont)
                            .foregroundStyle(ContrailTheme.mutedText)
                    }
                }

                Divider().background(ContrailTheme.contrailWhite.opacity(0.08))

                HStack {
                    Label("Focus Duration", systemImage: "timer")
                        .font(ContrailTheme.captionFont)
                        .foregroundStyle(ContrailTheme.mutedText)

                    Spacer()

                    Text(FlightCalculator.formattedDuration(duration))
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ContrailTheme.sunsetGold)
                }
            }
            .contrailCard()
            .animation(.easeInOut(duration: 0.3), value: dep.id)
            .animation(.easeInOut(duration: 0.3), value: dest.id)
        }
    }

    // MARK: - Board Button

    @ViewBuilder
    private var boardButton: some View {
        if canBoard, let dep = selectedDeparture, let dest = selectedDestination {
            Button {
                let duration = FlightCalculator.flightDuration(from: dep, to: dest)
                let info = ActiveSessionInfo(departure: dep, destination: dest, duration: duration)
                onStartSession(info)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "airplane")
                        .rotationEffect(.degrees(-45))
                    Text("Board Flight")
                        .fontWeight(.semibold)
                }
                .font(.system(size: 16))
                .foregroundStyle(ContrailTheme.darkNavy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ContrailTheme.skyBlue)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: ContrailTheme.skyBlue.opacity(0.3), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}

#Preview {
    AirportPickerView { _ in }
}
