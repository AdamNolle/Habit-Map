import SwiftUI
import HabitMapCore

struct CoachSection: View {
    let features: SlipFeatures
    let onAskMore: () -> Void

    @State private var insight: CoachInsight?
    @State private var isLoading = false
    @State private var error: String?
    @State private var coach: (any HabitCoachEngine)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(DesignTokens.Accent.lilac)
                        .frame(width: 12, height: 12)
                        .overlay(Rectangle().stroke(DesignTokens.Accent.lilac.darker(by: 0.2), lineWidth: 1))
                    MonoText("YOUR COACH", size: .footnote, weight: .heavy,
                             color: DesignTokens.Accent.lilac)
                }
                Spacer()
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DesignTokens.Surface.mutedText)
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                        .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                   value: isLoading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh coach insight")
            }

            if let insight {
                MonoText(insight.headline, size: .body, weight: .heavy, color: .white)
                    .fixedSize(horizontal: false, vertical: true)
                MonoText(insight.paragraph, size: .footnote, weight: .regular,
                         color: DesignTokens.Surface.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
                if let suggestion = insight.suggestion {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(DesignTokens.Accent.lilac)
                            .padding(.top, 2)
                        MonoText(suggestion, size: .footnote, weight: .regular,
                                 color: DesignTokens.Accent.lilac)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else if isLoading {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7).tint(DesignTokens.Accent.lilac)
                    MonoText("thinking…", size: .footnote, weight: .regular,
                             color: DesignTokens.Surface.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let error {
                MonoText(error, size: .footnote, weight: .regular,
                         color: DesignTokens.Surface.miss)
            }

            if coach?.supportsFreeFormChat ?? false {
                HStack {
                    Spacer()
                    Button(action: onAskMore) {
                        HStack(spacing: 6) {
                            MonoText("ASK MORE", size: .caption, weight: .heavy,
                                     color: DesignTokens.Accent.lilac)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(DesignTokens.Accent.lilac)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(10)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(DesignTokens.Accent.lilac, lineWidth: 2))
        .task {
            if coach == nil {
                coach = HabitCoachFactory.make()
            }
            if insight == nil { await refresh() }
        }
    }

    @MainActor
    private func refresh() async {
        guard let coach else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            insight = try await coach.coach(features: features)
        } catch {
            self.error = "Couldn't refresh: \(error.localizedDescription)"
        }
    }
}
