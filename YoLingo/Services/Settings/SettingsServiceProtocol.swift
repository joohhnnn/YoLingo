// YoLingo/Services/Settings/SettingsServiceProtocol.swift
import Foundation

// MARK: - SettingsServiceProtocol

/// 设置服务协议：读取和修改应用配置
/// setter 方法内部会持久化并通过 EventBus 广播变更
protocol SettingsServiceProtocol {
    // General
    var appLanguage: String { get }
    func setAppLanguage(_ language: String)

    var launchAtLogin: Bool { get }
    func setLaunchAtLogin(_ enabled: Bool)

    // AI
    var aiProvider: String { get }
    func setAIProvider(_ provider: String)

    func getAPIKey(for provider: String) -> String?
    func setAPIKey(_ key: String, for provider: String) throws

    // Floating Card
    var floatingCardPosition: FloatingCardPosition { get }
    func setFloatingCardPosition(_ position: FloatingCardPosition)

    var floatingCardOpacity: Double { get }
    func setFloatingCardOpacity(_ opacity: Double)

    // About (read-only)
    var appVersion: String { get }
}
