import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class HabitCellSnapshotTests: XCTestCase {
    private let accent = Color(hex: "#2BFF5F")

    func test_empty()       { snap(.empty) }
    func test_p25()         { snap(.p25) }
    func test_p50()         { snap(.p50) }
    func test_p75()         { snap(.p75) }
    func test_p100()        { snap(.p100) }
    func test_miss()        { snap(.miss) }
    func test_rest()        { snap(.rest) }
    func test_future()      { snap(.future) }
    func test_today_p50()   { snap(.p50, isToday: true) }
    func test_today_empty() { snap(.empty, isToday: true) }

    func test_levelMapping() {
        XCTAssertEqual(CellLevel.from(progress: 0.0), .empty)
        XCTAssertEqual(CellLevel.from(progress: 0.1), .p25)
        XCTAssertEqual(CellLevel.from(progress: 0.25), .p25)
        XCTAssertEqual(CellLevel.from(progress: 0.5), .p50)
        XCTAssertEqual(CellLevel.from(progress: 0.75), .p75)
        XCTAssertEqual(CellLevel.from(progress: 1.0), .p100)
        XCTAssertEqual(CellLevel.from(progress: 1.5), .p100)
    }

    private func snap(_ level: CellLevel, isToday: Bool = false, file: StaticString = #file, testName: String = #function, line: UInt = #line) {
        let view = HabitCell(level: level, accent: accent, isToday: isToday, size: 64)
            .padding(8)
            .background(Color.black)
        assertSnapshot(of: view, as: .image(precision: 0.99), file: file, testName: testName, line: line)
    }
}
