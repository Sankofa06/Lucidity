// CaptionStyleTests.swift
// Verifies caption style math and preset behavior.

import Testing
@testable import CaptionerKit

struct CaptionStyleTests {
    @Test func fontSizeScalesWithShorterSide() {
        let style = CaptionStylePreset.karaoke.style

        #expect(style.fontSize(canvasWidth: 1080, canvasHeight: 1920) == style.relativeFontSize * 1080)
        #expect(style.fontSize(canvasWidth: 1920, canvasHeight: 1080) == style.relativeFontSize * 1080)
    }

    @Test func highlightColorOnlyAppliesToActiveWord() {
        let style = CaptionStylePreset.karaoke.style

        #expect(style.color(forWordAt: 1, highlightedIndex: 1) == .yellow)
        #expect(style.color(forWordAt: 0, highlightedIndex: 1) == .white)
        #expect(CaptionStylePreset.boxed.style.color(forWordAt: 1, highlightedIndex: 1) == .white)
    }

    @Test func uppercasingIsAStyleChoice() {
        #expect(CaptionStylePreset.karaoke.style.displayText("Hi") == "HI")
        #expect(CaptionStylePreset.minimal.style.displayText("Hi") == "Hi")
    }

    @Test func switchingPresetKeepsUserLayout() {
        var current = CaptionStylePreset.karaoke.style
        current.relativeFontSize = 0.09
        current.verticalPosition = 0.3

        let next = CaptionStylePreset.boxed.style(keepingLayoutOf: current)

        #expect(next.relativeFontSize == 0.09)
        #expect(next.verticalPosition == 0.3)
        #expect(next.backgroundColor == CaptionStylePreset.boxed.style.backgroundColor)
    }

    @Test func presetDefaultsStayInsideSliderRanges() {
        for preset in CaptionStylePreset.allCases {
            #expect(CaptionStyle.fontSizeRange.contains(preset.style.relativeFontSize))
            #expect(CaptionStyle.verticalPositionRange.contains(preset.style.verticalPosition))
        }
    }
}
