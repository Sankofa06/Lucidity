// TranscriptMergerTests.swift
// Verifies TranscriptMerger handles both long-form recognizer delivery styles.

import Testing
@testable import CaptionerKit

struct TranscriptMergerTests {
    @Test func firstResultIsTakenWhole() {
        let words = TestWords.spoken(["hello", "there"])

        #expect(TranscriptMerger.merge([], with: words) == words)
    }

    @Test func perUtteranceResultsAreAppended() {
        let first = TestWords.spoken(["hello", "there"])
        let second = TestWords.spoken(["general", "kenobi"], start: 2)

        let merged = TranscriptMerger.merge(first, with: second)

        #expect(merged.map(\.text) == ["hello", "there", "general", "kenobi"])
    }

    @Test func cumulativeResultsDoNotDuplicateWords() {
        let first = TestWords.spoken(["hello", "there"])
        let cumulative = TestWords.spoken(["hello", "there", "friend"])

        let merged = TranscriptMerger.merge(first, with: cumulative)

        #expect(merged.map(\.text) == ["hello", "there", "friend"])
    }

    @Test func zeroLengthRepeatOfLastWordIsSkipped() {
        let committed = [TranscribedWord(text: "ok", start: 1, end: 1)]

        let merged = TranscriptMerger.merge(committed, with: committed)

        #expect(merged == committed)
    }

    @Test func blankWordsAreDropped() {
        let words = [
            TranscribedWord(text: " ", start: 0, end: 0.1),
            TranscribedWord(text: "hi", start: 0.1, end: 0.2)
        ]

        #expect(TranscriptMerger.merge([], with: words).map(\.text) == ["hi"])
    }

    @Test func incomingWordsAreOrderedByStart() {
        let words = [
            TranscribedWord(text: "second", start: 1, end: 1.2),
            TranscribedWord(text: "first", start: 0, end: 0.2)
        ]

        #expect(TranscriptMerger.merge([], with: words).map(\.text) == ["first", "second"])
    }
}
