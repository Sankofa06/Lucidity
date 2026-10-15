// CaptionTimeline.swift
// Answers "what is on screen at time t?" for preview and export.
//
// Live preview asks for the active cue and highlighted word at the player's
// current time. Video export asks for the full list of visual frames, each a
// time window with one highlighted word (or none). Both paths share these pure
// rules, so what you preview is what gets burned into the video.

import Foundation

/// One distinct visual state of a cue: the same words, with at most one of
/// them highlighted, shown for `start..<end`.
public struct CaptionFrame: Hashable, Sendable {
    /// Index into the cue's `words` of the highlighted word, or `nil` when the
    /// style does not highlight words.
    public var highlightedWordIndex: Int?
    public var start: TimeInterval
    public var end: TimeInterval

    public init(highlightedWordIndex: Int?, start: TimeInterval, end: TimeInterval) {
        self.highlightedWordIndex = highlightedWordIndex
        self.start = start
        self.end = end
    }
}

public enum CaptionTimeline {
    /// The cue visible at `time`, if any. Cue windows are half-open.
    public static func activeCue(in cues: [CaptionCue], at time: TimeInterval) -> CaptionCue? {
        cues.first { time >= $0.start && time < $0.end }
    }

    /// The word being spoken at `time` within `cue`: the last word that has
    /// started. Before the first word starts, the first word is used so a
    /// highlight style always highlights something.
    public static func activeWordIndex(in cue: CaptionCue, at time: TimeInterval) -> Int? {
        guard !cue.words.isEmpty else { return nil }
        return cue.words.lastIndex { $0.start <= time } ?? 0
    }

    /// Splits a cue into the visual frames an exporter must render. Without
    /// word highlighting there is one frame for the whole cue. With it, each
    /// word is highlighted from its start until the next word starts, and the
    /// last word stays highlighted until the cue ends. Empty windows are
    /// dropped. Frames agree with `activeWordIndex(in:at:)`.
    public static func frames(for cue: CaptionCue, highlightsWords: Bool) -> [CaptionFrame] {
        guard cue.end > cue.start, !cue.words.isEmpty else { return [] }
        guard highlightsWords else {
            return [CaptionFrame(highlightedWordIndex: nil, start: cue.start, end: cue.end)]
        }

        var frames: [CaptionFrame] = []
        for index in cue.words.indices {
            let start = index == 0 ? cue.start : max(cue.start, cue.words[index].start)
            let end = index + 1 < cue.words.count ? min(cue.end, cue.words[index + 1].start) : cue.end
            if end > start {
                frames.append(CaptionFrame(highlightedWordIndex: index, start: start, end: end))
            }
        }
        return frames
    }
}
