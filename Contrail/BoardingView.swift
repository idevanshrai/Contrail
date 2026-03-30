//
//  BoardingView.swift
//  Contrail
//

import SwiftUI

/// Aircraft type selection — affects seat layout and fuselage shape.
enum PlaneType: String, CaseIterable, Identifiable {
    case jet       = "Jet"
    case propeller = "Propeller"
    case concorde  = "Concorde"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .jet:       return "airplane"
        case .propeller: return "fan"
        case .concorde:  return "airplane"
        }
    }

    /// Seat columns per side
    var seatsPerSide: Int {
        switch self {
        case .jet:       return 3  // A B C | D E F
        case .propeller: return 2  // A B | C D
        case .concorde:  return 2  // A B | C D (narrow body)
        }
    }

    var seatRows: Int {
        switch self {
        case .jet:       return 6
        case .propeller: return 5
        case .concorde:  return 7
        }
    }

    var leftColumns: [String] {
        switch self {
        case .jet:       return ["A", "B", "C"]
        case .propeller: return ["A", "B"]
        case .concorde:  return ["A", "B"]
        }
    }

    var rightColumns: [String] {
        switch self {
        case .jet:       return ["D", "E", "F"]
        case .propeller: return ["C", "D"]
        case .concorde:  return ["C", "D"]
        }
    }

    /// Fun fact for easter egg
    var funFact: String {
        switch self {
        case .jet:       return "✈ Boeing 737: The best-selling commercial jet in history"
        case .propeller: return "🛩 The DC-3 could fly coast-to-coast in just 15 hours"
        case .concorde:  return "🦅 Concorde cruised at Mach 2.04 — faster than a rifle bullet"
        }
    }

    /// Fuselage width multiplier
    var bodyWidth: CGFloat {
        switch self {
        case .jet:       return 280
        case .propeller: return 220
        case .concorde:  return 200
        }
    }
}

/// Animated boarding sequence: Plane Type → Boarding Pass → Seat Selection → Takeoff.
struct BoardingView: View {

    let sessionInfo: ActiveSessionInfo
    var onBoardingComplete: () -> Void

    @State private var phase: BoardingPhase = .planeSelect
    @State private var selectedPlane: PlaneType = .jet
    @State private var boardingPassVisible = false
    @State private var seatGridVisible = false
    @State private var selectedSeat: String? = nil
    @State private var passElementsVisible = false
    @State private var showFunFact = false

    // Random gate and flight number
    private var gate: String {
        let gates = ["A1", "A3", "B7", "C2", "D4", "E9", "F12", "G5"]
        let idx = abs(sessionInfo.departure.iataCode.hashValue) % gates.count
        return gates[idx]
    }

    private var flightNumber: String {
        let num = abs(sessionInfo.destination.iataCode.hashValue % 9000) + 1000
        return "CT\(num)"
    }

    /// Easter egg: special messages for certain routes
    private var routeEasterEgg: String? {
        let route = "\(sessionInfo.departure.iataCode)-\(sessionInfo.destination.iataCode)"
        let eggs: [String: String] = [
            // Famous routes
            "JFK-LAX": "🌴 The transcontinental classic",
            "LAX-JFK": "🗽 Eastbound & down",
            "LHR-JFK": "🇬🇧→🇺🇸 The pond hop!",
            "JFK-LHR": "🇺🇸→🇬🇧 Mind the gap!",
            "DXB-LHR": "🏜→🌧 From sand to rain",
            "SFO-NRT": "🌊 Pacific crossing — 11 hours of ocean",
            "SIN-LHR": "🦁 The Kangaroo Route's northern cousin",
            "CDG-JFK": "🥐→🗽 Très magnifique!",
            // Easter eggs for Indian airports
            "DEL-BOM": "🇮🇳 The busiest air corridor in India!",
            "BOM-DEL": "🇮🇳 The busiest air corridor in India!",
            "DEL-BLR": "🖥 Silicon Valley Express",
            "BLR-DEL": "🖥 Silicon Valley Express",
        ]
        return eggs[route]
    }

    var body: some View {
        ZStack {
            ContrailTheme.darkNavy.ignoresSafeArea()
            ContrailTheme.ambientGlow.opacity(0.3).ignoresSafeArea()

            switch phase {
            case .planeSelect:
                planeSelectView
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))

            case .boardingPass:
                boardingPassView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))

            case .seatSelection:
                seatSelectionView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))

            case .takeoff:
                takeoffView
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Phase 0: Plane Type Selection

    private var planeSelectView: some View {
        VStack(spacing: 32) {
            Text("CHOOSE YOUR AIRCRAFT")
                .font(.system(size: 11, weight: .bold))
                .tracking(3)
                .foregroundStyle(ContrailTheme.mutedText)

            HStack(spacing: 16) {
                ForEach(PlaneType.allCases) { plane in
                    planeTypeCard(plane)
                }
            }

            // Fun fact
            if showFunFact {
                Text(selectedPlane.funFact)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ContrailTheme.glowAmber.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(ContrailTheme.glowAmber.opacity(0.08))
                    .clipShape(Capsule())
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Button {
                ContrailTheme.haptic(.levelChange)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    phase = .boardingPass
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                        boardingPassVisible = true
                    }
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6)) {
                        passElementsVisible = true
                    }
                }
            } label: {
                Text("Continue →")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(ContrailTheme.glowAmber)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(40)
    }

    private func planeTypeCard(_ plane: PlaneType) -> some View {
        let isSelected = selectedPlane == plane

        return Button {
            ContrailTheme.haptic(.alignment)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedPlane = plane
            }
            withAnimation(.easeInOut(duration: 0.3).delay(0.1)) {
                showFunFact = true
            }
        } label: {
            VStack(spacing: 12) {
                // Plane silhouette (stylized)
                ZStack {
                    if plane == .concorde {
                        // Distinctive delta wing shape
                        Image(systemName: "airplane")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundStyle(isSelected ? ContrailTheme.glowAmber : ContrailTheme.mutedText)
                            .scaleEffect(x: 0.8, y: 1.2)
                    } else if plane == .propeller {
                        Image(systemName: "fan")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundStyle(isSelected ? ContrailTheme.glowAmber : ContrailTheme.mutedText)
                    } else {
                        Image(systemName: "airplane")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundStyle(isSelected ? ContrailTheme.glowAmber : ContrailTheme.mutedText)
                    }
                }
                .frame(height: 44)

                Text(plane.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? ContrailTheme.contrailWhite : ContrailTheme.mutedText)

                Text("\(plane.leftColumns.count + plane.rightColumns.count)-abreast")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(ContrailTheme.mutedText.opacity(0.6))
            }
            .frame(width: 120, height: 120)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? ContrailTheme.glowAmber.opacity(0.1) : ContrailTheme.surfaceNavy)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? ContrailTheme.glowAmber.opacity(0.4) : ContrailTheme.contrailWhite.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Phase 1: Boarding Pass

    private var boardingPassView: some View {
        VStack(spacing: 32) {
            Text("YOUR BOARDING PASS")
                .font(.system(size: 11, weight: .bold))
                .tracking(3)
                .foregroundStyle(ContrailTheme.mutedText)
                .opacity(passElementsVisible ? 1 : 0)

            VStack(spacing: 0) {
                // Top: route
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FROM").font(.system(size: 9, weight: .bold)).foregroundStyle(ContrailTheme.mutedText)
                        Text(sessionInfo.departure.iataCode)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(ContrailTheme.darkNavy)
                        Text(sessionInfo.departure.municipality)
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(ContrailTheme.mutedText)
                    }
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "airplane").font(.system(size: 20)).foregroundStyle(ContrailTheme.skyBlue)
                        Text(FlightCalculator.formattedDuration(sessionInfo.duration))
                            .font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(ContrailTheme.mutedText)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("TO").font(.system(size: 9, weight: .bold)).foregroundStyle(ContrailTheme.mutedText)
                        Text(sessionInfo.destination.iataCode)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(ContrailTheme.darkNavy)
                        Text(sessionInfo.destination.municipality)
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(ContrailTheme.mutedText)
                    }
                }
                .padding(28)
                .background(ContrailTheme.contrailWhite)

                // Perforated divider
                HStack(spacing: 0) {
                    Circle().fill(ContrailTheme.darkNavy).frame(width: 20, height: 20).offset(x: -10)
                    Spacer()
                    ForEach(0..<20, id: \.self) { _ in
                        Circle().fill(Color.gray.opacity(0.3)).frame(width: 4, height: 4)
                        Spacer()
                    }
                    Circle().fill(ContrailTheme.darkNavy).frame(width: 20, height: 20).offset(x: 10)
                }
                .frame(height: 20)
                .background(ContrailTheme.contrailWhite)

                // Details
                HStack {
                    detailColumn(label: "FLIGHT", value: flightNumber)
                    Spacer()
                    detailColumn(label: "GATE", value: gate)
                    Spacer()
                    detailColumn(label: "AIRCRAFT", value: selectedPlane.rawValue.uppercased())
                    Spacer()
                    detailColumn(label: "SEAT", value: selectedSeat ?? "--")
                }
                .padding(24)
                .background(ContrailTheme.contrailWhite)

                // Route easter egg
                if let egg = routeEasterEgg {
                    Text(egg)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ContrailTheme.mutedText)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(ContrailTheme.contrailWhite)
                }

                // Barcode
                HStack(spacing: 1) {
                    ForEach(0..<50, id: \.self) { i in
                        Rectangle()
                            .fill(ContrailTheme.darkNavy.opacity(Double.random(in: 0.4...1.0)))
                            .frame(width: CGFloat.random(in: 1...3), height: 40)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .background(ContrailTheme.contrailWhite)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
            .frame(maxWidth: 420)
            .scaleEffect(boardingPassVisible ? 1 : 0.85)
            .opacity(boardingPassVisible ? 1 : 0)

            Button {
                ContrailTheme.haptic(.levelChange)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    phase = .seatSelection
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        seatGridVisible = true
                    }
                }
            } label: {
                Text("Select Your Seat →")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(ContrailTheme.glowAmber)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .opacity(passElementsVisible ? 1 : 0)
        }
        .padding(40)
    }

    private func detailColumn(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(ContrailTheme.mutedText)
            Text(value).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(ContrailTheme.darkNavy)
        }
    }

    // MARK: - Phase 2: Seat Selection (Fuselage)

    private var seatSelectionView: some View {
        VStack(spacing: 24) {
            Text("CHOOSE YOUR SEAT")
                .font(.system(size: 11, weight: .bold))
                .tracking(3)
                .foregroundStyle(ContrailTheme.mutedText)

            // Airplane fuselage
            ZStack {
                // Fuselage body
                FuselageShape()
                    .fill(ContrailTheme.surfaceNavy)
                    .frame(width: selectedPlane.bodyWidth, height: CGFloat(selectedPlane.seatRows * 55 + 120))
                    .overlay(
                        FuselageShape()
                            .stroke(ContrailTheme.contrailWhite.opacity(0.08), lineWidth: 1.5)
                    )

                // Seat grid inside fuselage
                VStack(spacing: 6) {
                    // Column headers
                    HStack(spacing: 0) {
                        ForEach(selectedPlane.leftColumns, id: \.self) { col in
                            Text(col)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(ContrailTheme.mutedText)
                                .frame(width: 36)
                        }
                        Spacer().frame(width: 30) // aisle
                        ForEach(selectedPlane.rightColumns, id: \.self) { col in
                            Text(col)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(ContrailTheme.mutedText)
                                .frame(width: 36)
                        }
                    }

                    // Rows
                    ForEach(1...selectedPlane.seatRows, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(selectedPlane.leftColumns, id: \.self) { col in
                                seatButton(row: row, col: col)
                            }

                            // Row number (aisle)
                            Text(String(format: "%02d", row))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(ContrailTheme.mutedText.opacity(0.4))
                                .frame(width: 30)

                            ForEach(selectedPlane.rightColumns, id: \.self) { col in
                                seatButton(row: row, col: col)
                            }
                        }
                    }
                }
                .padding(.top, 50)
            }
            .scaleEffect(seatGridVisible ? 1 : 0.9)
            .opacity(seatGridVisible ? 1 : 0)

            if let seat = selectedSeat {
                VStack(spacing: 8) {
                    Text("Seat \(seat)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(ContrailTheme.glowAmber)

                    Button {
                        ContrailTheme.haptic(.levelChange)
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            phase = .takeoff
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            onBoardingComplete()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "airplane").rotationEffect(.degrees(-45))
                            Text("Board Flight")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(ContrailTheme.glowAmber)
                        .clipShape(Capsule())
                        .shadow(color: ContrailTheme.glowAmber.opacity(0.3), radius: 12, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(40)
    }

    private func seatButton(row: Int, col: String) -> some View {
        let seatId = "\(row)\(col)"
        let isSelected = selectedSeat == seatId
        let isTaken = abs((col + String(row)).hashValue) % 3 == 0

        return Button {
            guard !isTaken else { return }
            ContrailTheme.haptic(.alignment)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                selectedSeat = seatId
            }
        } label: {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    isSelected ? ContrailTheme.glowAmber :
                    isTaken ? ContrailTheme.mutedText.opacity(0.15) :
                    ContrailTheme.contrailWhite.opacity(0.06)
                )
                .frame(width: 32, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(
                            isSelected ? ContrailTheme.glowAmber.opacity(0.6) :
                            isTaken ? Color.clear :
                            ContrailTheme.contrailWhite.opacity(0.04),
                            lineWidth: 1
                        )
                )
                .shadow(color: isSelected ? ContrailTheme.glowAmber.opacity(0.4) : .clear, radius: 6)
                .scaleEffect(isSelected ? 1.12 : 1.0)
                .padding(2)
        }
        .buttonStyle(.plain)
        .disabled(isTaken)
    }

    // MARK: - Phase 3: Takeoff

    private var takeoffView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "seatbelt")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(ContrailTheme.glowAmber)
                .symbolEffect(.pulse, isActive: true)

            Text("Fasten Your Seatbelt")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(ContrailTheme.contrailWhite)

            Text("Preparing for takeoff...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ContrailTheme.mutedText)

            HStack(spacing: 20) {
                Text(sessionInfo.departure.iataCode)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(ContrailTheme.contrailWhite)
                Image(systemName: "arrow.right")
                    .foregroundStyle(ContrailTheme.glowAmber)
                Text(sessionInfo.destination.iataCode)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(ContrailTheme.contrailWhite)
            }

            // Easter egg: aviator quote
            Text("\"The engine is the heart of an airplane, but the pilot is its soul.\"")
                .font(.system(size: 10, weight: .medium, design: .serif))
                .foregroundStyle(ContrailTheme.mutedText.opacity(0.4))
                .italic()
                .padding(.top, 16)

            Spacer()

            ProgressView()
                .progressViewStyle(.linear)
                .tint(ContrailTheme.glowAmber)
                .frame(width: 200)
                .padding(.bottom, 60)
        }
    }
}

// MARK: - Fuselage Shape

/// Custom shape that draws an airplane fuselage outline — rounded nose, tapered tail.
struct FuselageShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let noseRadius = w * 0.5
        let tailTaper = w * 0.15

        // Start from bottom-left of tail
        path.move(to: CGPoint(x: tailTaper, y: h))

        // Left side going up
        path.addLine(to: CGPoint(x: 0, y: noseRadius + 20))

        // Nose (rounded top)
        path.addQuadCurve(
            to: CGPoint(x: w, y: noseRadius + 20),
            control: CGPoint(x: w / 2, y: 0)
        )

        // Right side going down
        path.addLine(to: CGPoint(x: w - tailTaper, y: h))

        // Tail bottom
        path.addQuadCurve(
            to: CGPoint(x: tailTaper, y: h),
            control: CGPoint(x: w / 2, y: h - 10)
        )

        path.closeSubpath()
        return path
    }
}

enum BoardingPhase {
    case planeSelect
    case boardingPass
    case seatSelection
    case takeoff
}

#Preview {
    let dep = Airport(id: 1, name: "Berlin Brandenburg", iataCode: "BER",
                      latitude: 52.3667, longitude: 13.5033, country: "DE", municipality: "Berlin")
    let dest = Airport(id: 2, name: "Dubai Intl", iataCode: "DXB",
                       latitude: 25.2532, longitude: 55.3657, country: "AE", municipality: "Dubai")
    let info = ActiveSessionInfo(departure: dep, destination: dest, duration: 3600)
    BoardingView(sessionInfo: info) {}
}
