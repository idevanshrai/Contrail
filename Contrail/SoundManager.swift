//
//  SoundManager.swift
//  Contrail
//

import AVFoundation
import Combine
import Foundation

/// Manages looping ambient cabin sound playback during focus sessions.
@MainActor
final class SoundManager: ObservableObject {

    @Published var isPlaying: Bool = false
    @Published var isMuted: Bool = false

    private var audioPlayer: AVAudioPlayer?

    init() {
        preparePlayer()
    }

    // MARK: - Public API

    func play() {
        audioPlayer?.play()
        isPlaying = true
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
    }

    func toggleMute() {
        isMuted.toggle()
        audioPlayer?.volume = isMuted ? 0.0 : 0.6
    }

    // MARK: - Setup

    private func preparePlayer() {
        // Look for cabin_ambience.mp3 in the bundle
        guard let url = Bundle.main.url(forResource: "cabin_ambience", withExtension: "mp3") else {
            print("[SoundManager] cabin_ambience.mp3 not found in bundle. Ambient sound disabled.")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1  // loop indefinitely
            audioPlayer?.volume = 0.6
            audioPlayer?.prepareToPlay()
        } catch {
            print("[SoundManager] Failed to initialize audio player: \(error.localizedDescription)")
        }
    }
}
