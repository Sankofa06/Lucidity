// AudioExtracting.swift
// Pulls the soundtrack out of a video as an audio-only file.
//
// Speech recognition reads audio files, not movies, so the editor view model
// asks this service for an `.m4a` before transcribing. The caller deletes the
// returned file when done. Touches AVFoundation and the temporary directory.

import AVFoundation

protocol AudioExtracting: Sendable {
    func extractAudio(from videoURL: URL) async throws -> URL
}

struct AVAudioExtractor: AudioExtracting {
    func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw CaptionerError.noAudioTrack
        }
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw CaptionerError.audioExtractionFailed
        }

        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        do {
            try await session.export(to: output, as: .m4a)
        } catch {
            throw CaptionerError.audioExtractionFailed
        }
        return output
    }
}
