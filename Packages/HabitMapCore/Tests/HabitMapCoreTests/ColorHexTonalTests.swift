import XCTest
import SwiftUI
@testable import HabitMapCore

final class ColorHexTonalTests: XCTestCase {
    func test_tonalAccent_darkScheme_returnsOriginal() {
        let original = Color.tonalAccent("#3DFF7F", scheme: .dark)
        let expected = Color(hex: "#3DFF7F")
        XCTAssertEqual(original.rgbaComponents.r, expected.rgbaComponents.r, accuracy: 0.01)
        XCTAssertEqual(original.rgbaComponents.g, expected.rgbaComponents.g, accuracy: 0.01)
    }

    func test_tonalAccent_lightScheme_remapsKnownGreens() {
        let remapped = Color.tonalAccent("#3DFF7F", scheme: .light)
        let expected = Color(hex: "#1F7A3E")
        XCTAssertEqual(remapped.rgbaComponents.r, expected.rgbaComponents.r, accuracy: 0.01)
        XCTAssertEqual(remapped.rgbaComponents.g, expected.rgbaComponents.g, accuracy: 0.01)
    }

    func test_tonalAccent_lightScheme_unknownHexFallsThrough() {
        let unknown = Color.tonalAccent("#123456", scheme: .light)
        let original = Color(hex: "#123456")
        XCTAssertEqual(unknown.rgbaComponents.r, original.rgbaComponents.r, accuracy: 0.01)
    }

    func test_tonalAccent_caseInsensitive() {
        let upper = Color.tonalAccent("#3DA4FF", scheme: .light)
        let lower = Color.tonalAccent("#3da4ff", scheme: .light)
        XCTAssertEqual(upper.rgbaComponents.r, lower.rgbaComponents.r, accuracy: 0.01)
    }
}
