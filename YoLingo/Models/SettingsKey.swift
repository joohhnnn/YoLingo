import Foundation

// MARK: - SettingsKey

/// 设置项标识，用于 EventBus 通知哪个设置发生了变化
enum SettingsKey: String {
    case appLanguage
    case launchAtLogin
    case aiProvider
    case apiKey
    case floatingCardPosition
    case floatingCardOpacity
}
