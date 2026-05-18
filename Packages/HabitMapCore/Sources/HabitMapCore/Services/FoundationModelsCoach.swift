import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// iOS 26+ Apple Intelligence on-device LLM. All inference happens on the Neural
/// Engine; no data leaves the device. Falls back to the rule-based coach when
/// Apple Intelligence isn't available on the user's device.
@available(iOS 26.0, *)
public final class FoundationModelsCoach: HabitCoachEngine {
    public var supportsFreeFormChat: Bool { true }

    private let session: LanguageModelSession

    /// Check before constructing — Apple Intelligence requires a supported device
    /// AND that the user has it turned on in Settings.
    public static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    public init() throws {
        let instructions = """
        You are a non-punishing habit coach inside an iOS app called Habit Map.
        The user shares their recent habit-tracking data as structured JSON.
        Respond in 2-3 short sentences with the single most useful observation
        and (when relevant) one concrete suggested action.

        Hard rules:
        - Never use the words: broken, failed, missed, you didn't, streak lost.
        - Speak in second person, warm but direct.
        - Don't moralize. Don't make assumptions about why the user is the way they are.
        - When data is sparse, say so plainly instead of inventing patterns.
        """
        self.session = LanguageModelSession(instructions: instructions)
    }

    public func coach(features: SlipFeatures) async throws -> CoachInsight {
        let json = try JSONEncoder().encode(features)
        let jsonString = String(data: json, encoding: .utf8) ?? "{}"
        let prompt = """
        Analyze this habit data and produce a single CoachInsight as JSON.

        Data:
        \(jsonString)

        Respond with ONLY a JSON object — no commentary, no markdown fences — shaped like:
        {
          "headline": "<short 1-line summary>",
          "paragraph": "<2-3 sentences>",
          "suggestion": "<optional concrete next action, or null>"
        }
        """
        let response = try await session.respond(to: prompt)
        let text = response.content
        if let parsed = parse(jsonString: text) {
            return parsed
        }
        // Fallback if the model didn't return well-formed JSON: use the raw text as paragraph.
        return CoachInsight(
            headline: "Coach take",
            paragraph: text,
            suggestion: nil
        )
    }

    public func answer(question: String, features: SlipFeatures) async throws -> String {
        let json = try JSONEncoder().encode(features)
        let jsonString = String(data: json, encoding: .utf8) ?? "{}"
        let prompt = """
        Recent habit data:
        \(jsonString)

        Question: \(question)

        Answer in 1-3 sentences.
        """
        let response = try await session.respond(to: prompt)
        return response.content
    }

    private func parse(jsonString: String) -> CoachInsight? {
        // Strip any markdown code fences the model might wrap with.
        var trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            // Drop the leading fence line, then trailing fence.
            if let firstNewline = trimmed.firstIndex(of: "\n") {
                trimmed = String(trimmed[trimmed.index(after: firstNewline)...])
            }
            if let lastFence = trimmed.range(of: "```", options: .backwards) {
                trimmed = String(trimmed[..<lastFence.lowerBound])
            }
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = trimmed.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        guard let headline = dict["headline"] as? String,
              let paragraph = dict["paragraph"] as? String else {
            return nil
        }
        let suggestion = dict["suggestion"] as? String
        return CoachInsight(
            headline: headline,
            paragraph: paragraph,
            suggestion: (suggestion?.isEmpty == false) ? suggestion : nil
        )
    }
}

#else
// Stub so calling code can `if #available(iOS 26.0, *)` without conditional imports.
@available(iOS 26.0, *)
public final class FoundationModelsCoach: HabitCoachEngine {
    public var supportsFreeFormChat: Bool { false }
    public static var isAvailable: Bool { false }
    public init() throws {
        throw NSError(domain: "FoundationModelsCoach", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "FoundationModels framework unavailable in this build."])
    }
    public func coach(features: SlipFeatures) async throws -> CoachInsight { .learning }
    public func answer(question: String, features: SlipFeatures) async throws -> String { "" }
}
#endif
