// YoLingo/Services/Settings/SettingsService.swift
import Foundation
import Combine
import ServiceManagement

// MARK: - SettingsService

/// UserDefaults + Keychain 实现的设置服务
/// 每次写入后自动通过 EventBus 广播变更
final class SettingsService: SettingsServiceProtocol {

    private let eventBus: EventBus
    private let defaults: UserDefaults
    private let keychainService: String

    init(
        eventBus: EventBus,
        defaults: UserDefaults = .standard,
        keychainService: String = "com.yolingo.api-key"
    ) {
        self.eventBus = eventBus
        self.defaults = defaults
        self.keychainService = keychainService
    }

    // MARK: - General

    var appLanguage: String {
        defaults.string(forKey: "app_language") ?? "zh-Hans"
    }

    func setAppLanguage(_ language: String) {
        defaults.set(language, forKey: "app_language")
        eventBus.emit(.settingsChanged(.appLanguage))
    }

    var launchAtLogin: Bool {
        defaults.bool(forKey: "launch_at_login")
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            defaults.set(enabled, forKey: "launch_at_login")
            eventBus.emit(.settingsChanged(.launchAtLogin))
        } catch {
            NSLog("[Settings] Launch at login toggle failed: %@", error.localizedDescription)
        }
    }

    // MARK: - AI

    var aiProvider: String {
        defaults.string(forKey: "ai_provider") ?? "openai"
    }

    func setAIProvider(_ provider: String) {
        defaults.set(provider, forKey: "ai_provider")
        eventBus.emit(.settingsChanged(.aiProvider))
    }

    func getAPIKey(for provider: String) -> String? {
        guard let data = KeychainHelper.read(
            service: keychainService, account: provider
        ) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func setAPIKey(_ key: String, for provider: String) throws {
        guard let data = key.data(using: .utf8) else { return }
        try KeychainHelper.save(
            service: keychainService, account: provider, data: data
        )
        eventBus.emit(.settingsChanged(.apiKey))
    }

    // MARK: - Floating Card

    var floatingCardPosition: FloatingCardPosition {
        guard let raw = defaults.string(forKey: "floating_card_position"),
              let pos = FloatingCardPosition(rawValue: raw) else {
            return .bottomRight
        }
        return pos
    }

    func setFloatingCardPosition(_ position: FloatingCardPosition) {
        defaults.set(position.rawValue, forKey: "floating_card_position")
        eventBus.emit(.settingsChanged(.floatingCardPosition))
    }

    var floatingCardOpacity: Double {
        let val = defaults.double(forKey: "floating_card_opacity")
        return val == 0 ? 0.85 : val  // UserDefaults returns 0 for unset keys
    }

    func setFloatingCardOpacity(_ opacity: Double) {
        defaults.set(opacity, forKey: "floating_card_opacity")
        eventBus.emit(.settingsChanged(.floatingCardOpacity))
    }

    // MARK: - About

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (Build \(build))"
    }
}
