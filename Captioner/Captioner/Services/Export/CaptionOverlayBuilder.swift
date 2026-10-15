// CaptionOverlayBuilder.swift
// Builds the Core Animation layer tree that burns captions into a video.
//
// Each caption frame from `CaptionTimeline.frames` becomes one image layer that
// is invisible except during its time window. `AVCaptionBurnInExporter` puts
// this tree above the video layer. Core Animation in AVFoundation export uses
// a bottom-left origin, so vertical positions are flipped here.

import AVFoundation
import CaptionerKit
import QuartzCore

@MainActor
enum CaptionOverlayBuilder {
    static func makeOverlay(cues: [CaptionCue], style: CaptionStyle, renderSize: CGSize) -> CALayer {
        let overlay = CALayer()
        overlay.frame = CGRect(origin: .zero, size: renderSize)

        let fontSize = CGFloat(style.fontSize(canvasWidth: renderSize.width, canvasHeight: renderSize.height))
        let maxWidth = renderSize.width * CaptionImageRenderer.maxWidthFraction
        // verticalPosition is measured from the top; this layer space is
        // measured from the bottom.
        let centerY = renderSize.height * (1 - CGFloat(style.verticalPosition))

        for cue in cues {
            let words = cue.words.map(\.text)
            for frame in CaptionTimeline.frames(for: cue, highlightsWords: style.highlightsWords) {
                guard let image = CaptionImageRenderer.image(
                    words: words,
                    highlightedIndex: frame.highlightedWordIndex,
                    style: style,
                    fontSize: fontSize,
                    maxWidth: maxWidth
                ) else { continue }

                let layer = CALayer()
                layer.contents = image
                layer.bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
                layer.position = CGPoint(x: renderSize.width / 2, y: centerY)
                layer.opacity = 0
                layer.add(visibilityAnimation(start: frame.start, end: frame.end), forKey: "visibility")
                overlay.addSublayer(layer)
            }
        }
        return overlay
    }

    /// Shows a layer for `start..<end` on the video timeline. AVFoundation
    /// treats a beginTime of 0 as "now", so time zero must be expressed as
    /// `AVCoreAnimationBeginTimeAtZero`.
    private static func visibilityAnimation(start: TimeInterval, end: TimeInterval) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 1
        animation.beginTime = AVCoreAnimationBeginTimeAtZero + start
        animation.duration = end - start
        animation.isRemovedOnCompletion = true
        return animation
    }
}
