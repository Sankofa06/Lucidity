// PlaybackController.swift
// Owns the AVPlayer for the editor and publishes its current time.
//
// The caption preview needs the playhead about 30 times a second to pick the
// active cue and word. This controller wraps AVPlayer with play/pause/seek
// and an observable `currentTime`. Created by the editor view model per video;
// read by `PlayerSurface`, `CaptionOverlayView`, and the transport controls.

import AVFoundation
import Observation

@MainActor
@Observable
final class PlaybackController {
    let player: AVPlayer
    private(set) var currentTime: TimeInterval = 0
    private(set) var isPlaying = false
    let duration: TimeInterval

    @ObservationIgnored private var timeObserver: Any?

    init(url: URL, duration: TimeInterval) {
        self.player = AVPlayer(url: url)
        self.duration = duration
        // Play through the speaker even when the silent switch is on, like
        // other video apps. Failure only means the system default is used.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        startObservingTime()
    }

    func togglePlayback() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            // Restart from the top when the video already finished.
            if duration > 0, currentTime >= duration - 0.05 {
                seek(to: 0)
            }
            player.play()
            isPlaying = true
        }
    }

    func seek(to time: TimeInterval) {
        let clamped = min(max(0, time), duration)
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clamped
    }

    /// Stops playback and detaches the time observer. Call when the editor
    /// goes away; the observer would otherwise keep firing.
    func tearDown() {
        player.pause()
        isPlaying = false
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

    private func startObservingTime() {
        let interval = CMTime(value: 1, timescale: 30)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // Delivered on the main queue, as requested above.
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTime = time.seconds
                self.isPlaying = self.player.rate != 0
            }
        }
    }
}
