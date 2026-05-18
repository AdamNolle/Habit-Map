import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

@MainActor
final class FABSnapshotTests: XCTestCase {
    func test_fab() {
        let view = FAB { }
            .environmentObject(Haptics())
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
