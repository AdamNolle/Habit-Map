import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class PulseChartSnapshotTests: XCTestCase {
    private let accent = Color(hex: "#2BFF5F")
    private let ramp: [Double] = (0..<30).map { Double($0) / 29.0 }
    private let flat: [Double] = Array(repeating: 0.7, count: 30)
    private let mixed: [Double] = (0..<30).map { i in i % 3 == 0 ? 0.0 : (i % 3 == 1 ? 0.5 : 1.0) }
    private let empty: [Double] = Array(repeating: 0.0, count: 30)

    func test_rampData() {
        snap(PulseChart(data: ramp, accent: accent))
    }

    func test_flatData() {
        snap(PulseChart(data: flat, accent: accent))
    }

    func test_mixedData() {
        snap(PulseChart(data: mixed, accent: accent))
    }

    func test_emptyData() {
        snap(PulseChart(data: empty, accent: accent))
    }
}

private func snap(_ view: some View, file: StaticString = #file,
                  testName: String = #function, line: UInt = #line) {
    let wrapped = view
        .frame(width: 310, height: 100)
        .padding(16)
        .background(Color.black)
    assertSnapshot(of: wrapped, as: .image(precision: 0.99), file: file, testName: testName, line: line)
}
