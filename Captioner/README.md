# Captioner

Captioner is an iPhone app that adds animated, word-by-word captions to your
videos, in the style of Captions (captions.ai) and CapCut's auto-captions.
Transcription runs on the device.

It is a clean-room rebuild of that core workflow, not a copy of either app.
No code, assets, or binaries from Captions or CapCut were used or decompiled.

## What it does

1. **Pick a video** from Photos.
2. **Auto-transcribe** with Apple's Speech framework. Word-level timestamps
   come back, and recognition is on device whenever your language supports it.
3. **Style**: four presets (Karaoke, Pop, Boxed, Minimal), plus size and
   position sliders. The karaoke presets highlight each word as it's spoken.
4. **Fix**: tap a caption to edit it. Edited words are re-timed across the
   original spoken span. Clearing the text deletes the caption.
5. **Export**: a `.mov` with captions burned in (share sheet › Save Video),
   or an `.srt` subtitle file. If captions, style, or the project changes
   while a video is encoding, that result is discarded; export again to share
   the current edit.

## Parity with Captions / CapCut

| Feature | Captioner |
| --- | --- |
| Auto captions with word timing | ✅ |
| Animated word highlight (karaoke) | ✅ |
| Caption style presets, size, position | ✅ |
| Edit caption text | ✅ |
| Burned-in export and `.srt` export | ✅ |
| Private, on-device transcription | ✅ (when the language supports it) |
| In-app camera / teleprompter | ❌ Record with the Camera app, then import |
| Trimming, cuts, filler-word removal | ❌ |
| AI dubbing, eye contact, AI avatars, music | ❌ Server-side generative features are out of scope |
| Custom fonts, per-word emoji, animations beyond highlight | ❌ |

## Known limits

- Transcription uses the iPhone's current language
  (Settings › General › Language & Region).
- Languages without an on-device model fall back to Apple's servers. Those
  requests are capped at about one minute of audio.
- Export draws one bitmap per highlighted word. That's fine for short-form
  video (a few minutes). Very long videos with karaoke styles use more memory.
- The SwiftUI preview and the burned-in export share the same layout ratios.
  Line wrapping can still differ by a word at the edges.

## Architecture

SwiftUI MVVM + Services, with the pure domain logic in a local Swift package.

```
Captioner/
├── project.yml                  XcodeGen spec (generate the .xcodeproj from this)
├── CaptionerKit/                Pure Swift package, Foundation only, runs on Linux too
│   └── Sources/CaptionerKit/
│       ├── TranscribedWord      one recognized word + timestamps
│       ├── TranscriptMerger     folds long-form recognizer results into one transcript
│       ├── CaptionGrouper       words → short cues (word/char limits, pauses, punctuation)
│       ├── CaptionEditor        text edits with proportional re-timing
│       ├── CaptionTimeline      active cue/word; export frame breakdown
│       ├── SubRipFormatter      .srt output
│       └── CaptionStyle         presets, colors, size/position math
├── Captioner/                   iOS app
│   ├── App/                     entry point, root phase switch
│   ├── Features/                Home, Editor (view model + views), Help
│   ├── Services/                Import, Media, Transcription, Export, Playback
│   ├── DesignSystem/            color bridging, shared caption metrics
│   └── Content/HelpContent      onboarding steps, glossary, tips (in-app help)
└── CaptionerTests/              view model tests with stub services
```

Pipeline (`EditorViewModel.loadVideo(at:)`):

```
PhotosPicker → ImportedMovie (copy to tmp) → AVVideoInspector (size, rotation)
  → AVAudioExtractor (.m4a) → AppleSpeechTranscriber (SFSpeechRecognizer, on device)
  → TranscriptMerger → CaptionGrouper → cues
Preview: PlaybackController.currentTime → CaptionTimeline → CaptionOverlayView
Export:  CaptionTimeline.frames → CaptionImageRenderer → CALayers
         → AVVideoCompositionCoreAnimationTool → AVAssetExportSession (.mov)
```

## Build and run on your iPhone

Requires a Mac with Xcode 16 or newer and XcodeGen (`brew install xcodegen`).

```sh
cd Captioner
xcodegen generate
open Captioner.xcodeproj
```

In Xcode, select the **Captioner** scheme, choose your iPhone as the
destination, and press Run. Signing uses team `5RGU344VJR` with automatic
signing. On a free Apple ID, change the team in Signing & Capabilities. Free
provisioning profiles expire after 7 days. The first launch on a device may
require trusting the developer profile under Settings › General › VPN & Device
Management.

## Tests

```sh
swift test --package-path Captioner/CaptionerKit          # domain, macOS or Linux
xcodebuild -project Captioner/Captioner.xcodeproj -scheme Captioner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test
```

CI (`.github/workflows/captioner.yml`) runs both on a GitHub-hosted macOS
runner, with warnings treated as errors.

## Versioning

`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` live in `project.yml`
(currently 0.1.0 build 1).
