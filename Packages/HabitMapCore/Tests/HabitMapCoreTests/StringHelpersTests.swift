import XCTest
@testable import HabitMapCore

final class StringHelpersTests: XCTestCase {
    func test_titleCased_upperToTitle() {
        XCTAssertEqual("DRINK WATER".titleCased, "Drink Water")
    }

    func test_titleCased_lowerToTitle() {
        XCTAssertEqual("no soda today".titleCased, "No Soda Today")
    }

    func test_titleCased_mixedCaseNormalises() {
        XCTAssertEqual("hELLo WoRLD".titleCased, "Hello World")
    }

    func test_titleCased_singleWord() {
        XCTAssertEqual("meditate".titleCased, "Meditate")
    }

    func test_titleCased_empty() {
        XCTAssertEqual("".titleCased, "")
    }

    func test_titleCased_preservesInteriorWhitespace() {
        XCTAssertEqual("a  b".titleCased, "A  B")
    }

    func test_titleCased_leadingWhitespace() {
        XCTAssertEqual(" hi".titleCased, " Hi")
    }
}
