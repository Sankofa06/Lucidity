// VideoInspecting.swift
// Reads the facts about a video the editor needs before playback.
//
// Returns the duration and the upright display size: the encoded size with the
// track's rotation applied, so portrait iPhone videos report as portrait.
// Called by the editor view model after import; touches AVFoundation only.

import AVFoundation
import CoreGraphics

struct VideoInfo: Equatable, Sendable {
    let duration: TimeInterval
    /// Upright size in pixels, after applying the track's rotation.
    let displaySize: CGSize

    var aspectRatio: CGFloat {
        displaySize.height > 0 ? displaySize.width / displaySize.height : 9.0 / 16.0
    }
}

protocol VideoInspecting: Sendable {
    func inspect(_ url: URL) async throws -> VideoInfo
}

struct AVVideoInspector: VideoInspecting {
    func inspect(_ url: URL) async throws -> VideoInfo {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw CaptionerError.noVideoTrack
        }
        let (naturalSize, transform) = try await track.load(.naturalSize, .preferredTransform)
        return VideoInfo(
            duration: duration.seconds,
            displaySize: VideoGeometry.uprightSize(naturalSize: naturalSize, transform: transform)
        )
    }
}

/// Rotation math shared by inspection and export so both agree on the frame.
enum VideoGeometry {
    static func uprightSize(naturalSize: CGSize, transform: CGAffineTransform) -> CGSize {
        let rect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        return CGSize(width: abs(rect.width), height: abs(rect.height))
    }

    /// The track transform shifted so the rotated frame starts at the origin.
    /// iPhone transforms usually include this offset already; this guards
    /// against files whose transforms do not.
    static func uprightTransform(naturalSize: CGSize, transform: CGAffineTransform) -> CGAffineTransform {
        let rect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        return transform.concatenating(CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
    }
}
