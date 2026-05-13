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
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(DesignTokens.Accent.sunrise)
                    .frame(width: 28, height: 28)
                    .overlay(Rectangle().stroke(DesignTokens.Accent.sunrise.darker(by: 0.2), lineWidth: 2))
                    .overlay(
                        PixelText(".", pixelSize: 3, color: .black)
                    )
                VStack(alignment: .leading, spacing: 6) {
                    PixelText("EASE UP", pixelSize: 2, color: DesignTokens.Accent.sunrise)
                    Text("Want to pause one habit? Less can be more right now.")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundColor(DesignTokens.Surface.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    PixelText("X", pixelSize: 2, color: DesignTokens.Surface.mutedText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss calm mode banner")
            }
            HStack {
                Spacer()
                Button(action: onManage) {
                    PixelText("MANAGE HABITS", pixelSize: 2, color: .black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(DesignTokens.Accent.sunrise)
                        .overlay(Rectangle().stroke(DesignTokens.Accent.sunrise.darker(by: 0.2), lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Manage habits")
            }
        }
        .padding(12)
        .background(DesignTokens.Surface.card)
        .overlay(Rectangle().stroke(DesignTokens.Accent.sunrise, lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calm mode suggestion: pause one habit if helpful")
    }
}
