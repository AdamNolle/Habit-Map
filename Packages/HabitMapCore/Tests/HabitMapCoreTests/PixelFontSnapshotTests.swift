import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class PixelFontSnapshotTests: SnapshotTestCase {
    func test_singleLetter_A() {
        let view = PixelText("A", pixelSize: 4, color: .white)
            .frame(width: 24, height: 32)
            .background(Color.black)
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_word_TODAY() {
        let view = PixelText("TODAY", pixelSize: 4, color: Color(hex: "#2BFF5F"))
            .padding(8)
            .background(Color.black)
            .fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_allAlphabetGlyphsExist() {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        for char in letters {
            XCTAssertNotNil(PixelFontGlyphs.rows(for: char), "Missing glyph for \(char)")
        }
    }

    func test_unknownCharFallsBackToBlock() {
        let rows = PixelFontGlyphs.rows(for: "\u{2603}") ?? PixelFontGlyphs.fallback
        XCTAssertEqual(rows, PixelFontGlyphs.fallback)
    }

    func test_plusGlyph_exists() {
        XCTAssertNotNil(PixelFontGlyphs.rows(for: "+"))
    }

    func test_minusGlyph_exists() {
        XCTAssertNotNil(PixelFontGlyphs.rows(for: "-"))
    }

    func test_punctuationGlyphs_exist() {
        for char in Array("!?',()<>") {
            XCTAssertNotNil(PixelFontGlyphs.rows(for: char), "Missing glyph for \(char)")
        }
    }
}
