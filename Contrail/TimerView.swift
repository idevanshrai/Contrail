//
//  TimerView.swift
//  Contrail
//

import SwiftUI
import SwiftData
import MapKit

/// Active focus session — zoomed camera following the airplane along the route,
/// with distance/time remaining at the bottom, press-and-hold exit, sound picker.
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

    // Flight map state
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var airplaneCoord: CLLocationCoordinate2D
    @State private var airplaneHeading: Double = 0

    // Press-and-hold exit
    @State private var holdProgress: Double = 0
    @State private var isHolding = false
    @State private var holdTimer: Timer?
    @State private var showExitConfirmation = false

    // Landing
    @State private var landingAnnounced = false
    @State private var hasSpooledDown = false
    @State private var showSoundPicker = false

    // Easter egg
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
            // Live flight map (full bleed, zoomed on plane)
            flightMapView
                .ignoresSafeArea()

            // Top overlay: route + controls
            VStack(spacing: 0) {
                topBar
                    .padding(.top, 16)
                    .padding(.horizontal, 20)

                Spacer()

                // Bottom: distance + time remaining
                bottomInfoBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }

            // Landing announcement
            if soundManager.showLandingMessage {
                landingAnnouncementOverlay
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Exit confirmation
            if showExitConfirmation {
                exitConfirmationOverlay
                    .transition(.opacity)
            }

            // Sound picker
            if showSoundPicker {
                soundPickerOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Easter egg toast
            if showEasterEgg {
                easterEggToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Arrived
            if isComplete {
                arrivedOverlay
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear { startSession() }
        .onDisappear { cleanup() }
    }

    // MARK: - Flight Map (Zoomed, Following Plane)

    private var flightMapView: some View {
        Map(position: $cameraPosition) {
            // Full flight path
            MapPolyline(coordinates: flightPathCoordinates)
                .stroke(ContrailTheme.glowAmber.opacity(0.3), lineWidth: 2)

            // Completed path (brighter)
            let completedCoords = Array(flightPathCoordinates.prefix(max(1, Int(Double(flightPathCoordinates.count) * progress))))
            MapPolyline(coordinates: completedCoords)
                .stroke(ContrailTheme.glowAmber, lineWidth: 3)

            // Departure marker
            Annotation("", coordinate: CLLocationCoordinate2D(
                latitude: sessionInfo.departure.latitude, longitude: sessionInfo.departure.longitude
            )) {
                Circle().fill(ContrailTheme.skyBlue).frame(width: 10, height: 10)
                    .shadow(color: ContrailTheme.skyBlue.opacity(0.5), radius: 4)
            }

            // Destination marker
            Annotation("", coordinate: CLLocationCoordinate2D(
                latitude: sessionInfo.destination.latitude, longitude: sessionInfo.destination.longitude
            )) {
                ZStack {
                    Circle().stroke(ContrailTheme.glowAmber, lineWidth: 2).frame(width: 14, height: 14)
                    Circle().fill(ContrailTheme.glowAmber.opacity(0.3)).frame(width: 10, height: 10)
                }
                .shadow(color: ContrailTheme.glowAmber.opacity(0.5), radius: 4)
            }

            // Airplane (follows route, rotated to heading)
            Annotation("", coordinate: airplaneCoord) {
                Image(systemName: "airplane")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(ContrailTheme.glowAmber)
                    .rotationEffect(.degrees(airplaneHeading - 90))
                    .shadow(color: ContrailTheme.glowAmber.opacity(0.6), radius: 8)
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .mapControls { }
    }

    private var flightPathCoordinates: [CLLocationCoordinate2D] {
        let steps = 100
        let lat1 = sessionInfo.departure.latitude * .pi / 180
        let lon1 = sessionInfo.departure.longitude * .pi / 180
        let lat2 = sessionInfo.destination.latitude * .pi / 180
        let lon2 = sessionInfo.destination.longitude * .pi / 180

        let d = 2 * asin(sqrt(
            pow(sin((lat2 - lat1) / 2), 2) +
            cos(lat1) * cos(lat2) * pow(sin((lon2 - lon1) / 2), 2)
        ))
        guard d > 0 else { return [] }

        return (0...steps).map { i in
            let f = Double(i) / Double(steps)
            let A = sin((1 - f) * d) / sin(d)
            let B = sin(f * d) / sin(d)
            let x = A * cos(lat1) * cos(lon1) + B * cos(lat2) * cos(lon2)
            let y = A * cos(lat1) * sin(lon1) + B * cos(lat2) * sin(lon2)
            let z = A * sin(lat1) + B * sin(lat2)
            let lat = atan2(z, sqrt(x * x + y * y)) * 180 / .pi
            let lon = atan2(y, x) * 180 / .pi
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    private func currentBearing() -> Double {
        let coords = flightPathCoordinates
        let idx = min(Int(Double(coords.count - 1) * progress), coords.count - 2)
        guard idx >= 0, idx + 1 < coords.count else { return 0 }
        let from = coords[idx], to = coords[idx + 1]
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return atan2(y, x) * 180 / .pi
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            // Pause/play
            Button {
                ContrailTheme.haptic()
                if isPaused { resumeTimer() } else { pauseTimer() }
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(ContrailTheme.contrailWhite)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial.opacity(0.5))
                    .background(ContrailTheme.darkNavy.opacity(0.4))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Sound button
            Button {
                ContrailTheme.haptic(.alignment)
                withAnimation(.spring(response: 0.3)) { showSoundPicker.toggle() }
            } label: {
                Image(systemName: soundManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ContrailTheme.contrailWhite)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial.opacity(0.5))
                    .background(ContrailTheme.darkNavy.opacity(0.4))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            // Route label
            HStack(spacing: 8) {
                Text(sessionInfo.departure.iataCode)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(ContrailTheme.glowAmber)
                Text(sessionInfo.destination.iataCode)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(ContrailTheme.contrailWhite)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial.opacity(0.5))
            .background(ContrailTheme.darkNavy.opacity(0.4))
            .clipShape(Capsule())

            Spacer()

            // Press-and-hold end
            if !isComplete {
                pressAndHoldButton
            } else {
                Button {
                    ContrailTheme.haptic(.levelChange)
                    onComplete()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ContrailTheme.arrivedGreen)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial.opacity(0.5))
                        .background(ContrailTheme.arrivedGreen.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Bottom Info Bar (Time + Distance Remaining)

    private var bottomInfoBar: some View {
        HStack(spacing: 0) {
            // Time remaining
            VStack(alignment: .leading, spacing: 2) {
                Text("Time Remaining")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ContrailTheme.mutedText)
                Text(FlightCalculator.countdownString(remainingTime))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(ContrailTheme.contrailWhite)
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.1), value: remainingTime)
            }

            Spacer()

            // Phase indicator
            Text(flightPhase.label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(flightPhase.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(flightPhase.color.opacity(0.1))
                .clipShape(Capsule())
                .animation(.easeInOut(duration: 0.5), value: flightPhase)

            Spacer()

            // Distance remaining
            VStack(alignment: .trailing, spacing: 2) {
                Text("Distance Remaining")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ContrailTheme.mutedText)
                Text(String(format: "%.0f km", distanceRemaining))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(ContrailTheme.contrailWhite)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial.opacity(0.6))
        .background(ContrailTheme.darkNavy.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ContrailTheme.contrailWhite.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8)
    }

    // MARK: - Press-and-Hold

    private var pressAndHoldButton: some View {
        ZStack {
            Circle()
                .stroke(ContrailTheme.contrailWhite.opacity(0.08), lineWidth: 3)
                .frame(width: 36, height: 36)
            Circle()
                .trim(from: 0, to: holdProgress)
                .stroke(ContrailTheme.dangerRed, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 36, height: 36)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.05), value: holdProgress)
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(holdProgress > 0 ? ContrailTheme.dangerRed : ContrailTheme.mutedText)
        }
        .background(.ultraThinMaterial.opacity(0.5))
        .background(ContrailTheme.darkNavy.opacity(0.4))
        .clipShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isHolding { startHolding() } }
                .onEnded { _ in stopHolding() }
        )
    }

    private func startHolding() {
        isHolding = true; holdProgress = 0
        ContrailTheme.haptic(.alignment)
        let steps = 60; let interval = 3.0 / Double(steps); var step = 0
        holdTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            DispatchQueue.main.async {
                step += 1; holdProgress = Double(step) / Double(steps)
                if step == steps / 3 || step == (steps * 2) / 3 { ContrailTheme.haptic(.levelChange) }
                if step >= steps {
                    holdTimer?.invalidate(); holdTimer = nil; isHolding = false
                    ContrailTheme.haptic(.generic)
                    withAnimation(.spring(response: 0.4)) { showExitConfirmation = true }
                }
            }
        }
    }

    private func stopHolding() {
        isHolding = false; holdTimer?.invalidate(); holdTimer = nil
        withAnimation(.easeOut(duration: 0.3)) { holdProgress = 0 }
    }

    // MARK: - Exit Confirmation

    private var exitConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { withAnimation { showExitConfirmation = false } }

            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(ContrailTheme.glowAmber)

                Text("End Flight?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ContrailTheme.contrailWhite)

                Text("You're \(Int(progress * 100))% through your flight.\nYour focus streak will be broken.")
                    .font(.system(size: 13)).foregroundStyle(ContrailTheme.mutedText)
                    .multilineTextAlignment(.center).lineSpacing(4)

                // Easter egg: different messages based on progress
                if progress > 0.8 {
                    Text("🏆 You're almost there! Don't give up!")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ContrailTheme.glowAmber)
                } else if progress > 0.5 {
                    Text("✈ Past the point of no return...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ContrailTheme.mutedText.opacity(0.6))
                }

                HStack(spacing: 14) {
                    Button {
                        ContrailTheme.haptic()
                        withAnimation { showExitConfirmation = false }
                    } label: {
                        Text("Keep Flying")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(ContrailTheme.glowAmber)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        ContrailTheme.haptic(.levelChange)
                        showExitConfirmation = false; endSession()
                    } label: {
                        Text("End Flight")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ContrailTheme.dangerRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(ContrailTheme.dangerRed.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(ContrailTheme.dangerRed.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(28).frame(maxWidth: 340)
            .background(.ultraThinMaterial).background(ContrailTheme.surfaceNavy.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(ContrailTheme.contrailWhite.opacity(0.06), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 30)
        }
    }

    // MARK: - Landing Announcement

    private var landingAnnouncementOverlay: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "seatbelt").font(.system(size: 16)).foregroundStyle(ContrailTheme.glowAmber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preparing for Landing")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(ContrailTheme.contrailWhite)
                    Text("We'll be arriving at \(sessionInfo.destination.iataCode) shortly")
                        .font(.system(size: 11)).foregroundStyle(ContrailTheme.mutedText)
                }
                Spacer()
            }
            .padding(16)
            .background(.ultraThinMaterial.opacity(0.7)).background(ContrailTheme.surfaceNavy.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(ContrailTheme.glowAmber.opacity(0.15), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 10)
            .padding(.horizontal, 28).padding(.top, 70)
            Spacer()
        }
    }

    // MARK: - Easter Egg Toast

    private var easterEggToast: some View {
        VStack {
            Spacer()
            Text(easterEggMessage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ContrailTheme.glowAmber)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial.opacity(0.7))
                .background(ContrailTheme.glowAmber.opacity(0.06))
                .clipShape(Capsule())
                .padding(.bottom, 100)
        }
    }

    // MARK: - Arrived

    private var arrivedOverlay: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(ContrailTheme.arrivedGreen.opacity(0.15)).frame(width: 120, height: 120)
                    .scaleEffect(isComplete ? 1.5 : 0.5).opacity(isComplete ? 0 : 0.5)
                    .animation(.easeOut(duration: 2).repeatForever(autoreverses: false), value: isComplete)
                Circle().fill(ContrailTheme.arrivedGreen.opacity(0.2)).frame(width: 80, height: 80)
                Image(systemName: "checkmark").font(.system(size: 28, weight: .medium)).foregroundStyle(ContrailTheme.arrivedGreen)
            }
            Text("Landed at \(sessionInfo.destination.iataCode)")
                .font(.system(size: 20, weight: .bold)).foregroundStyle(ContrailTheme.contrailWhite)
            Text(sessionInfo.destination.municipality)
                .font(.system(size: 14)).foregroundStyle(ContrailTheme.mutedText)

            // Easter egg: total distance traveled
            Text("You focused for \(FlightCalculator.formattedDuration(totalDuration)) and traveled \(String(format: "%.0f", distanceTotal)) km ✈")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ContrailTheme.mutedText.opacity(0.5))

            Spacer()
        }
    }

    // MARK: - Sound Picker

    private var soundPickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
                .onTapGesture { withAnimation(.spring(response: 0.3)) { showSoundPicker = false } }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("AMBIENT SOUND").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(ContrailTheme.mutedText)
                    Spacer()
                    Button { soundManager.toggleMute() } label: {
                        Image(systemName: soundManager.isMuted ? "speaker.slash" : "speaker.wave.2")
                            .font(.system(size: 13))
                            .foregroundStyle(soundManager.isMuted ? ContrailTheme.dangerRed : ContrailTheme.skyBlue)
                    }.buttonStyle(.plain)
                }

                Text("Engine").font(.system(size: 9, weight: .semibold)).foregroundStyle(ContrailTheme.mutedText.opacity(0.6)).textCase(.uppercase)
                HStack(spacing: 8) {
                    ForEach(AmbientSound.allCases.filter(\.isEngineSound)) { sound in soundOption(sound) }
                }

                Text("Focus").font(.system(size: 9, weight: .semibold)).foregroundStyle(ContrailTheme.mutedText.opacity(0.6)).textCase(.uppercase).padding(.top, 4)
                HStack(spacing: 8) {
                    ForEach(AmbientSound.allCases.filter { !$0.isEngineSound }) { sound in soundOption(sound) }
                }

                HStack(spacing: 10) {
                    Image(systemName: "speaker.fill").font(.system(size: 10)).foregroundStyle(ContrailTheme.mutedText)
                    Slider(value: Binding(get: { soundManager.volume }, set: { soundManager.setVolume($0) }), in: 0...1)
                        .tint(ContrailTheme.glowAmber)
                    Image(systemName: "speaker.wave.3.fill").font(.system(size: 10)).foregroundStyle(ContrailTheme.mutedText)
                }.padding(.top, 4)
            }
            .padding(20).frame(width: 300)
            .background(.ultraThinMaterial).background(ContrailTheme.surfaceNavy.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(ContrailTheme.contrailWhite.opacity(0.06), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 20)
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
                Image(systemName: sound.icon).font(.system(size: 16)).foregroundStyle(isActive ? ContrailTheme.glowAmber : ContrailTheme.mutedText)
                Text(sound.rawValue).font(.system(size: 9, weight: .medium)).foregroundStyle(isActive ? ContrailTheme.contrailWhite : ContrailTheme.mutedText)
            }
            .frame(width: 72, height: 56)
            .background(isActive ? ContrailTheme.glowAmber.opacity(0.12) : ContrailTheme.contrailWhite.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(isActive ? ContrailTheme.glowAmber.opacity(0.3) : .clear, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    // MARK: - Timer Logic

    private func startSession() {
        isRunning = true
        soundManager.play()
        scheduleTimer()
        updateCameraToFollowPlane()
        triggerRandomEasterEgg()
    }

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if remainingTime > 0 {
                    remainingTime -= 1
                    updateAirplanePosition()
                    checkPhaseTransitions()
                } else {
                    completeSession()
                }
            }
        }
    }

    private func updateAirplanePosition() {
        let coords = flightPathCoordinates
        let idx = min(Int(Double(coords.count - 1) * progress), coords.count - 1)

        withAnimation(.linear(duration: 1)) {
            airplaneCoord = coords[idx]
            airplaneHeading = currentBearing()
        }

        // Update camera every 3 seconds — zoomed & oriented along heading
        if Int(remainingTime) % 3 == 0 {
            updateCameraToFollowPlane()
        }
    }

    private func updateCameraToFollowPlane() {
        withAnimation(.easeInOut(duration: 2)) {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: airplaneCoord,
                distance: 150_000, // ~150km altitude zoom
                heading: airplaneHeading,
                pitch: 45 // tilted view looking along the route
            ))
        }
    }

    private func checkPhaseTransitions() {
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

    private func triggerRandomEasterEgg() {
        // Random aviation facts during the flight
        let facts = [
            "🌍 At 35,000ft, you can see about 230 miles in every direction",
            "✈ Commercial planes fly at ~900 km/h — that's 250 m/s",
            "☁ Contrails form when exhaust meets -40°C air",
            "🛫 The busiest airspace in the world is over London",
            "🌊 70% of flight paths cross over ocean",
            "⭐ At cruise altitude, you can see 4x more stars",
            "🔊 The loudest sound on a plane comes from the air conditioning",
        ]

        // Show a fact at a random point during the session
        let delay = Double.random(in: 30...max(31, totalDuration * 0.7))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
            guard self.isRunning, !self.isComplete else { return }
            easterEggMessage = facts.randomElement() ?? ""
            withAnimation(.spring(response: 0.4)) { showEasterEgg = true }
            ContrailTheme.haptic(.alignment)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation { showEasterEgg = false }
            }
        }
    }

    private func pauseTimer() { isPaused = true; timer?.invalidate(); timer = nil }
    private func resumeTimer() { isPaused = false; scheduleTimer() }

    private func completeSession() {
        timer?.invalidate(); timer = nil; isRunning = false; soundManager.stop(); remainingTime = 0
        ContrailTheme.haptic(.levelChange)

        withAnimation(.spring(response: 0.6)) {
            airplaneCoord = CLLocationCoordinate2D(latitude: sessionInfo.destination.latitude, longitude: sessionInfo.destination.longitude)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { isComplete = true }
        }

        let session = Session(
            departureCode: sessionInfo.departure.iataCode,
            departureName: sessionInfo.departure.name,
            destinationCode: sessionInfo.destination.iataCode,
            destinationName: sessionInfo.destination.name,
            duration: totalDuration
        )
        modelContext.insert(session)
    }

    private func endSession() { cleanup(); onComplete() }

    private func cleanup() {
        timer?.invalidate(); timer = nil
        holdTimer?.invalidate(); holdTimer = nil
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

#Preview {
    let dep = Airport(id: 1, name: "John F Kennedy Intl", iataCode: "JFK", latitude: 40.6413, longitude: -73.7781, country: "US", municipality: "New York")
    let dest = Airport(id: 2, name: "Los Angeles Intl", iataCode: "LAX", latitude: 33.9425, longitude: -118.4081, country: "US", municipality: "Los Angeles")
    let info = ActiveSessionInfo(departure: dep, destination: dest, duration: 120)
    TimerView(sessionInfo: info) {}
}
