// YoLingo/Services/Settings/Localizer.swift
import Foundation

// MARK: - Localizer

/// 简易本地化工具
/// 根据用户选择的 app_language 加载对应的 .strings 文件
struct Localizer {
    static func string(_ key: String, table: String = "Settings") -> String {
        let language = UserDefaults.standard.string(forKey: "app_language") ?? "zh-Hans"

        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // Fallback: try zh-Hans
            if let fallback = Bundle.main.path(forResource: "zh-Hans", ofType: "lproj"),
               let fallbackBundle = Bundle(path: fallback) {
                return fallbackBundle.localizedString(forKey: key, value: key, table: table)
            }
            return key
        }

        return bundle.localizedString(forKey: key, value: key, table: table)
    }
}
