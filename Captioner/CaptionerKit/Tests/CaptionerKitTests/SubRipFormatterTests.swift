// SubRipFormatterTests.swift
// Verifies SubRip timestamps and document layout.

import Testing
@testable import CaptionerKit

struct SubRipFormatterTests {
    @Test func timestampsArePaddedAndRounded() {
        #expect(SubRipFormatter.timestamp(0) == "00:00:00,000")
        #expect(SubRipFormatter.timestamp(3_723.0456) == "01:02:03,046")
        #expect(SubRipFormatter.timestamp(59.9996) == "00:01:00,000")
        #expect(SubRipFormatter.timestamp(-2) == "00:00:00,000")
    }

    @Test func documentNumbersCuesAndSeparatesWithBlankLines() {
        let cues = [
            CaptionCue(words: TestWords.spoken(["Hello"]), start: 0, end: 1.5),
            CaptionCue(words: TestWords.spoken(["there", "friend"], start: 2), start: 2, end: 3)
        ]

        let expected = """
        1
        00:00:00,000 --> 00:00:01,500
        Hello

        2
        00:00:02,000 --> 00:00:03,000
        there friend

        """
        #expect(SubRipFormatter.document(for: cues) == expected)
    }

    @Test func emptyDocument() {
        #expect(SubRipFormatter.document(for: []) == "")
    }
}
