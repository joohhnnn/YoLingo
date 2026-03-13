import AppKit
import Combine
import SwiftUI

// MARK: - AppDelegate

/// 应用代理，管理：
/// 1. 全局 fn 键监听的启动/停止
/// 2. 各个窗口（覆盖层、悬浮卡片、抓词浮窗、复习窗口）的生命周期
/// 3. Menu bar 图标和菜单
/// 4. 事件总线订阅，协调各窗口之间的联动
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Dependencies

    private let container = AppContainer()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Windows

    private var captureOverlayWindow: CaptureOverlayWindow?
    private var capturePopoverWindow: CapturePopoverWindow?
    private var floatingCardWindow: FloatingCardWindow?
    private var reviewWindow: ReviewWindow?
    private var settingsWindow: SettingsWindow?
    private var isFloatingCardVisible = true

    // MARK: - Menu Bar

    private var statusItem: NSStatusItem?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 配置文件日志（日志同时写入 ~/Library/Logs/YoLingo.log）
        setupFileLogging()
        NSLog("[YoLingo] ========== applicationDidFinishLaunching 开始 ==========")

        // 1. 检查权限
        checkPermissions()

        // 2. 设置 menu bar 图标
        setupMenuBar()

        // 3. 启动抓词覆盖层（全屏透明，不影响操作）
        setupCaptureOverlay()

        // 4. 启动抓词浮窗（初始隐藏，抓词成功后弹出）
        setupCapturePopover()

        // 5. 启动悬浮卡片
        setupFloatingCard()

        // 6. 订阅事件总线，协调窗口联动
        subscribeToEvents()

        // 7. 开始监听 fn 键
        container.captureService.startListening()

        // 隐藏 Dock 图标（作为 menu bar app 运行）
        // NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        container.captureService.stopListening()
    }

    // MARK: - Setup

    private func checkPermissions() {
        let axTrusted = AXIsProcessTrusted()
        NSLog("[YoLingo] 权限检查 — Accessibility: %@", axTrusted ? "✅" : "❌")
        if !axTrusted {
            AccessibilityCapturer.requestPermission()
        }
    }

    /// 将 NSLog 输出同时写入文件，方便排查
    private func setupFileLogging() {
        let logDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs")
        let logFile = logDir.appendingPathComponent("YoLingo.log")
        // 清空旧日志
        try? "".write(to: logFile, atomically: true, encoding: .utf8)
        // 重定向 stderr 到日志文件（NSLog 输出到 stderr）
        freopen(logFile.path.cString(using: .utf8), "a", stderr)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "book.circle", accessibilityDescription: "YoLingo")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开复习", action: #selector(openReview), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "显示/隐藏悬浮卡片", action: #selector(toggleFloatingCard), keyEquivalent: "f"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "偏好设置...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "查看诊断日志", action: #selector(openDiagnosticLog), keyEquivalent: "d"))
        menu.addItem(NSMenuItem(title: "检查权限状态", action: #selector(showPermissionStatus), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 YoLingo", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @MainActor
    private func setupCaptureOverlay() {
        let vm = container.makeCaptureOverlayVM()
        captureOverlayWindow = CaptureOverlayWindow(viewModel: vm)
        captureOverlayWindow?.show()
    }

    @MainActor
    private func setupCapturePopover() {
        let vm = container.makeCapturePopoverVM()
        capturePopoverWindow = CapturePopoverWindow(viewModel: vm)
    }

    @MainActor
    private func setupFloatingCard() {
        let vm = container.makeFloatingCardVM()
        floatingCardWindow = FloatingCardWindow(viewModel: vm)
        floatingCardWindow?.show()
    }

    /// 订阅事件总线，在 AppDelegate 层协调各窗口
    private func subscribeToEvents() {
        container.eventBus.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .wordCaptured(let result):
                    // 抓词成功 → 在鼠标位置弹出浮窗
                    self?.capturePopoverWindow?.show(near: result.position)

                case .wordSaved:
                    // 新词入库 → 触感反馈
                    NSHapticFeedbackManager.defaultPerformer.perform(
                        .alignment,
                        performanceTime: .now
                    )

                case .settingsChanged(let key):
                    switch key {
                    case .floatingCardPosition, .floatingCardOpacity:
                        break  // FloatingCardVM handles this
                    default:
                        break
                    }

                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Menu Actions

    @objc private func openReview() {
        Task { @MainActor in
            if reviewWindow == nil {
                let vm = container.makeReviewVM()
                reviewWindow = ReviewWindow(viewModel: vm)
            }
            reviewWindow?.show()
        }
    }

    @objc private func toggleFloatingCard() {
        if isFloatingCardVisible {
            floatingCardWindow?.hide()
        } else {
            floatingCardWindow?.show()
        }
        isFloatingCardVisible.toggle()
    }

    @objc private func openSettings() {
        Task { @MainActor in
            if settingsWindow == nil {
                let vm = container.makeSettingsVM()
                settingsWindow = SettingsWindow(viewModel: vm)
            }
            settingsWindow?.show()
        }
    }

    @objc private func openDiagnosticLog() {
        let logFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/YoLingo.log")
        NSWorkspace.shared.open(logFile)
    }

    @objc private func showPermissionStatus() {
        let ax = AXIsProcessTrusted()

        // 检查 Globe 键系统设置
        let fnUsageType = UserDefaults.standard.object(forKey: "com.apple.HIToolbox.AppleFnUsageType")
        let fnSetting: String
        if let val = fnUsageType as? Int {
            switch val {
            case 0: fnSetting = "不执行任何操作 ✅"
            case 1: fnSetting = "切换输入法 ⚠️"
            case 2: fnSetting = "显示表情与符号 ⚠️"
            case 3: fnSetting = "开始听写 ⚠️"
            default: fnSetting = "未知 (\(val))"
            }
        } else {
            // 无法直接读取，用命令行读
            fnSetting = "（请用终端执行：defaults read com.apple.HIToolbox AppleFnUsageType）"
        }

        let message = """
        【权限状态】
        辅助功能 (Accessibility): \(ax ? "✅ 已授权" : "❌ 未授权")

        【系统设置】
        按下 🌐 键时: \(fnSetting)

        【需要的设置】
        1. 系统设置 → 隐私与安全性 → 辅助功能 → 打开 YoLingo ✅
        2. 系统设置 → 隐私与安全性 → 输入监控 → 打开 YoLingo ✅
        3. 系统设置 → 键盘 → "按下 🌐 键时" → 建议设为"不执行任何操作"

        【日志文件】
        ~/Library/Logs/YoLingo.log
        """

        let alert = NSAlert()
        alert.messageText = "YoLingo 诊断信息"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开辅助功能设置")
        alert.addButton(withTitle: "打开输入监控设置")
        alert.addButton(withTitle: "好的")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 打开辅助功能设置
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        } else if response == .alertSecondButtonReturn {
            // 打开输入监控设置
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
