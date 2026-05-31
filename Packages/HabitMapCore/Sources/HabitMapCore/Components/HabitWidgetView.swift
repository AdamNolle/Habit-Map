import SwiftUI

/// Home-screen widget face. Lives in the package (not the extension) so it can be
/// reused, previewed, and snapshot-tested without a widget host. The extension
/// wraps this in `WidgetKit` plumbing and a `containerBackground`.
public struct HabitWidgetView: View {
    let snapshot: WidgetSnapshot
    let isCompact: Bool

    public init(snapshot: WidgetSnapshot, isCompact: Bool = true) {
        self.snapshot = snapshot
        self.isCompact = isCompact
    }

    private var accent: Color { Color(hex: snapshot.accentHex) }

    public var body: some View {
        Group {
            if isCompact { compact } else { wide }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(DesignTokens.Surface.bg)
    }

    private var eyebrow: some View {
        HStack(spacing: 5) {
            Pip(color: accent, size: 5)
            Text("HABIT MAP")
                .font(.custom(FontFamily.mono, size: 9))
                .fontWeight(.semibold)
                .tracking(1.6)
                .foregroundColor(DesignTokens.Surface.mutedText)
        }
    }

    private var consistencyBlock: some View {
        HStack(alignment: .lastTextBaseline, spacing: 1) {
            MonoNum("\(snapshot.consistencyPct)", size: 38, color: accent)
            MonoNum("%", size: 16, color: accent)
        }
    }

    private var compact: some View {
        VStack(alignment: .leading, spacing: 6) {
            eyebrow
            Spacer(minLength: 0)
            consistencyBlock
            Text("30-day consistency")
                .font(.custom(FontFamily.sans, size: 10))
                .foregroundColor(DesignTokens.Surface.mutedText)
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                miniStat(label: "TODAY", value: "\(snapshot.todayDone)/\(snapshot.todayTotal)")
                miniStat(label: "STREAK", value: "\(snapshot.currentStreak)d")
            }
        }
        .padding(14)
    }

    private var wide: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                eyebrow
                Spacer(minLength: 0)
                consistencyBlock
                Text("30-day consistency")
                    .font(.custom(FontFamily.sans, size: 10))
                    .foregroundColor(DesignTokens.Surface.mutedText)
            }
            Rectangle()
                .fill(DesignTokens.Surface.hairline())
                .frame(width: 1)
            VStack(alignment: .leading, spacing: 12) {
                miniStat(label: "TODAY", value: "\(snapshot.todayDone)/\(snapshot.todayTotal)")
                miniStat(label: "STREAK", value: "\(snapshot.currentStreak)d")
                miniStat(label: "DONE", value: snapshot.todayComplete ? "YES" : "—")
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.custom(FontFamily.mono, size: 8))
                .fontWeight(.semibold)
                .tracking(1.0)
                .foregroundColor(DesignTokens.Surface.mutedText)
            Text(value)
                .font(.custom(FontFamily.mono, size: 15))
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundColor(DesignTokens.Surface.fg())
        }
    }
}
