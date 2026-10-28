// HelpContent.swift
// Static onboarding steps and glossary shown in the app.
//
// Single source of truth for in-app help: `HomeView` shows the steps as
// onboarding and `HelpView` shows steps, glossary, and tips. Keep this in sync
// with `Captioner/README.md` whenever a user-facing concept changes.

import Foundation

struct HelpStep: Identifiable, Sendable {
    let id: Int
    let symbolName: String
    let title: String
    let detail: String
}

struct GlossaryEntry: Identifiable, Sendable {
    var id: String { term }
    let term: String
    let definition: String
}

enum HelpContent {
    static let steps: [HelpStep] = [
        HelpStep(id: 1, symbolName: "video.badge.plus", title: "Pick a video", detail: "Choose any video with speech from your library. Record with the Camera app first if you need a new clip."),
        HelpStep(id: 2, symbolName: "waveform", title: "Auto-transcribe", detail: "Captioner listens to the audio and writes captions with word-level timing, on your iPhone."),
        HelpStep(id: 3, symbolName: "textformat", title: "Style and fix", detail: "Pick a look, drag the size and position sliders, and tap any caption to fix a word."),
        HelpStep(id: 4, symbolName: "square.and.arrow.up", title: "Export", detail: "Export a video with captions burned in, or an .srt subtitle file for YouTube, CapCut, or Premiere.")
    ]

    static let glossary: [GlossaryEntry] = [
        GlossaryEntry(term: "Caption", definition: "A short group of words shown on screen together. Captioner shows a few words at a time, the way short-form videos do."),
        GlossaryEntry(term: "Karaoke highlight", definition: "The word being spoken changes color as you hear it. The Karaoke and Pop styles use it."),
        GlossaryEntry(term: "Style", definition: "A ready-made caption look: Karaoke, Pop, Boxed, or Minimal. Your size and position settings carry over when you switch."),
        GlossaryEntry(term: "Burn in", definition: "Draw captions into the video picture itself, so they show everywhere, including on Instagram, TikTok, and in messages."),
        GlossaryEntry(term: "SRT", definition: "A plain subtitle file with timings. Upload it next to your video where platforms support separate captions."),
        GlossaryEntry(term: "On-device transcription", definition: "Speech recognition that runs on your iPhone. When your language supports it, audio never leaves the phone.")
    ]

    static let tips: [String] = [
        "Clear speech with little background music gives the best transcripts.",
        "Clearing a caption's text and saving deletes that caption.",
        "Captioner uses your iPhone's language. Change it in Settings › General › Language & Region.",
        "If your language can't be transcribed on device, Apple's servers are used, and only about the first minute is captioned."
    ]
}
