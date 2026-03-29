//
//  MapPickerView.swift
//  Contrail
//

import SwiftUI
import MapKit

/// Interactive globe-style destination selector inspired by FocusFlights.
/// Greeting header + dark map + glassmorphic time slider + "Start Journey" button.
struct MapPickerView: View {

    let departure: Airport
    let preferredMapStyle: String
    @StateObject private var airportService = AirportDataService()

    @State private var focusMinutes: Double = 60
    @State private var selectedAirport: Airport?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showingDestinationCard = false

    var onStartSession: (ActiveSessionInfo) -> Void

    private var focusDuration: TimeInterval { focusMinutes * 60 }
    private var radiusKm: Double { FlightCalculator.reachableRadiusKm(forDuration: focusDuration) }
    private var radiusMeters: Double { radiusKm * 1000 }

    private var reachableAirports: [Airport] {
        airportService.airportsReachable(from: departure, within: focusDuration)
    }

    private var displayedAirports: [Airport] {
        Array(reachableAirports.prefix(80))
    }

    /// Resolve the map style from AppStorage string
    private var mapStyle: MapStyle {
        switch preferredMapStyle {
        case "standard":
            return .standard(pointsOfInterest: .excludingAll)
        case "hybrid":
            return .hybrid(pointsOfInterest: .excludingAll)
        default: // "imagery"
            return .imagery(elevation: .realistic)
        }
    }

    var body: some View {
        ZStack {
            ContrailTheme.darkNavy.ignoresSafeArea()

            // Map fills entire view
            mapView
                .ignoresSafeArea()

            // Overlay content
            VStack(spacing: 0) {
                // Greeting header
                greetingHeader
                    .padding(.top, 20)
                    .padding(.horizontal, 28)

                Spacer()

                // Bottom controls overlay
                VStack(spacing: 16) {
                    // Destination card (if selected)
                    if let airport = selectedAirport {
                        destinationCard(airport: airport)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Time slider bar
                    timeSliderBar

                    // Start Journey button
                    startJourneyButton
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            updateCamera()
        }
        .onChange(of: focusMinutes) { _, _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                updateCamera()
            }
            // Clear selection if airport no longer reachable
            if let selected = selectedAirport {
                let dur = FlightCalculator.flightDuration(from: departure, to: selected)
                if dur > focusDuration {
                    withAnimation { selectedAirport = nil }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedAirport?.id)
    }

    // MARK: - Camera

    private func updateCamera() {
        cameraPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: departure.latitude, longitude: departure.longitude),
            latitudinalMeters: radiusMeters * 2.5,
            longitudinalMeters: radiusMeters * 2.5
        ))
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ContrailTheme.greeting)
                    .font(ContrailTheme.greetingFont)
                    .foregroundStyle(ContrailTheme.contrailWhite.opacity(0.7))

                Text(departure.municipality.isEmpty ? departure.name : departure.municipality)
                    .font(ContrailTheme.cityFont)
                    .foregroundStyle(ContrailTheme.contrailWhite)
            }
            .shadow(color: .black.opacity(0.6), radius: 12, y: 2)

            Spacer()

            // Reachable destinations badge
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(reachableAirports.count)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(ContrailTheme.skyBlue)
                Text("destinations")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ContrailTheme.contrailWhite.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 8)
        }
    }

    // MARK: - Map

    private var mapView: some View {
        Map(position: $cameraPosition) {
            // Departure pin
            Annotation(departure.iataCode, coordinate: CLLocationCoordinate2D(
                latitude: departure.latitude, longitude: departure.longitude
            )) {
                departurePinView
            }

            // Reachability circle
            MapCircle(
                center: CLLocationCoordinate2D(latitude: departure.latitude, longitude: departure.longitude),
                radius: radiusMeters
            )
            .foregroundStyle(ContrailTheme.glowAmber.opacity(0.05))
            .stroke(ContrailTheme.glowAmber.opacity(0.25), lineWidth: 1.5)

            // Destination pins
            ForEach(displayedAirports) { airport in
                Annotation(airport.iataCode, coordinate: CLLocationCoordinate2D(
                    latitude: airport.latitude, longitude: airport.longitude
                )) {
                    destinationPinView(for: airport)
                }
            }
        }
        .mapStyle(mapStyle)
        .mapControls {
            MapZoomStepper()
        }
    }

    private var departurePinView: some View {
        ZStack {
            // Pulse ring
            Circle()
                .stroke(ContrailTheme.skyBlue.opacity(0.3), lineWidth: 2)
                .frame(width: 40, height: 40)

            Circle()
                .fill(ContrailTheme.skyBlue)
                .frame(width: 28, height: 28)
                .shadow(color: ContrailTheme.skyBlue.opacity(0.6), radius: 10)

            Image(systemName: "airplane")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(-45))
        }
    }

    private func destinationPinView(for airport: Airport) -> some View {
        let isSelected = selectedAirport?.id == airport.id

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedAirport = airport
            }
        } label: {
            ZStack {
                if isSelected {
                    // Glow ring
                    Circle()
                        .fill(ContrailTheme.glowAmber.opacity(0.2))
                        .frame(width: 36, height: 36)

                    Circle()
                        .fill(ContrailTheme.glowAmber)
                        .frame(width: 22, height: 22)
                        .shadow(color: ContrailTheme.glowAmber.opacity(0.6), radius: 8)
                } else {
                    Circle()
                        .fill(ContrailTheme.contrailWhite.opacity(0.8))
                        .frame(width: 10, height: 10)
                        .shadow(color: ContrailTheme.contrailWhite.opacity(0.4), radius: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .hoverGlow(isSelected ? ContrailTheme.glowAmber : ContrailTheme.contrailWhite, radius: 6)
    }

    // MARK: - Destination Card

    private func destinationCard(airport: Airport) -> some View {
        let duration = FlightCalculator.flightDuration(from: departure, to: airport)
        let distance = FlightCalculator.haversineDistance(from: departure, to: airport)

        return HStack(spacing: 16) {
            // Route info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(departure.iataCode)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(ContrailTheme.contrailWhite)

                    Image(systemName: "airplane")
                        .font(.system(size: 11))
                        .foregroundStyle(ContrailTheme.glowAmber)
                        .rotationEffect(.degrees(0))

                    Text(airport.iataCode)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(ContrailTheme.glowAmber)
                }

                Text("\(airport.name), \(airport.country)")
                    .font(.system(size: 12))
                    .foregroundStyle(ContrailTheme.mutedText)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(FlightCalculator.formattedDuration(duration), systemImage: "clock")
                    Label(String(format: "%.0f km", distance), systemImage: "ruler")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ContrailTheme.skyBlue)
            }

            Spacer()

            // Close button
            Button {
                withAnimation { selectedAirport = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ContrailTheme.mutedText)
                    .frame(width: 28, height: 28)
                    .background(ContrailTheme.contrailWhite.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.7))
        .background(ContrailTheme.surfaceNavy.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ContrailTheme.glowAmber.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    }

    // MARK: - Time Slider Bar

    private var timeSliderBar: some View {
        HStack(spacing: 14) {
            Image(systemName: "timer")
                .font(.system(size: 13))
                .foregroundStyle(ContrailTheme.skyBlue)

            Text("5m")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(ContrailTheme.mutedText)

            Slider(value: $focusMinutes, in: 5...240, step: 5)
                .tint(ContrailTheme.skyBlue)

            Text("4h")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(ContrailTheme.mutedText)

            Text(FlightCalculator.formattedDuration(focusDuration))
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(ContrailTheme.contrailWhite)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.15), value: focusMinutes)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.7))
        .background(ContrailTheme.surfaceNavy.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ContrailTheme.contrailWhite.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
    }

    // MARK: - Start Journey Button

    private var startJourneyButton: some View {
        Button {
            guard let airport = selectedAirport else { return }
            let duration = FlightCalculator.flightDuration(from: departure, to: airport)
            let info = ActiveSessionInfo(departure: departure, destination: airport, duration: duration)
            onStartSession(info)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "airplane")
                    .rotationEffect(.degrees(-45))
                Text("Start Journey")
                    .fontWeight(.semibold)
            }
            .font(.system(size: 15))
            .foregroundStyle(
                selectedAirport != nil ? ContrailTheme.darkNavy : ContrailTheme.mutedText
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                selectedAirport != nil
                    ? AnyShapeStyle(ContrailTheme.contrailWhite)
                    : AnyShapeStyle(ContrailTheme.surfaceNavy)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(
                color: selectedAirport != nil
                    ? ContrailTheme.contrailWhite.opacity(0.2)
                    : Color.clear,
                radius: 12, y: 4
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedAirport == nil)
        .animation(.easeInOut(duration: 0.2), value: selectedAirport?.id)
    }
}

#Preview {
    let berlin = Airport(id: 0, name: "Berlin Brandenburg", iataCode: "BER",
                         latitude: 52.3667, longitude: 13.5033, country: "DE", municipality: "Berlin")
    MapPickerView(departure: berlin, preferredMapStyle: "imagery") { _ in }
}
