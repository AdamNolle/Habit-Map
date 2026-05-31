import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

@MainActor
final class LayoutComponentsSnapshotTests: SnapshotTestCase {
    private let accent = Color(hex: "#2BFF5F")

    func test_glassCard() {
        let view = GlassCard(cornerRadius: 16, padding: 18) {
            Text("CARD")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: 200)
        .padding(16).background(Color.black)
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_iconTile_done() {
        let view = IconTile(symbol: "drop.fill", accent: accent, done: true, size: 40)
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_iconTile_notDone() {
        let view = IconTile(symbol: "drop.fill", accent: accent, done: false, size: 40)
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_chip_selected() {
        let view = Chip(label: "All habits", isSelected: true, accent: accent) {}
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_chip_unselected() {
        let view = Chip(label: "Health", isSelected: false, accent: accent) {}
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_appButton_filled() {
        let view = AppButton("CONTINUE", style: .filled, accent: accent) {}
            .environmentObject(Haptics())
            .frame(width: 220)
            .padding(16).background(Color.black)
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
