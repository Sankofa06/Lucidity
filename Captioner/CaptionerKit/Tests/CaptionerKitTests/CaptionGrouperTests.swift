// CaptionGrouperTests.swift
// Verifies CaptionGrouper's cue-breaking rules and display windows.

import Testing
@testable import CaptionerKit

struct CaptionGrouperTests {
    @Test func emptyTranscriptMakesNoCues() {
        #expect(CaptionGrouper.cues(from: []).isEmpty)
    }

    @Test func breaksAtMaxWords() {
        let words = TestWords.spoken(["a", "b", "c", "d", "e", "f"])

        let cues = CaptionGrouper.cues(from: words, rules: CaptionGroupingRules(maxWords: 4))

        #expect(cues.map(\.text) == ["a b c d", "e f"])
    }

    @Test func breaksAtMaxCharacters() {
        let words = TestWords.spoken(["abcdef", "ghijkl", "mn"])

        let cues = CaptionGrouper.cues(from: words, rules: CaptionGroupingRules(maxWords: 10, maxCharacters: 13))

        #expect(cues.map(\.text) == ["abcdef ghijkl", "mn"])
    }

    @Test func overlongSingleWordGetsItsOwnCue() {
        let words = TestWords.spoken(["supercalifragilistic", "ok"])

        let cues = CaptionGrouper.cues(from: words, rules: CaptionGroupingRules(maxCharacters: 5))

        #expect(cues.map(\.text) == ["supercalifragilistic", "ok"])
    }

    @Test func breaksOnPause() {
        let words = TestWords.spoken(["before"]) + TestWords.spoken(["after"], start: 2)

        let cues = CaptionGrouper.cues(from: words)

        #expect(cues.map(\.text) == ["before", "after"])
    }

    @Test func breaksAfterSentencePunctuation() {
        let words = TestWords.spoken(["Done.", "Next", "one?", "Yes!"])

        let cues = CaptionGrouper.cues(from: words)

        #expect(cues.map(\.text) == ["Done.", "Next one?", "Yes!"])
    }

    @Test func cueLingersButNeverOverlapsNextCue() {
        let words = TestWords.spoken(["one"]) + TestWords.spoken(["two"], start: 1.0)
        let rules = CaptionGroupingRules(pauseThreshold: 0.5, linger: 0.4)

        let cues = CaptionGrouper.cues(from: words, rules: rules)

        // "one" ends at 0.3 and lingers to 0.7; "two" ends at 1.3 and lingers to 1.7.
        #expect(cues.count == 2)
        #expect(abs(cues[0].end - 0.7) < 0.0001)
        #expect(abs(cues[1].end - 1.7) < 0.0001)

        let tight = TestWords.spoken(["one"]) + TestWords.spoken(["two"], start: 0.5)
        let tightCues = CaptionGrouper.cues(from: tight, rules: CaptionGroupingRules(maxWords: 1, linger: 0.4))
        #expect(tightCues[0].end == tightCues[1].start)
    }

    @Test func cueStartsAtFirstWord() {
        let cues = CaptionGrouper.cues(from: TestWords.spoken(["hi"], start: 3))

        #expect(cues.first?.start == 3)
    }
}
