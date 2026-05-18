import Foundation

/// Engine that turns a `SlipFeatures` snapshot into a `CoachInsight` and answers
/// free-form questions. Two implementations:
/// - `RuleBasedCoach` (iOS 17+) — deterministic templated copy. Always available.
/// - `FoundationModelsCoach` (iOS 26+) — Apple Intelligence on-device LLM.
public protocol HabitCoachEngine: Sendable {
    func coach(features: SlipFeatures) async throws -> CoachInsight
    func answer(question: String, features: SlipFeatures) async throws -> String
    var supportsFreeFormChat: Bool { get }
}

public enum HabitCoachFactory {
    /// Returns the best available coach for this device + OS.
    /// Note: actual Foundation Models availability is gated on Apple Intelligence
    /// being on. We only return the FM-backed coach when the framework is present
    /// AND the user has it enabled.
    @MainActor
    public static func make() -> any HabitCoachEngine {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if FoundationModelsCoach.isAvailable {
                if let fm = try? FoundationModelsCoach() {
                    return fm
                }
            }
        }
        #endif
        return RuleBasedCoach()
    }
}
