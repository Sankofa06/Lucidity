// CaptionGrouper.swift
// Packs a flat word transcript into short, punchy caption cues.
//
// Short-form caption apps show a few words at a time instead of full
// sentences. This pure grouper starts a new cue when the current one is full
// (word or character limit), when the speaker pauses, or after sentence-ending
// punctuation. The editor view model calls it once after transcription.

import Foundation

/// Tunables for `CaptionGrouper`. The defaults mirror the short-form style of
/// popular caption apps: a handful of words, one or two lines on a phone.
public struct CaptionGroupingRules: Hashable, Sendable {
    /// Most words allowed in one cue.
    public var maxWords: Int
    /// Most characters (including spaces) allowed in one cue. A single word
    /// longer than this still gets its own cue.
    public var maxCharacters: Int
    /// A silence longer than this between two words always starts a new cue.
    public var pauseThreshold: TimeInterval
    /// How long a cue stays up after its last word, unless the next cue starts
    /// sooner.
    public var linger: TimeInterval

    public init(
        maxWords: Int = 4,
        maxCharacters: Int = 24,
        pauseThreshold: TimeInterval = 0.6,
        linger: TimeInterval = 0.4
    ) {
        self.maxWords = maxWords
        self.maxCharacters = maxCharacters
        self.pauseThreshold = pauseThreshold
        self.linger = linger
    }

    public static let standard = CaptionGroupingRules()
}

public enum CaptionGrouper {
    /// Groups `words` into cues according to `rules`. Words are ordered by
    /// start time first, so out-of-order recognizer output is tolerated.
    public static func cues(
        from words: [TranscribedWord],
        rules: CaptionGroupingRules = .standard
    ) -> [CaptionCue] {
        let groups = wordGroups(from: words.sorted { $0.start < $1.start }, rules: rules)
        return groups.enumerated().map { index, group in
            makeCue(group: group, nextStart: index + 1 < groups.count ? groups[index + 1][0].start : nil, rules: rules)
        }
    }

    // MARK: - Private helpers

    private static func wordGroups(from words: [TranscribedWord], rules: CaptionGroupingRules) -> [[TranscribedWord]] {
        var groups: [[TranscribedWord]] = []
        var current: [TranscribedWord] = []

        for word in words {
            if let previous = current.last, shouldBreak(current: current, previous: previous, next: word, rules: rules) {
                groups.append(current)
                current = []
            }
            current.append(word)
        }
        if !current.isEmpty {
            groups.append(current)
        }
        return groups
    }

    private static func shouldBreak(
        current: [TranscribedWord],
        previous: TranscribedWord,
        next: TranscribedWord,
        rules: CaptionGroupingRules
    ) -> Bool {
        let candidateLength = (current + [next]).map(\.text).joined(separator: " ").count
        return current.count >= rules.maxWords
            || candidateLength > rules.maxCharacters
            || next.start - previous.end > rules.pauseThreshold
            || endsSentence(previous.text)
    }

    private static func endsSentence(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        return ".?!".contains(last)
    }

    private static func makeCue(group: [TranscribedWord], nextStart: TimeInterval?, rules: CaptionGroupingRules) -> CaptionCue {
        let start = group[0].start
        let spokenEnd = group.map(\.end).max() ?? start
        // Linger after the last word, but never overlap the next cue.
        var end = spokenEnd + rules.linger
        if let nextStart {
            end = min(end, nextStart)
        }
        return CaptionCue(words: group, start: start, end: max(start, end))
    }
}
