import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class PixelIconSnapshotTests: XCTestCase {
    func test_homeIcon() { snap(.home) }
    func test_gridIcon() { snap(.grid) }
    func test_plusIcon() { snap(.plus) }
    func test_chartIcon() { snap(.chart) }
    func test_gearIcon() { snap(.gear) }

    func test_iconScalesCleanly() {
        let view = PixelIcon(.home, color: Color(hex: "#2BFF5F"), size: 72)
            .background(Color.black)
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    private func snap(_ name: PixelIconName, file: StaticString = #file, testName: String = #function, line: UInt = #line) {
        let view = PixelIcon(name, color: Color(hex: "#2BFF5F"), size: 48)
            .background(Color.black)
        assertSnapshot(of: view, as: .image(precision: 0.99), file: file, testName: testName, line: line)
    }
}
