// SpeechTranscribing.swift
// On-device speech-to-text with per-word timestamps.
//
// Wraps Apple's Speech framework. The editor view model asks for permission,
// then transcribes the extracted audio file into `TranscribedWord`s.
// Recognition runs on device when the language supports it, so audio never
// leaves the phone. Long files can produce several final results; each one is
// folded in with `TranscriptMerger`.

import CaptionerKit
import Foundation
import Speech

protocol SpeechTranscribing: Sendable {
    /// Asks for Speech Recognition permission if needed. Returns whether it is granted.
    func requestAuthorization() async -> Bool
    func transcribe(audioURL: URL) async throws -> [TranscribedWord]
}

struct AppleSpeechTranscriber: SpeechTranscribing {
    func requestAuthorization() async -> Bool {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            // The explicit @Sendable keeps this closure off the main actor.
            // Speech calls it on a background queue, and a main-actor closure
            // there would trip Swift 6's runtime isolation check.
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status)
            }
        }
        return status == .authorized
    }

    func transcribe(audioURL: URL) async throws -> [TranscribedWord] {
        // Uses the device's current language.
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw CaptionerError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        request.taskHint = .dictation
        // On-device recognition is private and has no server-side length
        // limit. Languages without an on-device model fall back to Apple's
        // servers, which cap a request at roughly one minute of audio.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let (results, continuation) = AsyncThrowingStream<[TranscribedWord], Error>.makeStream()
        let delegate = RecognitionDelegate(continuation: continuation)
        let task = RecognitionTaskBox(task: recognizer.recognitionTask(with: request, delegate: delegate))
        continuation.onTermination = { @Sendable _ in
            task.cancel()
        }

        var words: [TranscribedWord] = []
        do {
            for try await finalWords in results {
                words = TranscriptMerger.merge(words, with: finalWords)
            }
        } catch {
            // Recognizers often end long files with an error (such as "no
            // speech detected" for trailing silence) after delivering good
            // results. Keep what arrived; only fail if nothing did.
            if words.isEmpty {
                throw CaptionerError.transcriptionFailed(error.localizedDescription)
            }
        }
        // Keep the recognizer and delegate alive until recognition finishes;
        // ARC may otherwise release them after their last visible use above.
        withExtendedLifetime((recognizer, delegate)) {}

        guard !words.isEmpty else {
            throw CaptionerError.noSpeechDetected
        }
        return words
    }
}

/// Forwards Speech delegate callbacks into an async stream. Each final
/// utterance becomes one stream element; the task's completion ends the stream.
private final class RecognitionDelegate: NSObject, SFSpeechRecognitionTaskDelegate, Sendable {
    private let continuation: AsyncThrowingStream<[TranscribedWord], Error>.Continuation

    init(continuation: AsyncThrowingStream<[TranscribedWord], Error>.Continuation) {
        self.continuation = continuation
        super.init()
    }

    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        let words = recognitionResult.bestTranscription.segments.map { segment in
            TranscribedWord(
                text: segment.substring,
                start: segment.timestamp,
                end: segment.timestamp + segment.duration
            )
        }
        continuation.yield(words)
    }

    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        if successfully {
            continuation.finish()
        } else {
            continuation.finish(throwing: task.error ?? CaptionerError.noSpeechDetected)
        }
    }
}

/// Lets the stream's @Sendable termination handler cancel the recognition
/// task. `SFSpeechRecognitionTask.cancel()` is safe to call from any thread,
/// which is the invariant behind `@unchecked Sendable`.
private final class RecognitionTaskBox: @unchecked Sendable {
    private let task: SFSpeechRecognitionTask

    init(task: SFSpeechRecognitionTask) {
        self.task = task
    }

    func cancel() {
        task.cancel()
    }
}
