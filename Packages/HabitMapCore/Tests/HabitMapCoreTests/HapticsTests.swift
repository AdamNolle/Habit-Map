import XCTest
@testable import HabitMapCore

@MainActor
final class HapticsTests: XCTestCase {
    func test_canInstantiate() {
        let h = Haptics()
        XCTAssertTrue(h.isEnabled)
    }

    func test_disabledByDefault_whenPassedFalse() {
        let h = Haptics(isEnabled: false)
        XCTAssertFalse(h.isEnabled)
    }

    func test_isEnabledToggle() {
        let h = Haptics(isEnabled: true)
        h.isEnabled = false
        XCTAssertFalse(h.isEnabled)
        h.isEnabled = true
        XCTAssertTrue(h.isEnabled)
    }

    // Smoke tests — methods must not crash in simulator/test context.

    func test_navigationMethods_doNotCrash() {
        let h = Haptics()
        h.pageSwipe()
        h.tabChange()
        h.selection()
        h.filterChange()
    }

    func test_habitInteractionMethods_doNotCrash() {
        let h = Haptics()
        h.habitComplete()
        h.habitUncomplete()
    }

    func test_multiStep_allSteps_doNotCrash() {
        let h = Haptics()
        for step in 0...5 {
            h.multiStep(step: step, of: 5)
        }
    }

    func test_multiStep_singleRep_doNotCrash() {
        let h = Haptics()
        h.multiStep(step: 1, of: 1)
    }

    func test_multiStep_zeroDenominator_doNotCrash() {
        let h = Haptics()
        h.multiStep(step: 0, of: 0)
    }

    func test_sheetAndWizardMethods_doNotCrash() {
        let h = Haptics()
        h.sheetPresent()
        h.wizardStep()
    }

    func test_notificationMethods_doNotCrash() {
        let h = Haptics()
        h.tap()
        h.complete()
        h.warn()
        h.success()
        h.failure()
    }

    func test_allMethodsDisabled_doNotCrash() {
        let h = Haptics(isEnabled: false)
        h.pageSwipe(); h.tabChange(); h.selection(); h.filterChange()
        h.habitComplete(); h.habitUncomplete()
        h.multiStep(step: 1, of: 3)
        h.tap(); h.wizardStep(); h.sheetPresent()
        h.complete(); h.warn(); h.success(); h.failure()
    }
}
