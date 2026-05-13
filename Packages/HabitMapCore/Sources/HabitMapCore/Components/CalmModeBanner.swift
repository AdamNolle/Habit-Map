import SwiftUI

public struct CalmModeBanner: View {
    let onManage: () -> Void
    let onDismiss: () -> Void

    public init(onManage: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.onManage = onManage
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(DesignTokens.Accent.sunrise)
                    .frame(width: 24, height: 24)
                    .overlay(Rectangle().stroke(DesignTokens.Accent.sunrise.darker(by: 0.2), lineWidth: 2))
                    .overlay(
                        PixelText("!", pixelSize: 2, color: .black)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    MonoText("EASE UP", size: .footnote, weight: .heavy,
                             color: DesignTokens.Accent.sunrise)
                    MonoText("Want to pause one habit? Less can be more right now.",
                             size: .body, weight: .regular,
                             color: DesignTokens.Surface.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DesignTokens.Surface.mutedText)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss calm mode banner")
            }
            HStack {
                Spacer()
                Button(action: onManage) {
                    MonoText("MANAGE HABITS", size: .footnote, weight: .heavy, color: .black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(DesignTokens.Accent.sunrise)
                        .overlay(Rectangle().stroke(DesignTokens.Accent.sunrise.darker(by: 0.2), lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Manage habits")
            }
        }
        .padding(10)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(DesignTokens.Accent.sunrise, lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calm mode suggestion: pause one habit if helpful")
    }
}
