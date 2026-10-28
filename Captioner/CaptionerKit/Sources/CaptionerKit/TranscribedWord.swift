// TranscribedWord.swift
// One recognized word with its position on the source video's timeline.
//
// This is the atomic unit every other CaptionerKit type is built from. The
// app's speech service produces these from recognizer segments, the grouper
// packs them into caption cues, and the editor re-times them after text edits.
// Times are seconds from the start of the source video.

import Foundation

public struct TranscribedWord: Hashable, Codable, Sendable {
    /// The word as it should appear on screen, including attached punctuation.
    public var text: String
    /// When the word starts being spoken, in seconds.
    public var start: TimeInterval
    /// When the word finishes being spoken, in seconds.
    public var end: TimeInterval

    public init(text: String, start: TimeInterval, end: TimeInterval) {
        self.text = text
        self.start = start
        self.end = end
    }

    /// Spoken length of the word; never negative even if a recognizer reports
    /// an end earlier than the start.
    public var duration: TimeInterval {
        max(0, end - start)
    }
}
