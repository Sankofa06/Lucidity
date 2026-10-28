// EditorViewModelTests.swift
// Verifies EditorViewModel's pipeline, editing, styling, and export flows.
//
// Uses the stubs in ServiceStubs.swift only; no media, permissions, or network.

import CaptionerKit
import Foundation
import Testing
@testable import Captioner

@MainActor
struct EditorViewModelTests {
    private let videoURL = URL(fileURLWithPath: "/tmp/stub-video.mov")

    private func makeViewModel(
        transcriber: StubTranscriber = StubTranscriber(words: TestTranscripts.words),
        audioExtractor: StubAudioExtractor = StubAudioExtractor(),
        videoExporter: any CaptionVideoExporting = StubVideoExporter()
    ) -> EditorViewModel {
        EditorViewModel(
            importer: StubImporter(),
            inspector: StubInspector(),
            audioExtractor: audioExtractor,
            transcriber: transcriber,
            videoExporter: videoExporter,
            subtitleWriter: StubSubtitleWriter()
        )
    }

    @Test func loadingVideoProducesGroupedCues() async {
        let viewModel = makeViewModel()

        await viewModel.loadVideo(at: videoURL)

        #expect(viewModel.phase == .editing)
        #expect(viewModel.cues.map(\.text) == ["Hello there.", "This is Captioner"])
        #expect(viewModel.videoInfo?.duration == 10)
        #expect(viewModel.playback != nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func deniedPermissionReturnsHomeWithMessage() async {
        let viewModel = makeViewModel(transcriber: StubTranscriber(isAuthorized: false))

        await viewModel.loadVideo(at: videoURL)

        #expect(viewModel.phase == .empty)
        #expect(viewModel.errorMessage == CaptionerError.speechPermissionDenied.errorDescription)
        #expect(viewModel.playback == nil)
    }

    @Test func silentVideoReportsMissingAudio() async {
        let viewModel = makeViewModel(audioExtractor: StubAudioExtractor(error: .noAudioTrack))

        await viewModel.loadVideo(at: videoURL)

        #expect(viewModel.phase == .empty)
        #expect(viewModel.errorMessage == CaptionerError.noAudioTrack.errorDescription)
    }

    @Test func editingCueUpdatesTextAndClearsExports() async throws {
        let viewModel = makeViewModel()
        await viewModel.loadVideo(at: videoURL)
        viewModel.exportSubtitles()
        #expect(viewModel.exportedSubtitleURL != nil)

        let first = try #require(viewModel.cues.first)
        viewModel.updateCue(id: first.id, text: "Hi there.")

        #expect(viewModel.cues.first?.text == "Hi there.")
        #expect(viewModel.exportedSubtitleURL == nil)
    }

    @Test func blankEditDeletesCue() async throws {
        let viewModel = makeViewModel()
        await viewModel.loadVideo(at: videoURL)

        let first = try #require(viewModel.cues.first)
        viewModel.updateCue(id: first.id, text: "  ")

        #expect(viewModel.cues.map(\.text) == ["This is Captioner"])
    }

    @Test func presetSwitchKeepsLayout() {
        let viewModel = makeViewModel()
        viewModel.style.verticalPosition = 0.3

        viewModel.selectPreset(.boxed)

        #expect(viewModel.preset == .boxed)
        #expect(viewModel.style.verticalPosition == 0.3)
        #expect(viewModel.style.backgroundColor != nil)
    }

    @Test func exportUsesCurrentStyle() async {
        let exporter = StubVideoExporter()
        let viewModel = makeViewModel(videoExporter: exporter)
        await viewModel.loadVideo(at: videoURL)
        viewModel.selectPreset(.pop)

        await viewModel.exportVideo()

        #expect(viewModel.exportedVideoURL != nil)
        #expect(viewModel.isExporting == false)
        #expect(exporter.exportedStyles == [viewModel.style])
    }

    @Test func editDuringExportDiscardsCompletedVideo() async throws {
        let exporter = SuspendedStubVideoExporter()
        let viewModel = makeViewModel(videoExporter: exporter)
        await viewModel.loadVideo(at: videoURL)
        let firstCue = try #require(viewModel.cues.first)

        let exportTask = Task { await viewModel.exportVideo() }
        await exporter.waitUntilStarted()
        viewModel.updateCue(id: firstCue.id, text: "Updated caption")
        let outputURL = URL(fileURLWithPath: "/tmp/stale-export.mov")
        exporter.complete(with: outputURL)
        await exportTask.value

        #expect(viewModel.cues.first?.text == "Updated caption")
        #expect(viewModel.exportedVideoURL == nil)
        #expect(viewModel.isExporting == false)
    }

    @Test func styleChangeDuringExportDiscardsCompletedVideo() async {
        let exporter = SuspendedStubVideoExporter()
        let viewModel = makeViewModel(videoExporter: exporter)
        await viewModel.loadVideo(at: videoURL)

        let exportTask = Task { await viewModel.exportVideo() }
        await exporter.waitUntilStarted()
        viewModel.style.verticalPosition = 0.42
        exporter.complete(with: URL(fileURLWithPath: "/tmp/stale-style-export.mov"))
        await exportTask.value

        #expect(viewModel.exportedVideoURL == nil)
        #expect(viewModel.isExporting == false)
    }

    @Test func startingOverDuringExportDiscardsCompletedVideo() async {
        let exporter = SuspendedStubVideoExporter()
        let viewModel = makeViewModel(videoExporter: exporter)
        await viewModel.loadVideo(at: videoURL)

        let exportTask = Task { await viewModel.exportVideo() }
        await exporter.waitUntilStarted()
        viewModel.startOver()
        exporter.complete(with: URL(fileURLWithPath: "/tmp/previous-project-export.mov"))
        await exportTask.value

        #expect(viewModel.phase == .empty)
        #expect(viewModel.exportedVideoURL == nil)
        #expect(viewModel.isExporting == false)
    }

    @Test func unchangedProjectPublishesCompletedVideo() async {
        let exporter = SuspendedStubVideoExporter()
        let viewModel = makeViewModel(videoExporter: exporter)
        await viewModel.loadVideo(at: videoURL)
        let outputURL = URL(fileURLWithPath: "/tmp/current-project-export.mov")

        let exportTask = Task { await viewModel.exportVideo() }
        await exporter.waitUntilStarted()
        exporter.complete(with: outputURL)
        await exportTask.value

        #expect(viewModel.exportedVideoURL == outputURL)
        #expect(viewModel.isExporting == false)
    }

    @Test func activeCueFollowsPlayhead() async {
        let viewModel = makeViewModel()
        await viewModel.loadVideo(at: videoURL)

        viewModel.playback?.seek(to: 0.95)

        #expect(viewModel.activeCue?.text == "This is Captioner")
        // Karaoke highlights words: 0.95 s falls in "is" (0.9–1.2 s).
        #expect(viewModel.activeWordIndex == 1)
    }

    @Test func startOverClearsProject() async {
        let viewModel = makeViewModel()
        await viewModel.loadVideo(at: videoURL)

        viewModel.startOver()

        #expect(viewModel.phase == .empty)
        #expect(viewModel.cues.isEmpty)
        #expect(viewModel.playback == nil)
    }
}
