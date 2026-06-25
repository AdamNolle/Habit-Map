import SwiftUI
import HabitMapCore

struct CoachChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let body: String

    enum Role { case user, coach }
}

struct CoachChatView: View {
    @Environment(\.dismiss) private var dismiss
    let features: SlipFeatures

    @State private var coach: (any HabitCoachEngine)?
    @State private var messages: [CoachChatMessage] = []
    @State private var draft: String = ""
    @State private var isThinking = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let coach, !coach.supportsFreeFormChat {
                    unavailableBanner
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(messages) { message in
                                messageBubble(message)
                                    .id(message.id)
                            }
                            if isThinking {
                                HStack(spacing: 6) {
                                    ProgressView().scaleEffect(0.7)
                                    MonoText("coach is thinking…", size: .footnote, weight: .regular,
                                             color: DesignTokens.Surface.mutedText)
                                }
                                .padding(.horizontal, 10)
                            }
                        }
                        .padding(DesignTokens.Spacing.md)
                    }
                    .onChange(of: messages) { _, _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                inputBar
            }
            .background(DesignTokens.Surface.bg)
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            if coach == nil {
                coach = HabitCoachFactory.make()
            }
        }
    }

    private var unavailableBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoText("LIMITED MODE", size: .caption, weight: .heavy,
                     color: DesignTokens.Accent.sunrise)
            MonoText("Free-form questions need Apple Intelligence (iOS 26+). On older devices you'll get templated answers — still useful for slip windows, idle habits, and stacking.",
                     size: .footnote, weight: .regular,
                     color: DesignTokens.Surface.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(DesignTokens.Accent.sunrise, lineWidth: 2))
        .padding(DesignTokens.Spacing.md)
    }

    @ViewBuilder
    private func messageBubble(_ message: CoachChatMessage) -> some View {
        let bubbleColor = message.role == .user ? DesignTokens.Accent.classicGreen : DesignTokens.Accent.lilac
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.role == .user ? "You" : "Coach")
                    .font(.custom(FontFamily.sans, size: 10))
                    .fontWeight(.semibold)
                    .kerning(0.4)
                    .textCase(.uppercase)
                    .foregroundColor(bubbleColor)
                Text(message.body)
                    .font(.custom(FontFamily.sans, size: 14))
                    .foregroundColor(DesignTokens.Surface.fg())
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(DesignTokens.Surface.card)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(bubbleColor.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            if message.role == .coach { Spacer(minLength: 40) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about your patterns…", text: $draft)
                .font(.custom(FontFamily.sans, size: 15))
                .padding(10)
                .background(DesignTokens.Surface.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(DesignTokens.Surface.hairline(), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .submitLabel(.send)
                .onSubmit { send() }
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(draft.trimmingCharacters(in: .whitespaces).isEmpty
                                     ? DesignTokens.Surface.dimText
                                     : DesignTokens.Accent.lilac)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Send")
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, 8)
        .background(DesignTokens.Surface.bg)
        .overlay(Rectangle().fill(DesignTokens.Surface.cardBorder).frame(height: 1), alignment: .top)
    }

    @MainActor
    private func send() {
        guard let coach else { return }
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        messages.append(CoachChatMessage(role: .user, body: trimmed))
        draft = ""
        isThinking = true
        Task {
            defer { isThinking = false }
            do {
                let reply = try await coach.answer(question: trimmed, features: features)
                messages.append(CoachChatMessage(role: .coach, body: reply))
            } catch {
                messages.append(CoachChatMessage(role: .coach,
                                                 body: "Couldn't answer: \(error.localizedDescription)"))
            }
        }
    }
}
