// EditorViewModel.swift
// Owns the caption-making workflow and all editor UI state.
//
// Pipeline: import video → inspect → start playback → extract audio → ask for
// Speech permission → transcribe → group words into cues. After that it
// handles caption text edits, style changes, and exports (burned-in video and
// `.srt`). Every side effect goes through an injected service protocol, so
// tests drive the whole flow with stubs. Read by `RootView`, `HomeView`, and
// the editor views.

import CaptionerKit
import Foundation
import Observation
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class EditorViewModel {
    /// Where the user is in the workflow. `working` carries a status message.
    enum Phase: Equatable {
        case empty
        case working(String)
        case editing
    }

    private(set) var phase: Phase = .empty
    private(set) var videoURL: URL?
    private(set) var videoInfo: VideoInfo?
    private(set) var playback: PlaybackController?
    private(set) var cues: [CaptionCue] = []
    private(set) var preset: CaptionStylePreset = .karaoke
    /// Editable from the style sliders through a binding.
    var style: CaptionStyle = CaptionStylePreset.karaoke.style {
        didSet { invalidateExports() }
    }
    private(set) var isExporting = false
    private(set) var exportedVideoURL: URL?
    private(set) var exportedSubtitleURL: URL?
    /// Set when something fails; the view shows it as an alert and clears it.
    var errorMessage: String?

    @ObservationIgnored private let importer: any MovieImporting
    @ObservationIgnored private let inspector: any VideoInspecting
    @ObservationIgnored private let audioExtractor: any AudioExtracting
    @ObservationIgnored private let transcriber: any SpeechTranscribing
    @ObservationIgnored private let videoExporter: any CaptionVideoExporting
    @ObservationIgnored private let subtitleWriter: any SubtitleFileWriting
    @ObservationIgnored private let groupingRules: CaptionGroupingRules
    /// Distinguishes an export's captured project from edits made while it awaits.
    @ObservationIgnored private var exportRevision = 0

    init(
        importer: any MovieImporting = PhotosMovieImporter(),
        inspector: any VideoInspecting = AVVideoInspector(),
        audioExtractor: any AudioExtracting = AVAudioExtractor(),
        transcriber: any SpeechTranscribing = AppleSpeechTranscriber(),
        videoExporter: any CaptionVideoExporting = AVCaptionBurnInExporter(),
        subtitleWriter: any SubtitleFileWriting = SubRipFileWriter(),
        groupingRules: CaptionGroupingRules = .standard
    ) {
        self.importer = importer
        self.inspector = inspector
        self.audioExtractor = audioExtractor
        self.transcriber = transcriber
        self.videoExporter = videoExporter
        self.subtitleWriter = subtitleWriter
        self.groupingRules = groupingRules
    }

    // MARK: - Derived state for the preview

    /// The cue on screen at the current playhead.
    var activeCue: CaptionCue? {
        guard let playback else { return nil }
        return CaptionTimeline.activeCue(in: cues, at: playback.currentTime)
    }

    /// The highlighted word in `activeCue`, or `nil` when the style has no highlight.
    var activeWordIndex: Int? {
        guard style.highlightsWords, let cue = activeCue, let playback else { return nil }
        return CaptionTimeline.activeWordIndex(in: cue, at: playback.currentTime)
    }

    // MARK: - Import and transcription

    /// Entry point from the Photos picker.
    func importVideo(from item: PhotosPickerItem) async {
        phase = .working("Importing video…")
        do {
            let url = try await importer.importMovie(from: item)
            await loadVideo(at: url)
        } catch {
            fail(with: error)
        }
    }

    /// Runs the full pipeline for a local video file.
    func loadVideo(at url: URL) async {
        reset()
        phase = .working("Reading video…")
        do {
            let info = try await inspector.inspect(url)
            videoURL = url
            videoInfo = info
            playback = PlaybackController(url: url, duration: info.duration)

            phase = .working("Preparing audio…")
            let audioURL = try await audioExtractor.extractAudio(from: url)
            // The extracted audio is scratch data; remove it however we exit.
            defer { try? FileManager.default.removeItem(at: audioURL) }

            guard await transcriber.requestAuthorization() else {
                throw CaptionerError.speechPermissionDenied
            }

            phase = .working("Transcribing speech on device…")
            let words = try await transcriber.transcribe(audioURL: audioURL)
            cues = CaptionGrouper.cues(from: words, rules: groupingRules)
            phase = .editing
        } catch {
            fail(with: error)
        }
    }

    /// Clears the current project and returns to the start screen.
    func startOver() {
        reset()
        phase = .empty
    }

    // MARK: - Editing

    /// Replaces a cue's text. Blank text deletes the cue.
    func updateCue(id: CaptionCue.ID, text: String) {
        cues = CaptionEditor.applying(text: text, toCueWithID: id, in: cues)
        invalidateExports()
    }

    func selectPreset(_ newPreset: CaptionStylePreset) {
        preset = newPreset
        style = newPreset.style(keepingLayoutOf: style)
    }

    func seek(toCue cue: CaptionCue) {
        playback?.seek(to: cue.start)
    }

    // MARK: - Export

    func exportVideo() async {
        guard let videoURL, !isExporting else { return }
        let revision = exportRevision
        let exportCues = cues
        let exportStyle = style
        isExporting = true
        defer { isExporting = false }
        playback?.player.pause()
        do {
            let outputURL = try await videoExporter.exportVideo(source: videoURL, cues: exportCues, style: exportStyle)
            guard exportRevision == revision else { return }
            exportedVideoURL = outputURL
        } catch {
            guard exportRevision == revision else { return }
            errorMessage = message(for: error)
        }
    }

    func exportSubtitles() {
        do {
            exportedSubtitleURL = try subtitleWriter.writeSubRip(cues)
        } catch {
            errorMessage = message(for: error)
        }
    }

    /// Any edit or style change makes earlier exports stale.
    func invalidateExports() {
        exportRevision += 1
        exportedVideoURL = nil
        exportedSubtitleURL = nil
    }

    // MARK: - Private helpers

    private func reset() {
        playback?.tearDown()
        playback = nil
        videoURL = nil
        videoInfo = nil
        cues = []
        invalidateExports()
    }

    private func fail(with error: Error) {
        errorMessage = message(for: error)
        // Every pipeline failure returns to the start screen with nothing
        // half-loaded; picking the video again retries from scratch.
        reset()
        phase = .empty
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
