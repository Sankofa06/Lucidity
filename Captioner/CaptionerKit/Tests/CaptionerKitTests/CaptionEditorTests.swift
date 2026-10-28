// CaptionEditorTests.swift
// Verifies CaptionEditor keeps timings sane when caption text is edited.

import Foundation
import Testing
@testable import CaptionerKit

struct CaptionEditorTests {
    private let cue = CaptionCue(words: TestWords.spoken(["helo", "wrld"], start: 1, length: 0.5), start: 1, end: 2.4)

    @Test func unchangedTextKeepsOriginalTimings() {
        #expect(CaptionEditor.replacingText(of: cue, with: "  helo   wrld ") == cue)
    }

    @Test func editedWordsSpanTheOriginalSpokenRange() throws {
        let edited = try #require(CaptionEditor.replacingText(of: cue, with: "hello big world"))

        #expect(edited.id == cue.id)
        #expect(edited.text == "hello big world")
        #expect(edited.words.first?.start == 1)
        #expect(edited.words.last?.end == 2)
        #expect(edited.start == cue.start)
        #expect(edited.end == cue.end)
    }

    @Test func editedWordsAreContiguousAndProportional() throws {
        let edited = try #require(CaptionEditor.replacingText(of: cue, with: "aaa a"))

        #expect(edited.words[0].end == edited.words[1].start)
        // 3 of 4 characters gets 3/4 of the one-second span.
        #expect(abs(edited.words[0].duration - 0.75) < 0.0001)
    }

    @Test func blankTextDeletesCue() {
        #expect(CaptionEditor.replacingText(of: cue, with: "   ") == nil)
        #expect(CaptionEditor.applying(text: "", toCueWithID: cue.id, in: [cue]).isEmpty)
    }

    @Test func applyingOnlyTouchesMatchingCue() {
        let other = CaptionCue(words: TestWords.spoken(["keep"], start: 5), start: 5, end: 6)

        let result = CaptionEditor.applying(text: "fixed", toCueWithID: cue.id, in: [cue, other])

        #expect(result.map(\.text) == ["fixed", "keep"])
        #expect(result[1] == other)
    }
}
