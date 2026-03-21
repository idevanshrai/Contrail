//
//  TimerView.swift
//  Contrail
//

import SwiftUI
import SwiftData

/// The active focus session screen — countdown, animated airplane, and ambient sound controls.
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
            ContrailTheme.skyGradient.ignoresSafeArea()

            // Subtle stars
            StarsView()

            VStack(spacing: 0) {
                routeHeader
                    .padding(.top, 30)

                Spacer()

                countdownDisplay
                phaseLabel

                Spacer()

                flightProgressBar
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)

                controlBar
                    .padding(.bottom, 30)
            }
            .padding()
        }
        .onAppear { startSession() }
        .onDisappear { cleanup() }
    }

    // MARK: - Route Header

    private var routeHeader: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text(sessionInfo.departure.iataCode)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(ContrailTheme.contrailWhite)
                Text(sessionInfo.departure.municipality)
                    .font(ContrailTheme.captionFont)
                    .foregroundStyle(ContrailTheme.mutedText)
            }

            VStack(spacing: 4) {
                Image(systemName: "airplane")
                    .font(.system(size: 14))
                    .foregroundStyle(ContrailTheme.skyBlue.opacity(0.7))
                Text(FlightCalculator.formattedDuration(totalDuration))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(ContrailTheme.mutedText)
            }

            VStack(spacing: 4) {
                Text(sessionInfo.destination.iataCode)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(ContrailTheme.contrailWhite)
                Text(sessionInfo.destination.municipality)
                    .font(ContrailTheme.captionFont)
                    .foregroundStyle(ContrailTheme.mutedText)
            }
        }
    }

    // MARK: - Countdown

    private var countdownDisplay: some View {
        Text(FlightCalculator.countdownString(remainingTime))
            .font(ContrailTheme.countdownFont)
            .foregroundStyle(ContrailTheme.contrailWhite)
            .contentTransition(.numericText())
            .animation(.linear(duration: 0.1), value: remainingTime)
            .padding(.bottom, 8)
    }

    private var phaseLabel: some View {
        Text(flightPhase.label)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(flightPhase.color)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(flightPhase.color.opacity(0.12))
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.5), value: flightPhase)
    }

    // MARK: - Progress Bar

    private var flightProgressBar: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(ContrailTheme.contrailWhite.opacity(0.1))
                    .frame(height: 4)

                // Contrail (filled portion)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ContrailTheme.contrailGradient)
                        .frame(width: max(0, geo.size.width * progress))
                        .animation(.linear(duration: 1), value: progress)
                }
                .frame(height: 4)

                // Airplane icon
                GeometryReader { geo in
                    Image(systemName: "airplane")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(ContrailTheme.contrailWhite)
                        .rotationEffect(.degrees(0))
                        .offset(x: max(0, min(geo.size.width * progress - 10, geo.size.width - 20)))
                        .animation(.linear(duration: 1), value: progress)
                }
                .frame(height: 24)
                .offset(y: -10)
            }
            .frame(height: 24)

            // Departure / Destination labels
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
        HStack(spacing: 24) {
            // Sound toggle
            Button {
                soundManager.toggleMute()
            } label: {
                Image(systemName: soundManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(ContrailTheme.mutedText)
                    .frame(width: 44, height: 44)
                    .background(ContrailTheme.surfaceNavy.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Pause / Resume
            if !isComplete {
                Button {
                    if isPaused {
                        resumeTimer()
                    } else {
                        pauseTimer()
                    }
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ContrailTheme.contrailWhite)
                        .frame(width: 56, height: 56)
                        .background(ContrailTheme.skyBlue)
                        .clipShape(Circle())
                        .shadow(color: ContrailTheme.skyBlue.opacity(0.4), radius: 8, y: 2)
                }
                .buttonStyle(.plain)
            }

            // End flight / Return
            Button {
                if isComplete {
                    onComplete()
                } else {
                    endSession()
                }
            } label: {
                Image(systemName: isComplete ? "arrow.right.circle.fill" : "xmark")
                    .font(.system(size: 16))
                    .foregroundStyle(isComplete ? ContrailTheme.arrivedGreen : ContrailTheme.mutedText)
                    .frame(width: 44, height: 44)
                    .background(ContrailTheme.surfaceNavy.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
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

        // Save to SwiftData
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
        case .boarding: return ContrailTheme.sunsetGold
        case .takeoff:  return ContrailTheme.skyBlue
        case .cruising: return ContrailTheme.contrailWhite
        case .landing:  return ContrailTheme.sunsetGold
        case .arrived:  return ContrailTheme.arrivedGreen
        }
    }
}

// MARK: - Stars Background

struct StarsView: View {
    @State private var opacity: Double = 0.3

    var body: some View {
        Canvas { context, size in
            // Use a seeded generator for consistent star positions
            var rng = SeededRandomNumberGenerator(seed: 42)
            for _ in 0..<60 {
                let x = Double.random(in: 0...size.width, using: &rng)
                let y = Double.random(in: 0...size.height, using: &rng)
                let radius = Double.random(in: 0.5...1.5, using: &rng)
                let starOpacity = Double.random(in: 0.2...0.7, using: &rng)

                context.opacity = starOpacity * opacity
                let rect = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(.white))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                opacity = 0.8
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
