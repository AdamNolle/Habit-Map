import Foundation
import UIKit

/// Semantic haptics. Inject via EnvironmentObject and call from any interactive
/// surface. All calls are no-ops when `UserSettings.hapticsEnabled == false`.
///
/// Levels (mapped to Apple's haptics primitives):
/// - `selection()` — light "tick" for picker / tab / chip changes
/// - `tap()` — light impact for routine taps (button press, single cell tap)
/// - `complete()` — medium impact + success notification for hitting a goal
/// - `warn()` — warning notification (calm-mode appears, risk insight appears)
/// - `success()` — success notification (habit created, settings saved)
/// - `failure()` — error notification (reset confirmed, delete confirmed)
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
        // Pre-warm generators to reduce first-fire latency
        selectionGen.prepare()
        lightGen.prepare()
        mediumGen.prepare()
        heavyGen.prepare()
        notificationGen.prepare()
    }

    public func selection() {
        guard isEnabled else { return }
        selectionGen.selectionChanged()
        selectionGen.prepare()
    }

    public func tap() {
        guard isEnabled else { return }
        lightGen.impactOccurred(intensity: 0.7)
        lightGen.prepare()
    }

    public func complete() {
        guard isEnabled else { return }
        mediumGen.impactOccurred(intensity: 1.0)
        notificationGen.notificationOccurred(.success)
        mediumGen.prepare()
        notificationGen.prepare()
    }

    public func warn() {
        guard isEnabled else { return }
        notificationGen.notificationOccurred(.warning)
        notificationGen.prepare()
    }

    public func success() {
        guard isEnabled else { return }
        notificationGen.notificationOccurred(.success)
        notificationGen.prepare()
    }

    public func failure() {
        guard isEnabled else { return }
        heavyGen.impactOccurred()
        notificationGen.notificationOccurred(.error)
        heavyGen.prepare()
        notificationGen.prepare()
    }
}
