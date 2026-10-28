// CaptionEditor.swift
// Pure text edits for caption cues.
//
// When someone fixes a misheard word, the recognizer's per-word timings no
// longer line up with the new text. This editor keeps the cue's spoken span
// and spreads the new words across it in proportion to their length, which
// keeps word highlighting believable. Unchanged text keeps the original
// timings exactly. The editor view model calls this when a cue is edited.

import Foundation

public enum CaptionEditor {
    /// Returns `cue` rewritten to `newText`, or `nil` when the text is blank
    /// (meaning the cue should be deleted).
    public static func replacingText(of cue: CaptionCue, with newText: String) -> CaptionCue? {
        let tokens = newText.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return nil }

        // Nothing actually changed: keep the recognizer's real timings.
        if tokens == cue.words.map(\.text) {
            return cue
        }

        let spanStart = cue.words.first?.start ?? cue.start
        let spanEnd = max(spanStart, cue.words.last?.end ?? cue.end)
        let span = spanEnd - spanStart
        // Tokens come from splitting on whitespace, so each has at least one
        // character and the total is never zero.
        let totalCharacters = Double(tokens.reduce(0) { $0 + $1.count })

        var cursor = spanStart
        var words: [TranscribedWord] = []
        for (index, token) in tokens.enumerated() {
            let share = span * Double(token.count) / totalCharacters
            // Pin the last word to the span end so rounding never drifts.
            let end = index == tokens.count - 1 ? spanEnd : cursor + share
            words.append(TranscribedWord(text: token, start: cursor, end: end))
            cursor = end
        }
        return CaptionCue(id: cue.id, words: words, start: cue.start, end: cue.end)
    }

    /// Applies `newText` to the cue with `id`, deleting it when the text is
    /// blank. Cues with other ids are returned untouched.
    public static func applying(text newText: String, toCueWithID id: UUID, in cues: [CaptionCue]) -> [CaptionCue] {
        cues.compactMap { cue in
            cue.id == id ? replacingText(of: cue, with: newText) : cue
        }
    }
}
