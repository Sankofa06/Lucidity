// CaptionVideoExporting.swift
// Exports a copy of the video with captions burned into the picture.
//
// Rebuilds the video in an AVMutableComposition (keeping every audio track),
// applies the track's rotation so portrait videos stay upright, layers the
// caption overlay on top with AVVideoCompositionCoreAnimationTool, and writes a
// `.mov` to the temporary directory. Called by the editor view model.
// Main-actor isolated because the overlay is drawn with UIKit; the encode
// itself runs inside AVFoundation without blocking the UI.

import AVFoundation
import CaptionerKit

@MainActor
protocol CaptionVideoExporting {
    func exportVideo(source: URL, cues: [CaptionCue], style: CaptionStyle) async throws -> URL
}

struct AVCaptionBurnInExporter: CaptionVideoExporting {
    func exportVideo(source: URL, cues: [CaptionCue], style: CaptionStyle) async throws -> URL {
        let asset = AVURLAsset(url: source)
        let composition = AVMutableComposition()

        guard
            let sourceVideo = try await asset.loadTracks(withMediaType: .video).first,
            let compositionVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw CaptionerError.noVideoTrack
        }

        let duration = try await asset.load(.duration)
        let fullRange = CMTimeRange(start: .zero, duration: duration)
        try compositionVideo.insertTimeRange(fullRange, of: sourceVideo, at: .zero)

        for sourceAudio in try await asset.loadTracks(withMediaType: .audio) {
            let compositionAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try compositionAudio?.insertTimeRange(fullRange, of: sourceAudio, at: .zero)
        }

        let (naturalSize, transform, frameRate) = try await sourceVideo.load(.naturalSize, .preferredTransform, .nominalFrameRate)
        let renderSize = VideoGeometry.uprightSize(naturalSize: naturalSize, transform: transform)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideo)
        layerInstruction.setTransform(VideoGeometry.uprightTransform(naturalSize: naturalSize, transform: transform), at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = fullRange
        instruction.layerInstructions = [layerInstruction]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        // Match the source frame rate; fall back to 30 fps when unknown.
        let framesPerSecond = frameRate > 0 ? Int32(frameRate.rounded()) : 30
        videoComposition.frameDuration = CMTime(value: 1, timescale: framesPerSecond)
        videoComposition.instructions = [instruction]

        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = parentLayer.frame
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(CaptionOverlayBuilder.makeOverlay(cues: cues, style: style, renderSize: renderSize))
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw CaptionerError.exportFailed
        }
        session.videoComposition = videoComposition

        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("Captioned-\(UUID().uuidString.prefix(8))")
            .appendingPathExtension("mov")
        do {
            try await session.export(to: output, as: .mov)
        } catch {
            throw CaptionerError.exportFailed
        }
        return output
    }
}
