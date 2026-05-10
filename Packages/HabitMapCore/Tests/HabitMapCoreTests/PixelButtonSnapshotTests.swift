import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class PixelButtonSnapshotTests: XCTestCase {
    private func host<V: View>(_ view: V) -> some View {
        view.frame(width: 240).padding(16).background(Color.black).fixedSize()
    }

    func test_primary() {
        assertSnapshot(of: host(PixelButton("SAVE", style: .primary) {}),
                       as: .image(precision: 0.99))
    }
    func test_secondary() {
        assertSnapshot(of: host(PixelButton("CANCEL", style: .secondary) {}),
                       as: .image(precision: 0.99))
    }
    func test_destructive() {
        assertSnapshot(of: host(PixelButton("DELETE", style: .destructive) {}),
                       as: .image(precision: 0.99))
    }
    func test_disabled() {
        assertSnapshot(of: host(PixelButton("NEXT", isEnabled: false) {}),
                       as: .image(precision: 0.99))
    }
}
