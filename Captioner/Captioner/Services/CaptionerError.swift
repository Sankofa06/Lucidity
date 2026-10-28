// CaptionerError.swift
// User-facing failures raised by Captioner's services.
//
// Services throw these so the editor view model can show a plain-language
// message without knowing framework error codes. Touches nothing; thrown by
// the import, media, transcription, and export services.

import Foundation

enum CaptionerError: LocalizedError, Equatable {
    case importFailed
    case noVideoTrack
    case noAudioTrack
    case audioExtractionFailed
    case speechPermissionDenied
    case recognizerUnavailable
    case noSpeechDetected
    case transcriptionFailed(String)
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .importFailed:
            "That video couldn't be imported. Try another one."
        case .noVideoTrack:
            "That file doesn't contain a video track."
        case .noAudioTrack:
            "That video has no audio, so there's nothing to caption."
        case .audioExtractionFailed:
            "Couldn't read the video's audio."
        case .speechPermissionDenied:
            "Captioner needs Speech Recognition access. Turn it on in Settings › Privacy & Security › Speech Recognition."
        case .recognizerUnavailable:
            "Speech recognition isn't available for your device language right now."
        case .noSpeechDetected:
            "No speech was detected in this video."
        case .transcriptionFailed(let reason):
            "Transcription failed: \(reason)"
        case .exportFailed:
            "Couldn't export the captioned video."
        }
    }
}
