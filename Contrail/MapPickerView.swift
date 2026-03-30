//
//  MapPickerView.swift
//  Contrail
//

import SwiftUI
import MapKit

/// Interactive globe-style destination selector.
/// Greeting → dark map → black/yellow airport carousel → time slider → "Book My Flight".
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

    /// Map pins — capped at 250 for performance, carousel shows all.
    private var mapPinAirports: [Airport] {
        Array(reachableAirports.prefix(250))
    }

    private var mapStyle: MapStyle {
        switch preferredMapStyle {
        case "standard": return .standard(pointsOfInterest: .excludingAll)
        case "hybrid":   return .hybrid(pointsOfInterest: .excludingAll)
        default:         return .imagery(elevation: .realistic)
        }
    }

    var body: some View {
        ZStack {
            ContrailTheme.darkNavy.ignoresSafeArea()

            mapView.ignoresSafeArea()

            // Overlays
            VStack(spacing: 0) {
                // Greeting
                greetingHeader
                    .padding(.top, 20)
                    .padding(.horizontal, 28)

                Spacer()

                VStack(spacing: 12) {
                    // Time tick ruler
                    timeRuler
                        .padding(.horizontal, 4)

                    // Airport carousel
                    airportCarousel

                    // Book button
                    bookFlightButton
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear { updateCamera() }
        .onChange(of: focusMinutes) { _, _ in
            withAnimation(.easeInOut(duration: 0.5)) { updateCamera() }
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

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(reachableAirports.count)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(ContrailTheme.glowAmber)
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
            Annotation(departure.iataCode, coordinate: CLLocationCoordinate2D(
                latitude: departure.latitude, longitude: departure.longitude
            )) { departurePinView }

            MapCircle(
                center: CLLocationCoordinate2D(latitude: departure.latitude, longitude: departure.longitude),
                radius: radiusMeters
            )
            .foregroundStyle(ContrailTheme.glowAmber.opacity(0.04))
            .stroke(ContrailTheme.glowAmber.opacity(0.2), lineWidth: 1.5)

            ForEach(mapPinAirports) { airport in
                Annotation("", coordinate: CLLocationCoordinate2D(
                    latitude: airport.latitude, longitude: airport.longitude
                )) { mapDotView(for: airport) }
            }
        }
        .mapStyle(mapStyle)
        .mapControls { MapZoomStepper() }
    }

    private var departurePinView: some View {
        ZStack {
            Circle().stroke(ContrailTheme.glowAmber.opacity(0.4), lineWidth: 2).frame(width: 36, height: 36)
            Circle().fill(ContrailTheme.glowAmber).frame(width: 22, height: 22)
                .shadow(color: ContrailTheme.glowAmber.opacity(0.6), radius: 10)
            Image(systemName: "airplane").font(.system(size: 11, weight: .bold))
                .foregroundStyle(.black).rotationEffect(.degrees(-45))
        }
    }

    private func mapDotView(for airport: Airport) -> some View {
        let isSelected = selectedAirport?.id == airport.id
        return Button {
            ContrailTheme.haptic(.alignment)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedAirport = airport
            }
        } label: {
            Circle()
                .fill(isSelected ? ContrailTheme.glowAmber : ContrailTheme.contrailWhite.opacity(0.6))
                .frame(width: isSelected ? 14 : 6, height: isSelected ? 14 : 6)
                .shadow(color: (isSelected ? ContrailTheme.glowAmber : ContrailTheme.contrailWhite).opacity(0.4), radius: isSelected ? 8 : 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Time Ruler (FocusFlights-inspired tick marks)

    private var timeRuler: some View {
        VStack(spacing: 4) {
            // Tick marks
            GeometryReader { geo in
                let totalWidth = geo.size.width - 48 // padding
                let marks: [(String, Double)] = [
                    ("30m", 30), ("40m", 40), ("50m", 50),
                    ("1h 0m", 60), ("1h 10m", 70), ("1h 20m", 80), ("1h 30m", 90),
                ]

                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(ContrailTheme.contrailWhite.opacity(0.08))
                        .frame(height: 1)
                        .offset(y: 8)

                    // Tick marks
                    ForEach(marks, id: \.0) { label, mins in
                        let frac = (mins - 5) / (240 - 5)
                        let x = 24 + totalWidth * frac

                        VStack(spacing: 2) {
                            Rectangle()
                                .fill(ContrailTheme.contrailWhite.opacity(mins == Double(Int(focusMinutes)) ? 0.8 : 0.2))
                                .frame(width: 1, height: mins == Double(Int(focusMinutes)) ? 12 : 8)

                            if mins.truncatingRemainder(dividingBy: 30) == 0 || mins == Double(Int(focusMinutes)) {
                                Text(label)
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(ContrailTheme.contrailWhite.opacity(0.4))
                            }
                        }
                        .position(x: x, y: 14)
                    }
                }
            }
            .frame(height: 28)

            // Slider (hidden visual, interactive)
            Slider(value: $focusMinutes, in: 5...240, step: 5)
                .tint(ContrailTheme.glowAmber)
                .padding(.horizontal, 24)
                .frame(height: 20)
                .onChange(of: focusMinutes) { _, _ in
                    ContrailTheme.haptic(.alignment)
                }
        }
    }

    // MARK: - Airport Carousel (Black/Yellow Cards)

    private var airportCarousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(reachableAirports) { airport in
                        airportCard(airport: airport)
                            .id(airport.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 24)
            }
            .scrollTargetBehavior(.viewAligned)
            .frame(height: 80)
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
            ContrailTheme.haptic(.levelChange)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedAirport = airport
            }
            // Pan map
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
            HStack(spacing: 12) {
                // Yellow IATA badge
                VStack(spacing: 2) {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 10))
                        .foregroundStyle(ContrailTheme.glowAmber)
                    Text(airport.iataCode)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(ContrailTheme.glowAmber)
                }
                .frame(width: 50)

                // City + distance
                VStack(alignment: .leading, spacing: 3) {
                    Text(airport.municipality.isEmpty ? airport.name : airport.municipality)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ContrailTheme.contrailWhite)
                        .lineLimit(1)

                    Text(FlightCalculator.formattedDuration(duration))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(ContrailTheme.mutedText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minWidth: 140)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isSelected ? ContrailTheme.glowAmber : ContrailTheme.glowAmber.opacity(0.25),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: isSelected ? ContrailTheme.glowAmber.opacity(0.3) : .black.opacity(0.3), radius: isSelected ? 10 : 4, y: 2)
            .scaleEffect(isSelected ? 1.06 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Book Flight Button

    private var bookFlightButton: some View {
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
                Text(selectedAirport != nil ? "Book My Flight" : "Select a Destination")
                    .fontWeight(.semibold)
            }
            .font(.system(size: 15))
            .foregroundStyle(
                selectedAirport != nil ? .black : ContrailTheme.mutedText
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                selectedAirport != nil
                    ? AnyShapeStyle(ContrailTheme.glowAmber)
                    : AnyShapeStyle(ContrailTheme.surfaceNavy)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(
                color: selectedAirport != nil ? ContrailTheme.glowAmber.opacity(0.3) : .clear,
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
