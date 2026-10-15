// SubRipFormatter.swift
// Writes caption cues as a SubRip (`.srt`) subtitle document.
//
// SRT is the most widely accepted subtitle format (YouTube, Premiere, CapCut,
// VLC). The app's subtitle file writer saves this string to disk so it can be
// shared. Pure and locale-independent.

import Foundation

public enum SubRipFormatter {
    /// The complete SRT document for `cues`, numbered from 1. Empty input
    /// produces an empty string.
    public static func document(for cues: [CaptionCue]) -> String {
        cues.enumerated().map { index, cue in
            "\(index + 1)\n\(timestamp(cue.start)) --> \(timestamp(cue.end))\n\(cue.text)\n"
        }
        .joined(separator: "\n")
    }

    /// Formats seconds as `HH:MM:SS,mmm`, rounding to the nearest millisecond.
    /// Negative values clamp to zero.
    public static func timestamp(_ seconds: TimeInterval) -> String {
        let totalMilliseconds = Int((max(0, seconds) * 1000).rounded())
        let hours = totalMilliseconds / 3_600_000
        let minutes = totalMilliseconds / 60_000 % 60
        let wholeSeconds = totalMilliseconds / 1000 % 60
        let milliseconds = totalMilliseconds % 1000
        return "\(padded(hours, to: 2)):\(padded(minutes, to: 2)):\(padded(wholeSeconds, to: 2)),\(padded(milliseconds, to: 3))"
    }

    // Manual zero padding avoids `String(format:)`, whose `%d` handling of
    // 64-bit Int differs across platforms.
    private static func padded(_ value: Int, to width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}
