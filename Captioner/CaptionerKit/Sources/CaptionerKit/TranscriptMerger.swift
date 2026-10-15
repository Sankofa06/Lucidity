// TranscriptMerger.swift
// Folds successive final speech-recognition results into one word list.
//
// Long-form recognition can deliver several "final" results for one file:
// one per utterance, or cumulative results that repeat earlier words. This
// pure merger keeps the words already committed and appends only the incoming
// words that begin after them, so either delivery pattern yields one clean,
// ordered transcript. The app's speech service calls this for every final
// result it receives.

import Foundation

public enum TranscriptMerger {
    /// Slack allowed when deciding whether an incoming word starts after the
    /// committed transcript. Recognizers round timestamps, so an exact
    /// comparison would drop words that start right at the boundary.
    public static let overlapTolerance: TimeInterval = 0.05

    /// Returns `committed` followed by the words of `incoming` that start after
    /// the committed transcript ends. Blank words are discarded.
    public static func merge(
        _ committed: [TranscribedWord],
        with incoming: [TranscribedWord]
    ) -> [TranscribedWord] {
        let candidates = incoming
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.start < $1.start }

        guard let lastCommitted = committed.last else {
            return candidates
        }

        let fresh = candidates.filter { word in
            // A cumulative result repeats the final committed word verbatim;
            // skip it even when its duration is shorter than the tolerance.
            word != lastCommitted && word.start >= lastCommitted.end - overlapTolerance
        }
        return committed + fresh
    }
}
