// TestWords.swift
// Shared fixtures for CaptionerKit tests.
//
// Builds evenly spaced word lists so each test can state timings compactly.

@testable import CaptionerKit

enum TestWords {
    /// Words spoken back to back, each `length` seconds, starting at `start`.
    static func spoken(_ texts: [String], start: Double = 0, length: Double = 0.3) -> [TranscribedWord] {
        texts.enumerated().map { index, text in
            let wordStart = start + Double(index) * length
            return TranscribedWord(text: text, start: wordStart, end: wordStart + length)
        }
    }
}
