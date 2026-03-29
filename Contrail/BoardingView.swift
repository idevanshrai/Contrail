//
//  BoardingView.swift
//  Contrail
//

import SwiftUI

/// Animated boarding sequence before the focus session begins.
/// Three phases: Boarding Pass → Seat Selection → Takeoff Transition.
struct BoardingView: View {

    let sessionInfo: ActiveSessionInfo
    var onBoardingComplete: () -> Void

    @State private var phase: BoardingPhase = .boardingPass
    @State private var boardingPassVisible = false
    @State private var seatGridVisible = false
    @State private var selectedSeat: String? = nil
    @State private var takeoffVisible = false
    @State private var passElementsVisible = false

    private let seatRows = ["A", "B", "C", "D", "E", "F"]
    private let seatColumns = 1...6

    // Random gate and flight number for immersion
    private var gate: String {
        let gates = ["A1", "A3", "B7", "C2", "D4", "E9", "F12", "G5"]
        let idx = abs(sessionInfo.departure.iataCode.hashValue) % gates.count
        return gates[idx]
    }

    private var flightNumber: String {
        let num = abs(sessionInfo.destination.iataCode.hashValue % 9000) + 1000
        return "CT\(num)"
    }

    var body: some View {
        ZStack {
            ContrailTheme.darkNavy.ignoresSafeArea()

            // Ambient glow
            ContrailTheme.ambientGlow
                .opacity(0.3)
                .ignoresSafeArea()

            switch phase {
            case .boardingPass:
                boardingPassView
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
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
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                boardingPassVisible = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6)) {
                passElementsVisible = true
            }
        }
    }

    // MARK: - Phase 1: Boarding Pass

    private var boardingPassView: some View {
        VStack(spacing: 32) {
            Text("YOUR BOARDING PASS")
                .font(.system(size: 11, weight: .bold))
                .tracking(3)
                .foregroundStyle(ContrailTheme.mutedText)
                .opacity(passElementsVisible ? 1 : 0)

            // The boarding pass card
            VStack(spacing: 0) {
                // Top section — route
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FROM")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(ContrailTheme.mutedText)
                        Text(sessionInfo.departure.iataCode)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(ContrailTheme.darkNavy)
                        Text(sessionInfo.departure.municipality)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ContrailTheme.mutedText)
                    }

                    Spacer()

                    VStack(spacing: 6) {
                        Image(systemName: "airplane")
                            .font(.system(size: 20))
                            .foregroundStyle(ContrailTheme.skyBlue)
                        Text(FlightCalculator.formattedDuration(sessionInfo.duration))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(ContrailTheme.mutedText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("TO")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(ContrailTheme.mutedText)
                        Text(sessionInfo.destination.iataCode)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(ContrailTheme.darkNavy)
                        Text(sessionInfo.destination.municipality)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ContrailTheme.mutedText)
                    }
                }
                .padding(28)
                .background(ContrailTheme.contrailWhite)

                // Perforated divider
                HStack(spacing: 0) {
                    Circle()
                        .fill(ContrailTheme.darkNavy)
                        .frame(width: 20, height: 20)
                        .offset(x: -10)

                    Spacer()

                    ForEach(0..<20, id: \.self) { _ in
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 4, height: 4)
                        Spacer()
                    }

                    Circle()
                        .fill(ContrailTheme.darkNavy)
                        .frame(width: 20, height: 20)
                        .offset(x: 10)
                }
                .frame(height: 20)
                .background(ContrailTheme.contrailWhite)

                // Bottom section — details
                HStack {
                    detailColumn(label: "FLIGHT", value: flightNumber)
                    Spacer()
                    detailColumn(label: "GATE", value: gate)
                    Spacer()
                    detailColumn(label: "DATE", value: Date.now.formatted(.dateTime.month(.abbreviated).day()))
                    Spacer()
                    detailColumn(label: "SEAT", value: selectedSeat ?? "--")
                }
                .padding(24)
                .background(ContrailTheme.contrailWhite)

                // Barcode strip
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

            // Proceed button
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
                    .foregroundStyle(ContrailTheme.contrailWhite)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial.opacity(0.5))
                    .background(ContrailTheme.surfaceNavy)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(ContrailTheme.contrailWhite.opacity(0.1), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .hoverGlow()
            .opacity(passElementsVisible ? 1 : 0)
        }
        .padding(40)
    }

    private func detailColumn(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(ContrailTheme.mutedText)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(ContrailTheme.darkNavy)
        }
    }

    // MARK: - Phase 2: Seat Selection

    private var seatSelectionView: some View {
        VStack(spacing: 28) {
            Text("CHOOSE YOUR SEAT")
                .font(.system(size: 11, weight: .bold))
                .tracking(3)
                .foregroundStyle(ContrailTheme.mutedText)

            // Aircraft cabin cross-section
            VStack(spacing: 6) {
                // Window indicators
                HStack(spacing: 0) {
                    Text("Window")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(ContrailTheme.mutedText)
                    Spacer()
                    Text("Aisle")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(ContrailTheme.mutedText)
                    Spacer()
                    Text("Window")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(ContrailTheme.mutedText)
                }
                .padding(.horizontal, 20)

                ForEach(Array(seatColumns), id: \.self) { col in
                    HStack(spacing: 8) {
                        // Left side (A, B, C)
                        ForEach(["A", "B", "C"], id: \.self) { row in
                            seatButton(row: row, col: col)
                        }

                        // Aisle
                        Text("\(col)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(ContrailTheme.mutedText.opacity(0.5))
                            .frame(width: 24)

                        // Right side (D, E, F)
                        ForEach(["D", "E", "F"], id: \.self) { row in
                            seatButton(row: row, col: col)
                        }
                    }
                }
            }
            .padding(24)
            .background(.ultraThinMaterial.opacity(0.4))
            .background(ContrailTheme.surfaceNavy.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(ContrailTheme.contrailWhite.opacity(0.06), lineWidth: 1)
            )
            .frame(maxWidth: 360)
            .scaleEffect(seatGridVisible ? 1 : 0.9)
            .opacity(seatGridVisible ? 1 : 0)

            if selectedSeat != nil {
                Button {
                    ContrailTheme.haptic(.levelChange)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        phase = .takeoff
                    }
                    // Auto-complete boarding after brief takeoff moment
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        onBoardingComplete()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "airplane")
                            .rotationEffect(.degrees(-45))
                        Text("Board Flight")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ContrailTheme.darkNavy)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(ContrailTheme.contrailWhite)
                    .clipShape(Capsule())
                    .shadow(color: ContrailTheme.contrailWhite.opacity(0.2), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
                .hoverGlow(ContrailTheme.contrailWhite)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(40)
    }

    private func seatButton(row: String, col: Int) -> some View {
        let seatId = "\(col)\(row)"
        let isSelected = selectedSeat == seatId
        // Some seats are "taken" (deterministic hash)
        let isTaken = abs((row + String(col)).hashValue) % 3 == 0

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
                    isTaken ? ContrailTheme.mutedText.opacity(0.2) :
                    ContrailTheme.contrailWhite.opacity(0.08)
                )
                .frame(width: 36, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(
                            isSelected ? ContrailTheme.glowAmber.opacity(0.6) :
                            ContrailTheme.contrailWhite.opacity(0.06),
                            lineWidth: 1
                        )
                )
                .shadow(color: isSelected ? ContrailTheme.glowAmber.opacity(0.4) : .clear, radius: 6)
                .scaleEffect(isSelected ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isTaken)
    }

    // MARK: - Phase 3: Takeoff

    private var takeoffView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Seatbelt icon
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

            // Flight info
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
            .padding(.top, 8)

            Spacer()

            // Status bar
            ProgressView()
                .progressViewStyle(.linear)
                .tint(ContrailTheme.glowAmber)
                .frame(width: 200)
                .padding(.bottom, 60)
        }
    }
}

// MARK: - Boarding Phase

enum BoardingPhase {
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
