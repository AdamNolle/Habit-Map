import SwiftUI

/// Editorial section header: uppercase sans title + hairline spacer + optional mono action label.
public struct SectionHeader: View {
    let title: String
    let action: String?

    public init(_ title: String, action: String? = nil) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(.custom(FontFamily.sans, size: 11))
                .fontWeight(.bold)
                .tracking(11 * 0.14)
                .foregroundColor(DesignTokens.Surface.fgDim())
            Rectangle()
                .fill(DesignTokens.Surface.hairline())
                .frame(maxWidth: .infinity, maxHeight: 1)
            if let action {
                Text(action.uppercased())
                    .font(.custom(FontFamily.mono, size: 9.5))
                    .fontWeight(.semibold)
                    .tracking(9.5 * 0.18)
                    .foregroundColor(DesignTokens.Surface.mutedText)
            }
        }
    }
}
