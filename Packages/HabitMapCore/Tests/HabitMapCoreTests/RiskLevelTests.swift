import XCTest
@testable import HabitMapCore

/// `RiskLevel` is `Comparable` by raw severity. The risk heatmap and top-risk
/// ranking both rely on this ordering being monotonic.
final class RiskLevelTests: XCTestCase {
    func test_orderingIsMonotonicBySeverity() {
        let ascending: [RiskLevel] = [.noData, .completed4, .completed3, .completed2, .completed1, .warn, .danger]
        for i in 0..<(ascending.count - 1) {
            XCTAssertLessThan(ascending[i], ascending[i + 1],
                              "\(ascending[i]) should rank below \(ascending[i + 1])")
        }
    }

    func test_dangerIsMax() {
        XCTAssertEqual(RiskLevel.allCasesOrdered.max(), .danger)
    }

    func test_noDataIsMin() {
        XCTAssertEqual(RiskLevel.allCasesOrdered.min(), .noData)
    }

    func test_rawValuesAreStable() {
        // The matrix is Equatable/serialised by raw value; pin them.
        XCTAssertEqual(RiskLevel.noData.rawValue, 0)
        XCTAssertEqual(RiskLevel.warn.rawValue, 5)
        XCTAssertEqual(RiskLevel.danger.rawValue, 6)
    }
}

private extension RiskLevel {
    static let allCasesOrdered: [RiskLevel] =
        [.noData, .completed4, .completed3, .completed2, .completed1, .warn, .danger]
}
