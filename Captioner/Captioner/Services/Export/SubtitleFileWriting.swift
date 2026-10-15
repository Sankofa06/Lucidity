// SubtitleFileWriting.swift
// Saves captions as a shareable `.srt` subtitle file.
//
// The editor view model calls this for "Export .srt". Formatting lives in
// CaptionerKit's `SubRipFormatter`; this service only writes the file to the
// temporary directory and returns its URL for the share sheet.

import CaptionerKit
import Foundation

protocol SubtitleFileWriting: Sendable {
    func writeSubRip(_ cues: [CaptionCue]) throws -> URL
}

struct SubRipFileWriter: SubtitleFileWriting {
    func writeSubRip(_ cues: [CaptionCue]) throws -> URL {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("Captions-\(UUID().uuidString.prefix(8))")
            .appendingPathExtension("srt")
        try SubRipFormatter.document(for: cues).write(to: output, atomically: true, encoding: .utf8)
        return output
    }
}
