//
//  MapPickerView.swift
//  Contrail
//

import SwiftUI
import MapKit

/// Interactive globe-style destination selector inspired by FocusFlights.
/// Greeting header + dark map + airport carousel + time slider + "Start Journey" button.
struct MapPickerView: View {

    let departure: Airport
    let preferredMapStyle: String
    @StateObject private var airportService = AirportDataService()

    @State private var focusMinutes: Double = 60
    @State private var selectedAirport: Airport?
    @State private var cameraPosition: MapCameraPosition = .automatic

    var onStartSession: (ActiveSessionInfo) -> Void

    private var focusDuration: TimeInterval { focusMinutes * 60 }
    private var radiusKm: Double { FlightCalculator.reachableRadiusKm(forDuration: focusDuration) }
    private var radiusMeters: Double { radiusKm * 1000 }

    private var reachableAirports: [Airport] {
        airportService.airportsReachable(from: departure, within: focusDuration)
    }

    /// Map pins — capped at 200 for performance, but the carousel shows all.
    private var mapPinAirports: [Airport] {
        Array(reachableAirports.prefix(200))
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
                VStack(spacing: 12) {
                    // Airport carousel
                    airportCarousel

                    // Time slider bar
                    timeSliderBar
                        .padding(.horizontal, 24)

                    // Start Journey button
                    startJourneyButton
                        .padding(.horizontal, 24)
                }
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
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: reachableAirports.count)
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

            // Destination pins (capped for perf, but visible on map)
            ForEach(mapPinAirports) { airport in
                Annotation("", coordinate: CLLocationCoordinate2D(
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
            ContrailTheme.haptic(.alignment)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedAirport = airport
            }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(ContrailTheme.glowAmber.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Circle()
                        .fill(ContrailTheme.glowAmber)
                        .frame(width: 18, height: 18)
                        .shadow(color: ContrailTheme.glowAmber.opacity(0.6), radius: 8)
                } else {
                    Circle()
                        .fill(ContrailTheme.contrailWhite.opacity(0.7))
                        .frame(width: 7, height: 7)
                        .shadow(color: ContrailTheme.contrailWhite.opacity(0.3), radius: 3)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Airport Carousel

    private var airportCarousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(reachableAirports) { airport in
                        airportCard(airport: airport)
                            .id(airport.id)
                    }
                }
                .padding(.horizontal, 24)
            }
            .frame(height: 110)
            .onChange(of: selectedAirport?.id) { _, newId in
                if let id = newId {
                    withAnimation(.spring(response: 0.4)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private func airportCard(airport: Airport) -> some View {
        let isSelected = selectedAirport?.id == airport.id
        let duration = FlightCalculator.flightDuration(from: departure, to: airport)
        let distance = FlightCalculator.haversineDistance(from: departure, to: airport)

        return Button {
            ContrailTheme.haptic(.alignment)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedAirport = airport
            }
            // Pan camera to show both departure and destination
            withAnimation(.easeInOut(duration: 0.6)) {
                let midLat = (departure.latitude + airport.latitude) / 2
                let midLon = (departure.longitude + airport.longitude) / 2
                cameraPosition = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
                    latitudinalMeters: distance * 2800,
                    longitudinalMeters: distance * 2800
                ))
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Top row: IATA + city flag
                HStack(spacing: 8) {
                    Text(airport.iataCode)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(isSelected ? ContrailTheme.glowAmber : ContrailTheme.contrailWhite)

                    Spacer()

                    Text(airport.country)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(ContrailTheme.mutedText)
                }

                // City name
                Text(airport.municipality.isEmpty ? airport.name : airport.municipality)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ContrailTheme.contrailWhite.opacity(0.8))
                    .lineLimit(1)

                // Stats row: distance + time
                HStack(spacing: 12) {
                    Label(String(format: "%.0f km", distance), systemImage: "ruler")
                    Label(FlightCalculator.formattedDuration(duration), systemImage: "clock")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ContrailTheme.skyBlue)
            }
            .frame(width: 150)
            .padding(14)
            .background(.ultraThinMaterial.opacity(isSelected ? 0.7 : 0.4))
            .background(
                isSelected ? ContrailTheme.glowAmber.opacity(0.08) : ContrailTheme.surfaceNavy.opacity(0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? ContrailTheme.glowAmber.opacity(0.3) : ContrailTheme.contrailWhite.opacity(0.06),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(color: isSelected ? ContrailTheme.glowAmber.opacity(0.15) : .black.opacity(0.15), radius: 8, y: 2)
            .scaleEffect(isSelected ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
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
            ContrailTheme.haptic(.levelChange)
            let duration = FlightCalculator.flightDuration(from: departure, to: airport)
            let info = ActiveSessionInfo(departure: departure, destination: airport, duration: duration)
            onStartSession(info)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "airplane")
                    .rotationEffect(.degrees(-45))

                if let airport = selectedAirport {
                    Text("Fly to \(airport.iataCode)")
                        .fontWeight(.semibold)
                } else {
                    Text("Select a Destination")
                        .fontWeight(.semibold)
                }
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
