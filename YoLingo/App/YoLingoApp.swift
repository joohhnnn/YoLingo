import SwiftUI

// MARK: - YoLingoApp

/// 应用入口
/// 使用 AppDelegate 管理全局快捷键、窗口和 menu bar
@main
struct YoLingoApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 使用 Settings scene 提供偏好设置窗口
        Settings {
            Text("YoLingo 设置")
                .frame(width: 400, height: 300)
        }
    }
}
