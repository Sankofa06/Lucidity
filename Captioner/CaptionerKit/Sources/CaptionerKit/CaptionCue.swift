// CaptionCue.swift
// One on-screen caption: a short run of words shown together.
//
// The grouper creates cues from transcribed words, the editor rewrites them,
// the timeline picks the active cue during playback and export, and the SubRip
// formatter writes them to `.srt`. `start`/`end` are the display window, which
// can linger slightly past the last spoken word so captions do not flicker.

import Foundation

public struct CaptionCue: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var words: [TranscribedWord]
    /// When the cue appears, in seconds.
    public var start: TimeInterval
    /// When the cue disappears, in seconds.
    public var end: TimeInterval

    public init(id: UUID = UUID(), words: [TranscribedWord], start: TimeInterval, end: TimeInterval) {
        self.id = id
        self.words = words
        self.start = start
        self.end = end
    }

    /// The caption line as plain text, words separated by single spaces.
    public var text: String {
        words.map(\.text).joined(separator: " ")
    }
}
