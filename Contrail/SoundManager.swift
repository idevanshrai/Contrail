//
//  SoundManager.swift
//  Contrail
//

import AVFoundation
import Combine
import Foundation
import SwiftUI

/// Available ambient sound options.
enum AmbientSound: String, CaseIterable, Identifiable {
    // Engine sounds
    case jetEngine       = "Jet Engine"
    case propellerEngine = "Propeller"
    case concordeEngine  = "Concorde"

    // Focus sounds
    case rain       = "Rain"
    case lofi       = "Lo-fi"
    case brownNoise = "Brown Noise"

    var id: String { rawValue }

    var fileName: String {
        switch self {
        case .jetEngine:       return "jet_engine"
        case .propellerEngine: return "propeller"
        case .concordeEngine:  return "concorde"
        case .rain:            return "rain"
        case .lofi:            return "lofi"
        case .brownNoise:      return "brown_noise"
        }
    }

    var icon: String {
        switch self {
        case .jetEngine:       return "engine.combustion"
        case .propellerEngine: return "fan"
        case .concordeEngine:  return "airplane"
        case .rain:            return "cloud.rain"
        case .lofi:            return "headphones"
        case .brownNoise:      return "waveform"
        }
    }

    var isEngineSound: Bool {
        switch self {
        case .jetEngine, .propellerEngine, .concordeEngine: return true
        default: return false
        }
    }
}

/// Manages ambient sound playback with spool-up/down effects for engine sounds.
@MainActor
final class SoundManager: ObservableObject {

    @Published var isPlaying: Bool = false
    @Published var isMuted: Bool = false
    @Published var selectedSound: AmbientSound = .jetEngine
    @Published var volume: Double = 0.6
    @Published var showLandingMessage: Bool = false

    private var audioPlayer: AVAudioPlayer?
    private var spoolTimer: Timer?
    private var targetVolume: Double = 0.6

    init() {}

    // MARK: - Public API

    /// Start playing the selected sound. If it's an engine sound, spool up gradually.
    func play() {
        preparePlayer(for: selectedSound)
        audioPlayer?.volume = 0.0
        audioPlayer?.play()
        isPlaying = true

        if selectedSound.isEngineSound {
            spoolUp()
        } else {
            // Fade in over 1 second for non-engine sounds
            fadeVolume(to: Float(volume), duration: 1.0)
        }
    }

    func stop() {
        spoolTimer?.invalidate()
        spoolTimer = nil
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        showLandingMessage = false
    }

    func toggleMute() {
        isMuted.toggle()
        audioPlayer?.volume = isMuted ? 0.0 : Float(volume)
    }

    func setVolume(_ newVolume: Double) {
        volume = newVolume
        if !isMuted {
            audioPlayer?.volume = Float(newVolume)
        }
    }

    func switchSound(_ sound: AmbientSound) {
        let wasPlaying = isPlaying
        stop()
        selectedSound = sound
        if wasPlaying {
            play()
        }
    }

    // MARK: - Phase-based Effects

    /// Spool up the engine — pitch and volume ramp from low to cruise level.
    /// Called during the takeoff phase.
    func spoolUp() {
        guard selectedSound.isEngineSound else { return }
        targetVolume = volume
        audioPlayer?.volume = 0.0
        audioPlayer?.enableRate = true
        audioPlayer?.rate = 0.7 // Start slower (lower pitch)

        // Gradually increase over 4 seconds
        let steps = 40
        let interval = 4.0 / Double(steps)
        var step = 0

        spoolTimer?.invalidate()
        spoolTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            DispatchQueue.main.async {
                guard let self = self else { timer.invalidate(); return }
                step += 1
                let progress = Double(step) / Double(steps)

                // Volume: 0 → target
                if !self.isMuted {
                    self.audioPlayer?.volume = Float(self.targetVolume * progress)
                }

                // Rate: 0.7 → 1.0 (simulates engine spooling up)
                self.audioPlayer?.rate = Float(0.7 + 0.3 * progress)

                if step >= steps {
                    timer.invalidate()
                    self.spoolTimer = nil
                    self.audioPlayer?.rate = 1.0
                    if !self.isMuted {
                        self.audioPlayer?.volume = Float(self.targetVolume)
                    }
                }
            }
        }
    }

    /// Spool down the engine — pitch and volume ramp down for landing.
    func spoolDown() {
        guard selectedSound.isEngineSound, isPlaying else { return }
        targetVolume = volume

        let steps = 40
        let interval = 4.0 / Double(steps)
        var step = 0
        let startVolume = audioPlayer?.volume ?? Float(volume)
        let startRate = audioPlayer?.rate ?? 1.0

        spoolTimer?.invalidate()
        spoolTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            DispatchQueue.main.async {
                guard let self = self else { timer.invalidate(); return }
                step += 1
                let progress = Double(step) / Double(steps)

                // Volume: current → 30% of current
                if !self.isMuted {
                    let target = startVolume * 0.3
                    self.audioPlayer?.volume = startVolume - (startVolume - target) * Float(progress)
                }

                // Rate: 1.0 → 0.75 (engine winding down)
                let targetRate: Float = 0.75
                self.audioPlayer?.rate = startRate - (startRate - targetRate) * Float(progress)

                if step >= steps {
                    timer.invalidate()
                    self.spoolTimer = nil
                }
            }
        }
    }

    /// Show the "landing shortly" notification.
    func announceLanding() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showLandingMessage = true
        }

        // Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            withAnimation {
                self?.showLandingMessage = false
            }
        }
    }

    // MARK: - Private

    private func preparePlayer(for sound: AmbientSound) {
        // Try the specific sound file first
        if let url = Bundle.main.url(forResource: sound.fileName, withExtension: "mp3") {
            loadAudio(from: url)
            return
        }

        // Fallback to cabin_ambience.mp3
        if let url = Bundle.main.url(forResource: "cabin_ambience", withExtension: "mp3") {
            print("[SoundManager] \(sound.fileName).mp3 not found, using cabin_ambience.mp3")
            loadAudio(from: url)
            return
        }

        print("[SoundManager] No audio file found for '\(sound.fileName)'. Sound disabled.")
    }

    private func loadAudio(from url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = Float(volume)
            audioPlayer?.enableRate = true
            audioPlayer?.prepareToPlay()
        } catch {
            print("[SoundManager] Failed to initialize audio: \(error.localizedDescription)")
        }
    }

    private func fadeVolume(to target: Float, duration: Double) {
        let steps = 20
        let interval = duration / Double(steps)
        let startVolume = audioPlayer?.volume ?? 0.0
        var step = 0

        spoolTimer?.invalidate()
        spoolTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            DispatchQueue.main.async {
                guard let self = self else { timer.invalidate(); return }
                step += 1
                let progress = Float(step) / Float(steps)
                if !self.isMuted {
                    self.audioPlayer?.volume = startVolume + (target - startVolume) * progress
                }
                if step >= steps {
                    timer.invalidate()
                    self.spoolTimer = nil
                }
            }
        }
    }
}
