import XCTest
import SwiftUI
@testable import HabitMapCore

final class ColorHexTests: XCTestCase {
    func test_parsesHexWithHashPrefix() {
        let c = Color(hex: "#2BFF5F")
        let rgba = c.rgbaComponents
        XCTAssertEqual(rgba.r, 0x2B / 255.0, accuracy: 0.01)
        XCTAssertEqual(rgba.g, 0xFF / 255.0, accuracy: 0.01)
        XCTAssertEqual(rgba.b, 0x5F / 255.0, accuracy: 0.01)
        XCTAssertEqual(rgba.a, 1.0, accuracy: 0.01)
    }

    func test_parsesHexWithoutHashPrefix() {
        let c = Color(hex: "FF4D4D")
        XCTAssertEqual(c.rgbaComponents.r, 1.0, accuracy: 0.01)
    }

    func test_parsesHexWithAlpha() {
        let c = Color(hex: "#FF000080")
        XCTAssertEqual(c.rgbaComponents.a, 128.0 / 255.0, accuracy: 0.01)
    }

    func test_invalidHexFallsBackToClear() {
        let c = Color(hex: "not a hex")
        XCTAssertEqual(c.rgbaComponents.a, 0.0)
    }

    func test_lighterIncreasesBrightness() {
        let base = Color(hex: "#808080")
        let lighter = base.lighter(by: 0.3)
        XCTAssertGreaterThan(lighter.rgbaComponents.r, base.rgbaComponents.r)
    }

    func test_darkerDecreasesBrightness() {
        let base = Color(hex: "#808080")
        let darker = base.darker(by: 0.3)
        XCTAssertLessThan(darker.rgbaComponents.r, base.rgbaComponents.r)
    }
}
