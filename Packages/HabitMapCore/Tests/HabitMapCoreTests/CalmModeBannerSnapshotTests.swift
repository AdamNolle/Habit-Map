import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class CalmModeBannerSnapshotTests: SnapshotTestCase {
    func test_calmModeBanner() {
        let view = CalmModeBanner(onManage: {}, onDismiss: {})
            .frame(width: 360)
            .padding(16)
            .background(Color.black)
            .fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
