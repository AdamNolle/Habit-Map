import XCTest
import SwiftUI
import SnapshotTesting
@testable import HabitMapCore

final class RiskHeatmapSnapshotTests: XCTestCase {
    func test_empty() {
        let view = RiskHeatmap(forecast: .empty, accent: Color(hex: "#2BFF5F"))
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }

    func test_sampleMatrix() {
        var matrix: [[RiskLevel]] = Array(repeating: Array(repeating: .noData, count: 8), count: 7)
        matrix[0][2] = .completed4
        matrix[5][4] = .danger
        matrix[5][5] = .warn
        matrix[3][1] = .completed3
        let f = RiskForecast(matrix: matrix, topRisks: [])
        let view = RiskHeatmap(forecast: f, accent: Color(hex: "#2BFF5F"))
            .padding(16).background(Color.black).fixedSize()
        assertSnapshot(of: view, as: .image(precision: 0.99))
    }
}
