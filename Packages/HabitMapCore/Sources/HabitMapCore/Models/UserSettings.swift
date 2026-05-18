import Foundation
import SwiftData

@Model
public final class UserSettings {
    public var id: UUID = UUID()
    public var defaultPageId: UUID?
    public var showRecoveryRate: Bool = true
    public var calmModeThreshold: Double = 0.40
    public var restDaysDontCount: Bool = true
    public var notificationToneRaw: String = NotificationTone.gentle.rawValue
    public var dailyReminderTime: Date?
    public var weeklyReflectionEnabled: Bool = true
    public var riskAlertsEnabled: Bool = true
    public var iCloudSyncEnabled: Bool = true
    public var themeAccentHex: String = "#2BFF5F"
    public var displayModeRaw: String = DisplayMode.auto.rawValue
    public var hapticsEnabled: Bool = true

    public init(id: UUID = UUID(),
                showRecoveryRate: Bool = true,
                calmModeThreshold: Double = 0.40,
                restDaysDontCount: Bool = true,
                notificationTone: NotificationTone = .gentle,
                dailyReminderTime: Date? = nil,
                weeklyReflectionEnabled: Bool = true,
                riskAlertsEnabled: Bool = true,
                iCloudSyncEnabled: Bool = true,
                themeAccentHex: String = "#2BFF5F",
                displayMode: DisplayMode = .auto,
                hapticsEnabled: Bool = true) {
        self.id = id
        self.showRecoveryRate = showRecoveryRate
        self.calmModeThreshold = calmModeThreshold
        self.restDaysDontCount = restDaysDontCount
        self.notificationToneRaw = notificationTone.rawValue
        self.dailyReminderTime = dailyReminderTime
        self.weeklyReflectionEnabled = weeklyReflectionEnabled
        self.riskAlertsEnabled = riskAlertsEnabled
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.themeAccentHex = themeAccentHex
        self.displayModeRaw = displayMode.rawValue
        self.hapticsEnabled = hapticsEnabled
    }

    public var notificationTone: NotificationTone {
        get { NotificationTone(rawValue: notificationToneRaw) ?? .gentle }
        set { notificationToneRaw = newValue.rawValue }
    }

    public var displayMode: DisplayMode {
        get { DisplayMode(rawValue: displayModeRaw) ?? .auto }
        set { displayModeRaw = newValue.rawValue }
    }
}

public enum NotificationTone: String, Codable, Sendable {
    case gentle, direct
}

public enum DisplayMode: String, Codable, Sendable, CaseIterable {
    case dark, light, auto
}
