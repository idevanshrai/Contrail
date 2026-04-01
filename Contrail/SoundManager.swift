//
//  SoundManager.swift
//  Contrail
//

import AVFoundation
import Combine
import SwiftUI

/// Available ambient sound options.
enum AmbientSound: String, CaseIterable, Identifiable {
    case jetEngine       = "Jet Engine"
    case propellerEngine = "Propeller"
    case concordeEngine  = "Concorde"
    case rain            = "Rain"
    case lofi            = "Lo-fi"
    case brownNoise      = "Brown Noise"

    var id: String { rawValue }

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

/// Generates ambient sounds programmatically via AVAudioEngine — no mp3 files needed.
@MainActor
final class SoundManager: ObservableObject {

    @Published var isPlaying = false
    @Published var isMuted = false
    @Published var selectedSound: AmbientSound = .jetEngine
    @Published var volume: Double = 0.5
    @Published var showLandingMessage = false

    private var audioEngine: AVAudioEngine?
    private var noiseNode: AVAudioSourceNode?
    private var spoolTimer: Timer?

    // Synthesis parameters
    private var currentFrequency: Double = 120.0
    private var targetFrequency: Double = 120.0
    private var currentAmplitude: Double = 0.0
    private var targetAmplitude: Double = 0.5
    private var phase: Double = 0.0
    private var brownNoiseState: Double = 0.0

    init() {}

    // MARK: - Public API

    func play() {
        setupAudioEngine()
        isPlaying = true

        if selectedSound.isEngineSound {
            spoolUp()
        } else {
            targetAmplitude = volume
            fadeAmplitude(to: volume, duration: 1.0)
        }
    }

    func stop() {
        spoolTimer?.invalidate()
        spoolTimer = nil
        audioEngine?.stop()
        audioEngine = nil
        noiseNode = nil
        isPlaying = false
        showLandingMessage = false
        currentAmplitude = 0
    }

    func toggleMute() {
        isMuted.toggle()
        targetAmplitude = isMuted ? 0 : volume
    }

    func setVolume(_ newVolume: Double) {
        volume = newVolume
        if !isMuted && isPlaying {
            targetAmplitude = newVolume
        }
    }

    func switchSound(_ sound: AmbientSound) {
        let wasPlaying = isPlaying
        stop()
        selectedSound = sound
        configureSynthParams(for: sound)
        if wasPlaying { play() }
    }

    // MARK: - Spool Effects

    func spoolUp() {
        guard selectedSound.isEngineSound else { return }
        currentAmplitude = 0
        currentFrequency = baseFrequency(for: selectedSound) * 0.5

        let steps = 60
        let interval = 4.0 / Double(steps)
        var step = 0

        spoolTimer?.invalidate()
        spoolTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            DispatchQueue.main.async {
                guard let self = self else { timer.invalidate(); return }
                step += 1
                let progress = Double(step) / Double(steps)

                self.currentAmplitude = self.isMuted ? 0 : self.volume * progress
                self.currentFrequency = self.baseFrequency(for: self.selectedSound) * (0.5 + 0.5 * progress)

                if step >= steps {
                    timer.invalidate()
                    self.spoolTimer = nil
                    self.currentFrequency = self.baseFrequency(for: self.selectedSound)
                    self.currentAmplitude = self.isMuted ? 0 : self.volume
                }
            }
        }
    }

    func spoolDown() {
        guard selectedSound.isEngineSound, isPlaying else { return }

        let startAmp = currentAmplitude
        let startFreq = currentFrequency
        let steps = 60
        let interval = 4.0 / Double(steps)
        var step = 0

        spoolTimer?.invalidate()
        spoolTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            DispatchQueue.main.async {
                guard let self = self else { timer.invalidate(); return }
                step += 1
                let progress = Double(step) / Double(steps)

                self.currentAmplitude = self.isMuted ? 0 : startAmp * (1.0 - progress * 0.7)
                self.currentFrequency = startFreq * (1.0 - progress * 0.3)

                if step >= steps {
                    timer.invalidate()
                    self.spoolTimer = nil
                }
            }
        }
    }

    func announceLanding() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showLandingMessage = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            withAnimation { self?.showLandingMessage = false }
        }
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        configureSynthParams(for: selectedSound)

        noiseNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = bufferList[0]
            let data = buffer.mData!.assumingMemoryBound(to: Float.self)

            for frame in 0..<Int(frameCount) {
                var sample: Float = 0.0

                switch self.selectedSound {
                case .jetEngine:
                    // Deep jet drone: low-frequency rumble + harmonics
                    let fundamental = sin(self.phase * 2.0 * .pi)
                    let harmonic2 = sin(self.phase * 4.0 * .pi) * 0.4
                    let harmonic3 = sin(self.phase * 6.0 * .pi) * 0.2
                    let noise = Float.random(in: -0.15...0.15)
                    sample = Float(fundamental + harmonic2 + harmonic3) * 0.3 + noise

                case .propellerEngine:
                    // Propeller: pulsing buzz with RPM feel
                    let buzz = sin(self.phase * 2.0 * .pi)
                    let pulse = sin(self.phase * 0.1 * .pi) * 0.5 + 0.5
                    let noise = Float.random(in: -0.1...0.1)
                    sample = Float(buzz * pulse) * 0.35 + noise

                case .concordeEngine:
                    // Concorde: higher-pitched whine with overtones
                    let whine = sin(self.phase * 2.0 * .pi)
                    let overtone = sin(self.phase * 3.0 * .pi) * 0.5
                    let highOvertone = sin(self.phase * 5.0 * .pi) * 0.15
                    let hiss = Float.random(in: -0.08...0.08)
                    sample = Float(whine + overtone + highOvertone) * 0.25 + hiss

                case .rain:
                    // Rain: filtered white noise with gentle variation
                    let noise = Float.random(in: -1.0...1.0)
                    let slowMod = Float(sin(self.phase * 0.001 * .pi) * 0.3 + 0.7)
                    sample = noise * 0.3 * slowMod

                case .lofi:
                    // Lo-fi: warm sine waves with slight wobble
                    let base = sin(self.phase * 2.0 * .pi)
                    let wobble = sin(self.phase * 2.003 * .pi) // slight detuning
                    let sub = sin(self.phase * 0.5 * .pi) * 0.3
                    sample = Float(base + wobble + sub) * 0.15

                case .brownNoise:
                    // Brown noise: integrated white noise (deeper than white)
                    let white = Double.random(in: -1.0...1.0)
                    self.brownNoiseState += white * 0.02
                    self.brownNoiseState *= 0.998 // leak to prevent drift
                    sample = Float(self.brownNoiseState) * 0.8
                }

                self.phase += self.currentFrequency / sampleRate
                if self.phase > 1_000_000 { self.phase = 0 } // prevent precision loss

                // Apply amplitude
                sample *= Float(self.currentAmplitude)

                // Soft clip to prevent distortion
                sample = max(-0.9, min(0.9, sample))

                data[frame] = sample
            }
            return noErr
        }

        guard let node = noiseNode else { return }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
        } catch {
            print("[SoundManager] Failed to start audio engine: \(error)")
        }
    }

    private func configureSynthParams(for sound: AmbientSound) {
        currentFrequency = baseFrequency(for: sound)
        brownNoiseState = 0
        phase = 0
    }

    private func baseFrequency(for sound: AmbientSound) -> Double {
        switch sound {
        case .jetEngine:       return 85.0   // Deep rumble
        case .propellerEngine: return 140.0  // Buzzy RPM
        case .concordeEngine:  return 220.0  // High whine
        case .rain:            return 1.0    // Used for modulation
        case .lofi:            return 261.6  // Middle C area
        case .brownNoise:      return 1.0    // Not frequency-based
        }
    }

    private func fadeAmplitude(to target: Double, duration: Double) {
        let steps = 30
        let interval = duration / Double(steps)
        let start = currentAmplitude
        var step = 0

        spoolTimer?.invalidate()
        spoolTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            DispatchQueue.main.async {
                guard let self = self else { timer.invalidate(); return }
                step += 1
                let progress = Double(step) / Double(steps)
                self.currentAmplitude = start + (target - start) * progress
                if step >= steps { timer.invalidate(); self.spoolTimer = nil }
            }
        }
    }
}
