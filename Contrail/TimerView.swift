//
//  TimerView.swift
//  Contrail
//

import SwiftUI
import SwiftData

/// The active focus session screen — immersive nocturnal countdown with boarding-pass header.
struct TimerView: View {

    let sessionInfo: ActiveSessionInfo
    var onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @StateObject private var soundManager = SoundManager()

    @State private var remainingTime: TimeInterval
    @State private var totalDuration: TimeInterval
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var isComplete = false
    @State private var timer: Timer?

    init(sessionInfo: ActiveSessionInfo, onComplete: @escaping () -> Void) {
        self.sessionInfo = sessionInfo
        self.onComplete = onComplete
        _remainingTime = State(initialValue: sessionInfo.duration)
        _totalDuration = State(initialValue: sessionInfo.duration)
    }

    private var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1.0 - (remainingTime / totalDuration)
    }

    private var flightPhase: FlightPhase {
        switch progress {
        case 0..<0.05:    return .boarding
        case 0.05..<0.15: return .takeoff
        case 0.15..<0.85: return .cruising
        case 0.85..<1.0:  return .landing
        default:          return .arrived
        }
    }

    var body: some View {
        ZStack {
            // Nocturnal gradient background
            ContrailTheme.skyGradient.ignoresSafeArea()

            // Subtle stars
            StarsView()

            // Ambient glow behind countdown
            ContrailTheme.ambientGlow
                .opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Boarding pass header
                boardingPassHeader
                    .padding(.top, 32)
                    .padding(.horizontal, 40)

                Spacer()

                // Countdown
                countdownDisplay
                phaseLabel
                    .padding(.top, 8)

                Spacer()

                // Flight progress
                flightProgressBar
                    .padding(.horizontal, 50)
                    .padding(.bottom, 36)

                // Controls
                controlBar
                    .padding(.bottom, 36)
            }
            .padding()
        }
        .onAppear { startSession() }
        .onDisappear { cleanup() }
    }

    // MARK: - Boarding Pass Header

    private var boardingPassHeader: some View {
        HStack(spacing: 0) {
            // Departure
            VStack(spacing: 4) {
                Text(sessionInfo.departure.iataCode)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(ContrailTheme.contrailWhite)
                Text(sessionInfo.departure.municipality)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ContrailTheme.mutedText)
            }

            Spacer()

            // Flight path indicator
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(ContrailTheme.skyBlue)
                        .frame(width: 6, height: 6)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [ContrailTheme.skyBlue, ContrailTheme.glowAmber],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1.5)
                    Image(systemName: "airplane")
                        .font(.system(size: 12))
                        .foregroundStyle(ContrailTheme.glowAmber)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [ContrailTheme.glowAmber, ContrailTheme.glowAmber.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1.5)
                    Circle()
                        .stroke(ContrailTheme.glowAmber.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 6, height: 6)
                }

                Text(FlightCalculator.formattedDuration(totalDuration))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(ContrailTheme.mutedText)
            }
            .frame(maxWidth: 180)

            Spacer()

            // Destination
            VStack(spacing: 4) {
                Text(sessionInfo.destination.iataCode)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(ContrailTheme.contrailWhite)
                Text(sessionInfo.destination.municipality)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ContrailTheme.mutedText)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial.opacity(0.3))
        .background(ContrailTheme.surfaceNavy.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ContrailTheme.contrailWhite.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Countdown

    private var countdownDisplay: some View {
        Text(FlightCalculator.countdownString(remainingTime))
            .font(ContrailTheme.countdownFont)
            .foregroundStyle(ContrailTheme.contrailWhite)
            .shadow(color: ContrailTheme.skyBlue.opacity(0.2), radius: 20)
            .contentTransition(.numericText())
            .animation(.linear(duration: 0.1), value: remainingTime)
    }

    private var phaseLabel: some View {
        Text(flightPhase.label)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(flightPhase.color)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial.opacity(0.3))
            .background(flightPhase.color.opacity(0.08))
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.5), value: flightPhase)
    }

    // MARK: - Progress Bar

    private var flightProgressBar: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(ContrailTheme.contrailWhite.opacity(0.08))
                    .frame(height: 3)

                // Amber contrail (filled)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [ContrailTheme.skyBlue, ContrailTheme.glowAmber],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * progress))
                        .shadow(color: ContrailTheme.glowAmber.opacity(0.4), radius: 4)
                        .animation(.linear(duration: 1), value: progress)
                }
                .frame(height: 3)

                // Airplane icon
                GeometryReader { geo in
                    Image(systemName: "airplane")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(ContrailTheme.contrailWhite)
                        .shadow(color: ContrailTheme.contrailWhite.opacity(0.4), radius: 6)
                        .offset(x: max(0, min(geo.size.width * progress - 9, geo.size.width - 18)))
                        .animation(.linear(duration: 1), value: progress)
                }
                .frame(height: 22)
                .offset(y: -10)
            }
            .frame(height: 22)

            // Labels
            HStack {
                Text(sessionInfo.departure.iataCode)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(ContrailTheme.mutedText)
                Spacer()
                Text(sessionInfo.destination.iataCode)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(ContrailTheme.mutedText)
            }
        }
    }

    // MARK: - Controls

    private var controlBar: some View {
        HStack(spacing: 20) {
            // Sound toggle
            controlButton(
                icon: soundManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                color: ContrailTheme.mutedText
            ) {
                soundManager.toggleMute()
            }

            // Pause / Resume
            if !isComplete {
                Button {
                    if isPaused { resumeTimer() } else { pauseTimer() }
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ContrailTheme.darkNavy)
                        .frame(width: 56, height: 56)
                        .background(ContrailTheme.contrailWhite)
                        .clipShape(Circle())
                        .shadow(color: ContrailTheme.contrailWhite.opacity(0.3), radius: 12, y: 2)
                }
                .buttonStyle(.plain)
            }

            // End / Return
            controlButton(
                icon: isComplete ? "checkmark.circle.fill" : "xmark",
                color: isComplete ? ContrailTheme.arrivedGreen : ContrailTheme.mutedText
            ) {
                if isComplete { onComplete() } else { endSession() }
            }
        }
    }

    private func controlButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial.opacity(0.3))
                .background(ContrailTheme.surfaceNavy.opacity(0.5))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(ContrailTheme.contrailWhite.opacity(0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timer Logic

    private func startSession() {
        isRunning = true
        soundManager.play()
        scheduleTimer()
    }

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if remainingTime > 0 {
                    remainingTime -= 1
                } else {
                    completeSession()
                }
            }
        }
    }

    private func pauseTimer() {
        isPaused = true
        timer?.invalidate()
        timer = nil
    }

    private func resumeTimer() {
        isPaused = false
        scheduleTimer()
    }

    private func completeSession() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isComplete = true
        soundManager.stop()
        remainingTime = 0

        let session = Session(
            departureCode: sessionInfo.departure.iataCode,
            departureName: sessionInfo.departure.name,
            destinationCode: sessionInfo.destination.iataCode,
            destinationName: sessionInfo.destination.name,
            duration: totalDuration
        )
        modelContext.insert(session)
    }

    private func endSession() {
        cleanup()
        onComplete()
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        soundManager.stop()
    }
}

// MARK: - Flight Phase

enum FlightPhase: String, Equatable {
    case boarding, takeoff, cruising, landing, arrived

    var label: String {
        switch self {
        case .boarding: return "✈ Boarding"
        case .takeoff:  return "🛫 Taking Off"
        case .cruising: return "☁ Cruising"
        case .landing:  return "🛬 Landing"
        case .arrived:  return "✓ Arrived"
        }
    }

    var color: Color {
        switch self {
        case .boarding: return ContrailTheme.glowAmber
        case .takeoff:  return ContrailTheme.skyBlue
        case .cruising: return ContrailTheme.contrailWhite
        case .landing:  return ContrailTheme.glowAmber
        case .arrived:  return ContrailTheme.arrivedGreen
        }
    }
}

// MARK: - Stars Background

struct StarsView: View {
    @State private var opacity: Double = 0.2

    var body: some View {
        Canvas { context, size in
            var rng = SeededRandomNumberGenerator(seed: 42)
            for _ in 0..<80 {
                let x = Double.random(in: 0...size.width, using: &rng)
                let y = Double.random(in: 0...size.height, using: &rng)
                let radius = Double.random(in: 0.3...1.2, using: &rng)
                let starOpacity = Double.random(in: 0.15...0.6, using: &rng)

                context.opacity = starOpacity * opacity
                let rect = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(.white))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                opacity = 0.6
            }
        }
    }
}

/// Simple seeded random number generator for deterministic star placement.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

#Preview {
    let sampleDep = Airport(id: 1, name: "John F Kennedy Intl", iataCode: "JFK", latitude: 40.6413, longitude: -73.7781, country: "US", municipality: "New York")
    let sampleDest = Airport(id: 2, name: "Los Angeles Intl", iataCode: "LAX", latitude: 33.9425, longitude: -118.4081, country: "US", municipality: "Los Angeles")
    let info = ActiveSessionInfo(departure: sampleDep, destination: sampleDest, duration: 120)
    TimerView(sessionInfo: info) {}
}
