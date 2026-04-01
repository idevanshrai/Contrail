//
//  TimerView.swift
//  Contrail
//

import SwiftUI
import SwiftData
import MapKit

/// Active focus session — zoomed camera following the airplane along the route,
/// distance/time remaining at bottom, press-and-hold exit, sound picker.
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

    // Flight
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var airplaneCoord: CLLocationCoordinate2D
    @State private var airplaneHeading: Double = 0

    // Exit
    @State private var holdProgress: Double = 0
    @State private var isHolding = false
    @State private var holdTimer: Timer?
    @State private var showExitConfirmation = false

    // Landing
    @State private var landingAnnounced = false
    @State private var hasSpooledDown = false
    @State private var showSoundPicker = false
    @State private var showEasterEgg = false
    @State private var easterEggMessage = ""

    init(sessionInfo: ActiveSessionInfo, onComplete: @escaping () -> Void) {
        self.sessionInfo = sessionInfo
        self.onComplete = onComplete
        _remainingTime = State(initialValue: sessionInfo.duration)
        _totalDuration = State(initialValue: sessionInfo.duration)
        _airplaneCoord = State(initialValue: CLLocationCoordinate2D(
            latitude: sessionInfo.departure.latitude,
            longitude: sessionInfo.departure.longitude
        ))
    }

    private var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1.0 - (remainingTime / totalDuration)
    }

    private var distanceTotal: Double {
        FlightCalculator.haversineDistance(from: sessionInfo.departure, to: sessionInfo.destination)
    }

    private var distanceRemaining: Double {
        distanceTotal * (1.0 - progress)
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
            // Full-bleed satellite map
            flightMapView.ignoresSafeArea()

            // Top controls
            VStack(spacing: 0) {
                topBar.padding(.top, 16).padding(.horizontal, 20)
                Spacer()
                bottomInfoBar.padding(.horizontal, 20).padding(.bottom, 16)
            }

            // Overlays
            if soundManager.showLandingMessage {
                landingBanner.transition(.move(edge: .top).combined(with: .opacity))
            }
            if showExitConfirmation { exitDialog.transition(.opacity) }
            if showSoundPicker { soundPicker.transition(.move(edge: .bottom).combined(with: .opacity)) }
            if showEasterEgg { easterEggBanner.transition(.move(edge: .top).combined(with: .opacity)) }
            if isComplete { arrivedOverlay.transition(.scale.combined(with: .opacity)) }
        }
        .onAppear { startSession() }
        .onDisappear { cleanup() }
    }

    // MARK: - Map

    private var flightMapView: some View {
        Map(position: $cameraPosition) {
            // Full path (faded)
            MapPolyline(coordinates: flightPath)
                .stroke(ContrailTheme.glowAmber.opacity(0.25), lineWidth: 2)

            // Completed path (bright)
            MapPolyline(coordinates: Array(flightPath.prefix(max(1, Int(Double(flightPath.count) * progress)))))
                .stroke(ContrailTheme.glowAmber, lineWidth: 3)

            // Departure dot
            Annotation("", coordinate: CLLocationCoordinate2D(
                latitude: sessionInfo.departure.latitude, longitude: sessionInfo.departure.longitude
            )) {
                ZStack {
                    Circle().fill(ContrailTheme.skyBlue.opacity(0.2)).frame(width: 20, height: 20)
                    Circle().fill(ContrailTheme.skyBlue).frame(width: 8, height: 8)
                }
            }

            // Destination dot
            Annotation("", coordinate: CLLocationCoordinate2D(
                latitude: sessionInfo.destination.latitude, longitude: sessionInfo.destination.longitude
            )) {
                ZStack {
                    Circle().stroke(ContrailTheme.glowAmber, lineWidth: 2).frame(width: 16, height: 16)
                    Circle().fill(ContrailTheme.glowAmber.opacity(0.3)).frame(width: 8, height: 8)
                }
            }

            // Airplane
            Annotation("", coordinate: airplaneCoord) {
                ZStack {
                    // Glow behind plane
                    Circle()
                        .fill(ContrailTheme.glowAmber.opacity(0.15))
                        .frame(width: 40, height: 40)
                        .blur(radius: 8)

                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(ContrailTheme.glowAmber)
                        .rotationEffect(.degrees(airplaneHeading - 90))
                        .shadow(color: ContrailTheme.glowAmber.opacity(0.5), radius: 10)
                }
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .mapControls { }
    }

    // Great-circle path
    private var flightPath: [CLLocationCoordinate2D] {
        let steps = 100
        let lat1 = sessionInfo.departure.latitude * .pi / 180
        let lon1 = sessionInfo.departure.longitude * .pi / 180
        let lat2 = sessionInfo.destination.latitude * .pi / 180
        let lon2 = sessionInfo.destination.longitude * .pi / 180
        let d = 2 * asin(sqrt(pow(sin((lat2 - lat1) / 2), 2) + cos(lat1) * cos(lat2) * pow(sin((lon2 - lon1) / 2), 2)))
        guard d > 0 else { return [] }

        return (0...steps).map { i in
            let f = Double(i) / Double(steps)
            let A = sin((1 - f) * d) / sin(d)
            let B = sin(f * d) / sin(d)
            let x = A * cos(lat1) * cos(lon1) + B * cos(lat2) * cos(lon2)
            let y = A * cos(lat1) * sin(lon1) + B * cos(lat2) * sin(lon2)
            let z = A * sin(lat1) + B * sin(lat2)
            return CLLocationCoordinate2D(latitude: atan2(z, sqrt(x*x + y*y)) * 180 / .pi, longitude: atan2(y, x) * 180 / .pi)
        }
    }

    private func bearing() -> Double {
        let coords = flightPath
        let idx = min(Int(Double(coords.count - 1) * progress), coords.count - 2)
        guard idx >= 0, idx + 1 < coords.count else { return 0 }
        let from = coords[idx], to = coords[idx + 1]
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(to.latitude * .pi / 180)
        let x = cos(from.latitude * .pi / 180) * sin(to.latitude * .pi / 180) - sin(from.latitude * .pi / 180) * cos(to.latitude * .pi / 180) * cos(dLon)
        return atan2(y, x) * 180 / .pi
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 10) {
            // Pause/Play
            Button {
                ContrailTheme.haptic()
                if isPaused { resumeTimer() } else { pauseTimer() }
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ContrailTheme.contrailWhite)
                    .frame(width: 38, height: 38)
                    .background(ContrailTheme.cardBlack.opacity(0.9))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(ContrailTheme.contrailWhite.opacity(0.08), lineWidth: 1))
            }.buttonStyle(.plain)

            // Sound
            Button {
                ContrailTheme.haptic(.alignment)
                withAnimation(.spring(response: 0.3)) { showSoundPicker.toggle() }
            } label: {
                Image(systemName: soundManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(soundManager.isMuted ? ContrailTheme.dangerRed : ContrailTheme.contrailWhite)
                    .frame(width: 38, height: 38)
                    .background(ContrailTheme.cardBlack.opacity(0.9))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(ContrailTheme.contrailWhite.opacity(0.08), lineWidth: 1))
            }.buttonStyle(.plain)

            Spacer()

            // Route
            HStack(spacing: 8) {
                Text(sessionInfo.departure.iataCode)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                Image(systemName: "arrow.right")
                    .font(.system(size: 9)).foregroundStyle(ContrailTheme.glowAmber)
                Text(sessionInfo.destination.iataCode)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(ContrailTheme.contrailWhite)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(ContrailTheme.cardBlack.opacity(0.9))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(ContrailTheme.contrailWhite.opacity(0.08), lineWidth: 1))

            Spacer()

            // End Flight (press-and-hold)
            if !isComplete {
                endFlightButton
            } else {
                Button {
                    ContrailTheme.haptic(.levelChange)
                    onComplete()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ContrailTheme.arrivedGreen)
                        .frame(width: 38, height: 38)
                        .background(ContrailTheme.arrivedGreen.opacity(0.15))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(ContrailTheme.arrivedGreen.opacity(0.2), lineWidth: 1))
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: - Bottom Info Bar (Solid, Readable)

    private var bottomInfoBar: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Time Remaining")
                    .font(ContrailTheme.labelFont)
                    .foregroundStyle(ContrailTheme.mutedText)
                Text(FlightCalculator.countdownString(remainingTime))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(ContrailTheme.contrailWhite)
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.1), value: remainingTime)
            }

            Spacer()

            // Phase pill
            Text(flightPhase.label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(flightPhase.color)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(flightPhase.color.opacity(0.12))
                .clipShape(Capsule())

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("Distance Remaining")
                    .font(ContrailTheme.labelFont)
                    .foregroundStyle(ContrailTheme.mutedText)
                Text(String(format: "%.0f km", distanceRemaining))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(ContrailTheme.contrailWhite)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(ContrailTheme.cardBlack.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ContrailTheme.contrailWhite.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
    }

    // MARK: - Press-and-Hold End Flight

    private var endFlightButton: some View {
        ZStack {
            // Background
            Circle()
                .fill(ContrailTheme.cardBlack.opacity(0.9))
                .frame(width: 38, height: 38)
                .overlay(Circle().stroke(ContrailTheme.contrailWhite.opacity(0.08), lineWidth: 1))

            // Progress ring
            Circle()
                .trim(from: 0, to: holdProgress)
                .stroke(ContrailTheme.dangerRed, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 38, height: 38)
                .rotationEffect(.degrees(-90))

            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(holdProgress > 0 ? ContrailTheme.dangerRed : ContrailTheme.mutedText)
        }
        .onLongPressGesture(minimumDuration: 3.0, pressing: { pressing in
            if pressing {
                startHold()
            } else {
                cancelHold()
            }
        }, perform: {
            // Completed the full hold
            ContrailTheme.haptic(.generic)
            withAnimation(.spring(response: 0.4)) { showExitConfirmation = true }
            holdProgress = 0
        })
    }

    private func startHold() {
        isHolding = true
        holdProgress = 0
        ContrailTheme.haptic(.alignment)

        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            DispatchQueue.main.async {
                holdProgress = min(1.0, holdProgress + (0.05 / 3.0))

                // Haptic pulses at 33% and 66%
                if abs(holdProgress - 0.33) < 0.02 || abs(holdProgress - 0.66) < 0.02 {
                    ContrailTheme.haptic(.levelChange)
                }
            }
        }
    }

    private func cancelHold() {
        isHolding = false
        holdTimer?.invalidate()
        holdTimer = nil
        withAnimation(.easeOut(duration: 0.3)) { holdProgress = 0 }
    }

    // MARK: - Exit Confirmation

    private var exitDialog: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
                .onTapGesture { withAnimation { showExitConfirmation = false } }

            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(ContrailTheme.glowAmber)

                Text("End Flight?")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(ContrailTheme.contrailWhite)

                Text("You're \(Int(progress * 100))% through your flight.\nYour focus streak will be broken.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(ContrailTheme.mutedText)
                    .multilineTextAlignment(.center).lineSpacing(4)

                if progress > 0.8 {
                    Text("🏆 Almost there — don't give up!")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ContrailTheme.glowAmber)
                }

                HStack(spacing: 14) {
                    Button {
                        ContrailTheme.haptic()
                        withAnimation { showExitConfirmation = false }
                    } label: {
                        Text("Keep Flying")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(ContrailTheme.glowAmber)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }.buttonStyle(.plain)

                    Button {
                        ContrailTheme.haptic(.levelChange)
                        showExitConfirmation = false
                        endSession()
                    } label: {
                        Text("End Flight")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(ContrailTheme.dangerRed)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(ContrailTheme.dangerRed.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(ContrailTheme.dangerRed.opacity(0.2), lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }
            .padding(28).frame(maxWidth: 360)
            .background(ContrailTheme.cardBlack.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ContrailTheme.contrailWhite.opacity(0.06), lineWidth: 1))
            .shadow(color: .black.opacity(0.6), radius: 30)
        }
    }

    // MARK: - Landing

    private var landingBanner: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "seatbelt").font(.system(size: 16)).foregroundStyle(ContrailTheme.glowAmber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preparing for Landing")
                        .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(ContrailTheme.contrailWhite)
                    Text("We'll be arriving at \(sessionInfo.destination.iataCode) shortly")
                        .font(.system(size: 11, design: .rounded)).foregroundStyle(ContrailTheme.mutedText)
                }
                Spacer()
            }
            .padding(16)
            .background(ContrailTheme.cardBlack.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ContrailTheme.glowAmber.opacity(0.15), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 10)
            .padding(.horizontal, 28).padding(.top, 70)
            Spacer()
        }
    }

    private var easterEggBanner: some View {
        VStack {
            Spacer()
            Text(easterEggMessage)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(ContrailTheme.glowAmber)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(ContrailTheme.cardBlack.opacity(0.9))
                .clipShape(Capsule())
                .padding(.bottom, 100)
        }
    }

    // MARK: - Arrived

    private var arrivedOverlay: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(ContrailTheme.arrivedGreen.opacity(0.12)).frame(width: 120, height: 120)
                    .scaleEffect(isComplete ? 1.5 : 0.5).opacity(isComplete ? 0 : 0.5)
                    .animation(.easeOut(duration: 2).repeatForever(autoreverses: false), value: isComplete)
                Circle().fill(ContrailTheme.arrivedGreen.opacity(0.2)).frame(width: 80, height: 80)
                Image(systemName: "checkmark").font(.system(size: 28, weight: .medium)).foregroundStyle(ContrailTheme.arrivedGreen)
            }
            Text("Landed at \(sessionInfo.destination.iataCode)")
                .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(ContrailTheme.contrailWhite)
            Text(sessionInfo.destination.municipality)
                .font(.system(size: 14, design: .rounded)).foregroundStyle(ContrailTheme.mutedText)
            Text("✈ \(FlightCalculator.formattedDuration(totalDuration)) · \(String(format: "%.0f", distanceTotal)) km traveled")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(ContrailTheme.mutedText.opacity(0.5))
            Spacer()
        }
    }

    // MARK: - Sound Picker

    private var soundPicker: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
                .onTapGesture { withAnimation(.spring(response: 0.3)) { showSoundPicker = false } }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("AMBIENT SOUND")
                        .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(2)
                        .foregroundStyle(ContrailTheme.mutedText)
                    Spacer()
                    Button { soundManager.toggleMute() } label: {
                        Image(systemName: soundManager.isMuted ? "speaker.slash" : "speaker.wave.2")
                            .font(.system(size: 13))
                            .foregroundStyle(soundManager.isMuted ? ContrailTheme.dangerRed : ContrailTheme.glowAmber)
                    }.buttonStyle(.plain)
                }

                Text("ENGINE").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(ContrailTheme.mutedText.opacity(0.5))
                HStack(spacing: 8) { ForEach(AmbientSound.allCases.filter(\.isEngineSound)) { soundOption($0) } }

                Text("FOCUS").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(ContrailTheme.mutedText.opacity(0.5)).padding(.top, 4)
                HStack(spacing: 8) { ForEach(AmbientSound.allCases.filter { !$0.isEngineSound }) { soundOption($0) } }

                HStack(spacing: 10) {
                    Image(systemName: "speaker.fill").font(.system(size: 10)).foregroundStyle(ContrailTheme.mutedText)
                    Slider(value: Binding(get: { soundManager.volume }, set: { soundManager.setVolume($0) }), in: 0...1)
                        .tint(ContrailTheme.glowAmber)
                    Image(systemName: "speaker.wave.3.fill").font(.system(size: 10)).foregroundStyle(ContrailTheme.mutedText)
                }.padding(.top, 4)
            }
            .padding(20).frame(width: 300)
            .background(ContrailTheme.cardBlack.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ContrailTheme.contrailWhite.opacity(0.06), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 40).padding(.bottom, 80)
        }
    }

    private func soundOption(_ sound: AmbientSound) -> some View {
        let isActive = soundManager.selectedSound == sound
        return Button {
            ContrailTheme.haptic(.alignment)
            soundManager.switchSound(sound)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: sound.icon).font(.system(size: 16))
                    .foregroundStyle(isActive ? ContrailTheme.glowAmber : ContrailTheme.mutedText)
                Text(sound.rawValue).font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(isActive ? ContrailTheme.contrailWhite : ContrailTheme.mutedText)
            }
            .frame(width: 72, height: 56)
            .background(isActive ? ContrailTheme.glowAmber.opacity(0.1) : ContrailTheme.contrailWhite.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isActive ? ContrailTheme.glowAmber.opacity(0.3) : .clear, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    // MARK: - Timer Logic

    private func startSession() {
        isRunning = true
        soundManager.play()
        scheduleTimer()
        updateCameraZoomed()
        triggerEasterEgg()
    }

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                guard remainingTime > 0 else { completeSession(); return }
                remainingTime -= 1
                updatePlane()
                checkPhases()
            }
        }
    }

    private func updatePlane() {
        let coords = flightPath
        let idx = min(Int(Double(coords.count - 1) * progress), coords.count - 1)

        // Smooth animation for airplane position
        withAnimation(.easeInOut(duration: 1.0)) {
            airplaneCoord = coords[idx]
            airplaneHeading = bearing()
        }

        // Camera update every 5 seconds for smoothness
        if Int(remainingTime) % 5 == 0 {
            updateCameraZoomed()
        }
    }

    private func updateCameraZoomed() {
        withAnimation(.easeInOut(duration: 3.0)) {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: airplaneCoord,
                distance: 200_000,
                heading: airplaneHeading,
                pitch: 50
            ))
        }
    }

    private func checkPhases() {
        if flightPhase == .takeoff && progress >= 0.05 && progress < 0.07 {
            soundManager.spoolUp()
            ContrailTheme.haptic(.levelChange)
        }
        if remainingTime <= 60 && !landingAnnounced {
            landingAnnounced = true
            soundManager.announceLanding()
            ContrailTheme.haptic(.levelChange)
        }
        if flightPhase == .landing && !hasSpooledDown {
            hasSpooledDown = true
            soundManager.spoolDown()
            ContrailTheme.haptic(.levelChange)
        }
    }

    private func triggerEasterEgg() {
        let facts = [
            "🌍 At 35,000ft you can see ~230 miles in every direction",
            "☁ Contrails form when exhaust hits -40°C air",
            "✈ Commercial jets cruise at ~900 km/h",
            "⭐ At cruise altitude you can see 4x more stars",
            "🔊 The loudest sound on a plane is the AC system",
        ]
        let delay = Double.random(in: 30...max(31, totalDuration * 0.7))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard isRunning, !isComplete else { return }
            easterEggMessage = facts.randomElement() ?? ""
            withAnimation(.spring(response: 0.4)) { showEasterEgg = true }
            ContrailTheme.haptic(.alignment)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { withAnimation { showEasterEgg = false } }
        }
    }

    private func pauseTimer() { isPaused = true; timer?.invalidate(); timer = nil }
    private func resumeTimer() { isPaused = false; scheduleTimer() }

    private func completeSession() {
        timer?.invalidate(); timer = nil; isRunning = false; soundManager.stop(); remainingTime = 0
        ContrailTheme.haptic(.levelChange)
        withAnimation(.easeInOut(duration: 1.0)) {
            airplaneCoord = CLLocationCoordinate2D(latitude: sessionInfo.destination.latitude, longitude: sessionInfo.destination.longitude)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { isComplete = true }
        }
        modelContext.insert(Session(
            departureCode: sessionInfo.departure.iataCode, departureName: sessionInfo.departure.name,
            destinationCode: sessionInfo.destination.iataCode, destinationName: sessionInfo.destination.name,
            duration: totalDuration
        ))
    }

    private func endSession() { cleanup(); onComplete() }
    private func cleanup() { timer?.invalidate(); holdTimer?.invalidate(); soundManager.stop() }
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

#Preview {
    let dep = Airport(id: 1, name: "JFK Intl", iataCode: "JFK", latitude: 40.6413, longitude: -73.7781, country: "US", municipality: "New York")
    let dest = Airport(id: 2, name: "LAX Intl", iataCode: "LAX", latitude: 33.9425, longitude: -118.4081, country: "US", municipality: "Los Angeles")
    TimerView(sessionInfo: ActiveSessionInfo(departure: dep, destination: dest, duration: 120)) {}
}
