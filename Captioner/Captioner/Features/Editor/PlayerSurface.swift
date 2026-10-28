// PlayerSurface.swift
// Bare video surface backed by AVPlayerLayer, without system controls.
//
// SwiftUI's VideoPlayer adds its own controls and letterboxing, which would
// misplace the caption overlay. This view shows only the picture so its frame
// can be sized to the video's exact aspect ratio by `EditorView`.

import AVFoundation
import SwiftUI
import UIKit

struct PlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: PlayerLayerView, context: Context) {
        view.playerLayer.player = player
    }
}

/// A UIView whose backing layer is an AVPlayerLayer, so it resizes with Auto Layout.
final class PlayerLayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        // Safe: layerClass above guarantees the backing layer type.
        layer as! AVPlayerLayer
    }
}
