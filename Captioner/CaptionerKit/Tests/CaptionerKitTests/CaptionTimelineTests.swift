// CaptionTimelineTests.swift
// Verifies active-cue lookup and the export frame breakdown agree.

import Testing
@testable import CaptionerKit

struct CaptionTimelineTests {
    private let cue = CaptionCue(words: TestWords.spoken(["one", "two", "three"], start: 1, length: 0.5), start: 1, end: 3)

    @Test func activeCueUsesHalfOpenWindows() {
        let next = CaptionCue(words: TestWords.spoken(["next"], start: 3), start: 3, end: 4)

        #expect(CaptionTimeline.activeCue(in: [cue, next], at: 0.99) == nil)
        #expect(CaptionTimeline.activeCue(in: [cue, next], at: 1) == cue)
        #expect(CaptionTimeline.activeCue(in: [cue, next], at: 3) == next)
        #expect(CaptionTimeline.activeCue(in: [cue, next], at: 4) == nil)
    }

    @Test func activeWordIsLastStartedWord() {
        #expect(CaptionTimeline.activeWordIndex(in: cue, at: 0.5) == 0)
        #expect(CaptionTimeline.activeWordIndex(in: cue, at: 1.6) == 1)
        #expect(CaptionTimeline.activeWordIndex(in: cue, at: 2.9) == 2)
    }

    @Test func plainStyleHasOneFrame() {
        #expect(CaptionTimeline.frames(for: cue, highlightsWords: false) == [
            CaptionFrame(highlightedWordIndex: nil, start: 1, end: 3)
        ])
    }

    @Test func highlightFramesTileTheCue() {
        let frames = CaptionTimeline.frames(for: cue, highlightsWords: true)

        #expect(frames == [
            CaptionFrame(highlightedWordIndex: 0, start: 1, end: 1.5),
            CaptionFrame(highlightedWordIndex: 1, start: 1.5, end: 2),
            CaptionFrame(highlightedWordIndex: 2, start: 2, end: 3)
        ])
    }

    @Test func framesMatchActiveWordLookup() {
        for frame in CaptionTimeline.frames(for: cue, highlightsWords: true) {
            let midpoint = (frame.start + frame.end) / 2
            #expect(CaptionTimeline.activeWordIndex(in: cue, at: midpoint) == frame.highlightedWordIndex)
        }
    }

    @Test func emptyOrZeroLengthCueHasNoFrames() {
        #expect(CaptionTimeline.frames(for: CaptionCue(words: [], start: 0, end: 1), highlightsWords: true).isEmpty)
        #expect(CaptionTimeline.frames(for: CaptionCue(words: cue.words, start: 2, end: 2), highlightsWords: false).isEmpty)
    }
}
