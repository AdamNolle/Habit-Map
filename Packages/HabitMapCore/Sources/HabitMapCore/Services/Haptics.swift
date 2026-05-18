import Foundation
import UIKit

/// Semantic haptics. Inject via EnvironmentObject and call from any interactive
/// surface. All calls are no-ops when `isEnabled == false`.
@MainActor
public final class Haptics: ObservableObject {
    public var isEnabled: Bool

    private let selectionGen = UISelectionFeedbackGenerator()
    private let lightGen = UIImpactFeedbackGenerator(style: .light)
    private let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGen = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGen = UINotificationFeedbackGenerator()

    public init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
        selectionGen.prepare()
        lightGen.prepare()
        mediumGen.prepare()
        heavyGen.prepare()
        notificationGen.prepare()
    }

    // MARK: - Navigation

    /// Very light "tick" for page swipes between Today pages.
    public func pageSwipe() {
        guard isEnabled else { return }
        selectionGen.selectionChanged()
        selectionGen.prepare()
    }

    /// Subtle tick for tab bar changes.
    public func tabChange() {
        guard isEnabled else { return }
        selectionGen.selectionChanged()
        selectionGen.prepare()
    }

    /// Picker or list item selection (weekday picker, emoji, swatch, chip).
    public func selection() {
        guard isEnabled else { return }
        selectionGen.selectionChanged()
        selectionGen.prepare()
    }

    /// Filter chip toggle.
    public func filterChange() {
        guard isEnabled else { return }
        selectionGen.selectionChanged()
        selectionGen.prepare()
    }

    // MARK: - Habit Interactions

    /// Completing a habit — celebratory medium impact followed by success notification.
    public func habitComplete() {
        guard isEnabled else { return }
        mediumGen.impactOccurred(intensity: 0.85)
        mediumGen.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self, self.isEnabled else { return }
            self.notificationGen.notificationOccurred(.success)
            self.notificationGen.prepare()
        }
    }

    /// Uncompleting a habit — lighter than completing.
    public func habitUncomplete() {
        guard isEnabled else { return }
        lightGen.impactOccurred(intensity: 0.5)
        lightGen.prepare()
    }

    /// Multi-rep incremental step. Intensity scales with progress; last rep fires
    /// the same feel as habitComplete().
    public func multiStep(step: Int, of total: Int) {
        guard isEnabled else { return }
        if step >= total {
            mediumGen.impactOccurred(intensity: 1.0)
            mediumGen.prepare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self, self.isEnabled else { return }
                self.notificationGen.notificationOccurred(.success)
                self.notificationGen.prepare()
            }
        } else {
            let fraction = total > 0 ? Double(step) / Double(total) : 0.5
            let intensity = 0.4 + (fraction * 0.45)
            lightGen.impactOccurred(intensity: intensity)
            lightGen.prepare()
        }
    }

    // MARK: - Generic Taps

    /// Light impact for routine button/FAB taps.
    public func tap() {
        guard isEnabled else { return }
        lightGen.impactOccurred(intensity: 0.7)
        lightGen.prepare()
    }

    // MARK: - Wizard & Sheets

    /// Wizard step navigation.
    public func wizardStep() {
        guard isEnabled else { return }
        lightGen.impactOccurred(intensity: 0.6)
        lightGen.prepare()
    }

    /// Sheet/modal presentation.
    public func sheetPresent() {
        guard isEnabled else { return }
        lightGen.impactOccurred(intensity: 0.45)
        lightGen.prepare()
    }

    // MARK: - Notifications

    /// Goal or milestone completed — success notification.
    public func complete() {
        guard isEnabled else { return }
        mediumGen.impactOccurred(intensity: 1.0)
        notificationGen.notificationOccurred(.success)
        mediumGen.prepare()
        notificationGen.prepare()
    }

    /// Warning condition appeared (calm mode, risk insight).
    public func warn() {
        guard isEnabled else { return }
        notificationGen.notificationOccurred(.warning)
        notificationGen.prepare()
    }

    /// Save or creation succeeded.
    public func success() {
        guard isEnabled else { return }
        notificationGen.notificationOccurred(.success)
        notificationGen.prepare()
    }

    /// Destructive action confirmed (reset, delete).
    public func failure() {
        guard isEnabled else { return }
        heavyGen.impactOccurred()
        notificationGen.notificationOccurred(.error)
        heavyGen.prepare()
        notificationGen.prepare()
    }
}
