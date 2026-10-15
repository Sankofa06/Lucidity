// ServiceStubs.swift
// In-memory stand-ins for Captioner's service protocols.
//
// Lets EditorViewModelTests drive the whole caption pipeline without media
// files, Speech permission, or AVFoundation exports. Each stub records what it
// was asked to do and returns canned results.

import CaptionerKit
import Foundation
import PhotosUI
import SwiftUI
@testable import Captioner

struct StubImporter: MovieImporting {
    func importMovie(from item: PhotosPickerItem) async throws -> URL {
        URL(fileURLWithPath: "/tmp/stub-import.mov")
    }
}

struct StubInspector: VideoInspecting {
    var info = VideoInfo(duration: 10, displaySize: CGSize(width: 1080, height: 1920))

    func inspect(_ url: URL) async throws -> VideoInfo {
        info
    }
}

struct StubAudioExtractor: AudioExtracting {
    var error: CaptionerError?

    func extractAudio(from videoURL: URL) async throws -> URL {
        if let error { throw error }
        return FileManager.default.temporaryDirectory.appendingPathComponent("stub-audio-\(UUID().uuidString).m4a")
    }
}

struct StubTranscriber: SpeechTranscribing {
    var isAuthorized = true
    var words: [TranscribedWord] = []
    var error: CaptionerError?

    func requestAuthorization() async -> Bool {
        isAuthorized
    }

    func transcribe(audioURL: URL) async throws -> [TranscribedWord] {
        if let error { throw error }
        return words
    }
}

@MainActor
final class StubVideoExporter: CaptionVideoExporting {
    private(set) var exportedStyles: [CaptionStyle] = []

    func exportVideo(source: URL, cues: [CaptionCue], style: CaptionStyle) async throws -> URL {
        exportedStyles.append(style)
        return URL(fileURLWithPath: "/tmp/stub-export.mov")
    }
}

struct StubSubtitleWriter: SubtitleFileWriting {
    func writeSubRip(_ cues: [CaptionCue]) throws -> URL {
        URL(fileURLWithPath: "/tmp/stub-\(cues.count).srt")
    }
}

enum TestTranscripts {
    /// Two sentences, back to back, 0.3 s per word.
    static let words: [TranscribedWord] = ["Hello", "there.", "This", "is", "Captioner"].enumerated().map { index, text in
        TranscribedWord(text: text, start: Double(index) * 0.3, end: Double(index) * 0.3 + 0.3)
    }
}
